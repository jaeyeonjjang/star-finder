import XCTest
@testable import StarCore

final class LocateTests: XCTestCase {

    let catalog = CatalogTests.catalog
    lazy var byHip = catalog.starsByHip()
    var bounds: Boundaries { catalog.boundaries! }

    func star(_ hip: Int) -> Equatorial { Equatorial(ra: byHip[hip]!.ra, dec: byHip[hip]!.dec) }

    // MARK: 서양 별자리 경계

    func testFamousStars() {
        let cases: [(Int, String, String)] = [
            (27989, "Ori", "베텔게우스"), (24436, "Ori", "리겔"), (32349, "CMa", "시리우스"),
            (91262, "Lyr", "베가"), (11767, "UMi", "북극성"), (80763, "Sco", "안타레스"),
            (65474, "Vir", "스피카"), (677, "And", "알페라츠 (페가수스 사각형이지만 안드로메다 소속)"),
        ]
        for (hip, want, name) in cases {
            XCTAssertEqual(bounds.constellation(at: star(hip)), want, name)
        }
    }

    func testPolesAndSpecialPlaces() {
        XCTAssertEqual(bounds.constellation(at: .init(ra: 0, dec: 90)), "UMi")     // 천구 북극
        XCTAssertEqual(bounds.constellation(at: .init(ra: 123, dec: -90)), "Oct")  // 천구 남극
        XCTAssertEqual(bounds.constellation(at: .init(ra: 10.68, dec: 41.27)), "And") // 안드로메다 은하 M31
        // 뱀자리는 머리와 꼬리가 떨어져 있는데 둘 다 Ser
        XCTAssertEqual(bounds.constellation(at: .init(ra: 236.07, dec: 6.43)), "Ser")  // 머리 (우누칼하이)
        XCTAssertEqual(bounds.constellation(at: .init(ra: 275.33, dec: -2.90)), "Ser") // 꼬리 (η Ser)
    }

    func testEveryPointHasExactlyOneConstellation() {
        // 하늘을 2° 간격으로 훑어서 모든 점이 정확히 한 별자리에 속하고, 88개가 전부 나오는지
        var found = Set<String>()
        for dec in stride(from: -89.0, through: 89.0, by: 2) {
            for ra in stride(from: 0.5, to: 360, by: 2) {
                let c = bounds.constellation(at: .init(ra: ra, dec: dec))
                XCTAssertNotNil(c, "ra \(ra) dec \(dec)")
                if let c { found.insert(c) }
            }
        }
        XCTAssertEqual(found.count, 88)
    }

    func testLineStarsMostlyInsideOwnBoundary() {
        // 별자리 선에 쓰인 별은 대부분 자기 별자리 안에 있다.
        // (100%는 아니다: 알페라츠처럼 이웃 별자리의 별을 빌려 선을 긋는 경우가 있다)
        var inside = 0, total = 0
        for c in catalog.constellations {
            for hip in Set(c.lines.joined()) {
                total += 1
                if bounds.constellation(at: star(hip)) == c.id { inside += 1 }
            }
        }
        XCTAssertGreaterThan(Double(inside) / Double(total), 0.97, "\(inside)/\(total)")
    }

    func testRAWrap() {
        XCTAssert(Boundaries.contains(ra: 355, from: 350, to: 10))
        XCTAssert(Boundaries.contains(ra: 5, from: 350, to: 10))
        XCTAssertFalse(Boundaries.contains(ra: 20, from: 350, to: 10))
        XCTAssert(Boundaries.contains(ra: 350, from: 350, to: 10))   // 왼쪽 끝 포함
        XCTAssertFalse(Boundaries.contains(ra: 10, from: 350, to: 10)) // 오른쪽 끝 미포함
    }

    // MARK: AR 방향 -> 하늘 주소

    func testARRoundTrip() {
        // 하늘 주소 -> AR 방향 -> 다시 하늘 주소 = 처음 값
        let ctx = Astronomy.Context(date: Date(timeIntervalSince1970: 1_793_797_200),
                                    observer: Observer(latitude: 37.5665, longitude: 126.978))
        for p in [Equatorial(ra: 279.2346, dec: 38.78369), Equatorial(ra: 10, dec: -60), Equatorial(ra: 200, dec: 5)] {
            let v = Astronomy.arVector(Astronomy.horizontal(ra: p.ra, dec: p.dec, context: ctx))
            let back = Astronomy.equatorial(fromAR: v, context: ctx)
            XCTAssertEqual(back.ra, p.ra, accuracy: 1e-7)
            XCTAssertEqual(back.dec, p.dec, accuracy: 1e-7)
        }
    }

    // MARK: 한국 전통: 28수

    let ctx = Astronomy.Context(date: Date(timeIntervalSince1970: 1_793_797_200),
                                observer: Observer(latitude: 37.5665, longitude: 126.978))

    func mansion(_ p: Equatorial) -> Int? { catalog.korean!.mansion(at: p, context: ctx, starsByHip: byHip) }

    func testMansions() {
        XCTAssertEqual(mansion(star(65474)), 1)    // 스피카 = 각수의 거성 (자기 수의 시작점)
        XCTAssertEqual(mansion(star(80763)), 5)    // 안타레스 = 심수(心宿)의 가운데 별, "대화(大火)"
        XCTAssertEqual(mansion(star(17702)), 18)   // 플레이아데스(알키오네) = 묘수(昴宿)
        XCTAssertEqual(mansion(star(26727)), 21)   // 오리온 허리띠(알니탁) = 삼수(參宿), "세 별"
    }

    func testMansionsCoverWholeSky() {
        // 적경 한 바퀴를 돌면 28수가 순서대로 나온다. 단 자수(20)는 "자삼 역전"으로 사라져서 27개
        var seen: [Int] = []
        for ra in stride(from: 0.0, to: 360, by: 0.05) {
            let m = mansion(.init(ra: ra, dec: 0))!
            if seen.last != m { seen.append(m) }
        }
        XCTAssertEqual(Set(seen).count, 27)
        XCTAssertFalse(seen.contains(20))
        // 자수 거성(φ¹ Ori) 자리도 이제는 삼수
        XCTAssertEqual(mansion(star(26176)), 21)
    }

    // MARK: 한국 전통: 가장 가까운 별자리

    func testNearestKoreanConstellation() throws {
        let korean = catalog.korean!.constellations
        let vega = try XCTUnwrap(catalog.nearestConstellation(to: star(91262), in: korean))
        XCTAssertEqual(vega.constellation.nameKo, "직녀")    // 베가 = 직녀성
        XCTAssertEqual(vega.distance, 0, accuracy: 1e-6)
        let altair = try XCTUnwrap(catalog.nearestConstellation(to: star(97649), in: korean))
        XCTAssertEqual(altair.constellation.nameKo, "하고")  // 견우성(알타이르)이 속한 별자리는 하고(河鼓)
        // 별 하나 없는 먼 곳은 nil
        XCTAssertNil(catalog.nearestConstellation(to: .init(ra: 0, dec: 0), in: [], maxDistance: 10))
    }
}
