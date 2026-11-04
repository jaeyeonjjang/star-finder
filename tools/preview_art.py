"""별자리 그림을 하늘 지도(북쪽 위, 동쪽 왼쪽 — 실제로 올려다본 모습)에 겹쳐 그려서
StarCore/Art.swift와 같은 방식의 매핑이 맞는지 눈으로 확인한다."""
import json, sys, math
import numpy as np
from PIL import Image, ImageDraw

# 사용법 (저장소 루트에서): python3 tools/preview_art.py . preview.png Ori,UMa,Sco,Cyg
# 필요: pip install numpy pillow
root, out = sys.argv[1], sys.argv[2]
ids = sys.argv[3].split(",")
cat = json.load(open(f"{root}/tools/stars.json", encoding="utf-8"))
S = {s["hip"]: s for s in cat["stars"]}
C = {c["id"]: c for c in cat["constellations"]}

def unit(ra, dec):
    a, d = math.radians(ra), math.radians(dec)
    return np.array([math.cos(d) * math.cos(a), math.cos(d) * math.sin(a), math.sin(d)])

def render(cid, size=520, fov=None):
    c = C[cid]; art = c["art"]
    P = np.array([[a["x"], a["y"], 1.0] for a in art["anchors"]]).T      # 열 = 기준점
    V = np.array([unit(S[a["hip"]]["ra"], S[a["hip"]]["dec"]) for a in art["anchors"]]).T
    M = V @ np.linalg.inv(P); Minv = np.linalg.inv(M)
    w, h = art["width"], art["height"]
    ctr = M @ np.array([w / 2, h / 2, 1.0]); ctr /= np.linalg.norm(ctr)
    ra0 = math.atan2(ctr[1], ctr[0])
    east = np.array([-math.sin(ra0), math.cos(ra0), 0.0])
    north = np.cross(ctr, east)
    # 시야: 그림 모서리가 다 들어오게
    corners = [M @ np.array([x, y, 1.0]) for x in (0, w) for y in (0, h)]
    def proj(d):
        d = d / np.linalg.norm(d); z = d @ ctr
        return -(d @ east) / z, (d @ north) / z     # 동쪽이 왼쪽
    half = max(max(abs(v) for v in proj(k)) for k in corners) * 1.1
    # 화면 픽셀 -> 방향 -> 그림 픽셀
    g = np.linspace(-half, half, size)
    X, Y = np.meshgrid(g, -g)
    D = ctr[None, None, :] - X[..., None] * east + Y[..., None] * north
    Pp = D @ Minv.T
    px, py = Pp[..., 0] / Pp[..., 2], Pp[..., 1] / Pp[..., 2]
    src = np.asarray(Image.open(f"{root}/assets/constellations/{art['file']}").convert("L"), dtype=float) / 255
    ok = (px >= 0) & (px < w - 1) & (py >= 0) & (py < h - 1) & (Pp[..., 2] > 0)
    lum = np.zeros((size, size)); lum[ok] = src[py[ok].astype(int), px[ok].astype(int)]
    gold = np.array([1.0, 0.75, 0.35])
    bg = np.array([0.03, 0.06, 0.14])
    img = np.clip(bg + lum[..., None] * gold * 0.55, 0, 1)
    im = Image.fromarray((img * 255).astype(np.uint8)); dr = ImageDraw.Draw(im)
    def to_screen(ra, dec):
        x, y = proj(unit(ra, dec)); return ((x + half) / (2 * half) * size, (half - y) / (2 * half) * size)
    for seg in c["lines"]:
        pts = [to_screen(S[hp]["ra"], S[hp]["dec"]) for hp in seg]
        dr.line(pts, fill=(200, 220, 255), width=2)
    for s in cat["stars"]:
        if unit(s["ra"], s["dec"]) @ ctr < math.cos(math.radians(80)): continue
        x, y = to_screen(s["ra"], s["dec"])
        if 0 <= x < size and 0 <= y < size and s["mag"] < 5:
            r = max(1, 4.5 - s["mag"] * 0.7); dr.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255))
    for a in art["anchors"]:
        x, y = to_screen(S[a["hip"]]["ra"], S[a["hip"]]["dec"]); dr.ellipse([x - 7, y - 7, x + 7, y + 7], outline=(255, 80, 80), width=2)
    dr.text((8, 8), f"{cid} {c['nameEn']}", fill=(255, 255, 255))
    return im

tiles = [render(i) for i in ids]
cols = 2; rows = math.ceil(len(tiles) / cols)
sheet = Image.new("RGB", (cols * 520, rows * 520))
for k, t in enumerate(tiles):
    sheet.paste(t, ((k % cols) * 520, (k // cols) * 520))
sheet.save(out)
print(out)
