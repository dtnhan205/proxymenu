import SwiftUI
import AVFoundation
import AVKit

/// Màn hình xem video hướng dẫn "Cách Cài : How to install"
/// - Hiển thị video `cach_cai.mp4` trong ứng dụng
/// - Nút "X" góc trên để đóng video
/// - Nút tua lùi 10 giây (-10s)
/// - Nút tua tới 10 giây (+10s)
/// - Nút tạm dừng / tiếp tục phát (Play / Pause)
/// - Thanh tiến trình scrub thời gian mượt mà
struct HowToInstallVideoView: View {
    @Binding var isPresented: Bool
    var isEnglish: Bool = false

    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = true
    @State private var currentTime: Double = 0.0
    @State private var duration: Double = 0.0
    @State private var isDraggingSlider: Bool = false
    @State private var sliderValue: Double = 0.0
    @State private var timeObserverToken: Any?
    @State private var hasFinished: Bool = false
    @State private var loadError: String? = nil

    var body: some View {
        ZStack {
            // Nền tối mờ cao cấp phong cách Cyber HUD
            Color.black.opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header Bar với Tiêu đề & Nút "X" Đóng Video
                HStack(alignment: .center, spacing: 12) {
                    // Biểu tượng video phát sáng
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [CyberTheme.mechaGold, Color(red: 0.8, green: 0.45, blue: 0.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)
                            .shadow(color: CyberTheme.mechaGold.opacity(0.5), radius: 6)

                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isEnglish ? "HOW TO INSTALL" : "HƯỚNG DẪN CÀI ĐẶT")
                            .font(.system(size: 15, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)

                        Text("Cách Cài : How to install")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(CyberTheme.mechaGold)
                    }

                    Spacer()

                    // Nút X để đóng video
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        closeAndDismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                                )

                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                Divider()
                    .background(Color.white.opacity(0.12))

                // MARK: - Khung Video Chính
                ZStack {
                    if let player = player {
                        TutorialPlayerView(player: player)
                            .aspectRatio(16/9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [CyberTheme.mechaGold.opacity(0.6), Color.white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.2
                                    )
                            )
                            .shadow(color: CyberTheme.mechaGold.opacity(0.25), radius: 12)
                            .padding(.horizontal, 14)
                            .onTapGesture {
                                togglePlayPause()
                            }
                    } else if let error = loadError {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 38))
                                .foregroundColor(CyberTheme.crimsonNeon)
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 240)
                    } else {
                        VStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: CyberTheme.mechaGold))
                                .scaleEffect(1.2)
                            Text(isEnglish ? "Loading tutorial video..." : "Đang tải video hướng dẫn...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: 240)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

                // MARK: - Thanh Tiến Trình Thời Gian (Scrub Slider)
                VStack(spacing: 6) {
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.mechaGold)

                        Spacer()

                        Text(formatTime(duration))
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .padding(.horizontal, 20)

                    // Thanh slider kéo thả thời gian
                    Slider(
                        value: Binding(
                            get: { isDraggingSlider ? sliderValue : currentTime },
                            set: { newValue in
                                isDraggingSlider = true
                                sliderValue = newValue
                            }
                        ),
                        in: 0...max(1.0, duration),
                        onEditingChanged: { editing in
                            if !editing {
                                seekToTime(sliderValue)
                                isDraggingSlider = false
                            }
                        }
                    )
                    .accentColor(CyberTheme.mechaGold)
                    .padding(.horizontal, 16)
                }

                // MARK: - Bộ Điều Khiển: [Tua Lùi 10s] - [Tạm Dừng / Phát] - [Tua Tới 10s]
                HStack(spacing: 32) {
                    // Nút Tua Lùi 10 Giây
                    Button {
                        seekRelative(-10.0)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.16))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                    )

                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("-10s")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)

                    // Nút Phát / Tạm Dừng Chính (Center Play / Pause Button)
                    Button {
                        togglePlayPause()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [CyberTheme.mechaGold, Color(red: 0.85, green: 0.5, blue: 0.0)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 62, height: 62)
                                .shadow(color: CyberTheme.mechaGold.opacity(0.55), radius: 8)
                                .overlay(
                                    Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                                )

                            if hasFinished {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 24, weight: .heavy))
                                    .foregroundColor(.white)
                            } else if isPlaying {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 22, weight: .heavy))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 22, weight: .heavy))
                                    .foregroundColor(.white)
                                    .offset(x: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Nút Tua Tới 10 Giây
                    Button {
                        seekRelative(10.0)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.16))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                    )

                                Image(systemName: "goforward.10")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("+10s")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)
                .padding(.bottom, 18)

                // Lời nhắc hỗ trợ bên dưới
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(CyberTheme.mechaGold)
                        .font(.system(size: 12))
                    Text(isEnglish ? "Watch the full video to install and inject properly" : "Xem kỹ video hướng dẫn để thực hiện cài đặt chuẩn xác")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            teardownPlayer()
        }
    }

    // MARK: - Quản lý Audio & Video Player

    private func setupPlayer() {
        // Cấu hình âm thanh playback để phát rõ ràng tiếng video hướng dẫn
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        guard let videoURL = resolveVideoURL() else {
            loadError = isEnglish ? "Tutorial video file (cach_cai.mp4) not found." : "Không tìm thấy file video hướng dẫn (cach_cai.mp4)."
            return
        }

        let item = AVPlayerItem(url: videoURL)
        let avPlayer = AVPlayer(playerItem: item)
        self.player = avPlayer

        // Lấy thời lượng ban đầu
        Task {
            if let d = try? await item.asset.load(.duration) {
                let seconds = CMTimeGetSeconds(d)
                if seconds.isFinite && seconds > 0 {
                    await MainActor.run {
                        self.duration = seconds
                    }
                }
            }
        }

        // Lắng nghe tiến trình thời gian định kỳ mỗi 0.25 giây
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let sec = CMTimeGetSeconds(time)
            if !self.isDraggingSlider && sec.isFinite {
                self.currentTime = sec
            }
            if let curItem = avPlayer.currentItem {
                let d = CMTimeGetSeconds(curItem.duration)
                if d.isFinite && d > 0 && self.duration != d {
                    self.duration = d
                }
            }
        }

        // Lắng nghe sự kiện phát hết video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            self.hasFinished = true
            self.isPlaying = false
        }

        avPlayer.play()
        self.isPlaying = true
        self.hasFinished = false
    }

    private func teardownPlayer() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }

    private func closeAndDismiss() {
        teardownPlayer()
        isPresented = false
    }

    private func togglePlayPause() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        guard let player = player else { return }
        if hasFinished {
            player.seek(to: .zero)
            player.play()
            hasFinished = false
            isPlaying = true
        } else if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    private func seekRelative(_ delta: Double) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        guard let player = player else { return }
        let currentSec = CMTimeGetSeconds(player.currentTime())
        let maxSec = max(0.0, duration > 0 ? duration : currentSec + delta)
        let targetSec = max(0.0, min(maxSec, currentSec + delta))
        seekToTime(targetSec)
    }

    private func seekToTime(_ targetSec: Double) {
        guard let player = player else { return }
        let time = CMTime(seconds: targetSec, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = targetSec
        if hasFinished && targetSec < duration {
            hasFinished = false
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let s = Int(seconds)
        let mins = s / 60
        let secs = s % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    /// Định vị file video cach_cai.mp4 linh hoạt
    private func resolveVideoURL() -> URL? {
        // 1. Thử Bundle URL tiêu chuẩn
        if let url = Bundle.main.url(forResource: "cach_cai", withExtension: "mp4") {
            return url
        }
        if let url = Bundle.main.url(forResource: "cach_cai", withExtension: "MP4") {
            return url
        }
        // 2. Thử đường dẫn trong bundle root
        let bPath = Bundle.main.bundlePath
        let p1 = "\(bPath)/cach_cai.mp4"
        if FileManager.default.fileExists(atPath: p1) {
            return URL(fileURLWithPath: p1)
        }
        // 3. Thử Documents directory
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let p2 = docs.appendingPathComponent("cach_cai.mp4")
            if FileManager.default.fileExists(atPath: p2.path) {
                return p2
            }
        }
        // 4. Thử Home directory
        let p3 = "\(NSHomeDirectory())/cach_cai.mp4"
        if FileManager.default.fileExists(atPath: p3) {
            return URL(fileURLWithPath: p3)
        }
        return nil
    }
}

/// View bọc AVPlayerLayer với chế độ resizeAspect chuẩn xác, không làm méo hình
struct TutorialPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> TutorialPlayerUIView {
        let view = TutorialPlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: TutorialPlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }

    class TutorialPlayerUIView: UIView {
        var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }

        override static var layerClass: AnyClass {
            return AVPlayerLayer.self
        }
    }
}
