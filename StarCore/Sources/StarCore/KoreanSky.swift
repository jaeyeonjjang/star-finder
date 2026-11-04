import Foundation

/// 한국 전통 별자리(천상열차분야지도)의 갈래: 3원(垣) 28수(宿)
///
/// 동아시아에서는 하늘을 31구역으로 나눴다.
/// - 3원: 북극 주변의 "하늘 궁궐" 세 곳. 담장(垣)으로 둘러싸인 구역이라는 뜻
/// - 28수: 달이 하늘을 한 바퀴 도는 약 27.3일 동안 하룻밤씩 묵어 가는 "여관"(宿) 28곳.
///   7개씩 묶어 동·북·서·남 네 방향을 맡고, 방향마다 지키는 동물(사신)이 있다
///
/// 별자리 id 규칙 (Stellarium, 당나라 노래 『보천가』 순서):
/// - "P01" ~ "P39": 자미원,  "S01" ~ "S23": 태미원,  "H01" ~ "H20": 천시원
/// - "01A" ~ "28x": 28수. 숫자 = 몇 번째 수, 글자 = 그 수 안의 몇 번째 별자리 (A가 그 수의 대표)
public enum KoreanGroup: Sendable, Equatable, Hashable {
    case enclosure(Enclosure)   // 3원 중 하나
    case mansion(Int)           // 28수 중 몇 번째 (1...28)

    /// 3원
    public enum Enclosure: String, Sendable, CaseIterable {
        case purple = "P"       // 자미원: 북극성 주변. 임금이 사는 궁궐
        case supreme = "S"      // 태미원: 사자자리~처녀자리 근처. 조정(관청)
        case market = "H"       // 천시원: 헤라클레스~뱀주인자리 근처. 하늘의 시장

        public var name: String {
            switch self {
            case .purple: "자미원(紫微垣)"
            case .supreme: "태미원(太微垣)"
            case .market: "천시원(天市垣)"
            }
        }
    }

    /// 별자리 id로 갈래 찾기. 서양 별자리 id("Ori")나 이상한 값이면 nil
    public init?(id: String) {
        guard let first = id.first else { return nil }
        if let e = Enclosure(rawValue: String(first)) {
            self = .enclosure(e)                         // "P01" -> 자미원
        } else if let n = Int(id.prefix(2)), (1...28).contains(n), id.count >= 3 {
            self = .mansion(n)                           // "01A" -> 1번째 수
        } else {
            return nil
        }
    }

    /// "자미원(紫微垣)", "각수(角宿)"
    public var name: String {
        switch self {
        case .enclosure(let e):
            return e.name
        case .mansion(let n):
            let m = Self.mansions[n - 1]
            return "\(m.ko)수(\(m.hanja)宿)"
        }
    }

    /// 방향. 3원은 가운데, 28수는 7개씩 동·북·서·남
    public var direction: Direction {
        switch self {
        case .enclosure: return .center
        case .mansion(let n): return [.east, .north, .west, .south][(n - 1) / 7]
        }
    }

    /// 이 id가 28수의 대표 별자리인가 ("01A" = 각수 그 자체)
    public static func isMansionMain(_ id: String) -> Bool {
        if case .mansion = KoreanGroup(id: id) { return id.hasSuffix("A") && id.count == 3 }
        return false
    }

    /// 28수 이름 (한 글자). 순서대로 동방 7, 북방 7, 서방 7, 남방 7
    public static let mansions: [(ko: String, hanja: String)] = [
        ("각", "角"), ("항", "亢"), ("저", "氐"), ("방", "房"), ("심", "心"), ("미", "尾"), ("기", "箕"),
        ("두", "斗"), ("우", "牛"), ("여", "女"), ("허", "虛"), ("위", "危"), ("실", "室"), ("벽", "壁"),
        ("규", "奎"), ("루", "婁"), ("위", "胃"), ("묘", "昴"), ("필", "畢"), ("자", "觜"), ("삼", "參"),
        ("정", "井"), ("귀", "鬼"), ("류", "柳"), ("성", "星"), ("장", "張"), ("익", "翼"), ("진", "軫"),
    ]
}

/// 다섯 방향과 오방색 (동양에서 방향마다 정해 둔 색)
public enum Direction: Sendable, CaseIterable {
    case center, east, north, west, south

    public var name: String {
        switch self {
        case .center: "중앙"
        case .east: "동방"
        case .north: "북방"
        case .west: "서방"
        case .south: "남방"
        }
    }

    /// 사신(四神): 방향을 지키는 동물
    public var guardian: String? {
        switch self {
        case .center: nil
        case .east: "청룡"    // 푸른 용
        case .north: "현무"   // 검은 거북과 뱀
        case .west: "백호"    // 흰 호랑이
        case .south: "주작"   // 붉은 새
        }
    }

    /// 오방색 이름
    public var colorName: String {
        switch self {
        case .center: "황(黃)"
        case .east: "청(靑)"
        case .north: "흑(黑)"
        case .west: "백(白)"
        case .south: "적(赤)"
        }
    }

    /// 화면에 그릴 색. 북방의 흑(검정)은 밤하늘에서 안 보이므로 짙은 보라로 대신한다
    public var color: RGB {
        switch self {
        case .center: RGB(r: 1.0, g: 0.82, b: 0.30)
        case .east: RGB(r: 0.30, g: 0.65, b: 1.0)
        case .north: RGB(r: 0.62, g: 0.50, b: 1.0)
        case .west: RGB(r: 0.92, g: 0.92, b: 0.92)
        case .south: RGB(r: 1.0, g: 0.40, b: 0.33)
        }
    }
}

public extension Constellation {
    /// 한국 전통 별자리면 3원/28수 갈래, 아니면 nil
    var koreanGroup: KoreanGroup? { KoreanGroup(id: id) }
}
