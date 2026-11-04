// StarCore로 하늘을 계산해서 브라우저 시뮬레이터가 읽을 web/sky.json을 만든다.
//
// 사용법: swift run StarSim [--lat 37.5665] [--lon 126.978] [--date now|2026-11-04T22:00:00+09:00]
//                           [--hours 24] [--step 2]
//
// 핵심 아이디어: 별·선·그림은 시간에 따라 안 바뀌는 "적도 벡터"로 한 번만 내보내고,
// 시간에 따라 바뀌는 건 하늘 전체의 회전 행렬(Astronomy.equatorialToAR)뿐이다.
// 그래서 24시간치를 2분 간격으로 내보내도 행렬 720개(숫자 6,480개)면 된다.
//
// "지금 어느 별자리를 보고 있나"는 하늘을 1° 칸으로 나눠 칸마다 StarCore로 미리 판정한 표(grid)로 내보낸다.
// 브라우저는 카메라 방향에 해당하는 칸만 읽으면 된다 (판정 로직을 JS로 다시 짤 필요가 없다).
import Foundation
import StarCore

// MARK: - 인자

var lat = 37.5665, lon = 126.978, hours = 24.0, stepMinutes = 2.0
var start = Date()
var args = CommandLine.arguments.dropFirst()
while let key = args.popFirst() {
    guard let value = args.popFirst() else { fatalError("\(key) 값이 없음") }
    switch key {
    case "--lat": lat = Double(value)!
    case "--lon": lon = Double(value)!
    case "--hours": hours = Double(value)!
    case "--step": stepMinutes = Double(value)!
    case "--date":
        if value != "now" {
            guard let d = ISO8601DateFormatter().date(from: value) else { fatalError("날짜 형식: 2026-11-04T22:00:00+09:00") }
            start = d
        }
    default: fatalError("모르는 옵션: \(key)")
    }
}

// MARK: - 경로 (이 파일 위치 기준: simulator/Sources/StarSim/main.swift)

let simDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let repo = simDir.deletingLastPathComponent()
let catalog = try StarCatalog.load(from: Data(contentsOf: repo.appendingPathComponent("tools/stars.json")))
let byHip = catalog.starsByHip()
let korean = catalog.korean!

// MARK: - 출력 형식 (숫자는 평평한 배열로: [x, y, z, x, y, z, ...] — JSON 크기를 줄이려고)

struct Sky: Encodable {
    struct Frames: Encodable {
        let start: Double          // Unix 시간 (밀리초) — JS Date와 같은 단위
        let stepMinutes: Double
        let matrices: [[Double]]   // 프레임마다 3×3 행렬을 행 우선으로 펼친 9개
    }
    struct Stars: Encodable {
        let pos: [Double]          // 적도 단위 벡터 xyz
        let color: [Double]        // rgb 0...1
        let size: [Double]         // Appearance.relativeSize
    }
    struct Name: Encodable { let i: Int; let name: String }
    struct Con: Encodable {
        let id: String, ko: String, en: String
        let hanja: String?
        let dir: Int?              // 한국 전통: 방향 번호 (directions 배열 순서)
        let main: Bool?            // 한국 전통: 28수의 대표 별자리
        let pos: [Double]?         // 이름 놓을 곳 (적도 단위 벡터). 선 없는 별자리는 nil
        let story: String?         // 별자리 이야기
    }
    struct Culture: Encodable {
        let cons: [Con]
        let lines: [Int]           // 별 번호 쌍 [a, b, a, b, ...]
        let lineCon: [Int]         // 선분마다 몇 번째 별자리인지
    }
    struct Dir: Encodable { let name: String; let guardian: String?; let colorName: String; let color: [Double] }
    struct Mansion: Encodable { let name: String; let dir: Int }
    struct Grid: Encodable {
        let res: Double            // 칸 크기 (도). 칸 번호 = floor(적위+90) * 360 + floor(적경)
        let western: String        // base64 UInt8: 서양 별자리 번호+1
        let korean: String         // base64 UInt16(리틀엔디언): 가장 가까운(8° 이내) 한국 별자리 번호+1, 0 = 없음
        let mansion: String        // base64 UInt8: 28수 번호 1...28
    }
    struct Art: Encodable { let id: String; let file: String; let pos: [Double]; let uv: [Double]; let idx: [UInt32] }

    let observer: [Double]
    let frames: Frames
    let stars: Stars
    let starNames: [Name]
    let western: Culture
    let korean: Culture
    let directions: [Dir]
    let mansions: [Mansion]
    let grid: Grid
    let art: [Art]
}

func r(_ x: Double, _ digits: Double = 5) -> Double { (x * pow(10, digits)).rounded() / pow(10, digits) }
func vec(_ e: Equatorial) -> [Double] { Astronomy.unitVector(ra: e.ra, dec: e.dec).map { r($0) } }

// 시간별 회전 행렬
let count = Int(hours * 60 / stepMinutes) + 1
let observer = Observer(latitude: lat, longitude: lon)
let matrices = (0..<count).map { i -> [Double] in
    let ctx = Astronomy.Context(date: start.addingTimeInterval(Double(i) * stepMinutes * 60), observer: observer)
    return Astronomy.equatorialToAR(context: ctx).flatMap { $0 }.map { r($0, 8) }
}

// 별
var index: [Int: Int] = [:]
var pos: [Double] = [], color: [Double] = [], size: [Double] = [], names: [Sky.Name] = []
for (i, s) in catalog.stars.enumerated() {
    index[s.hip] = i
    pos += vec(Equatorial(ra: s.ra, dec: s.dec))
    let c = s.color
    color += [r(c.r, 3), r(c.g, 3), r(c.b, 3)]
    size.append(r(s.relativeSize, 3))
    if let n = s.name, s.mag < 2.0 { names.append(.init(i: i, name: n)) }
}

// 별자리 체계 하나 -> 선분 + 이름
let directions = Direction.allCases
func culture(_ list: [Constellation]) -> Sky.Culture {
    let centers = catalog.constellationCenters(of: list)
    var lines: [Int] = [], lineCon: [Int] = []
    var cons: [Sky.Con] = []
    for (ci, c) in list.enumerated() {
        for seg in c.lines {                      // 꺾은선 [a, b, c] -> 선분 (a, b), (b, c)
            for (a, b) in zip(seg, seg.dropFirst()) where a != b {
                if let ia = index[a], let ib = index[b] { lines += [ia, ib]; lineCon.append(ci) }
            }
        }
        let g = c.koreanGroup
        cons.append(.init(id: c.id, ko: c.nameKo, en: c.nameEn, hanja: c.nameHanja,
                          dir: g.map { directions.firstIndex(of: $0.direction)! },
                          main: g == nil ? nil : KoreanGroup.isMansionMain(c.id),
                          pos: centers[c.id].map(vec), story: c.story))
    }
    return .init(cons: cons, lines: lines, lineCon: lineCon)
}
let western = culture(catalog.constellations)
let koreanCulture = culture(korean.constellations)

// 판정 표 (1° 칸, 칸 가운데 점으로 판정)
let boundaries = catalog.boundaries!
let westernIndex = Dictionary(uniqueKeysWithValues: catalog.constellations.enumerated().map { ($1.id, $0) })
let finder = NearestFinder(constellations: korean.constellations, starsByHip: byHip)
let koreanIndex = Dictionary(uniqueKeysWithValues: korean.constellations.enumerated().map { ($1.id, $0) })
let ctx0 = Astronomy.Context(date: start, observer: observer)
var gW = [UInt8](), gK = [UInt16](), gM = [UInt8]()
for row in 0..<180 {
    for col in 0..<360 {
        let p = Equatorial(ra: Double(col) + 0.5, dec: Double(row) - 89.5)
        gW.append(UInt8((boundaries.constellation(at: p).flatMap { westernIndex[$0] } ?? -1) + 1))
        gK.append(UInt16((finder.nearest(to: p, maxDistance: 8).flatMap { koreanIndex[$0.constellation.id] } ?? -1) + 1))
        gM.append(UInt8(korean.mansion(at: p, context: ctx0, starsByHip: byHip) ?? 0))
    }
}
let gKBytes = gK.flatMap { [UInt8($0 & 0xff), UInt8($0 >> 8)] }

// 그림
let meshes = catalog.artMeshes()
let art = catalog.constellations.compactMap { c -> Sky.Art? in
    guard let a = c.art, let m = meshes[c.id] else { return nil }
    return Sky.Art(id: c.id, file: a.file, pos: m.positions.flatMap(vec),
                   uv: m.uvs.flatMap { [r($0.u), r($0.v)] }, idx: m.indices)
}

let sky = Sky(observer: [lat, lon],
              frames: .init(start: (start.timeIntervalSince1970 * 1000).rounded(), stepMinutes: stepMinutes, matrices: matrices),
              stars: .init(pos: pos, color: color, size: size), starNames: names,
              western: western, korean: koreanCulture,
              directions: directions.map { .init(name: $0.name, guardian: $0.guardian, colorName: $0.colorName,
                                                 color: [$0.color.r, $0.color.g, $0.color.b]) },
              mansions: (1...28).map { .init(name: KoreanGroup.mansion($0).name,
                                             dir: directions.firstIndex(of: KoreanGroup.mansion($0).direction)!) },
              grid: .init(res: 1, western: Data(gW).base64EncodedString(),
                          korean: Data(gKBytes).base64EncodedString(), mansion: Data(gM).base64EncodedString()),
              art: art)

let out = simDir.appendingPathComponent("web/sky.json")
try JSONEncoder().encode(sky).write(to: out)
let kb = (try? FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int).flatMap { $0 }.map { $0 / 1024 } ?? 0
print("별 \(catalog.stars.count)개, 서양 선 \(western.lineCon.count)개, 한국 선 \(koreanCulture.lineCon.count)개, "
      + "그림 \(art.count)개, 프레임 \(count)개 -> \(out.path) (\(kb) KB)")
