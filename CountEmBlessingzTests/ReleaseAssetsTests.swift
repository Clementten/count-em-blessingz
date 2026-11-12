import Testing
import SwiftData
import Foundation
import ImageIO
@testable import CountEmBlessingz

/// Guards the files in `release/` that the owner uploads or attaches by hand, so they cannot quietly go stale.
struct ReleaseAssetsTests {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    @Test func theReviewerSampleFileIsAValidImport() throws {
        let url = repositoryRoot.appending(path: "release/sample-import.blessingz")
        let file = try ExchangeFileCodec.decode(try Data(contentsOf: url))
        #expect(file.schemaVersion == 2 && file.kind == .full && file.currencyCode == "MYR")
        #expect(file.blessings.count == 5 && file.blessers.count == 4)
        #expect(file.blessings.allSatisfy { $0.amount > 0 })
    }

    @MainActor @Test func theSampleFilePlansCleanlyAgainstAnEmptyPot() throws {
        let container = try ModelContainer(
            for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let settings = AppSettings()
        settings.currencyCode = "MYR"
        container.mainContext.insert(settings)
        let file = try ExchangeFileCodec.decode(try Data(contentsOf: repositoryRoot.appending(path: "release/sample-import.blessingz")))
        let plan = try ImportService(context: container.mainContext).buildPlan(file: file)
        #expect(plan.isReady && plan.summary.new == 5 && plan.selectedCount == 5)      // a reviewer taps Import and sees entries
    }

    @Test(arguments: ["jade", "grand", "quiet"])
    func theAppStoreScreenshotSetIsCompleteAtTheRequiredSize(theme: String) throws {
        let names = ["01-home", "02-insights", "03-hall-of-fame", "04-add-blessing", "05-vibes", "06-import-review"]
        for name in names {
            let url = repositoryRoot.appending(path: "release/screenshots/\(theme)/\(name).png")
            let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil), "missing \(theme)/\(name).png")
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
            #expect(properties[kCGImagePropertyPixelWidth] as? Int == 1320, "\(theme)/\(name) width")
            #expect(properties[kCGImagePropertyPixelHeight] as? Int == 2868, "\(theme)/\(name) height")      // iPhone 6.9"
            #expect(properties[kCGImagePropertyHasAlpha] as? Bool != true, "\(theme)/\(name) must have no transparency")
        }
    }
}
