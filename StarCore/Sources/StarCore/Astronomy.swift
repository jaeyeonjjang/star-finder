import Foundation

/// 적도좌표(J2000) -> 지평좌표 변환.
/// 세차 보정 포함. astropy 대비 오차 약 0.01° (AR 용도로 충분).
/// `horizontal`은 대기굴절 미포함(기하학적 위치) — 눈에 보이는 위치는 `refracted(_:)`를 한 번 더 적용.
public enum Astronomy {

    // MARK: - 시간

    /// 율리우스일
    public static func julianDate(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    /// 그리니치 평균 항성시 (도, 0..<360)
    public static func gmst(_ date: Date) -> Double {
        let d = julianDate(date) - 2451545.0
        let t = d / 36525.0
        return normalize(280.46061837 + 360.98564736629 * d + 0.000387933 * t * t)
    }

    // MARK: - 좌표 변환

    /// 시간에 따라 바뀌지 않는 값을 미리 계산해 두는 컨텍스트.
    /// 프레임마다 별 수천 개를 변환할 때 이걸 한 번 만들고 재사용하세요.
    public struct Context: Sendable {
        let lst: Double            // 지방 항성시 (rad)
        let sinLat: Double, cosLat: Double
        let precession: Precession // J2000 -> 관측 시점

        public init(date: Date, observer: Observer) {
            let t = (Astronomy.julianDate(date) - 2451545.0) / 36525.0
            precession = Precession(centuries: t)
            lst = Astronomy.rad(Astronomy.gmst(date) + observer.longitude)
            sinLat = sin(Astronomy.rad(observer.latitude)); cosLat = cos(Astronomy.rad(observer.latitude))
        }
    }

    // MARK: - 세차

    /// 세차 보정: J2000 주소 -> 다른 시점의 주소 (IAU 1976 공식).
    /// 자전축이 J2000부터 t세기(1세기 = 100년) 동안 돌아간 양을 각도 세 개(zeta, z, theta)로 나타낸다.
    /// t가 음수면 과거 쪽 (예: 1875년 = -1.25세기)
    struct Precession: Sendable {
        let zeta: Double, z: Double, sinTheta: Double, cosTheta: Double

        init(centuries t: Double) {
            let arcsec = Double.pi / 180.0 / 3600.0
            zeta = (2306.2181 * t + 0.30188 * t * t) * arcsec
            z = (2306.2181 * t + 1.09468 * t * t) * arcsec
            let theta = (2004.3109 * t - 0.42665 * t * t) * arcsec
            sinTheta = sin(theta); cosTheta = cos(theta)
        }

        /// (적경, 적위) 라디안 -> 그 시점의 (적경, 적위) 라디안
        func apply(ra a0: Double, dec d0: Double) -> (ra: Double, dec: Double) {
            let cosD0 = cos(d0), sinD0 = sin(d0)
            let A = cosD0 * sin(a0 + zeta)
            let B = cosTheta * cosD0 * cos(a0 + zeta) - sinTheta * sinD0
            let C = sinTheta * cosD0 * cos(a0 + zeta) + cosTheta * sinD0
            return (atan2(A, B) + z, asin(max(-1, min(1, C))))
        }
    }

    /// J2000 좌표를 t세기 뒤(음수면 앞)의 좌표로 (도 단위)
    public static func precess(_ p: Equatorial, centuries t: Double) -> Equatorial {
        let r = Precession(centuries: t).apply(ra: rad(p.ra), dec: rad(p.dec))
        return Equatorial(ra: normalize(deg(r.ra)), dec: deg(r.dec))
    }

    /// 별 하나의 지평좌표
    public static func horizontal(ra: Double, dec: Double, context c: Context) -> Horizontal {
        // 1) 세차: J2000 -> 관측 시점
        let (raNow, decNow) = c.precession.apply(ra: rad(ra), dec: rad(dec))

        // 2) 시간각 -> 고도/방위각
        let h = c.lst - raNow
        let sinD = sin(decNow), cosD = cos(decNow), cosH = cos(h)
        let alt = asin(sinD * c.sinLat + cosD * c.cosLat * cosH)
        let az = atan2(-cosD * sin(h), sinD * c.cosLat - cosD * c.sinLat * cosH)
        return Horizontal(altitude: deg(alt), azimuth: normalize(deg(az)))
    }

    public static func horizontal(of star: Star, context: Context) -> Horizontal {
        horizontal(ra: star.ra, dec: star.dec, context: context)
    }

    // MARK: - 대기굴절

    /// 대기굴절량 (도). 공기가 빛을 휘게 해서 별이 실제보다 높아 보이는 정도.
    /// Sæmundsson (1986) 공식, 입력은 굴절 전(기하학적) 고도.
    /// 지평선에서 약 0.5°, 고도 45°에서 약 0.017°, 천정에서 0.
    /// - Parameters:
    ///   - pressure: 기압 (hPa), 기본 1010
    ///   - temperature: 기온 (°C), 기본 10
    public static func refraction(altitude: Double, pressure: Double = 1010, temperature: Double = 10) -> Double {
        // 공식이 -5° 근처에서 발산하므로 -1° 아래는 -1° 값으로 고정 (지평선 아래라 보이지 않음)
        let h = max(altitude, -1)
        let arcmin = 1.02 / tan(rad(h + 10.3 / (h + 5.11)))
        let scale = (pressure / 1010) * (283 / (273 + temperature))
        return max(arcmin, 0) / 60 * scale   // 천정 근처에서 살짝 음수가 나오는 것 방지
    }

    /// 대기굴절을 적용한 지평좌표 (눈에 보이는 위치)
    public static func refracted(_ h: Horizontal, pressure: Double = 1010, temperature: Double = 10) -> Horizontal {
        Horizontal(altitude: h.altitude + refraction(altitude: h.altitude, pressure: pressure, temperature: temperature),
                   azimuth: h.azimuth)
    }

    /// 지평좌표 -> AR 공간 단위 벡터 (+x 동, +y 위, -z 북)
    public static func arVector(_ h: Horizontal) -> Vector3 {
        let alt = rad(h.altitude), az = rad(h.azimuth)
        return Vector3(x: cos(alt) * sin(az), y: sin(alt), z: -cos(alt) * cos(az))
    }

    /// 적도좌표(J2000) 단위 벡터 -> AR 벡터로 보내는 3×3 회전 행렬 (행 우선: m[행][열]).
    ///
    /// 세차 보정도, 적도->지평 변환도 결국 "회전"이라서 하늘 전체가 행렬 하나로 같이 돈다.
    /// 그래서 별 5,000개를 매 프레임 `horizontal`로 변환하는 대신,
    /// 별은 고정된 적도 벡터(`unitVector`)로 한 번만 만들어 두고 프레임마다 이 행렬만 바꾸면 된다.
    /// (앱에서는 별, 선, 그림을 담은 부모 노드의 회전으로 쓰기. 대기굴절은 이 방식에 포함 안 됨)
    ///
    /// 구하는 법: 행렬의 각 열 = 축 방향 벡터(x, y, z축)를 변환한 결과
    public static func equatorialToAR(context: Context) -> [[Double]] {
        let axes = [(ra: 0.0, dec: 0.0), (ra: 90.0, dec: 0.0), (ra: 0.0, dec: 90.0)]  // x, y, z축
        let cols = axes.map { arVector(horizontal(ra: $0.ra, dec: $0.dec, context: context)) }
        return [cols.map(\.x), cols.map(\.y), cols.map(\.z)]
    }

    /// 거꾸로: AR 방향 -> J2000 적도좌표. "카메라가 보는 방향은 하늘 주소로 어디인가?"
    ///
    /// 회전 행렬의 역행렬은 전치 행렬(행과 열을 바꾼 것)이다. 돌린 걸 되돌리려면 반대로 돌리면 되기 때문.
    /// 그래서 역행렬을 따로 계산할 필요 없이 m[행][열] 대신 m[열][행]을 쓰면 된다.
    /// (대기굴절은 반영 안 됨)
    public static func equatorial(fromAR v: Vector3, context: Context) -> Equatorial {
        let m = equatorialToAR(context: context)
        let a = [v.x, v.y, v.z]
        let e = (0..<3).map { c in (0..<3).reduce(0) { $0 + m[$1][c] * a[$1] } }   // 전치 행렬 × 벡터
        return equatorial(x: e[0], y: e[1], z: e[2])
    }

    // MARK: - 적도좌표 <-> 3D 벡터 (적도 기준: x = 춘분점, z = 천구 북극)

    /// 적경/적위 -> 단위 벡터 [x, y, z]
    public static func unitVector(ra: Double, dec: Double) -> [Double] {
        let a = rad(ra), d = rad(dec)
        return [cos(d) * cos(a), cos(d) * sin(a), sin(d)]
    }

    /// 벡터 -> 적경/적위 (길이는 상관없음)
    public static func equatorial(x: Double, y: Double, z: Double) -> Equatorial {
        Equatorial(ra: normalize(deg(atan2(y, x))), dec: deg(atan2(z, (x * x + y * y).squareRoot())))
    }

    // MARK: - 유틸

    @inline(__always) static func rad(_ d: Double) -> Double { d * .pi / 180.0 }
    @inline(__always) static func deg(_ r: Double) -> Double { r * 180.0 / .pi }
    static func normalize(_ d: Double) -> Double {
        let r = d.truncatingRemainder(dividingBy: 360.0)
        return r < 0 ? r + 360.0 : r
    }
}
