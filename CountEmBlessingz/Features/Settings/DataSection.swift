import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Export CSV, back up, restore, erase. Everything stays on this device unless the user shares a file.
struct DataSection: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toast
    @Environment(ImportCoordinator.self) private var importCoordinator

    let settings: AppSettings
    @Query private var blessings: [Blessing]

    private enum ImportMode { case restore, merge }

    /// Files for the two share rows, encoded off the main thread whenever the entries change.
    private struct PreparedShare {
        let all: Data
        let changes: Data
        let changesFile: ExchangeFile
        let changeCount: Int
    }

    @State private var shareURL: URL?
    @State private var importing = false
    @State private var importMode: ImportMode = .restore
    @State private var prepared: PreparedShare?
    @State private var undoInfo: ImportSnapshotInfo?
    @State private var confirmingUndo = false
    @State private var pendingRestore: Data?
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
        .task(id: dataSignature) {
            await prepareShares()
            undoInfo = ImportService(context: modelContext).latestSnapshot()
        }
        .sheet(item: $shareURL) { ShareSheet(url: $0).presentationDetents([.medium, .large]) }
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

    /// Changes whenever something the share files contain changes.
    private var dataSignature: String {
        let latest = blessings.map(\.updatedAt).max()?.timeIntervalSince1970 ?? 0
        return "\(blessings.count)|\(latest)|\(settings.lastExportAt?.timeIntervalSince1970 ?? 0)|\(settings.deviceLabel)"
    }

    private func prepareShares() async {
        guard let payload = try? service.sharePayload() else { prepared = nil; return }
        let files = payload
        let encoded = await Task.detached(priority: .userInitiated) {
            (try? ExchangeFileCodec.encode(files.allFile), try? ExchangeFileCodec.encode(files.changesFile))
        }.value
        guard let all = encoded.0, let changes = encoded.1 else { prepared = nil; return }
        prepared = PreparedShare(all: all, changes: changes, changesFile: files.changesFile, changeCount: files.changeCount)
    }

    @ViewBuilder private var shareAllRow: some View {
        if let prepared {
            ShareLink(
                item: ExchangeShareItem(data: prepared.all, fileName: ExportService.shareFileName(.full), onShared: {}),
                preview: SharePreview(String(localized: "All my entries"))
            ) { rowLabel("Share all my entries", systemImage: "square.and.arrow.up") }
        } else {
            rowLabel("Share all my entries", systemImage: "square.and.arrow.up").opacity(0.4)
        }
    }

    /// Sharing marks the changes as exported, but only when the system actually asks for the file.
    @ViewBuilder private var shareChangesRow: some View {
        if let prepared, prepared.changeCount > 0 {
            let context = modelContext
            let file = prepared.changesFile
            ShareLink(
                item: ExchangeShareItem(
                    data: prepared.changes, fileName: ExportService.shareFileName(.sinceLastExport),
                    onShared: { Task { @MainActor in try? ExportService(context: context).markShared(file) } }
                ),
                preview: SharePreview(String(localized: "Changes since my last export"))
            ) { rowLabel("Share changes since last export (\(prepared.changeCount))", systemImage: "square.and.arrow.up.on.square") }
        } else {
            rowLabel(prepared == nil ? "Share changes since last export" : "No changes since last export",
                     systemImage: "square.and.arrow.up.on.square").opacity(0.4)
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
        do { shareURL = try makeFile() } catch { toast.show(String(localized: "Couldn't create the file.")) }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        if importMode == .merge {
            importCoordinator.receive(url)          // MainView reads it off the main thread and opens the review
            return
        }
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
