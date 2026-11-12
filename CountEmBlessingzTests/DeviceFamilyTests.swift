import Testing
import Foundation
@testable import CountEmBlessingz

/// The app is iPhone only and portrait only (a decision in release/owner-inputs.md). If it is also built for iPad,
/// App Store Connect rejects the upload: iPad multitasking needs all four orientations.
struct DeviceFamilyTests {
    private var info: [String: Any] { Bundle(for: AppSettings.self).infoDictionary ?? [:] }

    @Test func appIsBuiltForIPhoneOnly() {
        let family = info["UIDeviceFamily"] as? [Int]
        #expect(family == [1], "UIDeviceFamily must be [1] (iPhone); 2 would add iPad")
    }

    @Test func appIsPortraitOnly() {
        let orientations = info["UISupportedInterfaceOrientations"] as? [String]
        #expect(orientations == ["UIInterfaceOrientationPortrait"])
    }
}
