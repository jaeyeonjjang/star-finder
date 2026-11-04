# StarCore 공부 가이드

StarCore는 "지금 여기서 하늘을 보면 각 별이 어느 방향에 있나?"를 계산하는 순수 Swift 패키지다.
화면도, 카메라도, 센서도 없다. 입력(별 목록, 시각, 위치)을 받아 숫자(방향, 크기, 색)를 돌려줄 뿐이다.
그래서 WSL에서도 빌드되고 테스트할 수 있다.

이 문서는 다음 순서로 읽으면 된다.

1. 전체 흐름 — 데이터가 어떤 단계를 거쳐 AR 화면 좌표가 되나
2. 천문학 배경 — 각 단계가 왜 필요한가
3. 파일별 설명 — 코드가 실제로 어떻게 생겼나
4. 이 코드에 나오는 Swift 문법 — Python/TypeScript와 비교
5. 테스트
6. 직접 해볼 것

---

## 1. 전체 흐름

```
tools/stars.json  (별 5,044개 + 별자리 88개, J2000 적경/적위)
      │  StarCatalog.load(from:)                         ← Models.swift
      ▼
[Star]  ra, dec, mag, ci
      │
      │  Astronomy.Context(date:observer:)               ← Astronomy.swift
      │    "언제, 어디서" 보는지. 한 프레임에 한 번만 만든다
      ▼
Astronomy.horizontal(of:context:)
      │    ① 세차 보정: J2000 좌표 → 오늘 날짜 좌표
      │    ② 적도좌표 → 지평좌표 (고도, 방위각)
      ▼
Horizontal  altitude, azimuth     (기하학적 위치)
      │  Astronomy.refracted(_:)
      │    ③ 대기굴절: 공기 때문에 살짝 위로 뜨는 것 반영
      ▼
Horizontal                         (눈에 보이는 위치)
      │  Astronomy.arVector(_:)
      │    ④ 고도/방위각 → 3D 단위 벡터
      ▼
Vector3  x(동), y(위), z(-북)     → 앱에서 ×100m 해서 AR 공간에 배치

별마다 따로:  star.relativeSize, star.color       ← Appearance.swift
별자리마다:   catalog.constellationCenters()      ← Labels.swift
```

핵심은 **좌표계를 세 번 바꾸는 것**이다.

| 좌표계 | 기준 | 값 | 특징 |
|---|---|---|---|
| 적도좌표 (RA/Dec) | 지구 자전축, 춘분점 | 적경 0~360°, 적위 -90~+90° | 별마다 거의 고정. 카탈로그에 저장되는 값 |
| 지평좌표 (Alt/Az) | 관측자의 지평선, 북쪽 | 고도 -90~+90°, 방위각 0~360° | 시각과 위치에 따라 계속 바뀜 |
| AR 좌표 (x, y, z) | ARKit 월드 원점 | 단위 벡터 | 3D 엔진이 쓰는 형식 |

---

## 2. 천문학 배경

### 2.1 천구와 적도좌표

별까지의 거리는 무시하고, 모든 별이 지구를 감싼 거대한 공(천구) 표면에 붙어 있다고 생각한다.
지구의 위도/경도를 그대로 하늘에 투영한 것이 적도좌표다.

- **적위(Dec)** = 하늘의 위도. 천구 북극(북극성 근처)이 +90°
- **적경(RA)** = 하늘의 경도. 기준(0°)은 춘분점. 원래 시(h) 단위인데 이 프로젝트는 도(°)로 저장한다 (1h = 15°)

지구가 자전해도 별들끼리의 배치는 안 바뀌므로, 적도좌표는 별마다 거의 고정된 "주소"다.

### 2.2 J2000과 세차

지구 자전축은 팽이처럼 약 26,000년 주기로 천천히 돈다(세차운동).
자전축이 움직이면 적도좌표의 기준도 움직이므로, 좌표에는 "언제 기준인지"(epoch)가 붙는다.
카탈로그는 **J2000** (2000년 1월 1일 12시 TT) 기준이고, 26년 지난 지금은 약 0.36° 어긋나 있다.
`Context`에서 계산하는 `zeta`, `z`, `theta`가 이 보정에 쓰는 세 개의 회전각이다 (IAU 1976 공식).

### 2.3 시간: 율리우스일과 항성시

- **율리우스일(JD)**: 기원전 4713년부터 센 날 수. 날짜 계산을 그냥 실수 덧셈으로 하려고 쓴다.
  Unix 시간 0초(1970-01-01 00:00 UTC) = JD 2440587.5 이므로 `초 / 86400 + 2440587.5`.
- **항성시(sidereal time)**: "지금 내 머리 위(자오선)를 지나는 적경이 몇 도인가".
  지구는 태양 기준으로 24시간에 한 바퀴 돌지만, 별 기준으로는 약 23시간 56분에 한 바퀴 돈다.
  그래서 하루에 360°가 아니라 약 360.9856°씩 증가한다 (코드의 `360.98564736629`).
  - GMST: 그리니치(경도 0°) 기준
  - LST(지방 항성시) = GMST + 내 경도

### 2.4 시간각 → 고도/방위각

**시간각 H = LST − 별의 적경.** 별이 자오선을 지난 뒤 얼마나 서쪽으로 갔는지를 나타낸다.
시간각, 별의 적위, 내 위도를 알면 구면삼각법으로 고도와 방위각이 나온다.

```
sin(고도) = sin(적위)·sin(위도) + cos(적위)·cos(위도)·cos(H)
방위각    = atan2(−cos(적위)·sin(H),  sin(적위)·cos(위도) − cos(적위)·sin(위도)·cos(H))
```

방위각은 북 = 0°, 동 = 90° (시계 방향)이다.
`asin`/`acos` 대신 `atan2`를 쓰는 이유는 사분면(동쪽인지 서쪽인지)을 자동으로 구분해 주기 때문이다.

### 2.5 대기굴절

빛은 밀도가 다른 공기층을 지나며 휜다. 그래서 별은 실제보다 조금 높게 보인다.
지평선에서 약 0.5°(보름달 지름만큼), 고도 45°에서 약 1/60°, 천정에서 0.
Sæmundsson 공식을 쓰고, 기압과 기온으로 보정한다. 추우면 공기가 무거워져 더 많이 휜다.

### 2.6 등급과 색지수

- **등급(mag)**: 작을수록 밝다. 5등급 차이 = 밝기 100배. 맨눈 한계는 약 6등급. 시리우스 -1.44.
- **색지수(B−V)**: 파란 필터와 노란 필터로 잰 등급 차이. 작을수록(음수) 파랗고 뜨겁고, 클수록 빨갛고 차갑다.
  색지수 → 온도(Ballesteros 공식) → RGB(흑체 근사) 순서로 변환한다.

---

## 3. 파일별 설명

```
StarCore/
├── Package.swift                     # 패키지 설정 (= package.json / pyproject.toml)
├── Sources/StarCore/
│   ├── Models.swift                  # 데이터 타입
│   ├── Astronomy.swift               # 좌표 계산
│   ├── Appearance.swift              # 크기, 색
│   └── Labels.swift                  # 별자리 이름 위치
└── Tests/StarCoreTests/
    ├── AstronomyTests.swift          # astropy 기준값과 비교
    ├── AppearanceTests.swift         # 굴절, 크기, 색
    └── CatalogTests.swift            # 실제 stars.json으로 검증
```

### 3.1 Package.swift

```swift
platforms: [.iOS(.v17), .macOS(.v14)],
products: [.library(name: "StarCore", targets: ["StarCore"])],
targets: [
    .target(name: "StarCore"),
    .testTarget(name: "StarCoreTests", dependencies: ["StarCore"]),
]
```

- `target`: 소스 묶음. 폴더 이름(`Sources/StarCore`)과 이름이 같으면 자동으로 찾는다.
- `product`: 밖에서 가져다 쓸 수 있게 공개하는 것. 나중에 Xcode 앱 프로젝트가 이 `StarCore` 라이브러리를 import한다.
- 외부 의존성(`dependencies:`)이 없다. Foundation만 쓴다.

### 3.2 Models.swift — 데이터 타입

전부 `struct`(값 타입)다. 계산 로직은 없고 "모양"만 정의한다.

| 타입 | 역할 |
|---|---|
| `StarCatalog` | stars.json 최상위. `load(from:)`로 JSON을 디코딩 |
| `Star` | 별 하나. `hip`(Hipparcos 번호), `ra`, `dec`, `mag`, `name?`, `ci?` |
| `Constellation` | 별자리. `lines`는 HIP 번호 배열의 배열 (각 배열이 하나의 꺾은선) |
| `Horizontal` | 고도/방위각. `isAboveHorizon`은 계산 속성 |
| `Vector3` | AR 좌표 |
| `Observer` | 관측자 위도/경도 |

`Constellation.lines` 예시 (독수리자리):
```json
[[98036, 97649, 97278], [97649, 95501, 97804], ...]
```
`98036 → 97649 → 97278` 순서로 선을 잇는다는 뜻이다. 별 좌표는 여기에 없고, HIP 번호로 `stars`에서 찾는다.

`Star`의 JSON 키(`hip`, `ra`, ...)가 Swift 속성 이름과 같아서, `Codable`만 붙이면 디코딩 코드를 따로 안 써도 된다.

### 3.3 Astronomy.swift — 좌표 계산

`enum Astronomy`는 case가 하나도 없는 enum이다. 인스턴스를 만들 수 없고 `static` 함수만 담는 **네임스페이스**로 쓰는 Swift 관용구다. (Python이라면 모듈 `astronomy.py`의 함수들)

**`Context` — 성능을 위한 설계**

```swift
public struct Context: Sendable {
    let lst: Double
    let sinLat: Double, cosLat: Double
    let zeta: Double, z: Double, sinTheta: Double, cosTheta: Double
    public init(date: Date, observer: Observer) { ... }
}
```

세차 각도, 항성시, sin(위도) 같은 값은 별마다 같다. 별 5,000개를 매 프레임(초당 60번) 계산할 때
이걸 별마다 다시 구하면 낭비이므로, 한 프레임에 한 번 `Context`를 만들어 모든 별에 재사용한다.
React의 `useMemo`로 비싼 계산을 밖으로 빼는 것과 같은 생각이다.

**`horizontal(ra:dec:context:)`** — 2.2(세차)와 2.4(고도/방위각)를 순서대로 한다.

```swift
// 1) 세차: J2000 -> 관측 시점
let raNow = atan2(A, B) + c.z
let decNow = asin(max(-1, min(1, C)))   // 부동소수 오차로 C가 1.0000001이 되면 asin이 NaN → 잘라냄
// 2) 시간각 -> 고도/방위각
let h = c.lst - raNow
```

**`refraction` / `refracted`** — 2.5. `horizontal()` 자체에는 굴절을 넣지 않았다.
"기하학적 위치"와 "눈에 보이는 위치"를 분리해 두면 astropy 기준값(굴절 없음)과 비교 테스트를 그대로 유지할 수 있다.

```swift
let h = max(altitude, -1)   // 공식이 -5° 근처에서 무한대로 발산 → -1° 아래는 고정
```

**`arVector`** — 구면좌표 → 직교좌표 변환.

```swift
Vector3(x: cos(alt) * sin(az),   // 동쪽 성분
        y: sin(alt),              // 위쪽 성분
        z: -cos(alt) * cos(az))   // 북쪽이 -z
```

ARKit은 `.gravityAndHeading` 모드에서 +x = 동, +y = 위, **-z = 북**으로 축을 맞춘다. 그래서 z에 마이너스가 붙는다.
검산: 북쪽 지평선(alt 0, az 0) → (0, 0, -1). 동쪽(az 90) → (1, 0, 0). 천정(alt 90) → (0, 1, 0).

**유틸 함수**

- `rad`, `deg`: 도 ↔ 라디안. Swift의 `sin`/`cos`는 라디안을 받는다.
- `normalize`: 각도를 0..<360으로. `truncatingRemainder`는 실수 나머지(`%`는 정수 전용). 음수면 360을 더한다.
- `@inline(__always)`: 함수 호출 대신 본문을 그 자리에 붙여 넣으라는 컴파일러 힌트. 수천 번 호출되는 작은 함수라 붙였다.
- `public`이 없는 함수(`rad`, `normalize`)는 `internal` — 패키지 안에서만 보인다. 앱에서는 못 쓴다.

### 3.4 Appearance.swift — 크기와 색

**크기**

```swift
let s = pow(10, -exponent * magnitude)              // 0등급 → 1.0
return min(max(s, range.lowerBound), range.upperBound)   // 0.15...2.5로 자르기
```

물리적으로 맞는 지수는 0.2(밝기의 제곱근)지만, 그러면 시리우스와 6등급 별이 30배 차이 나서 어두운 별이 점으로도 안 보인다.
0.12로 낮춰 약 8배 차이로 줄였다. **물리적 정확성보다 보기 좋은 것을 택한 튜닝 값**이라 기본값 인자로 열어 두었다.

**색** — 두 단계로 나눴다.

1. `temperature(bv:)`: 색지수 → 온도(K). 태양(0.65) → 약 5,800K
2. `color(temperature:)`: 온도 → RGB. 6,600K 근처를 기준으로 구간별 근사식

그리고 `color(bv:saturation:)`에서 흰색과 섞는다. 실제 밤하늘의 별은 맨눈에 색이 아주 옅게만 보이기 때문이다.

```swift
func mix(_ v: Double) -> Double { 1 + (v - 1) * saturation }   // saturation 0 → 1(흰색), 1 → 원래 값
```

함수 안에 함수(`mix`, `c`)를 정의할 수 있다. 바깥 변수(`saturation`)를 캡처하는 클로저다.

마지막의 `extension Star { var color: RGB { ... } }`로 `star.color`처럼 쓸 수 있게 했다.

### 3.5 Labels.swift — 별자리 이름 위치

별자리 선에 쓰인 별들의 "가운데"에 이름을 놓는다. 문제는 **각도는 그냥 평균내면 안 된다**는 것.

```
적경 359°와 1°의 평균 = 180°   ← 하늘 정반대편!
```

그래서 각 별을 3D 단위 벡터로 바꿔서 x, y, z를 각각 더하고, 합 벡터를 다시 적경/적위로 되돌린다.
벡터 합은 0°/360° 경계나 천극에서도 문제가 없다. (지도에서 날짜변경선 근처 도시들의 중심을 구할 때도 같은 방법을 쓴다)

```swift
let members = Set(c.lines.joined()).compactMap { byHip[$0] }
```

한 줄에 많은 일이 있다.
- `c.lines.joined()`: `[[Int]]` → `[Int]`로 펼치기 (Python `itertools.chain`)
- `Set(...)`: 중복 제거 (여러 선이 공유하는 별을 한 번만 세려고)
- `.compactMap { byHip[$0] }`: 딕셔너리에서 찾고, 없는 것(nil)은 버리기. `$0`은 클로저의 첫 번째 인자 (JS `x => byHip[x]`)

---

## 4. 이 코드에 나오는 Swift 문법

| Swift | Python / TypeScript 대응 | 이 프로젝트에서 |
|---|---|---|
| `struct` | `@dataclass(frozen=True)` / readonly 객체 | 모든 모델. 대입하면 복사된다(값 타입) |
| `let` / `var` | `const` / `let` | 거의 전부 `let` |
| `Double?` | `float \| None` / `number \| undefined` | `Star.name`, `Star.ci` |
| `guard let bv else { return .white }` | `if bv is None: return WHITE` | 옵셔널 꺼내기 + 조기 반환 |
| `Codable` | pydantic 모델 / zod 스키마 | JSON ↔ struct 자동 변환 |
| `enum` (case 없음) | 모듈 | `Astronomy`, `Appearance` |
| `extension` | 기존 타입에 메서드 추가 (몽키패치와 비슷하지만 안전) | `Star.color`, `StarCatalog.constellationCenters()` |
| `static func` | `@staticmethod` | `Astronomy.gmst(...)` |
| `public` / (없음=internal) | export 여부 | 앱에 공개할 것만 `public` |
| `Sendable` | — | "여러 스레드에서 같이 써도 안전한 타입"이라는 표시 (Swift 6 동시성) |
| `Identifiable` | React의 `key` | SwiftUI 목록에서 `id`로 구분 |
| `0.15...2.5` | `range` (닫힌 구간) | `ClosedRange<Double>` |
| `{ $0.hip }` | `lambda s: s.hip` / `s => s.hip` | 클로저 |
| `try` / `throws` | `raise` 가능한 함수 호출 | `StarCatalog.load` |
| 인자 레이블 `horizontal(ra:dec:context:)` | 키워드 인자 `horizontal(ra=..., dec=...)` | 호출할 때 이름 필수 |
| `_ h: Horizontal` | 위치 인자 | `arVector(h)`처럼 레이블 없이 호출 |

**값 타입(struct)을 쓰는 이유**: 별 데이터는 읽기만 하고, 여러 곳에서 동시에 봐도 서로 바꿀 일이 없다.
값 타입은 복사되므로 "누가 내 데이터를 몰래 바꿨다" 같은 버그가 원천적으로 안 생긴다. Swift에서는 기본적으로 struct를 쓰고, 공유 상태가 꼭 필요할 때만 class를 쓴다.

**`simd`를 안 쓰는 이유**: Apple 플랫폼의 벡터 라이브러리라 Linux(WSL)에서 빌드가 안 된다.
그래서 `Vector3`, `RGB`를 직접 만들었다. 앱 쪽에서 `SIMD3<Float>(Float(v.x), ...)`로 변환해 쓰면 된다.

---

## 5. 테스트

```bash
cd StarCore
swift test                                   # 전체
swift test --filter AppearanceTests          # 클래스 하나
swift test --filter CatalogTests/testCatalogSize   # 테스트 하나
```

새 터미널에서 `swift`가 안 잡히면 `source ~/.local/share/swiftly/env.sh`.

| 파일 | 무엇을 검증하나 | 기준값 출처 |
|---|---|---|
| `AstronomyTests` | 서울, 2026-11-04 22시(KST)의 시리우스·베가·북극성·베텔게우스 위치, GMST, AR 축 방향, JSON 디코딩 | astropy (파이썬 천문 라이브러리) |
| `AppearanceTests` | 굴절량(지평선 34′, 45°에서 1′), 연속성, 크기 범위, 태양 온도, 별 색 경향 | 항해력 표준값, 물리 상식 |
| `CatalogTests` | 실제 `stars.json`: 별 개수, 별자리 88개, 선의 모든 별이 존재, 별자리 중심 | 같은 계산을 Python으로 한 값 |

읽어 볼 포인트:

- `XCTAssertEqual(a, b, accuracy: 0.05)` — 실수는 `==`로 비교하면 안 된다. 허용 오차를 준다.
- `check(...)`의 `file: StaticString = #filePath, line: UInt = #line` — 테스트가 실패했을 때 `check` 함수 안이 아니라 **호출한 줄**을 가리키게 하는 기법.
- `@testable import StarCore` — 테스트에서는 `internal` 함수(`StarCatalog.center(of:)` 등)도 쓸 수 있게 해 준다.
- `CatalogTests`는 `#filePath`(이 테스트 파일의 경로)에서 폴더를 네 번 올라가 `tools/stars.json`을 찾는다.
- `static let catalog = { ... }()` — 처음 쓸 때 한 번만 로드하고 모든 테스트가 공유한다 (lazy 초기화).

---

## 6. 직접 해볼 것

쉬운 순서대로.

1. **내 위치로 바꿔 보기**: `AstronomyTests`의 `seoul`을 다른 도시로 바꾸면 테스트가 실패한다. 왜 실패하는지, 어떤 값이 얼마나 바뀌는지 본다.
2. **튜닝 값 바꿔 보기**: `relativeSize`의 `exponent`를 0.2로 바꾸고 `testRelativeSize`가 왜 깨지는지 본다.
3. **테스트 추가**: 북극성의 고도는 관측 위도와 거의 같다(서울 약 37.5°). 위도를 바꿔 가며 이걸 확인하는 테스트를 써 본다.
4. **함수 추가**: 지금 떠 있는 별 중 가장 밝은 별 N개를 돌려주는 함수 `visibleStars(catalog:context:limit:)`를 만들어 본다. (`filter`, `sorted`, `prefix`)
5. **세차 끄고 비교**: `Context`의 `zeta`, `z`, `theta`를 0으로 두면 결과가 얼마나 어긋나는지 테스트 오차 메시지로 확인한다. (약 0.36°)
6. **도전: 달 위치**: Meeus 『Astronomical Algorithms』 47장 공식을 `Moon.swift`로 구현하고 astropy 값과 비교한다.

### 참고 자료

- Jean Meeus, *Astronomical Algorithms* — 이 코드의 공식 대부분의 출처. 천문 계산의 표준 교재
- [Swift 공식 문서 — The Swift Programming Language](https://docs.swift.org/swift-book/) (한국어 번역판도 있음)
- [astropy](https://www.astropy.org/) — 기준값을 만들 때 쓴 파이썬 라이브러리. 직접 검증해 보고 싶을 때
