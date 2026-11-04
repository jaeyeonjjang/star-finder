import XCTest
@testable import StarCore

/// 실제 tools/stars.json으로 하는 테스트
final class CatalogTests: XCTestCase {

    static let catalog: StarCatalog = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // StarCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // StarCore
            .deletingLastPathComponent()  // 저장소 루트
            .appendingPathComponent("tools/stars.json")
        return try! StarCatalog.load(from: Data(contentsOf: url))
    }()

    func testCatalogSize() {
        let cat = Self.catalog
        XCTAssertGreaterThan(cat.stars.count, 4000)
        XCTAssertEqual(cat.constellations.count, 88)
    }

    func testAllLineStarsExist() {
        let byHip = Self.catalog.starsByHip()
        for c in Self.catalog.constellations {
            XCTAssertFalse(c.lines.isEmpty, "\(c.id) 선 없음")
            for hip in c.lines.joined() {
                XCTAssertNotNil(byHip[hip], "\(c.id)의 HIP \(hip)이 카탈로그에 없음")
            }
        }
    }

    func testEveryConstellationHasCenter() {
        XCTAssertEqual(Self.catalog.constellationCenters().count, 88)
    }

    func testConstellationCenters() {
        let centers = Self.catalog.constellationCenters()
        // 기준값: Python으로 같은 방식(단위 벡터 평균) 계산
        let expected: [String: (Double, Double)] = [
            "Ori": (82.44, 6.53),
            "UMa": (162.61, 54.91),
            "And": (14.05, 36.56),    // 적경 0° 경계에 걸친 별자리
            "Peg": (340.87, 21.01),
            "UMi": (236.45, 80.02),   // 천극 근처
            "Oct": (314.49, -83.58),
        ]
        for (id, (ra, dec)) in expected {
            let c = try! XCTUnwrap(centers[id], id)
            XCTAssertEqual(c.ra, ra, accuracy: 0.01, "\(id) 적경")
            XCTAssertEqual(c.dec, dec, accuracy: 0.01, "\(id) 적위")
        }
    }

    func testCenterAcrossRAZero() {
        // 359°와 1°의 중심은 180°가 아니라 0°
        let c = StarCatalog.center(of: [.init(ra: 359, dec: 0), .init(ra: 1, dec: 0)])!
        XCTAssertEqual(min(c.ra, 360 - c.ra), 0, accuracy: 1e-9)
        XCTAssertNil(StarCatalog.center(of: []))
    }
}
