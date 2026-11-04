import XCTest
@testable import StarCore

final class AstronomyTests: XCTestCase {
    // 기준값: astropy로 계산한 서울, 2026-11-04 13:00 UTC (한국시간 22:00)
    let seoul = Observer(latitude: 37.5665, longitude: 126.978)
    let date = Date(timeIntervalSince1970: 1_793_797_200)
    let tol = 0.05 // 도

    func check(_ ra: Double, _ dec: Double, alt: Double, az: Double, file: StaticString = #filePath, line: UInt = #line) {
        let h = Astronomy.horizontal(ra: ra, dec: dec, context: .init(date: date, observer: seoul))
        XCTAssertEqual(h.altitude, alt, accuracy: tol, "고도", file: file, line: line)
        XCTAssertEqual(h.azimuth, az, accuracy: tol, "방위각", file: file, line: line)
    }

    func testSirius()     { check(101.28722, -16.71612, alt: -14.633, az: 100.064) }
    func testVega()       { check(279.23474,  38.78369, alt:  24.951, az: 300.945) }
    func testPolaris()    { check( 37.95456,  89.26411, alt:  38.032, az:   0.524) }
    func testBetelgeuse() { check( 88.79294,   7.40706, alt:   9.735, az:  88.098) }

    func testGMSTAtJ2000() {
        // 2000-01-01 12:00 UTC
        XCTAssertEqual(Astronomy.gmst(Date(timeIntervalSince1970: 946_728_000)), 280.46061837, accuracy: 1e-6)
    }

    func testARVectorAxes() {
        let north = Astronomy.arVector(Horizontal(altitude: 0, azimuth: 0))
        let east  = Astronomy.arVector(Horizontal(altitude: 0, azimuth: 90))
        let up    = Astronomy.arVector(Horizontal(altitude: 90, azimuth: 0))
        XCTAssertEqual(north.z, -1, accuracy: 1e-9)
        XCTAssertEqual(east.x, 1, accuracy: 1e-9)
        XCTAssertEqual(up.y, 1, accuracy: 1e-9)
    }

    func testSkyRotationMatchesHorizontal() {
        // 회전 행렬 · 적도 벡터 == horizontal -> arVector (같은 결과여야 함)
        let ctx = Astronomy.Context(date: date, observer: seoul)
        let m = Astronomy.equatorialToAR(context: ctx)
        for (ra, dec) in [(279.23474, 38.78369), (101.28722, -16.71612), (37.95456, 89.26411), (200.0, -60.0)] {
            let v = Astronomy.unitVector(ra: ra, dec: dec)
            let r = (0..<3).map { i in (0..<3).reduce(0) { $0 + m[i][$1] * v[$1] } }
            let want = Astronomy.arVector(Astronomy.horizontal(ra: ra, dec: dec, context: ctx))
            XCTAssertEqual(r[0], want.x, accuracy: 1e-9)
            XCTAssertEqual(r[1], want.y, accuracy: 1e-9)
            XCTAssertEqual(r[2], want.z, accuracy: 1e-9)
        }
        // 회전 행렬이면 각 행은 길이 1이고 서로 수직
        for i in 0..<3 {
            for j in 0..<3 {
                let dot = (0..<3).reduce(0) { $0 + m[i][$1] * m[j][$1] }
                XCTAssertEqual(dot, i == j ? 1 : 0, accuracy: 1e-9)
            }
        }
    }

    func testCatalogDecoding() throws {
        let json = #"{"epoch":"J2000","stars":[{"hip":32349,"ra":101.28722,"dec":-16.71612,"mag":-1.44,"name":"Sirius","ci":0.009}],"constellations":[{"id":"CMa","nameKo":"큰개자리","nameEn":"Great Dog","lines":[[32349,33160]]}]}"#
        let cat = try StarCatalog.load(from: Data(json.utf8))
        XCTAssertEqual(cat.stars.first?.name, "Sirius")
        XCTAssertEqual(cat.constellations.first?.nameKo, "큰개자리")
    }
}
