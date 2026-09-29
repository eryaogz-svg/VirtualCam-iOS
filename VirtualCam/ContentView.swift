import SwiftUI
import PhotosUI
import AVKit

struct ContentView: View {
    @StateObject private var camera = CameraModel()
    @State private var mode = 0
    @State private var pickerItem: PhotosPickerItem?
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if mode == 0 {
                CameraPreview(session: camera.session).ignoresSafeArea()
            } else if let player {
                VideoPlayer(player: player).ignoresSafeArea().onAppear { player.play() }
            } else {
                ContentUnavailableView("No Video Selected", systemImage: "video",
                    description: Text("Choose a video from Photos."))
            }

            VStack {
                HStack {
                    Picker("Source", selection: $mode) {
                        Text("Camera").tag(0)
                        Text("Video").tag(1)
                    }.pickerStyle(.segmented).frame(maxWidth: 260)
                    Spacer()
                    if mode == 0 {
                        Button { camera.flipCamera() } label: {
                            Image(systemName: "camera.rotate.fill").font(.title2)
                                .padding(12).background(.black.opacity(0.45), in: Circle())
                        }
                    }
                }.padding()
                Spacer()
                if mode == 1 {
                    PhotosPicker(selection: $pickerItem, matching: .videos) {
                        Label("Choose Video", systemImage: "photo.on.rectangle")
                            .font(.headline).padding(.horizontal,20).padding(.vertical,12)
                            .background(.black.opacity(0.65), in: Capsule())
                    }.padding(.bottom, 20)
                }
            }
        }
        .task { await camera.requestPermissionAndStart() }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadVideo(newItem) }
        }
        .onChange(of: mode) { _, newValue in
            if newValue == 1 { player?.play() } else { player?.pause() }
        }
    }

    @MainActor
    private func loadVideo(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            try data.write(to: url, options: .atomic)
            let queue = AVQueuePlayer()
            looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
            queue.isMuted = true
            player = queue
            mode = 1
            queue.play()
        } catch { print(error) }
    }
}
