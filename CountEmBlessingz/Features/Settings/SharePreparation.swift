import SwiftUI
import SwiftData

/// The app's main context, handed to a share callback that may run off the main thread. It is only ever used
/// after hopping back to the main actor, which is where this context lives.
private struct MainContextBox: @unchecked Sendable {
    let context: ModelContext
}

/// The two share files, built once and kept current for every Share button in the app
/// (Home and Settings). Encoding runs off the main thread.
@MainActor @Observable
final class SharePreparation {
    struct Prepared {
        let all: Data
        let changes: Data
        let changesFile: ExchangeFile
        let changeCount: Int
        let entryCount: Int
    }

    private(set) var prepared: Prepared?
    /// Bumped after every refresh so views can react (for example to refresh "Undo last import").
    private(set) var version = 0

    func refresh(context: ModelContext) async {
        defer { version += 1 }
        guard let payload = try? ExportService(context: context).sharePayload() else { prepared = nil; return }
        let encoded = await Task.detached(priority: .userInitiated) {
            (try? ExchangeFileCodec.encode(payload.allFile), try? ExchangeFileCodec.encode(payload.changesFile))
        }.value
        guard let all = encoded.0, let changes = encoded.1 else { prepared = nil; return }
        prepared = Prepared(
            all: all, changes: changes, changesFile: payload.changesFile,
            changeCount: payload.changeCount, entryCount: payload.allFile.blessings.count
        )
    }

    /// Everything, for `ShareLink`. Nil until prepared or when there is nothing to share.
    func allItem() -> ExchangeShareItem? {
        guard let prepared, prepared.entryCount > 0 else { return nil }
        return ExchangeShareItem(data: prepared.all, fileName: ExportService.shareFileName(.full), onShared: {})
    }

    /// Only what changed since the last share. Sharing it moves the "last export" marker, but only when
    /// the system actually asks for the file.
    func changesItem(context: ModelContext) -> ExchangeShareItem? {
        guard let prepared, prepared.changeCount > 0 else { return nil }
        let file = prepared.changesFile
        let box = MainContextBox(context: context)
        return ExchangeShareItem(
            data: prepared.changes, fileName: ExportService.shareFileName(.sinceLastExport),
            onShared: { Task { @MainActor in try? ExportService(context: box.context).markShared(file) } }
        )
    }
}
