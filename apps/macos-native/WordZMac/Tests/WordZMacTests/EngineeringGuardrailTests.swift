import XCTest
@testable import WordZMac

@MainActor
final class EngineeringGuardrailTests: XCTestCase {
    func testRepeatedNoOpSettingsSyncStaysWithinBaselineAndAvoidsRebuilds() async {
        let repository = FakeWorkspaceRepository()
        let builder = CountingRootContentSceneBuilder()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            rootSceneBuilder: builder
        )

        await workspace.initializeIfNeeded()
        let buildCountAfterInitialize = builder.buildCallCount

        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for _ in 0..<250 {
                workspace.syncSceneGraph(source: .settings)
            }
        }

        XCTAssertEqual(builder.buildCallCount, buildCountAfterInitialize)
        XCTAssertLessThan(milliseconds(elapsed), 750)
    }

    private func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        let seconds = Double(components.seconds) * 1_000
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000
        return seconds + attoseconds
    }
}
