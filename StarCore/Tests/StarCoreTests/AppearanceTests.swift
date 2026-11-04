import XCTest
@testable import StarCore

final class AppearanceTests: XCTestCase {

    // MARK: 대기굴절

    func testRefractionAtHorizon() {
        // 눈에 보이는 고도 0°인 별의 실제 고도는 약 -0.57° (굴절 34′) — 항해력 표준값
        XCTAssertEqual(Astronomy.refraction(altitude: -0.575), 34.0 / 60, accuracy: 0.01)
        // 기하학적 고도 0°에서는 약 29′
        XCTAssertEqual(Astronomy.refraction(altitude: 0), 29.0 / 60, accuracy: 0.01)
    }

    func testRefractionHighUp() {
        XCTAssertEqual(Astronomy.refraction(altitude: 45), 1.0 / 60, accuracy: 0.002)
        XCTAssertEqual(Astronomy.refraction(altitude: 90), 0, accuracy: 1e-4)
    }

    func testRefractionContinuousBelowHorizon() {
        // 지평선 아래에서 값이 튀지 않아야 별이 뜰 때 화면에서 순간이동하지 않는다
        XCTAssertEqual(Astronomy.refraction(altitude: -1), Astronomy.refraction(altitude: -10))
        XCTAssertEqual(Astronomy.refraction(altitude: -1.001), Astronomy.refraction(altitude: -0.999), accuracy: 1e-3)
    }

    func testRefractionWeather() {
        // 추우면 공기가 무거워져 더 많이 휜다
        XCTAssertGreaterThan(Astronomy.refraction(altitude: 5, temperature: -20),
                             Astronomy.refraction(altitude: 5, temperature: 30))
    }

    func testRefractedRaisesAltitudeOnly() {
        let h = Astronomy.refracted(Horizontal(altitude: 10, azimuth: 123))
        XCTAssertGreaterThan(h.altitude, 10)
        XCTAssertEqual(h.azimuth, 123)
    }

    // MARK: 크기

    func testRelativeSize() {
        XCTAssertEqual(Appearance.relativeSize(magnitude: 0), 1, accuracy: 1e-9)
        let sirius = Appearance.relativeSize(magnitude: -1.44)
        let faint = Appearance.relativeSize(magnitude: 6)
        XCTAssertGreaterThan(sirius, faint)
        XCTAssertLessThan(sirius / faint, 10)   // 너무 차이 나지 않게
        XCTAssertEqual(Appearance.relativeSize(magnitude: -10), 2.5)  // 상한
        XCTAssertEqual(Appearance.relativeSize(magnitude: 20), 0.15)  // 하한
    }

    // MARK: 색

    func testTemperatureOfSun() {
        // 태양 B-V 0.65 -> 약 5,800K
        XCTAssertEqual(Appearance.temperature(bv: 0.65), 5778, accuracy: 100)
    }

    func testStarColors() {
        let rigel = Appearance.color(bv: -0.03, saturation: 1)      // 청백색
        let betelgeuse = Appearance.color(bv: 1.85, saturation: 1)  // 주황/빨강
        XCTAssertGreaterThan(rigel.b, rigel.r)
        XCTAssertGreaterThan(betelgeuse.r, betelgeuse.b)
        for c in [rigel, betelgeuse] {
            for v in [c.r, c.g, c.b] { XCTAssert((0...1).contains(v)) }
        }
    }

    func testColorSaturationAndMissing() {
        XCTAssertEqual(Appearance.color(bv: nil), .white)
        XCTAssertEqual(Appearance.color(bv: 1.85, saturation: 0), .white)
        let full = Appearance.color(bv: 1.85, saturation: 1)
        let soft = Appearance.color(bv: 1.85, saturation: 0.5)
        XCTAssertGreaterThan(soft.b, full.b)  // 흰색 쪽으로 옅어짐
    }
}
