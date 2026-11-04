"""별자리 그림(명암 있는 흑백) -> 윤곽선 스타일(검은 배경에 흰 선 + 번짐).
앱에서는 이 흰 선을 금색으로 물들이고 가산 합성하면 "빛나는 금색 윤곽선"이 된다.

원본 그림의 밝기 구조:
    배경 = 0 (검정), 몸통 채우기 = 70~100 (회색), 안쪽 잉크 선 = 10~40 (진한 회색)

뽑는 선 두 가지:
    1) 바깥 테두리: 몸통 영역(마스크)을 조금 부풀린 것 - 원래 마스크  (형태학적 팽창)
    2) 안쪽 선:    주변 평균보다 확 어두운 픽셀 (잉크로 그린 주름, 얼굴 등)

사용법 (저장소 루트에서):
    python3 tools/make_outline.py                         # 전부 변환
    python3 tools/make_outline.py orion.png ursa_major.png  # 일부만
필요: pip install numpy pillow
"""
import argparse, os
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "constellations")
DST = os.path.join(HERE, "..", "assets", "constellations-outline")


def f(img, flt):
    """numpy 배열에 PIL 필터 적용"""
    return np.asarray(Image.fromarray(img).filter(flt))


def outline(src, edge=2, ink=12, glow=6):
    lum = src.astype(np.uint8)

    # 1) 몸통 마스크. 안쪽 잉크 선이 어두워서 구멍처럼 보이므로 살짝 흐리게 한 뒤 임계값
    body = f(lum, ImageFilter.GaussianBlur(2)) > 12
    body = f(body.astype(np.uint8) * 255, ImageFilter.MedianFilter(5)) > 127   # 잡티 제거
    m = body.astype(np.uint8) * 255
    # 바깥 테두리 = 팽창(MaxFilter) - 원래. MaxFilter 크기는 홀수
    rim = (f(m, ImageFilter.MaxFilter(2 * edge + 1)) > 0) & ~body

    # 2) 안쪽 잉크 선: 주변 평균보다 ink 이상 어두운 곳. 테두리 근처는 제외(이중선 방지)
    local = f(lum, ImageFilter.BoxBlur(4)).astype(int)
    inner_area = f(m, ImageFilter.MinFilter(7)) > 0          # 침식: 몸통 안쪽만
    lines = inner_area & (local - lum.astype(int) > ink)
    lines = f(lines.astype(np.uint8) * 255, ImageFilter.MedianFilter(3)) > 127  # 점 잡티 제거

    # 3) 합치고 번짐 추가: 선 자체 + 흐린 선(glow)을 더한다
    line = (rim | lines).astype(np.float32)
    line = f((line * 255).astype(np.uint8), ImageFilter.GaussianBlur(0.7)).astype(np.float32) / 255
    halo = f((line * 255).astype(np.uint8), ImageFilter.GaussianBlur(glow)).astype(np.float32) / 255
    out = np.clip(line * 1.0 + halo * 0.8, 0, 1)

    # 4) 가장자리 페이드: 번짐이 이미지 테두리에서 뚝 끊기면 하늘에 네모가 보이므로 테두리 쪽을 서서히 0으로
    h, w = out.shape
    yy, xx = np.mgrid[0:h, 0:w]
    border = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    out *= np.clip(border / (glow * 2.5), 0, 1)
    return (out * 255).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*", help="변환할 파일 이름 (없으면 전부)")
    ap.add_argument("--edge", type=int, default=2, help="바깥 테두리 두께 (픽셀)")
    ap.add_argument("--ink", type=int, default=12, help="안쪽 선 감도 (작을수록 선이 많아짐)")
    ap.add_argument("--glow", type=float, default=6, help="번짐 반경")
    args = ap.parse_args()

    os.makedirs(DST, exist_ok=True)
    names = args.files or sorted(n for n in os.listdir(SRC) if n.endswith(".png"))
    for n in names:
        src = np.asarray(Image.open(os.path.join(SRC, n)).convert("L"))
        Image.fromarray(outline(src, args.edge, args.ink, args.glow)).save(os.path.join(DST, n), optimize=True)
    print(f"{len(names)}개 -> {os.path.normpath(DST)}")


if __name__ == "__main__":
    main()
