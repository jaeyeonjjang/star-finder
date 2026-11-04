import XCTest
@testable import StarCore

final class KoreanSkyTests: XCTestCase {

    let catalog = CatalogTests.catalog
    var korean: [Constellation] { catalog.korean!.constellations }

    func testLoaded() {
        XCTAssertEqual(korean.count, 312)
        XCTAssertEqual(catalog.korean?.license, "GPL-2.0")
    }

    func testUniqueIds() {
        // 원본 데이터는 H19가 두 개(여상, 종대부)라서 build_catalog.py가 종대부를 H19b로 바꾼다
        XCTAssertEqual(Set(korean.map(\.id)).count, korean.count)
        XCTAssertEqual(korean.first { $0.id == "H19b" }?.nameHanja, "宗大夫")
        XCTAssertEqual(KoreanGroup(id: "H19b"), .enclosure(.market))
    }

    func testAllLineStarsExist() {
        let byHip = catalog.starsByHip()
        for c in korean {
            for hip in c.lines.joined() {
                XCTAssertNotNil(byHip[hip], "\(c.id) \(c.nameKo)의 HIP \(hip)이 카탈로그에 없음")
            }
        }
    }

    func testNames() throws {
        let p01 = try XCTUnwrap(korean.first { $0.id == "P01" })
        XCTAssertEqual(p01.nameKo, "북극")
        XCTAssertEqual(p01.nameHanja, "北極")
        // 괄호가 겹친 이름: "삼대(상대)(三台(上台))"
        let s20 = try XCTUnwrap(korean.first { $0.nameHanja == "三台(上台)" })
        XCTAssertEqual(s20.nameKo, "삼대(상대)")
    }

    // MARK: 갈래 (3원 28수)

    func testGroupFromId() {
        XCTAssertEqual(KoreanGroup(id: "P01"), .enclosure(.purple))
        XCTAssertEqual(KoreanGroup(id: "S05"), .enclosure(.supreme))
        XCTAssertEqual(KoreanGroup(id: "H20"), .enclosure(.market))
        XCTAssertEqual(KoreanGroup(id: "01A"), .mansion(1))
        XCTAssertEqual(KoreanGroup(id: "28H"), .mansion(28))
        XCTAssertNil(KoreanGroup(id: "Ori"))   // 서양 별자리
        XCTAssertNil(KoreanGroup(id: "29A"))   // 28수까지만
        XCTAssertNil(KoreanGroup(id: "00A"))
        XCTAssertNil(KoreanGroup(id: ""))
    }

    func testGroupCounts() {
        var count: [KoreanGroup: Int] = [:]
        for c in korean { count[c.koreanGroup!, default: 0] += 1 }
        XCTAssertEqual(count[.enclosure(.purple)], 39)
        XCTAssertEqual(count[.enclosure(.supreme)], 23)
        XCTAssertEqual(count[.enclosure(.market)], 20)
        XCTAssertEqual((1...28).reduce(0) { $0 + (count[.mansion($1)] ?? 0) }, 230)
    }

    func testMansionTableMatchesData() throws {
        // 코드에 적어 둔 28수 한자가 실제 데이터의 대표 별자리(01A~28A) 이름 안에 들어 있어야 한다.
        // (데이터에는 "남두(南斗)", "견우(牽牛)"처럼 두 글자인 것도 있어서 '같다'가 아니라 '포함'으로 확인)
        for n in 1...28 {
            let id = String(format: "%02dA", n)
            let c = try XCTUnwrap(korean.first { $0.id == id }, id)
            XCTAssert(KoreanGroup.isMansionMain(id))
            XCTAssert(c.nameHanja!.contains(KoreanGroup.mansions[n - 1].hanja), "\(id): \(c.nameHanja!)")
        }
        XCTAssertFalse(KoreanGroup.isMansionMain("01B"))
        XCTAssertFalse(KoreanGroup.isMansionMain("P01"))
        XCTAssertEqual(KoreanGroup.mansion(1).name, "각수(角宿)")
    }

    func testDirections() {
        XCTAssertEqual(KoreanGroup.enclosure(.purple).direction, .center)
        XCTAssertEqual(KoreanGroup.mansion(1).direction, .east)    // 각수: 동방 청룡
        XCTAssertEqual(KoreanGroup.mansion(7).direction, .east)
        XCTAssertEqual(KoreanGroup.mansion(8).direction, .north)   // 두수: 북방 현무
        XCTAssertEqual(KoreanGroup.mansion(15).direction, .west)   // 규수: 서방 백호
        XCTAssertEqual(KoreanGroup.mansion(28).direction, .south)  // 진수: 남방 주작
        XCTAssertEqual(Direction.east.guardian, "청룡")
    }

    // MARK: 라벨 위치

    func testCenters() throws {
        let centers = catalog.constellationCenters(of: korean)
        // 선이 없는 4개 (성단 2개, 원래 빈 것 1개, 카탈로그에 없는 별 때문에 1개) 빼고 전부
        XCTAssertEqual(centers.count, 308)
        // 별 하나짜리 별자리(천일, [[61281, 61281]])의 가운데 = 그 별
        let star = try XCTUnwrap(catalog.starsByHip()[61281])
        let c = try XCTUnwrap(centers["P03"])
        XCTAssertEqual(c.ra, star.ra, accuracy: 1e-9)
        XCTAssertEqual(c.dec, star.dec, accuracy: 1e-9)
    }
}
