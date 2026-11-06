import SwiftUI
import UIKit

// MARK: - ProxyClientView
//
// Màn hình quản lý proxy.
//
// Trạng thái hiển thị là trạng thái THẬT do `ProxyClient` công bố, được đặt sau
// khi request kiểm tra đi xuyên proxy thành công. Không có trạng thái giả lập.
//
// Phạm vi: proxy áp dụng cho các URLSession do ProxyClient tạo (kiểm tra kết nối).
// Không định tuyến toàn bộ traffic của hệ thống — điều đó cần NetworkExtension
// với entitlement hợp lệ trên App ID thật.

@MainActor
struct ProxyClientView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var store = ProxyConfigStore.shared
    @ObservedObject private var client = ProxyClient.shared

    @State private var editorConfig: ProxyConfiguration?
    @State private var pendingDelete: ProxyConfiguration?
    @State private var routingVerification: ProxyRoutingVerification?
    @State private var isVerifyingRouting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    statusCard
                    routingVerificationCard
                    scopeNotice
                    configurationsCard
                    addButton
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.vertical, 14)
            }
            .scrollContentBackgroundCompat()
            .scrollDismissesKeyboardCompat()
            .appBackground()
            .navigationTitle("Proxy Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.techBackgroundTop.opacity(0.85), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.neonCyan)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .preferredColorScheme(.dark)
        .sheet(item: $editorConfig) { config in
            ProxyEditorView(config: config)
        }
        .alert(
            "Xoá cấu hình?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Xoá", role: .destructive) {
                if let config = pendingDelete {
                    if client.activeConfiguration?.id == config.id {
                        client.disconnect()
                    }
                    store.delete(config.id)
                }
                pendingDelete = nil
            }
            Button("Huỷ", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDelete?.displayName ?? "")
        }
    }

    // MARK: - Status

    private var statusColor: Color {
        switch client.state {
        case .connected: return AppTheme.neonLime
        case .connecting: return AppTheme.neonAmber
        case .failed: return AppTheme.neonRed
        case .disconnected: return Color.white.opacity(0.45)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                PulsingDot(color: statusColor, size: 7)
                NeonReadout(text: "TRẠNG THÁI KẾT NỐI", tint: statusColor)
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: client.networkType.iconName)
                        .font(.caption2.weight(.bold))
                    Text(client.networkType.rawValue)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Color.white.opacity(0.65))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06), in: Capsule())
            }

            Text(client.state.title)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            if let config = client.activeConfiguration ?? store.selectedConfiguration {
                Text("\(config.proto.displayName) · \(config.endpoint)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.7))
            } else {
                Text("Chưa chọn cấu hình proxy.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            if let warning = client.connectionWarning, client.state.isConnected {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.neonAmber)
                    Text(warning)
                        .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(AppTheme.neonAmber.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.neonAmber.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            if case .failed(let message) = client.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.neonRed)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack(spacing: 10) {
                metricTile(
                    title: "IP HIỆN TẠI",
                    value: client.egressIP ?? "—",
                    tint: AppTheme.neonCyan
                )
                metricTile(
                    title: "THỜI GIAN",
                    value: client.state.isConnected ? ProxyDuration.hms(client.elapsed) : "—",
                    tint: AppTheme.neonViolet
                )
            }

            if let latency = client.lastTest?.tcpLatencyMs {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.caption2)
                    Text("Độ trễ TCP: \(latency) ms")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(AppTheme.neonAmber)
            }

            HStack(spacing: 10) {
                connectButton
                testButton
            }
        }
        .padding(16)
        .techCard(glow: statusColor, opacity: 0.16)
    }

    private func metricTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(Color.white.opacity(0.5))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private var connectButton: some View {
        let isConnected = client.state.isConnected
        let isBusy = client.state.isBusy
        let enabled = isConnected || (store.selectedConfiguration != nil && !isBusy)

        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if isConnected {
                client.disconnect()
            } else if let config = store.selectedConfiguration {
                let password = store.password(for: config.id)
                Task { await client.connect(config, password: password) }
            }
        } label: {
            HStack(spacing: 7) {
                if isBusy {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isConnected ? "stop.fill" : "power")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(isConnected ? "NGẮT KẾT NỐI" : "KẾT NỐI")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                isConnected ? AppTheme.neonRed : AppTheme.neonLime,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var testButton: some View {
        let config = client.activeConfiguration ?? store.selectedConfiguration
        return Button {
            guard let config else { return }
            let password = store.password(for: config.id)
            Task { await client.test(config, password: password) }
        } label: {
            HStack(spacing: 6) {
                if client.isTesting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 12, weight: .bold))
                }
                Text("KIỂM TRA")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(AppTheme.neonCyan)
            .frame(width: 118, height: 42)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(AppTheme.neonCyan.opacity(0.35), lineWidth: 1)
            )
            .opacity(config == nil ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(config == nil || client.isTesting)
    }

    // MARK: - Routing verification card

    /// Xác minh lưu lượng thật sự đi qua proxy bằng cách so IP trực tiếp với IP
    /// qua proxy. Đây là bằng chứng mạnh hơn trạng thái "Connected".
    private var routingVerificationCard: some View {
        let config = client.activeConfiguration ?? store.selectedConfiguration

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.neonLime)
                NeonReadout(text: "XÁC MINH ĐỊNH TUYẾN", tint: AppTheme.neonLime)
                Spacer()
                Button {
                    guard let config else { return }
                    let password = store.password(for: config.id)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isVerifyingRouting = true
                    routingVerification = nil
                    Task { @MainActor in
                        let result = await client.verifyRouting(config, password: password)
                        routingVerification = result
                        isVerifyingRouting = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        if isVerifyingRouting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.7)
                        }
                        Text("CHẠY")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.neonLime, in: Capsule())
                    .opacity(config == nil ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(config == nil || isVerifyingRouting)
            }

            if let result = routingVerification {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        verificationTile(
                            title: "IP TRỰC TIẾP",
                            value: result.directIP ?? "—",
                            tint: Color.white.opacity(0.75)
                        )
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                        verificationTile(
                            title: "IP QUA PROXY",
                            value: result.proxiedIP ?? "—",
                            tint: result.routedThroughProxy ? AppTheme.neonLime : AppTheme.neonRed
                        )
                    }

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: result.routedThroughProxy
                              ? "checkmark.circle.fill"
                              : "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(result.routedThroughProxy ? AppTheme.neonLime : AppTheme.neonAmber)
                        Text(result.message)
                            .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("So sánh IP khi đi trực tiếp và khi đi qua proxy. Nếu hai IP khác nhau, lưu lượng đã thực sự đi qua proxy.")
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: ProxySessionProvider.isRoutingThroughProxy
                      ? "arrow.triangle.branch"
                      : "arrow.triangle.branch")
                    .font(.caption2)
                    .foregroundStyle(ProxySessionProvider.isRoutingThroughProxy
                                     ? AppTheme.neonLime
                                     : Color.white.opacity(0.4))
                Text(ProxySessionProvider.isRoutingThroughProxy
                     ? "Đang áp dụng cho các service mạng nội bộ (PatchHub, kiểm tra cập nhật, tải ảnh)."
                     : "Chưa áp dụng — các service mạng nội bộ đang đi trực tiếp.")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .techCard(glow: AppTheme.neonLime, opacity: 0.10)
    }

    private func verificationTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.45))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Scope notice

    private var scopeNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.neonAmber)
                NeonReadout(text: "PHẠM VI ÁP DỤNG", tint: AppTheme.neonAmber)
            }
            Text("Proxy được áp dụng cho các phiên mạng do Proxy Client tạo và kiểm chứng bằng request thật. \(ProxyDiagnostics.networkExtensionLimitMessage) Không giải mã HTTPS, không dùng root CA.")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.neonAmber.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Configuration list

    private var configurationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.neonCyan)
                NeonReadout(text: "CẤU HÌNH ĐÃ LƯU", tint: AppTheme.neonCyan)
                Spacer()
                Text("\(store.configurations.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.6))
            }

            if store.configurations.isEmpty {
                Text("Chưa có cấu hình. Nhấn “THÊM CẤU HÌNH” để bắt đầu.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(store.configurations) { config in
                    configurationRow(config)
                    if config.id != store.configurations.last?.id {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
            }
        }
        .padding(14)
        .techCard(glow: AppTheme.neonCyan, opacity: 0.10)
    }

    private func configurationRow(_ config: ProxyConfiguration) -> some View {
        let isSelected = store.selectedID == config.id
        let isActive = client.activeConfiguration?.id == config.id && client.state.isConnected

        return HStack(spacing: 10) {
            Button {
                store.select(config.id)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? AppTheme.neonCyan : Color.white.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                        if isSelected {
                            Circle()
                                .fill(AppTheme.neonCyan)
                                .frame(width: 9, height: 9)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(config.displayName)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if isActive {
                                Text("LIVE")
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.neonLime, in: Capsule())
                            }
                        }
                        Text("\(config.proto.displayName) · \(config.endpoint)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button {
                editorConfig = config
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.neonCyan)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                pendingDelete = config
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.neonRed)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    private var addButton: some View {
        Button {
            let created = store.add()
            editorConfig = created
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("THÊM CẤU HÌNH")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                LinearGradient(
                    colors: [AppTheme.neonCyan, AppTheme.neonLime],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ProxyEditorView

@MainActor
struct ProxyEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ProxyConfigStore.shared
    @ObservedObject private var client = ProxyClient.shared

    @State private var name: String
    @State private var host: String
    @State private var portText: String
    @State private var proto: ProxyProtocol
    @State private var requiresAuthentication: Bool
    @State private var username: String
    @State private var password: String
    @State private var saveTask: Task<Void, Never>?
    @State private var isTesting = false
    @State private var localTest: ProxyTestResult?

    private let original: ProxyConfiguration
    /// Cấu hình mới tạo nhưng chưa nhập gì: nếu đóng mà vẫn trống thì xoá,
    /// tránh để lại bản ghi rỗng trong danh sách.
    private let wasBlank: Bool

    init(config: ProxyConfiguration) {
        self.original = config
        self.wasBlank = config.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        _name = State(initialValue: config.name)
        _host = State(initialValue: config.host)
        _portText = State(initialValue: String(config.port))
        _proto = State(initialValue: config.proto)
        _requiresAuthentication = State(initialValue: config.requiresAuthentication)
        _username = State(initialValue: config.username)
        _password = State(initialValue: ProxyConfigStore.shared.password(for: config.id) ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    formCard
                    protocolNote
                    testCard
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.vertical, 14)
            }
            .scrollContentBackgroundCompat()
            .scrollDismissesKeyboardCompat()
            .appBackground()
            .navigationTitle("Cấu hình Proxy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.techBackgroundTop.opacity(0.85), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        saveNow()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.neonCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            if wasBlank && host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                store.delete(original.id)
            } else {
                saveNow()
            }
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldRow(title: "TÊN (TUỲ CHỌN)") {
                TextField("Ví dụ: Proxy VN", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onChange(of: name) { _ in scheduleSave() }
            }

            fieldRow(title: "GIAO THỨC") {
                Picker("Giao thức", selection: $proto) {
                    ForEach(ProxyProtocol.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: proto) { _ in scheduleSave() }
            }

            fieldRow(title: "ĐỊA CHỈ IP / HOST") {
                TextField("1.2.3.4 hoặc proxy.example.com", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onChange(of: host) { _ in scheduleSave() }
            }

            fieldRow(title: "PORT") {
                TextField("8080", text: $portText)
                    .keyboardType(.numberPad)
                    .onChange(of: portText) { newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue { portText = filtered }
                        scheduleSave()
                    }
            }

            Toggle(isOn: $requiresAuthentication) {
                Text("Yêu cầu xác thực")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .neonToggleTint(AppTheme.neonCyan)
            .onChange(of: requiresAuthentication) { _ in scheduleSave() }

            if requiresAuthentication {
                fieldRow(title: "USERNAME") {
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: username) { _ in scheduleSave() }
                }

                fieldRow(title: "PASSWORD") {
                    SecureField("password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: password) { _ in scheduleSave() }
                }
            }

            if let message = validationMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.neonRed)
            }
        }
        .padding(16)
        .techCard(glow: AppTheme.neonCyan, opacity: 0.12)
    }

    private func fieldRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(Color.white.opacity(0.5))
            content()
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var protocolNote: some View {
        if let note = proto.credentialNote {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.neonAmber)
                Text(note)
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(11)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Text(proto.detailText)
                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.neonLime)
                NeonReadout(text: "KIỂM TRA PROXY", tint: AppTheme.neonLime)
                Spacer()
                Button {
                    runTest()
                } label: {
                    HStack(spacing: 5) {
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.7)
                        }
                        Text("CHẠY")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.neonLime, in: Capsule())
                    .opacity(canTest ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canTest || isTesting)
            }

            if let result = localTest {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.success ? "THÀNH CÔNG" : "THẤT BẠI")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(result.success ? AppTheme.neonLime : AppTheme.neonRed)
                    Text(result.message)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Chạy kiểm tra để đo độ trễ TCP và xác thực proxy bằng request thật.")
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .techCard(glow: AppTheme.neonLime, opacity: 0.10)
    }

    // MARK: - Model helpers

    private var currentPort: Int {
        Int(portText) ?? 0
    }

    private var canTest: Bool {
        draftConfiguration.validationMessage == nil
    }

    private var validationMessage: String? {
        draftConfiguration.validationMessage
    }

    private var draftConfiguration: ProxyConfiguration {
        var config = original
        config.name = name
        config.host = host
        config.port = currentPort
        config.proto = proto
        config.username = username
        config.requiresAuthentication = requiresAuthentication
        config.updatedAt = Date()
        return config
    }

    private func runTest() {
        let config = draftConfiguration
        saveNow()
        let testPassword: String? = requiresAuthentication ? self.password : nil
        isTesting = true
        Task { @MainActor in
            let result = await client.test(config, password: testPassword)
            localTest = result
            isTesting = false
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    private func saveNow() {
        var config = draftConfiguration
        config.normalize()
        let storedPassword: String? = requiresAuthentication ? password : ""
        store.update(config, password: storedPassword)
    }
}

// MARK: - ProxyClientSettingsCard
//
// Card nhúng trong SettingsView. Tự quản lý sheet để SettingsView không phải
// tham chiếu tới ProxyClient (tránh phải đổi actor isolation của SettingsView).
@MainActor
struct ProxyClientSettingsCard: View {
    @ObservedObject private var client = ProxyClient.shared
    @ObservedObject private var store = ProxyConfigStore.shared
    @State private var showClient = false

    private var tint: Color {
        switch client.state {
        case .connected: return AppTheme.neonLime
        case .connecting: return AppTheme.neonAmber
        case .failed: return AppTheme.neonRed
        case .disconnected: return AppTheme.neonCyan
        }
    }

    private var subtitle: String {
        if client.state.isConnected, let config = client.activeConfiguration {
            return "\(config.proto.displayName) · \(config.endpoint)"
        }
        if let selected = store.selectedConfiguration {
            return "\(client.state.title) · \(selected.endpoint)"
        }
        return "Chưa có cấu hình proxy"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                NeonReadout(text: "PROXY CLIENT", tint: tint)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)
                    Text(client.state.isConnected ? "LIVE" : "IDLE")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(tint)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06), in: Capsule())
            }

            Text(subtitle)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.7))
                .lineLimit(2)

            Button {
                showClient = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .bold))
                    Text("MỞ PROXY CLIENT")
                        .font(.system(size: 11.5, weight: .heavy, design: .monospaced))
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(
                    LinearGradient(
                        colors: [AppTheme.neonCyan, AppTheme.neonLime],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard(glow: tint, opacity: 0.14)
        .sheet(isPresented: $showClient) {
            ProxyClientView()
        }
    }
}