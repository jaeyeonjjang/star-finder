import XCTest
@testable import StarCore

/// 별자리 이야기 (tools/stories.json -> stars.json의 story)
final class StoryTests: XCTestCase {

    let catalog = CatalogTests.catalog

    func testEveryWesternConstellationHasStory() {
        for c in catalog.constellations {
            XCTAssertFalse((c.story ?? "").isEmpty, "\(c.id) \(c.nameKo) 이야기 없음")
        }
    }

    func testKoreanStories() {
        let korean = catalog.korean!.constellations
        // 28수 대표 별자리는 전부 있어야 한다
        for c in korean where KoreanGroup.isMansionMain(c.id) {
            XCTAssertFalse((c.story ?? "").isEmpty, "\(c.id) \(c.nameKo) 이야기 없음")
        }
        XCTAssertEqual(korean.filter { $0.story != nil }.count, 50)
        // 견우와 직녀
        XCTAssert(korean.first { $0.nameKo == "직녀" }!.story!.contains("오작교"))
    }

    func testStoriesAreReasonableLength() {
        // 너무 짧으면 빠뜨린 것, 너무 길면 화면에 안 들어간다
        let all = catalog.constellations + catalog.korean!.constellations
        for c in all {
            guard let s = c.story else { continue }
            XCTAssert((40...600).contains(s.count), "\(c.id) 이야기 길이 \(s.count)자")
        }
    }
}
