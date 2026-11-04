import XCTest
@testable import StarCore

final class ArtTests: XCTestCase {

    let catalog = CatalogTests.catalog
    lazy var byHip = catalog.starsByHip()

    /// 두 방향 사이의 각도 (도).
    /// acos(내적)은 각도가 아주 작을 때 정밀도가 떨어지므로(약 1e-6°가 한계) atan2(|외적|, 내적)을 쓴다.
    func angle(_ a: Equatorial, _ b: Equatorial) -> Double {
        let u = Astronomy.unitVector(ra: a.ra, dec: a.dec), v = Astronomy.unitVector(ra: b.ra, dec: b.dec)
        let dot = u[0] * v[0] + u[1] * v[1] + u[2] * v[2]
        let cx = u[1] * v[2] - u[2] * v[1], cy = u[2] * v[0] - u[0] * v[2], cz = u[0] * v[1] - u[1] * v[0]
        return Astronomy.deg(atan2((cx * cx + cy * cy + cz * cz).squareRoot(), dot))
    }

    // MARK: 행렬

    func testMatrixInverse() throws {
        let m = Matrix3(rows: [[2, 0, 1], [1, 3, 2], [1, 1, 2]])   // 행렬식 6
        let inv = try XCTUnwrap(m.inverse())
        let id = m * inv
        for r in 0..<3 {
            for c in 0..<3 {
                XCTAssertEqual(id.e[r][c], r == c ? 1 : 0, accuracy: 1e-12)
            }
        }
        XCTAssertNil(Matrix3(rows: [[1, 2, 3], [2, 4, 6], [1, 1, 1]]).inverse())  // 행렬식 0
    }

    // MARK: 실제 데이터

    func testEightyFiveConstellationsHaveArt() {
        XCTAssertEqual(catalog.constellations.filter { $0.art != nil }.count, 85)
        XCTAssertEqual(catalog.artMeshes().count, 85)
    }

    func testAnchorsLandOnTheirStars() throws {
        // 가장 중요한 성질: 기준점 픽셀은 정확히 그 별 위치로 가야 한다
        for c in catalog.constellations {
            guard let art = c.art else { continue }
            let p = try XCTUnwrap(ArtProjection(art: art, starsByHip: byHip), c.id)
            for a in art.anchors {
                let star = byHip[a.hip]!
                let got = p.equatorial(x: a.x, y: a.y)
                XCTAssertLessThan(angle(got, Equatorial(ra: star.ra, dec: star.dec)), 1e-6, "\(c.id) HIP \(a.hip)")
            }
        }
    }

    func testArtIsNotDistorted() throws {
        // 그림 중앙에서 가로 1픽셀과 세로 1픽셀이 하늘에서 비슷한 각도여야 한다
        // (기준점 데이터가 이상하면 그림이 한쪽으로 심하게 늘어난다)
        for c in catalog.constellations {
            guard let art = c.art else { continue }
            let p = try XCTUnwrap(ArtProjection(art: art, starsByHip: byHip))
            let cx = Double(art.width) / 2, cy = Double(art.height) / 2, d = 10.0
            let center = p.equatorial(x: cx, y: cy)
            let sx = angle(center, p.equatorial(x: cx + d, y: cy))
            let sy = angle(center, p.equatorial(x: cx, y: cy + d))
            XCTAssertEqual(sx / sy, 1, accuracy: 0.5, "\(c.id) 가로/세로 비율 \(sx / sy)")
        }
    }

    func testOrionArtCoversOrion() throws {
        // 오리온 그림 한가운데는 오리온자리 중심(별자리 선 기준)에서 멀지 않아야 한다
        let ori = try XCTUnwrap(catalog.constellations.first { $0.id == "Ori" })
        let p = try XCTUnwrap(ArtProjection(art: ori.art!, starsByHip: byHip))
        let artCenter = p.equatorial(x: 256, y: 256)
        let lineCenter = try XCTUnwrap(catalog.constellationCenters()["Ori"])
        XCTAssertLessThan(angle(artCenter, lineCenter), 10)
    }

    // MARK: 메시

    func testMeshShape() throws {
        let mesh = try XCTUnwrap(catalog.artMeshes(segments: 4)["Ori"])
        XCTAssertEqual(mesh.positions.count, 25)      // (4+1)²
        XCTAssertEqual(mesh.uvs.count, 25)
        XCTAssertEqual(mesh.indices.count, 4 * 4 * 6) // 칸마다 삼각형 2개 × 꼭짓점 3개
        XCTAssert(mesh.indices.allSatisfy { $0 < 25 })
        XCTAssertEqual(mesh.uvs.first, UV(u: 0, v: 0))
        XCTAssertEqual(mesh.uvs.last, UV(u: 1, v: 1))
    }

    func testDegenerateAnchors() {
        // 기준점 3개가 한 직선 위 -> 평면이 정해지지 않음
        let art = ConstellationArt(file: "x.png", width: 100, height: 100, anchors: [
            .init(x: 0, y: 0, hip: 32349), .init(x: 50, y: 50, hip: 30438), .init(x: 100, y: 100, hip: 69673),
        ])
        XCTAssertNil(ArtProjection(art: art, starsByHip: byHip))
        // 없는 별
        let missing = ConstellationArt(file: "x.png", width: 100, height: 100, anchors: [
            .init(x: 0, y: 0, hip: -1), .init(x: 50, y: 0, hip: 30438), .init(x: 0, y: 50, hip: 69673),
        ])
        XCTAssertNil(ArtProjection(art: missing, starsByHip: byHip))
    }
}
