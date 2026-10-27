import Foundation
import Testing

@testable import Ttak

struct TestEnvironmentTests {
    @Test func appModuleIsLoadedInTtakHost() {
        #expect(String(reflecting: TtakApp.self) == "Ttak.TtakApp")
        #expect(Bundle.main.bundleIdentifier == "app.ttak.Ttak")
    }
}
