// StarCore로 하늘을 계산해서 브라우저 시뮬레이터가 읽을 web/sky.json을 만든다.
//
// 사용법: swift run StarSim [--lat 37.5665] [--lon 126.978] [--date now|2026-11-04T22:00:00+09:00]
//                           [--hours 24] [--step 2]
//
// 핵심 아이디어: 별·선·그림은 시간에 따라 안 바뀌는 "적도 벡터"로 한 번만 내보내고,
// 시간에 따라 바뀌는 건 하늘 전체의 회전 행렬(Astronomy.equatorialToAR)뿐이다.
// 그래서 24시간치를 2분 간격으로 내보내도 행렬 720개(숫자 6,480개)면 된다.
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
    struct Label: Encodable { let id: String; let ko: String; let en: String; let pos: [Double] }
    struct Art: Encodable { let id: String; let file: String; let pos: [Double]; let uv: [Double]; let idx: [UInt32] }

    let observer: [Double]
    let frames: Frames
    let stars: Stars
    let starNames: [Name]
    let lines: [Int]               // 별 번호 쌍 [a, b, a, b, ...]
    let labels: [Label]
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

// 별자리 선: 꺾은선 [a, b, c] -> 선분 (a, b), (b, c)
var lines: [Int] = []
for c in catalog.constellations {
    for seg in c.lines {
        for (a, b) in zip(seg, seg.dropFirst()) {
            if let ia = index[a], let ib = index[b] { lines += [ia, ib] }
        }
    }
}

// 라벨, 그림
let centers = catalog.constellationCenters()
let labels = catalog.constellations.compactMap { c in
    centers[c.id].map { Sky.Label(id: c.id, ko: c.nameKo, en: c.nameEn, pos: vec($0)) }
}
let meshes = catalog.artMeshes()
let art = catalog.constellations.compactMap { c -> Sky.Art? in
    guard let a = c.art, let m = meshes[c.id] else { return nil }
    return Sky.Art(id: c.id, file: a.file, pos: m.positions.flatMap(vec),
                   uv: m.uvs.flatMap { [r($0.u), r($0.v)] }, idx: m.indices)
}

let sky = Sky(observer: [lat, lon],
              frames: .init(start: (start.timeIntervalSince1970 * 1000).rounded(), stepMinutes: stepMinutes, matrices: matrices),
              stars: .init(pos: pos, color: color, size: size), starNames: names,
              lines: lines, labels: labels, art: art)

let out = simDir.appendingPathComponent("web/sky.json")
try JSONEncoder().encode(sky).write(to: out)
let kb = (try? FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int).flatMap { $0 }.map { $0 / 1024 } ?? 0
print("별 \(catalog.stars.count)개, 선 \(lines.count / 2)개, 그림 \(art.count)개, 프레임 \(count)개 -> \(out.path) (\(kb) KB)")
