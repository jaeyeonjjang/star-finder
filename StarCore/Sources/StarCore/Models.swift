import Foundation

/// stars.json 최상위 구조
public struct StarCatalog: Codable, Sendable {
    public let epoch: String
    public let stars: [Star]
    /// 서양 별자리 (국제천문연맹 88개)
    public let constellations: [Constellation]
    /// 다른 문화권 별자리. 지금은 "korean" (천상열차분야지도 312개)
    public let skyCultures: [String: SkyCulture]?
    /// 서양 별자리 공식 경계선 (Locate.swift)
    public let boundaries: Boundaries?

    /// 한국 전통 별자리
    public var korean: SkyCulture? { skyCultures?["korean"] }

    public static func load(from data: Data) throws -> StarCatalog {
        try JSONDecoder().decode(StarCatalog.self, from: data)
    }
}

public struct Star: Codable, Sendable, Identifiable {
    public let hip: Int
    /// 적경 (도, J2000)
    public let ra: Double
    /// 적위 (도, J2000)
    public let dec: Double
    /// 겉보기 등급 (작을수록 밝음)
    public let mag: Double
    public let name: String?
    /// 색지수 B-V (파랑 < 0 < 빨강)
    public let ci: Double?

    public var id: Int { hip }
}

/// 별자리 체계 하나 (예: 한국 전통)
public struct SkyCulture: Codable, Sendable {
    public let name: String        // "한국 전통 (천상열차분야지도)"
    public let license: String     // "GPL-2.0"
    public let constellations: [Constellation]
    /// 28수의 거성(距星, 각 수의 시작 기준 별) HIP 번호 28개. 한국 전통만 있음
    public let mansionStars: [Int]?
}

/// 국제천문연맹(IAU) 별자리 경계선. 1875년 기준 좌표(B1875)에서 전부 가로선 아니면 세로선이다.
/// (1930년에 IAU가 그렇게 정했다. 세차 때문에 지금 좌표로는 살짝 비뚤어져 있다)
public struct Boundaries: Codable, Sendable {
    public let epoch: String           // "B1875"
    /// 가로 경계선: 적위 dec에서 적경 ra1부터 동쪽으로 ra2까지. 위아래가 별자리 a, b
    public let parallels: [Parallel]
    /// 세로 경계선: 적경 ra에서 적위 dec1부터 dec2까지. 판정에는 안 쓰고 그릴 때만 쓴다
    public let meridians: [Meridian]

    public struct Parallel: Codable, Sendable {
        public let dec: Double, ra1: Double, ra2: Double
        public let a: String, b: String
    }
    public struct Meridian: Codable, Sendable {
        public let ra: Double, dec1: Double, dec2: Double
        public let a: String, b: String
    }
}

public struct Constellation: Codable, Sendable, Identifiable {
    public let id: String          // "Ori" (서양), "P01" / "01A" (한국 전통, KoreanSky.swift 참고)
    public let nameKo: String      // "오리온자리", "북극"
    public let nameEn: String      // "Orion", "Northern Pole"
    /// 한자 이름 (한국 전통 별자리만). "北極"
    public let nameHanja: String?
    /// 선분 목록. 각 배열은 HIP 번호를 순서대로 이은 폴리라인
    public let lines: [[Int]]
    /// 별자리 그림. Pup, Vel, Ser은 nil — 용골자리(Car) 그림이 아르고호 전체,
    /// 땅꾼자리(Oph) 그림에 뱀이 포함되어 있어서 따로 없다.
    public let art: ConstellationArt?
}

/// 별자리 그림 정보. 이미지 파일은 assets/constellations/{file}
public struct ConstellationArt: Codable, Sendable {
    public let file: String       // "orion.png"
    public let width: Int         // 픽셀
    public let height: Int
    /// 그림의 픽셀 위치 3개와, 그 위치에 와야 하는 별 3개
    public let anchors: [Anchor]

    public struct Anchor: Codable, Sendable {
        public let x: Double      // 픽셀, 왼쪽 위가 (0, 0)
        public let y: Double
        public let hip: Int
    }
}

/// 지평 좌표 (관측자 기준)
public struct Horizontal: Sendable, Equatable {
    /// 고도 (도). 0 = 지평선, 90 = 천정
    public let altitude: Double
    /// 방위각 (도). 0 = 북, 90 = 동, 180 = 남, 270 = 서
    public let azimuth: Double

    public var isAboveHorizon: Bool { altitude > 0 }
}

/// AR 공간용 단위 벡터. ARKit `.gravityAndHeading` 축과 동일:
/// +x = 동, +y = 위, -z = 북
public struct Vector3: Sendable, Equatable {
    public let x: Double, y: Double, z: Double
}

/// 관측자 위치
public struct Observer: Sendable {
    public let latitude: Double   // 북위 +
    public let longitude: Double  // 동경 +
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
