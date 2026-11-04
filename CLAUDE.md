# Star Finder — 별자리 찾기 AR 앱

## 목표
아이폰 카메라를 하늘에 대면 별과 별자리(선, 한국어 이름)를 AR로 겹쳐 보여주는 iOS 앱.

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
├── tools/build_catalog.py   # HYG + Stellarium + d3-celestial -> stars.json
└── StarCore/                # 순수 Swift 패키지 (Foundation만 사용, WSL/맥 공용)
    ├── Sources/StarCore/Models.swift     # StarCatalog, Star, Constellation, Horizontal, Vector3, Observer
    ├── Sources/StarCore/Astronomy.swift  # 율리우스일, GMST, 세차 보정, 적도->지평, 지평->AR 벡터
    └── Tests/StarCoreTests/              # astropy 기준값으로 검증 (허용 오차 0.05°)
```

## 규칙
- StarCore에는 ARKit, CoreLocation, simd 등 애플 전용 프레임워크를 넣지 않는다 (WSL에서 빌드돼야 함).
- 별 좌표는 J2000 기준(도 단위). 세차 보정은 `Astronomy.Context`에서 처리. 대기굴절은 아직 미적용.
- 데이터 라이선스: HYG(CC BY-SA 4.0), Stellarium 별자리 선(GPL-2.0), d3-celestial(BSD-3). 상용 출시 전 확인 필요.

## 진행 상황
- [x] build_catalog.py 작성 및 실행 확인 (별 약 5,000개, 별자리 88개)
- [x] StarCore 코드 작성 (공식은 astropy 대비 오차 0.01° 이내로 검증)
- [x] WSL에 Swift 6.4.2 설치, `swift test` 7개 통과 (2026-11-04)
- [ ] GitHub 저장소 생성 ← **현재 단계**
- [ ] (맥) Xcode 프로젝트 생성, AR 화면 + 북쪽 방향 맞추기 테스트
- [ ] (맥) StarCore 연결, 별/별자리 선/이름 라벨(빌보드) 표시
- [ ] 다듬기: 등급별 별 크기, 색지수로 별 색, 지평선 아래 처리, 행성/달, 탭하면 정보
