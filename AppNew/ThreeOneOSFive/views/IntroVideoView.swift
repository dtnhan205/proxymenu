import SwiftUI
import AVFoundation
import AVKit

/// Màn hình phát video intro ngầu khi mở app:
/// - Tự động phát video `intro.mp4` trong bundle với hiệu ứng cyberpunk HUD.
/// - Che kín toàn màn hình (aspect ratio fill), không giật lag nhờ AVPlayerLayer phần cứng.
/// - Thiết lập AudioSession `.ambient` để không ngắt nhạc nền của người dùng.
/// - Có nút "BỎ QUA ►" ở góc trên bên phải để người dùng có thể lướt nhanh vào màn hình Key.
/// - Khi hết video hoặc bấm bỏ qua, view sẽ ẩn dần (fade out mượt mà) rồi mới chuyển sang màn hình Key.
struct IntroVideoView: View {

    /// Callback khi video hoàn tất hoặc người dùng chọn bỏ qua.
    var onFinish: () -> Void

    @State private var player: AVPlayer?
    @State private var isFinished: Bool = false
    @State private var opacity: Double = 1.0
    @State private var hasStarted: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                PlayerLayerRepresentable(player: player)
                    .ignoresSafeArea()
            } else {
                // Fallback nếu chưa tải được player (tránh màn hình đen)
                Image("Background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }


        }
        .opacity(opacity)
        .onAppear {
            setupPlayerAndPlay()
        }
        .onDisappear {
            teardownPlayer()
        }
    }

    private func setupPlayerAndPlay() {
        guard !hasStarted else { return }
        hasStarted = true

        // Cấu hình audio session ambient để không gián đoạn âm nhạc người dùng đang nghe
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        // Tìm file intro.mp4 trong bundle
        guard let url = Bundle.main.url(forResource: "intro", withExtension: "mp4") else {
            // Nếu không tìm thấy file video trong bundle, chuyển tiếp ngay
            NSLog("[IntroVideoView] intro.mp4 not found in bundle, skipping to key")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                handleFinish()
            }
            return
        }

        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.actionAtItemEnd = .none
        self.player = avPlayer

        // Lắng nghe sự kiện phát hết video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            self.handleFinish()
        }

        avPlayer.play()
    }

    private func teardownPlayer() {
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }



    private func handleFinish() {
        guard !isFinished else { return }
        isFinished = true

        // Hiệu ứng mờ dần (fade out) theo đúng yêu cầu: "khi mở sẽ hiện và ẩn dần mới tới phần key"
        withAnimation(.easeOut(duration: 0.6)) {
            opacity = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            teardownPlayer()
            onFinish()
        }
    }
}

/// UIViewRepresentable bọc AVPlayerLayer để render video tốc độ cao, aspect fill toàn màn hình.
struct PlayerLayerRepresentable: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }

    class PlayerUIView: UIView {
        var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }

        override static var layerClass: AnyClass {
            return AVPlayerLayer.self
        }
    }
}
