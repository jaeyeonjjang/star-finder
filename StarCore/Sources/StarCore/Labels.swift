import Foundation

/// 적도좌표 (도, J2000)
public struct Equatorial: Sendable, Equatable {
    public let ra: Double
    public let dec: Double
    public init(ra: Double, dec: Double) {
        self.ra = ra; self.dec = dec
    }
}

public extension StarCatalog {

    /// HIP 번호 -> 별
    func starsByHip() -> [Int: Star] {
        Dictionary(stars.map { ($0.hip, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// 별자리 이름 라벨 위치 (별자리 id -> 중심 좌표).
    /// 앱 시작 시 한 번 계산해 두고, 프레임마다 `Astronomy.horizontal(ra:dec:context:)`로 변환하세요.
    func constellationCenters() -> [String: Equatorial] {
        constellationCenters(of: constellations)
    }

    /// 아무 별자리 목록이나 (예: `catalog.korean!.constellations`)
    func constellationCenters(of list: [Constellation]) -> [String: Equatorial] {
        let byHip = starsByHip()
        var result: [String: Equatorial] = [:]
        for c in list {
            let members = Set(c.lines.joined()).compactMap { byHip[$0] }
            if let center = Self.center(of: members.map { Equatorial(ra: $0.ra, dec: $0.dec) }) {
                result[c.id] = center
            }
        }
        return result
    }

    /// 여러 점의 구면 중심.
    /// 적경을 그냥 평균내면 0°/360° 경계(예: 359°와 1° -> 180°)나 천극 근처에서 틀어지므로
    /// 단위 벡터로 바꿔 평균낸 뒤 다시 적경/적위로 되돌린다.
    static func center(of points: [Equatorial]) -> Equatorial? {
        var x = 0.0, y = 0.0, z = 0.0
        for p in points {
            let v = Astronomy.unitVector(ra: p.ra, dec: p.dec)
            x += v[0]; y += v[1]; z += v[2]
        }
        guard x * x + y * y + z * z > 1e-12 else { return nil }  // 점이 없거나 정확히 상쇄됨
        return Astronomy.equatorial(x: x, y: y, z: z)
    }
}
