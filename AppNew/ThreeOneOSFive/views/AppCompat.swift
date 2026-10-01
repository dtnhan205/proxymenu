import SwiftUI

// MARK: - AppCompat.swift
//
// Minimum deployment target hiện tại: **iOS 16.0**. Mọi file dưới đây
// dùng SwiftUI APIs iOS 16+ trực tiếp — KHÔNG cần compat wrappers nữa.
//
// Các hàm *Compat còn giữ (NavigationStackCompat, scrollContentBackgroundCompat,
// scrollDismissesKeyboardCompat, navigationDestinationCompat) vẫn được dùng
// trong các view files làm alias để code chính dễ đọc — không có nhánh
// `if #available` bên trong, chỉ pass-through. Nếu sau này muốn bỏ hẳn
// các alias này, có thể đổi tất cả call sites về API gốc và xóa AppCompat.
//
// Lịch sử:
//   - 2026-08: target raise từ 15.0 → 16.0. Loại bỏ tất cả compat wrappers
//     cho `.fontWeight`, `.tracking`, `.toolbarBackground`, `.toolbar { ToolbarItem }`,
//     `LabeledContent`, `ToolbarPlacement`, `ShareLink`, ...

struct NavigationStackCompat<Content: View>: View {
    @ViewBuilder let content: Content

    /// Pass-through wrapper. Code cũ có thể gọi `NavigationStackCompat { ... }`
    /// thay cho `NavigationStack { ... }` — alias cho consistency.
    var body: some View {
        NavigationStack { content }
    }
}

extension View {
    /// Alias cho `.navigationDestination(isPresented:destination:)` (iOS 16+).
    /// Tên `Compat` giữ để không phải đổi call sites trong code chính.
    @ViewBuilder
    func navigationDestinationCompat<V: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> V
    ) -> some View {
        self.navigationDestination(isPresented: isPresented, destination: destination)
    }

    /// Alias cho `.scrollContentBackground(.hidden)` (iOS 16+).
    @ViewBuilder
    func scrollContentBackgroundCompat() -> some View {
        self.scrollContentBackground(.hidden)
    }

    /// Alias cho `.scrollDismissesKeyboard(.interactively)` (iOS 16+).
    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        self.scrollDismissesKeyboard(.interactively)
    }
}
