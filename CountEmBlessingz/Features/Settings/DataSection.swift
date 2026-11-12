import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Export CSV, back up, restore, erase. Everything stays on this device unless the user shares a file.
struct DataSection: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toast
    @Environment(ImportCoordinator.self) private var importCoordinator

    @Environment(SharePreparation.self) private var sharing
    let settings: AppSettings

    private enum ImportMode { case restore, merge }

    /// A file ready for the system share sheet. `markAfter` is set for "changes since last export": the marker
    /// moves only if the person really shared it.
    private struct ShareRequest: Identifiable {
        let id = UUID()
        let url: URL
        var markAfter: ExchangeFile?
    }

    @State private var shareRequest: ShareRequest?
    @State private var importing = false
    @State private var importMode: ImportMode = .restore
    @State private var undoInfo: ImportSnapshotInfo?
    @State private var confirmingUndo = false
    @State private var pendingRestore: ExchangeFile?
    @State private var restoreError: String?
    @State private var eraseArmed = false
    @State private var confirmingErase = false

    private var service: ExportService { ExportService(context: modelContext) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            shareAllRow
            shareChangesRow
            action("Import from file", systemImage: "square.and.arrow.down") { importMode = .merge; importing = true }
            action("Export CSV", systemImage: "tablecells") { share { try service.writeCSV() } }
            action("Back up to file", systemImage: "externaldrive") { share { try service.writeBackup() } }
            action("Restore from backup", systemImage: "arrow.counterclockwise") { importMode = .restore; importing = true }
            if let undoInfo {
                action("Undo last import (\(undoInfo.date.formatted(date: .abbreviated, time: .shortened)))",
                       systemImage: "arrow.uturn.backward") { confirmingUndo = true }
            }
            action(eraseArmed ? "Tap again to erase everything" : "Erase all data",
                   systemImage: "trash", destructive: true, action: eraseTapped)
        }
        .task(id: sharing.version) {
            undoInfo = ImportService(context: modelContext).latestSnapshot()     // after every import / undo / edit
        }
        .sheet(item: $shareRequest) { request in
            ShareSheet(url: request.url) { completed in
                if completed, let file = request.markAfter { try? service.markShared(file) }
            }
            .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.blessingzExchange, .json]) { result in
            handleImport(result)
        }
        .confirmationDialog("Undo last import?", isPresented: $confirmingUndo, titleVisibility: .visible) {
            Button("Undo import", role: .destructive, action: undoImport)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your pot goes back to how it was just before that import. Anything you added or changed since then is lost.")
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

    // MARK: Share my entries

    @ViewBuilder private var shareAllRow: some View {
        if let item = sharing.allItem() {
            ShareLink(item: item, preview: SharePreview(String(localized: "All my entries"))) {
                rowLabel("Share all my entries", systemImage: "square.and.arrow.up")
            }
        } else {
            rowLabel(sharing.prepared == nil ? "Share all my entries" : "No entries to share yet",
                     systemImage: "square.and.arrow.up").opacity(0.4)
        }
    }

    /// Opens the share sheet with only what changed. The "last export" marker moves when the sheet reports that
    /// the file was really shared (sent, saved or copied), never just because it was opened.
    @ViewBuilder private var shareChangesRow: some View {
        if let count = sharing.prepared?.changeCount, count > 0 {
            action("Share changes since last export (\(count))", systemImage: "square.and.arrow.up.on.square") {
                shareChanges()
            }
        } else {
            rowLabel(sharing.prepared == nil ? "Share changes since last export" : "No changes since last export",
                     systemImage: "square.and.arrow.up.on.square").opacity(0.4)
        }
    }

    private func shareChanges() {
        guard let prepared = sharing.prepared, prepared.changeCount > 0 else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(ExportService.shareFileName(.sinceLastExport))
        do {
            try prepared.changes.write(to: url, options: [.atomic, .completeFileProtection])
            shareRequest = ShareRequest(url: url, markAfter: prepared.changesFile)
        } catch {
            toast.show(String(localized: "Couldn't create the file."))
        }
    }

    private func undoImport() {
        do {
            try ImportService(context: modelContext).undoLastImport()
            toast.show(String(localized: "Import undone."))
        } catch {
            toast.show((error as? LocalizedError)?.errorDescription ?? String(localized: "Couldn't undo."))
        }
        undoInfo = ImportService(context: modelContext).latestSnapshot()
    }

    private func rowLabel(_ title: LocalizedStringKey, systemImage: String, destructive: Bool = false) -> some View {
        HStack {
            Image(systemName: systemImage).frame(width: 24)
            Text(title)
            Spacer()
        }
        .font(theme.bodyFont(15, .regular))
        .foregroundStyle(destructive ? theme.danger : theme.textPrimary)
        .frame(minHeight: 44)
        .contentShape(Rectangle())          // the whole row is tappable, not just the text
        .overlay(alignment: .bottom) { Rectangle().fill(theme.rowDivider).frame(height: 1) }
    }

    private var restoreBinding: Binding<Bool> {
        Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })
    }

    private func action(_ title: LocalizedStringKey, systemImage: String, destructive: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) { rowLabel(title, systemImage: systemImage, destructive: destructive) }
            .buttonStyle(.plain)
    }

    private func share(_ makeFile: () throws -> URL) {
        do { shareRequest = ShareRequest(url: try makeFile()) } catch { toast.show(String(localized: "Couldn't create the file.")) }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        if importMode == .merge {
            importCoordinator.receive(url)          // MainView reads it off the main thread and opens the review
            return
        }
        // Read and check the file in the background, then ask for confirmation.
        Task {
            do {
                let file = try await ExchangeFileLoader.load(url: url, allowLegacy: true)
                guard file.kind == .full else { throw ExportError.notAFullBackup }
                pendingRestore = file
            } catch {
                restoreError = (error as? LocalizedError)?.errorDescription ?? String(localized: "That file couldn't be read.")
            }
        }
    }

    private func restore() {
        guard let file = pendingRestore else { return }
        pendingRestore = nil
        do {
            try service.restore(file: file)
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
