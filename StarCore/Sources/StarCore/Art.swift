import Foundation

/// 그림 픽셀 (x, y) -> 하늘 방향.
///
/// 원리: 그림의 픽셀 좌표에 1을 붙인 (x, y, 1)을 3차원 벡터로 보고,
/// 기준점 3개에서 "(x, y, 1)을 별의 방향 벡터로 보내는" 3×3 행렬 M을 구한다.
///
///     M · [x₁ x₂ x₃]   [별₁ 별₂ 별₃]          M = [별₁ 별₂ 별₃] · [x₁ x₂ x₃]⁻¹
///         [y₁ y₂ y₃] = [ (3D 방향)  ]   =>               (3D)       [y₁ y₂ y₃]
///         [ 1  1  1]                                                 [ 1  1  1]
///
/// 그러면 다른 픽셀도 M · (x, y, 1)을 단위 벡터로 정규화하면 하늘 위치가 된다.
/// 그림을 "세 별을 지나는 평면"에 붙인 뒤 천구 중심에서 천구 표면으로 투영하는 것과 같다.
/// (Stellarium도 같은 방식)
public struct ArtProjection: Sendable {
    let m: Matrix3
    public let art: ConstellationArt

    /// 기준점 별을 찾을 수 없거나 기준점 3개가 한 직선 위에 있으면 nil
    public init?(art: ConstellationArt, starsByHip: [Int: Star]) {
        guard art.anchors.count == 3 else { return nil }
        var pixel: [[Double]] = [], sky: [[Double]] = []
        for a in art.anchors {
            guard let s = starsByHip[a.hip] else { return nil }
            pixel.append([a.x, a.y, 1])
            sky.append(Astronomy.unitVector(ra: s.ra, dec: s.dec))
        }
        // 열(column)로 쌓기: 각 기준점이 한 열
        guard let pixelInv = Matrix3(columns: pixel).inverse() else { return nil }
        m = Matrix3(columns: sky) * pixelInv
        self.art = art
    }

    /// 픽셀 -> 적도좌표 (J2000)
    public func equatorial(x: Double, y: Double) -> Equatorial {
        let v = m * [x, y, 1]
        return Astronomy.equatorial(x: v[0], y: v[1], z: v[2])
    }

    /// 그림을 segments × segments 칸 격자로 나눈 메시.
    /// 천구는 휘어 있으므로 그림 한 장을 평면 하나로 붙이면 가장자리가 별에서 어긋난다.
    /// 격자로 잘게 나누면 각 칸은 거의 평평해서 오차가 작다. (8칸이면 큰 별자리도 충분)
    public func mesh(segments n: Int = 8) -> ArtMesh {
        let w = Double(art.width), h = Double(art.height)
        var positions: [Equatorial] = [], uvs: [UV] = []
        for row in 0...n {
            for col in 0...n {
                let u = Double(col) / Double(n), v = Double(row) / Double(n)
                positions.append(equatorial(x: u * w, y: v * h))
                uvs.append(UV(u: u, v: v))
            }
        }
        // 칸 하나 = 삼각형 2개
        //   a ── b
        //   │ ╲  │
        //   c ── d
        var indices: [UInt32] = []
        for row in 0..<n {
            for col in 0..<n {
                let a = UInt32(row * (n + 1) + col), b = a + 1
                let c = a + UInt32(n + 1), d = c + 1
                indices += [a, d, b, a, c, d]
            }
        }
        return ArtMesh(positions: positions, uvs: uvs, indices: indices)
    }
}

/// 텍스처 좌표. 이미지 왼쪽 위 = (0, 0), 오른쪽 아래 = (1, 1)
/// (RealityKit은 v가 아래->위일 수 있음. 앱에서 그림이 뒤집혀 보이면 1 - v로 바꾸기)
public struct UV: Sendable, Equatable {
    public let u: Double, v: Double
}

/// 앱에서 RealityKit `MeshDescriptor`로 바꿔 쓰는 메시 데이터
public struct ArtMesh: Sendable {
    /// 꼭짓점 위치 (J2000). 프레임마다 `Astronomy.horizontal(ra:dec:context:)` -> `arVector`로 변환
    public let positions: [Equatorial]
    public let uvs: [UV]
    /// 삼각형 꼭짓점 번호, 3개씩 한 삼각형
    public let indices: [UInt32]
}

public extension StarCatalog {
    /// 그림이 있는 별자리마다 메시 (별자리 id -> 메시). 앱 시작 시 한 번 계산.
    func artMeshes(segments: Int = 8) -> [String: ArtMesh] {
        let byHip = starsByHip()
        var result: [String: ArtMesh] = [:]
        for c in constellations {
            if let art = c.art, let p = ArtProjection(art: art, starsByHip: byHip) {
                result[c.id] = p.mesh(segments: segments)
            }
        }
        return result
    }
}

// MARK: - 3×3 행렬 (simd는 리눅스에서 못 쓰므로 직접 구현)

struct Matrix3: Sendable {
    /// 행 우선: e[행][열]
    let e: [[Double]]

    init(rows: [[Double]]) { e = rows }
    init(columns c: [[Double]]) {
        e = (0..<3).map { r in (0..<3).map { col in c[col][r] } }
    }

    static func * (a: Matrix3, b: Matrix3) -> Matrix3 {
        Matrix3(rows: (0..<3).map { r in
            (0..<3).map { c in (0..<3).reduce(0) { $0 + a.e[r][$1] * b.e[$1][c] } }
        })
    }

    static func * (a: Matrix3, v: [Double]) -> [Double] {
        (0..<3).map { r in (0..<3).reduce(0) { $0 + a.e[r][$1] * v[$1] } }
    }

    var determinant: Double {
        e[0][0] * (e[1][1] * e[2][2] - e[1][2] * e[2][1])
      - e[0][1] * (e[1][0] * e[2][2] - e[1][2] * e[2][0])
      + e[0][2] * (e[1][0] * e[2][1] - e[1][1] * e[2][0])
    }

    /// 역행렬 (여인수 전개). 행렬식이 0에 가까우면 nil
    func inverse() -> Matrix3? {
        let det = determinant
        guard abs(det) > 1e-12 else { return nil }
        // 여인수 행렬의 전치 / 행렬식
        func cof(_ r: Int, _ c: Int) -> Double {
            let rs = (0..<3).filter { $0 != r }, cs = (0..<3).filter { $0 != c }
            let minor = e[rs[0]][cs[0]] * e[rs[1]][cs[1]] - e[rs[0]][cs[1]] * e[rs[1]][cs[0]]
            return ((r + c) % 2 == 0 ? 1 : -1) * minor
        }
        return Matrix3(rows: (0..<3).map { r in (0..<3).map { c in cof(c, r) / det } })
    }
}
