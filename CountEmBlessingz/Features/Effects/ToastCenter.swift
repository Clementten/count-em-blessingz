import SwiftUI

@MainActor @Observable
final class ToastCenter {
    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let actionTitle: String?
        let action: (() -> Void)?
    }

    private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, actionTitle: String? = nil, duration: TimeInterval = 3, action: (() -> Void)? = nil) {
        dismissTask?.cancel()
        let toast = Toast(message: message, actionTitle: actionTitle, action: action)
        current = toast
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            if self?.current?.id == toast.id { self?.current = nil }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

struct ToastOverlay: View {
    @Environment(\.theme) private var theme
    let toast: ToastCenter

    var body: some View {
        if let current = toast.current {
            HStack(spacing: 12) {
                Text(current.message)
                    .font(theme.bodyFont(14, .medium)).foregroundStyle(theme.textPrimary)
                if let title = current.actionTitle, let action = current.action {
                    Button(title) { action(); toast.dismiss() }
                        .font(theme.bodyFont(14, .semibold)).foregroundStyle(theme.accent)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(theme.line, lineWidth: 1))
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }
}
