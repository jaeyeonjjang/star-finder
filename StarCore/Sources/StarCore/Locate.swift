import Foundation

// "지금 카메라가 보는 곳은 어느 별자리인가?"
//
// 앱에서 쓰는 순서:
//   1. ARKit 카메라가 보는 방향 (카메라 transform의 -z축) -> Vector3
//   2. Astronomy.equatorial(fromAR:context:)  -> 하늘 주소 (J2000)
//   3. 서양:  catalog.boundaries?.constellation(at:)       -> "Ori"
//      한국:  catalog.korean?.mansion(at:context:starsByHip:) -> 28수 번호
//             catalog.nearestConstellation(to:in:)          -> 가장 가까운 별자리

public extension Boundaries {

    /// B1875.0 = 율리우스일 2405889.2586 -> J2000에서 -1.25세기
    static let b1875Centuries = (2405889.258550475 - 2451545.0) / 36525.0

    /// 이 점(J2000)이 들어 있는 서양 별자리 id. 경계선 데이터가 이상하면 nil
    ///
    /// 원리 (울타리 세기):
    ///   울타리로 둘러싸인 마당 안에 서 있다고 하자. 북쪽으로 쭉 걸어서 마당을 벗어날 때까지
    ///   그 마당의 울타리를 몇 번 넘는가? 안에 있었다면 홀수 번(1, 3, ...), 밖에 있었다면 짝수 번(0, 2, ...).
    ///   이 점에서 북쪽(적위가 커지는 쪽)으로 선을 그어서, 별자리마다 자기 경계선을 몇 번 넘는지 센다.
    ///   홀수인 별자리가 정답.
    ///
    /// - 세로 경계선은 북쪽으로 그은 선과 나란해서 넘을 일이 없다 -> 가로 경계선만 센다
    /// - 작은곰자리는 북극을 품고 있어서 북쪽으로 가도 울타리를 안 넘고 북극에 도착한다.
    ///   그래서 작은곰자리만 1을 더해 준다 (북극 너머로 넘어가는 보이지 않는 울타리 하나)
    /// - 경계선은 1875년 기준 좌표라서, 점도 J2000 -> 1875년으로 바꾼 뒤 비교한다
    func constellation(at p: Equatorial) -> String? {
        let q = Astronomy.precess(p, centuries: Self.b1875Centuries)
        var crossings: [String: Int] = ["UMi": 1]
        for e in parallels where e.dec > q.dec && Self.contains(ra: q.ra, from: e.ra1, to: e.ra2) {
            crossings[e.a, default: 0] += 1
            crossings[e.b, default: 0] += 1
        }
        let inside = crossings.filter { $0.value % 2 == 1 }
        return inside.count == 1 ? inside.first!.key : nil
    }

    /// 적경 ra가 from부터 동쪽으로 to까지 구간에 있나. 0°/360°를 넘어가는 구간(예: 350° -> 10°)도 처리
    /// 왼쪽 끝은 포함, 오른쪽 끝은 미포함 (경계선 위의 점이 두 번 세지지 않게)
    static func contains(ra: Double, from: Double, to: Double) -> Bool {
        from <= to ? (from <= ra && ra < to) : (ra >= from || ra < to)
    }
}

public extension SkyCulture {

    /// 이 점(J2000)이 속한 28수 번호 (1 = 각수 ... 28 = 진수). 거성 정보가 없으면 nil
    ///
    /// 28수의 범위는 "거성부터 다음 수의 거성까지"의 적경 구간이다.
    /// 귤을 위에서 내려다보면 꼭지(천구 북극)에서 퍼져 나가는 28조각으로 나뉜 것과 같다.
    /// 조각의 폭은 제각각이다 (가장 넓은 정수 약 32°, 좁은 귀수 약 1.5°).
    /// 전통 방식대로 관측 시점의 적경(세차 보정 후)으로 비교한다.
    ///
    /// 자삼(觜參) 역전: 자수(20번) 거성(오리온 머리 근처의 φ¹ Ori)이 세차와 별의 움직임 때문에 지금은
    /// 다음 수인 삼수(21번) 거성 민타카보다 동쪽에 있다. 자수의 폭이 음수(약 -0.7°)가 되어
    /// 지금 하늘에서는 사라진다. 그래서 폭이 음수인(= 다음 거성까지 180° 넘게 돌아야 하는) 수는 건너뛴다.
    func mansion(at p: Equatorial, context: Astronomy.Context, starsByHip: [Int: Star]) -> Int? {
        guard let hips = mansionStars, hips.count == 28 else { return nil }
        func raNow(_ ra: Double, _ dec: Double) -> Double {
            Astronomy.normalize(Astronomy.deg(context.precession.apply(ra: Astronomy.rad(ra), dec: Astronomy.rad(dec)).ra))
        }
        var starts: [Double] = []
        for h in hips {
            guard let s = starsByHip[h] else { return nil }
            starts.append(raNow(s.ra, s.dec))
        }
        let ra = raNow(p.ra, p.dec)
        for n in 0..<28 {
            let from = starts[n], to = starts[(n + 1) % 28]
            let width = Astronomy.normalize(to - from)
            if width < 180, Boundaries.contains(ra: ra, from: from, to: to) { return n + 1 }
        }
        return nil
    }
}

/// 가장 가까운 별자리 찾기. 경계선이 없는 한국 전통 별자리에서 "지금 보는 곳 근처 별자리"를 찾을 때 쓴다.
/// 별자리까지의 거리 = 그 별자리에 속한 별 중 가장 가까운 별까지의 거리.
///
/// 별 위치를 화살표로 바꾸는 준비 작업을 처음 한 번만 해 두고 계속 재사용한다.
/// (앱에서는 매 프레임 부르므로 준비를 매번 하면 느리다 — `Astronomy.Context`와 같은 생각)
public struct NearestFinder: Sendable {
    public let constellations: [Constellation]
    let members: [(index: Int, v: [Double])]   // (몇 번째 별자리, 소속 별의 방향 화살표)

    public init(constellations: [Constellation], starsByHip: [Int: Star]) {
        self.constellations = constellations
        var m: [(Int, [Double])] = []
        for (i, c) in constellations.enumerated() {
            for hip in Set(c.lines.joined()) {
                if let s = starsByHip[hip] { m.append((i, Astronomy.unitVector(ra: s.ra, dec: s.dec))) }
            }
        }
        members = m
    }

    /// 가장 가까운 별자리와 거리(도). maxDistance(도)보다 멀면 nil
    public func nearest(to p: Equatorial, maxDistance: Double = 10) -> (constellation: Constellation, distance: Double)? {
        let v = Astronomy.unitVector(ra: p.ra, dec: p.dec)
        // 거리 비교 대신 내적 비교: 두 화살표의 내적이 클수록 가깝다 (1.8절). acos를 매번 안 해도 돼서 빠르다
        var bestIndex = -1, bestDot = cos(Astronomy.rad(maxDistance))
        for (i, u) in members {
            let dot = v[0] * u[0] + v[1] * u[1] + v[2] * u[2]
            if dot >= bestDot { bestDot = dot; bestIndex = i }
        }
        guard bestIndex >= 0 else { return nil }
        return (constellations[bestIndex], Astronomy.deg(acos(min(1, bestDot))))
    }
}

public extension StarCatalog {
    /// 한 번만 찾을 때 쓰는 간편 버전. 여러 번 찾을 거면 NearestFinder를 만들어 두고 쓰기
    func nearestConstellation(to p: Equatorial, in list: [Constellation],
                              maxDistance: Double = 10) -> (constellation: Constellation, distance: Double)? {
        NearestFinder(constellations: list, starsByHip: starsByHip()).nearest(to: p, maxDistance: maxDistance)
    }
}
