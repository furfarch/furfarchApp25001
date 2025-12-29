import SwiftUI
import UIKit

struct CarPhotoPickerView: View {
    @State private var showingCamera = false
    @State private var image: UIImage?
    var onImagePicked: (UIImage) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(alignment: .bottomTrailing) {
                        Text("Retake")
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding(8)
                    }
                    .onTapGesture { showingCamera = true }
            } else {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Car Photo", systemImage: "camera")
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker { img in
                showingCamera = false
                guard let img else { return }
                image = img
                onImagePicked(img)
            }
        }
    }
}
