import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Export CSV, back up, restore, erase. Everything stays on this device unless the user shares a file.
struct DataSection: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toast

    @State private var shareURL: URL?
    @State private var importing = false
    @State private var pendingRestore: Data?
    @State private var restoreError: String?
    @State private var eraseArmed = false
    @State private var confirmingErase = false

    private var service: ExportService { ExportService(context: modelContext) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            action("Export CSV", systemImage: "tablecells") { share { try service.writeCSV() } }
            action("Back up to file", systemImage: "externaldrive") { share { try service.writeBackup() } }
            action("Restore from backup", systemImage: "arrow.counterclockwise") { importing = true }
            action(eraseArmed ? "Tap again to erase everything" : "Erase all data",
                   systemImage: "trash", destructive: true, action: eraseTapped)
        }
        .sheet(item: $shareURL) { ShareSheet(url: $0).presentationDetents([.medium, .large]) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.blessingzExchange, .json]) { result in
            handleImport(result)
        }
        .confirmationDialog("Replace everything on this device?", isPresented: restoreBinding, titleVisibility: .visible) {
            Button("Replace everything", role: .destructive, action: restore)
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("Your current blessings and settings will be replaced by the backup.")
        }
        .confirmationDialog("Erase all data?", isPresented: $confirmingErase, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive, action: erase)
            Button("Cancel", role: .cancel) { eraseArmed = false }
        } message: {
            Text("This permanently deletes every blessing on this device. It can't be undone.")
        }
        .alert("Couldn't restore", isPresented: Binding(get: { restoreError != nil }, set: { if !$0 { restoreError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreError ?? "")
        }
    }

    private var restoreBinding: Binding<Bool> {
        Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })
    }

    private func action(_ title: LocalizedStringKey, systemImage: String, destructive: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage).frame(width: 24)
                Text(title)
                Spacer()
            }
            .font(theme.bodyFont(15, .regular))
            .foregroundStyle(destructive ? theme.danger : theme.textPrimary)
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) { Rectangle().fill(theme.rowDivider).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    private func share(_ makeFile: () throws -> URL) {
        do { shareURL = try makeFile() } catch { toast.show(String(localized: "Couldn't create the file.")) }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            pendingRestore = try Data(contentsOf: url)
        } catch {
            restoreError = String(localized: "That file couldn't be read.")
        }
    }

    private func restore() {
        guard let data = pendingRestore else { return }
        pendingRestore = nil
        do {
            try service.restore(from: data)
            toast.show(String(localized: "Backup restored."))
        } catch {
            restoreError = (error as? LocalizedError)?.errorDescription ?? String(localized: "Something went wrong. Nothing was changed.")
        }
    }

    private func eraseTapped() {
        if eraseArmed {
            confirmingErase = true
        } else {
            eraseArmed = true
            Task {
                try? await Task.sleep(for: .seconds(4))
                if !confirmingErase { eraseArmed = false }
            }
        }
    }

    private func erase() {
        eraseArmed = false
        do { try service.eraseAll() } catch { toast.show(String(localized: "Couldn't erase data.")) }
    }
}
