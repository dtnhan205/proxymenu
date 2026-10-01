import SwiftUI

/// Sheet-style wrapper khớp API LicenseKeyView { _ in ... } đang được gọi
/// từ GamePatchesView. Tận dụng toàn bộ flow trong LicenseGateView.
struct LicenseKeyView: View {

    /// Callback khi key hợp với parameter bất kỳ (GamePatchesView dùng `_ in`).
    var onActivated: (Any?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LicenseGateView(
            onUnlock: {
                onActivated(nil)
                dismiss()
            }
        )
    }
}
