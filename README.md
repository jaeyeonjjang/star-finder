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
cd tools && python3 build_catalog.py        # -> stars.json (별 ~5,000개, 88개 별자리)

# 계산 로직 테스트
cd ../StarCore && swift test
```

## 사용 예

```swift
let catalog = try StarCatalog.load(from: data)
let ctx = Astronomy.Context(date: .now, observer: .init(latitude: 37.5665, longitude: 126.978))
for star in catalog.stars {
    let h = Astronomy.horizontal(of: star, context: ctx)
    guard h.isAboveHorizon else { continue }
    let v = Astronomy.arVector(h)   // ARKit 좌표 (+x 동, +y 위, -z 북)
}
```

## 데이터 라이선스
- HYG Database v4.1 — CC BY-SA 4.0
- Stellarium modern sky culture (별자리 선) — GPL-2.0
- d3-celestial (별자리 한국어 이름) — BSD-3-Clause

앱 출시 시 앱 내 정보 화면에 출처 표기 필요. Stellarium 데이터는 GPL이라 상용 출시 전 라이선스 확인 권장.
