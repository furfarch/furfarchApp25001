import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        previewLayer.frame = uiView.bounds
    }
}

struct LivePlateScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = CameraScannerModel()
    private var scanner: CameraScanner
    @State private var showCameraAlert = false
    @State private var cameraAlertMessage: String = ""
    var onPlateRecognized: (String) -> Void = { _ in }

    init() {
        let model = CameraScannerModel()
        _model = StateObject(wrappedValue: model)
        self.scanner = CameraScanner(model: model)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(previewLayer: scanner.previewLayer)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if let best = model.latestResult?.bestMatch {
                    Text(best)
                        .font(.largeTitle).bold()
                        .padding(12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 40)
                } else {
                    Text("Point camera at plate")
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                HStack(spacing: 16) {
                    Button("Start Scan") { scanner.start() }
                        .buttonStyle(.borderedProminent)
                    Button("Stop") { scanner.stop() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 30)
        }
        .onAppear {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                scanner.start()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        if granted { scanner.start() }
                        else {
                            cameraAlertMessage = "Camera access was denied. Please enable it in Settings to use live scanning."
                            showCameraAlert = true
                        }
                    }
                }
            case .denied, .restricted:
                cameraAlertMessage = "Camera access is not available. Please enable Camera permission in Settings."
                showCameraAlert = true
            @unknown default:
                break
            }
        }
        .onChange(of: model.cameraError) { old, new in
            if let e = new { cameraAlertMessage = e; showCameraAlert = true }
        }
        .onDisappear { scanner.stop() }
        .alert(isPresented: $showCameraAlert) {
            Alert(title: Text("Camera Unavailable"), message: Text(cameraAlertMessage), primaryButton: .default(Text("Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }, secondaryButton: .cancel())
        }
    }
}

#Preview {
    LivePlateScannerView()
}
