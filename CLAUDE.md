# Star Finder — 별자리 찾기 AR 앱

## 목표
아이폰 카메라를 하늘에 대면 별과 별자리(선, 한국어 이름, 그림)를 AR로 겹쳐 보여주는 iOS 앱.
사용자의 공부용 프로젝트 — 코드를 바꾸면 왜 그렇게 했는지 설명하고 `docs/StarCore-가이드.md`도 갱신.

## 결정 사항
- **iOS 네이티브**: Swift + SwiftUI + ARKit + RealityKit (SceneKit은 사용하지 않음)
- **방식**: 이미지 인식이 아니라 센서 기반. GPS + 현재 시각으로 별 위치를 계산하고,
  ARKit `worldAlignment = .gravityAndHeading`으로 AR 축을 실제 동서남북에 맞춰 배치
- **AR 좌표계**: +x = 동, +y = 위, -z = 북. 별은 사용자 주변 큰 구(반지름 ~100m)에 배치
- 사용자는 React/Python 경험이 있고 Swift는 이 프로젝트로 시작함. 설명은 한국어로, 간결하게.

## 개발 환경
- **회사: Windows + WSL(Ubuntu)** → 애플 프레임워크가 필요 없는 작업
  (데이터 가공, StarCore 계산 로직 + 테스트)
- **집: Mac + 실제 iPhone** → Xcode, SwiftUI, ARKit/RealityKit, 실기기 테스트
- GitHub로 동기화

## 구조
```
star-finder/
├── docs/StarCore-가이드.md   # 공부용 구조 설명 (StarCore 바꾸면 같이 갱신)
├── assets/constellations/   # 별자리 그림 PNG 85개 (Stellarium 원본, 명암 있는 흑백)
├── assets/constellations-outline/  # 윤곽선 스타일 변환본 (make_outline.py) ← 앱에서 이걸 씀
├── tools/build_catalog.py   # HYG + Stellarium + d3-celestial -> stars.json + 그림
├── tools/make_outline.py    # 원본 그림 -> 윤곽선 + 번짐 (numpy, pillow)
├── tools/preview_art.py     # 그림이 별에 맞게 겹치는지 확인용 이미지 (numpy, pillow)
├── simulator/               # 브라우저 시뮬레이터 (WSL에서 화면 확인용)
│   ├── Sources/StarSim/     #   StarCore로 sky.json 생성 (별/선/그림 적도 벡터 + 시간별 회전 행렬)
│   ├── web/index.html       #   three.js 렌더링, 마우스 = 폰 방향
│   └── run.sh               #   빌드 -> 서버(:8000) -> Windows 브라우저
└── StarCore/                # 순수 Swift 패키지 (Foundation만 사용, WSL/맥 공용)
    ├── Sources/StarCore/Models.swift     # StarCatalog, Star, Constellation, Horizontal, Vector3, Observer
    ├── Sources/StarCore/Astronomy.swift  # 율리우스일, GMST, 세차 보정, 적도->지평, 대기굴절, 지평->AR 벡터
    ├── Sources/StarCore/Appearance.swift # 등급->크기, 색지수->RGB
    ├── Sources/StarCore/Labels.swift     # 별자리 이름 라벨 위치(구면 중심)
    ├── Sources/StarCore/Art.swift        # 별자리 그림: 기준점 3개 -> 3×3 행렬 -> 격자 메시
    ├── Sources/StarCore/KoreanSky.swift  # 천상열차분야지도: 3원 28수(KoreanGroup), 오방색(Direction)
    ├── Sources/StarCore/Locate.swift     # 지금 보는 곳: IAU 경계선(울타리 세기), 28수, 가까운 별자리
    └── Tests/StarCoreTests/              # astropy 기준값 + 실제 stars.json으로 검증 (허용 오차 0.05°)
```

## 규칙
- StarCore에는 ARKit, CoreLocation, simd 등 애플 전용 프레임워크를 넣지 않는다 (WSL에서 빌드돼야 함).
- 별 좌표는 J2000 기준(도 단위). 세차 보정은 `Astronomy.Context`에서 처리. 대기굴절은 `Astronomy.refracted(_:)`로 따로 적용 (`horizontal`은 기하학적 위치).
- 크기 지수(0.12), 색 채도(0.6)는 튜닝 값. 실기기에서 보고 조정.
- 데이터 라이선스: HYG(CC BY-SA 4.0), Stellarium 별자리 선·경계선(CC BY-SA 4.0), Stellarium 그림(Free Art License), d3-celestial(BSD-3). 앱에 출처 표기 필요.
- **한국 전통 별자리(Stellarium korean)는 GPL-2.0** — 공부용은 괜찮지만 앱 출시 시 소스 공개 의무 검토 필요.
- 한국 데이터 정리: id 중복 H19(여상/종대부) -> 종대부는 H19b. 카탈로그에 없는 별(HIP 55203, 78727)에서는 선을 끊음.
- 28수 자삼 역전: 자수(20) 폭이 음수라 판정에서 건너뜀 (지금 하늘엔 27수).
- 소스 코드 바꿀 때마다 `docs/StarCore-가이드.md` 같이 갱신 (사용자 요청).
- 그림 스타일: 윤곽선(흰 선 + 번짐, 검은 배경). 앱에서 금색으로 물들이고 가산 합성. 감도 기본값 ink=12.
- 하늘 전체 = 회전 하나: `Astronomy.equatorialToAR(context:)`. 앱에서도 별/선/그림을 부모 노드 하나에 넣고 그 회전만 프레임마다 바꾼다 (시뮬레이터가 이 방식).
- 그림 UV는 이미지 왼쪽 위 원점. RealityKit에서 뒤집혀 보이면 v를 1-v로, 안 보이면 삼각형 방향(컬링) 확인.

## 진행 상황
- [x] build_catalog.py 작성 및 실행 확인 (별 약 5,000개, 별자리 88개)
- [x] StarCore 코드 작성 (공식은 astropy 대비 오차 0.01° 이내로 검증)
- [x] WSL에 Swift 6.4.2 설치, `swift test` 7개 통과 (2026-11-04)
- [x] GitHub 저장소 생성 (github.com/jaeyeonjjang/star-finder)
- [x] (WSL) 미리 만들어 둠: 대기굴절, 등급별 크기, 색지수->색, 별자리 라벨 위치 (테스트 21개)
- [x] (WSL) 별자리 그림 85장(88개 별자리 모두 덮음 — Car=아르고호 전체, Oph에 뱀 포함): 데이터 + 메시 계산 + 미리보기로 위치 확인 (테스트 28개)
- [x] (WSL) 그림 윤곽선 스타일 변환 85장
- [x] (WSL) 브라우저 시뮬레이터 (`simulator/run.sh`), 하늘 회전 행렬 (테스트 29개)
- [x] (WSL) 한국 전통 별자리 312개 + 서양/한국 탭 (시뮬레이터)
- [x] (WSL) 지금 보는 곳 판정: 서양 IAU 경계선, 한국 28수 + 가까운 별자리 (테스트 47개)
- [ ] (맥) Xcode 프로젝트 생성, AR 화면 + 북쪽 방향 맞추기 테스트 ← **현재 단계**
- [ ] (맥) StarCore 연결, 별/별자리 선/이름 라벨(빌보드) 표시
- [ ] (맥) 별자리 그림 표시 (MeshDescriptor + UnlitMaterial, 금색, 가산 합성)
- [ ] 다듬기: 지평선 아래 처리, 행성/달, 탭하면 정보
