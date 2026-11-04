import Foundation

/// 적도좌표(J2000) -> 지평좌표 변환.
/// 세차 보정 포함, 대기굴절 미포함. astropy 대비 오차 약 0.01° (AR 용도로 충분).
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
        let zeta: Double, z: Double, sinTheta: Double, cosTheta: Double

        public init(date: Date, observer: Observer) {
            let t = (Astronomy.julianDate(date) - 2451545.0) / 36525.0
            let arcsec = Double.pi / 180.0 / 3600.0
            zeta = (2306.2181 * t + 0.30188 * t * t) * arcsec
            z = (2306.2181 * t + 1.09468 * t * t) * arcsec
            let theta = (2004.3109 * t - 0.42665 * t * t) * arcsec
            sinTheta = sin(theta); cosTheta = cos(theta)
            lst = Astronomy.rad(Astronomy.gmst(date) + observer.longitude)
            sinLat = sin(Astronomy.rad(observer.latitude)); cosLat = cos(Astronomy.rad(observer.latitude))
        }
    }

    /// 별 하나의 지평좌표
    public static func horizontal(ra: Double, dec: Double, context c: Context) -> Horizontal {
        // 1) 세차: J2000 -> 관측 시점
        let a0 = rad(ra), d0 = rad(dec)
        let cosD0 = cos(d0), sinD0 = sin(d0)
        let A = cosD0 * sin(a0 + c.zeta)
        let B = c.cosTheta * cosD0 * cos(a0 + c.zeta) - c.sinTheta * sinD0
        let C = c.sinTheta * cosD0 * cos(a0 + c.zeta) + c.cosTheta * sinD0
        let raNow = atan2(A, B) + c.z
        let decNow = asin(max(-1, min(1, C)))

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

    /// 지평좌표 -> AR 공간 단위 벡터 (+x 동, +y 위, -z 북)
    public static func arVector(_ h: Horizontal) -> Vector3 {
        let alt = rad(h.altitude), az = rad(h.azimuth)
        return Vector3(x: cos(alt) * sin(az), y: sin(alt), z: -cos(alt) * cos(az))
    }

    // MARK: - 유틸

    @inline(__always) static func rad(_ d: Double) -> Double { d * .pi / 180.0 }
    @inline(__always) static func deg(_ r: Double) -> Double { r * 180.0 / .pi }
    static func normalize(_ d: Double) -> Double {
        let r = d.truncatingRemainder(dividingBy: 360.0)
        return r < 0 ? r + 360.0 : r
    }
}
