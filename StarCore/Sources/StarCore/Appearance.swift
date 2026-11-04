import Foundation

/// 색 (각 채널 0...1). 앱에서 `UIColor(red:green:blue:alpha:)` 등으로 변환해 쓰세요.
public struct RGB: Sendable, Equatable {
    public let r: Double, g: Double, b: Double
    public init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }
    public static let white = RGB(r: 1, g: 1, b: 1)
}

/// 별을 화면에 그릴 때의 크기와 색
public enum Appearance {

    // MARK: - 크기

    /// 등급 -> 상대 크기. 0등급 = 1.0
    ///
    /// 물리적으로는 밝기(플럭스) ∝ 10^(-0.4·mag), 반지름은 그 제곱근 ∝ 10^(-0.2·mag)이지만
    /// 그대로 쓰면 시리우스와 6등급 별의 크기가 약 30배나 차이 나서 어두운 별이 안 보인다.
    /// 지수를 0.12로 낮춰 차이를 약 8배로 줄였다. (튜닝 값: 실기기에서 보고 조정)
    public static func relativeSize(magnitude: Double,
                                    exponent: Double = 0.12,
                                    range: ClosedRange<Double> = 0.15...2.5) -> Double {
        let s = pow(10, -exponent * magnitude)
        return min(max(s, range.lowerBound), range.upperBound)
    }

    // MARK: - 색

    /// 색지수 B-V -> 표면 온도 (K). Ballesteros (2012) 공식
    public static func temperature(bv: Double) -> Double {
        4600 * (1 / (0.92 * bv + 1.7) + 1 / (0.92 * bv + 0.62))
    }

    /// 온도 (K) -> RGB. Tanner Helland 흑체 근사 (1000K~40000K)
    public static func color(temperature kelvin: Double) -> RGB {
        let t = min(max(kelvin, 1000), 40000) / 100
        let r, g, b: Double
        if t <= 66 {
            r = 255
            g = 99.4708025861 * log(t) - 161.1195681661
            b = t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307
        } else {
            r = 329.698727446 * pow(t - 60, -0.1332047592)
            g = 288.1221695283 * pow(t - 60, -0.0755148492)
            b = 255
        }
        func c(_ v: Double) -> Double { min(max(v, 0), 255) / 255 }
        return RGB(r: c(r), g: c(g), b: c(b))
    }

    /// 별 색. 색지수가 없으면 흰색.
    /// - Parameter saturation: 0 = 흰색, 1 = 흑체 색 그대로. 실제 밤하늘의 별은 색이 옅어서
    ///   기본값 0.6으로 흰색과 섞는다. (튜닝 값)
    public static func color(bv: Double?, saturation: Double = 0.6) -> RGB {
        guard let bv else { return .white }
        let c = color(temperature: temperature(bv: bv))
        func mix(_ v: Double) -> Double { 1 + (v - 1) * saturation }
        return RGB(r: mix(c.r), g: mix(c.g), b: mix(c.b))
    }
}

public extension Star {
    var relativeSize: Double { Appearance.relativeSize(magnitude: mag) }
    var color: RGB { Appearance.color(bv: ci) }
}
