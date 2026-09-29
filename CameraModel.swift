import AVFoundation
import SwiftUI

@MainActor
final class CameraModel: ObservableObject {
    let session = AVCaptureSession()
    private var position: AVCaptureDevice.Position = .back

    func requestPermissionAndStart() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        configure(position: position)
    }

    func flipCamera() {
        position = position == .back ? .front : .back
        configure(position: position)
    }

    private func configure(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
            if !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async { [session] in
                    session.startRunning()
                }
            }
        }

        session.inputs.forEach { session.removeInput($0) }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)
        session.sessionPreset = .high
    }
}
