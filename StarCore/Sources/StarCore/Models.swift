import Foundation

/// stars.json 최상위 구조
public struct StarCatalog: Codable, Sendable {
    public let epoch: String
    public let stars: [Star]
    public let constellations: [Constellation]

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

public struct Constellation: Codable, Sendable, Identifiable {
    public let id: String          // "Ori"
    public let nameKo: String      // "오리온자리"
    public let nameEn: String      // "Orion"
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
