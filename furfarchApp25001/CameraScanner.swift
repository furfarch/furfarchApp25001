import Foundation
import AVFoundation
import UIKit
import Combine

@MainActor
final class CameraScannerModel: ObservableObject {
    @Published var latestResult: PlateRecognitionResult?
}

final class CameraScanner: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let previewLayer = AVCaptureVideoPreviewLayer()

    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "CameraScanner.VideoQueue")
    private var isProcessing = false

    private let model: CameraScannerModel

    init(model: CameraScannerModel) {
        self.model = model
        super.init()
        setupSession()
    }

    deinit {
        stop()
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            print("CameraScanner: cannot create camera input")
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(output) else {
            print("CameraScanner: cannot add video output")
            session.commitConfiguration()
            return
        }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                // Rotate frames for portrait UI. Common angles supported: 0, 90, 180, 270.
                let desiredAngle: CGFloat = 90
                if connection.isVideoRotationAngleSupported(desiredAngle) {
                    connection.videoRotationAngle = desiredAngle
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        session.commitConfiguration()
    }

    func start() {
        if !session.isRunning {
            session.startRunning()
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Prevent overlapping processing; add a safety reset in case the recognizer callback never fires
        guard !isProcessing else { return }
        isProcessing = true

        // Create a timeout work item that will reset isProcessing if the recognizer callback doesn't complete
        var timeoutWorkItem: DispatchWorkItem?
        timeoutWorkItem = DispatchWorkItem { [weak self] in
            print("CameraScanner: recognition timeout — resetting processing flag")
            self?.isProcessing = false
            timeoutWorkItem = nil
        }
        // schedule timeout on the same queue so we don't race with callback cancellation
        queue.asyncAfter(deadline: .now() + 2.0, execute: timeoutWorkItem!)

        // Call the existing recognizer API (keep API usage unchanged)
        PlateRecognizer.recognize(from: sampleBuffer) { [weak self] result in
            // cancel the timeout and set results on main actor
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil

            guard let self = self else { return }
            Task { @MainActor in
                self.model.latestResult = result
                // small defensive delay to avoid UI presentation/dismissal races
                // (ensure we do not remain stuck in processing if UI changes occur immediately)
                // Use async sleep to yield briefly on main actor
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                self.isProcessing = false
            }
        }
    }
}
