<h1 align="center">나랑 별 보러 가지 않을래~</h1>

# Star Finder — 1단계: 데이터 + StarCore

```
star-finder/
├── tools/build_catalog.py   # 별/별자리 데이터 -> stars.json
└── StarCore/                # 순수 Swift 계산 패키지 (WSL/맥 공용)
```

## WSL에 Swift 설치 (Ubuntu 기준, 최초 1회)

```bash
sudo apt update && sudo apt install -y curl git libcurl4-openssl-dev libxml2-dev
curl -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz
tar zxf swiftly-$(uname -m).tar.gz && ./swiftly init
source ~/.local/share/swiftly/env.sh
swift --version
```

VS Code에서는 "WSL" 확장으로 폴더를 연 뒤 "Swift" 확장(swiftlang)을 WSL 쪽에 설치하세요.

## 실행

```bash
# 데이터 생성 (Python 3, 외부 패키지 불필요)
cd tools && python3 build_catalog.py        # -> stars.json (별 ~5,000개, 88개 별자리) + ../assets/constellations/*.png

# (선택) 별자리 그림 윤곽선 스타일 변환 / 미리보기 — numpy, pillow 필요
cd .. && python3 tools/make_outline.py      # -> assets/constellations-outline/*.png
python3 tools/preview_art.py . preview.png Ori,Leo outline

# 계산 로직 테스트
cd ../StarCore && swift test
```

## 사용 예

```swift
let catalog = try StarCatalog.load(from: data)
let ctx = Astronomy.Context(date: .now, observer: .init(latitude: 37.5665, longitude: 126.978))
for star in catalog.stars {
    let h = Astronomy.refracted(Astronomy.horizontal(of: star, context: ctx))  // 눈에 보이는 위치
    guard h.isAboveHorizon else { continue }
    let v = Astronomy.arVector(h)   // ARKit 좌표 (+x 동, +y 위, -z 북)
    let size = star.relativeSize    // 0등급 = 1.0
    let color = star.color          // RGB (0...1)
}

// 별자리 이름 라벨: 시작할 때 한 번 계산
let centers = catalog.constellationCenters()   // ["Ori": Equatorial(ra:dec:), ...]

// 별자리 그림: 시작할 때 한 번 계산, 꼭짓점은 프레임마다 horizontal -> arVector로 변환
let meshes = catalog.artMeshes()               // ["Ori": ArtMesh(positions:uvs:indices:), ...]
```

## 데이터 라이선스
- HYG Database v4.1 — CC BY-SA 4.0
- Stellarium modern sky culture (별자리 선) — CC BY-SA 4.0
- Stellarium modern sky culture (별자리 그림, `assets/constellations/`) — Free Art License
- d3-celestial (별자리 한국어 이름) — BSD-3-Clause

앱 출시 시 앱 내 정보 화면에 출처 표기 필요.
