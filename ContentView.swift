import SwiftUI
import PhotosUI
import AVKit

struct ContentView: View {
    @StateObject private var camera = CameraModel()
    @State private var mode: SourceMode = .camera
    @State private var pickerItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    enum SourceMode: String {
        case camera = "Camera"
        case video = "Video"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if mode == .camera {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea()
                } else if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onAppear { player.play() }
                } else {
                    ContentUnavailableView(
                        "No Video Selected",
                        systemImage: "video",
                        description: Text("Tap Choose Video below.")
                    )
                }
            }

            VStack {
                HStack {
                    Picker("Source", selection: $mode) {
                        Text("Camera").tag(SourceMode.camera)
                        Text("Video").tag(SourceMode.video)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)

                    Spacer()

                    if mode == .camera {
                        Button {
                            camera.flipCamera()
                        } label: {
                            Image(systemName: "camera.rotate.fill")
                                .font(.title2)
                                .padding(12)
                                .background(.black.opacity(0.45), in: Circle())
                        }
                    }
                }
                .padding()

                Spacer()

                if mode == .video {
                    PhotosPicker(selection: $pickerItem, matching: .videos) {
                        Label("Choose Video", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.black.opacity(0.65), in: Capsule())
                    }
                    .padding(.bottom, 18)
                }

                HStack(spacing: 38) {
                    Button {
                        mode = .camera
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                    }

                    Circle()
                        .stroke(.white, lineWidth: 5)
                        .frame(width: 74, height: 74)
                        .overlay(Circle().fill(.white).padding(7))

                    Button {
                        mode = .video
                    } label: {
                        Image(systemName: "play.rectangle.fill")
                            .font(.title2)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .task {
            await camera.requestPermissionAndStart()
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadVideo(from: newItem) }
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .video {
                player?.play()
            } else {
                player?.pause()
            }
        }
    }

    @MainActor
    private func loadVideo(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try data.write(to: url, options: .atomic)

            videoURL = url
            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            looper = AVPlayerLooper(player: queue, templateItem: item)
            queue.isMuted = true
            player = queue
            mode = .video
            queue.play()
        } catch {
            print("Video import failed: \(error)")
        }
    }
}
