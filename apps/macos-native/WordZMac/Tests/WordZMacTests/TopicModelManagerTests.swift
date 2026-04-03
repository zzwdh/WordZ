import XCTest
@testable import WordZMac

final class TopicModelManagerTests: XCTestCase {
    func testHashedFallbackVectorIsStableAndDeterministic() throws {
        let vector = try XCTUnwrap(
            TopicModelManager.hashedFallbackVector(for: "alpha beta alpha", dimensions: 8)
        )

        XCTAssertEqual(vector.count, 32)
        XCTAssertEqual(vector[13], 2, accuracy: 0.0001)
        XCTAssertEqual(vector[7], -1, accuracy: 0.0001)
        XCTAssertEqual(vector.filter { $0 != 0 }.count, 2)
    }

    func testLoadModelReturnsInvalidManifestForMalformedJSON() {
        let manager = TopicModelManager(
            manifestProvider: {
                Data("{\"modelID\":true}".utf8)
            },
            systemEmbeddingProvider: { nil }
        )

        XCTAssertThrowsError(try manager.loadModel()) { error in
            guard case TopicAnalysisError.invalidModelManifest = error else {
                return XCTFail("Expected invalidModelManifest, received \(error)")
            }
        }
    }
}
