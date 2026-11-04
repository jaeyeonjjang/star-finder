"""
별자리 앱용 데이터 생성 스크립트
- 별: HYG Database v4.1 (CC BY-SA 4.0)
- 별자리 선: Stellarium modern sky culture (CC BY-SA 4.0)
- 별자리 그림: Stellarium modern sky culture illustrations (Free Art License)
- 별자리 한국어 이름: d3-celestial (BSD-3-Clause)
- 한국 전통 별자리 (천상열차분야지도): Stellarium korean sky culture (GPL-2.0)

사용법: python3 build_catalog.py [--mag 6.0] [--out stars.json] [--no-art]
"""
import argparse, csv, io, json, os, urllib.request

HYG_URL = "https://raw.githubusercontent.com/astronexus/HYG-Database/main/hyg/CURRENT/hygdata_v41.csv"
LINES_URL = "https://raw.githubusercontent.com/Stellarium/stellarium/master/skycultures/modern/index.json"
ART_BASE = "https://raw.githubusercontent.com/Stellarium/stellarium/master/skycultures/modern/"
NAMES_URL = "https://raw.githubusercontent.com/ofrohn/d3-celestial/master/data/constellations.json"
KOREAN_URL = "https://raw.githubusercontent.com/Stellarium/stellarium/master/skycultures/korean/index.json"


def fetch(url: str) -> str:
    print(f"다운로드: {url}")
    with urllib.request.urlopen(url) as r:
        return r.read().decode("utf-8")


def parse_lines(raw):
    """Stellarium 선 목록 -> HIP 번호만 남긴 꺾은선 목록.
    "DSO:M44" 같은 별 아닌 천체는 빼고, 점이 2개 미만인 선은 버린다.
    (별 하나짜리 별자리는 [h, h]처럼 같은 번호를 두 번 써서 표시돼 있어서 그대로 남는다)"""
    lines = [[int(h) for h in seg if isinstance(h, int) or str(h).isdigit()] for seg in raw]
    return [seg for seg in lines if len(seg) >= 2]


def split_at_missing(lines, found):
    """카탈로그에 없는 별이 있으면 그 자리에서 선을 끊는다.
    [a, b, X, c, d] -> [a, b], [c, d]  (선 전체를 버리면 별자리가 통째로 사라질 수 있어서)"""
    out = []
    for seg in lines:
        part = []
        for h in seg + [None]:              # None = 끝 표시
            if h is not None and h in found:
                part.append(h)
            else:
                if len(part) >= 2:
                    out.append(part)
                part = []
    return out


def split_korean_name(native):
    """'북극(北極)' -> ('북극', '北極'). '삼대(상대)(三台(上台))'처럼 괄호가 겹친 것도 처리:
    맨 끝 ')'와 짝이 맞는 '('를 뒤에서부터 찾는다."""
    if not native.endswith(")"):
        return native, None
    depth = 0
    for i in range(len(native) - 1, -1, -1):
        depth += {")": 1, "(": -1}.get(native[i], 0)
        if depth == 0:
            return native[:i], native[i + 1:-1]
    return native, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mag", type=float, default=6.0, help="이 등급보다 밝은 별만 포함 (기본 6.0, 맨눈 한계)")
    ap.add_argument("--out", default="stars.json")
    ap.add_argument("--art-dir", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "constellations"),
                    help="별자리 그림 PNG 저장 폴더 (기본 ../assets/constellations)")
    ap.add_argument("--no-art", action="store_true", help="그림 PNG 다운로드 생략 (stars.json의 기준점 정보는 포함)")
    args = ap.parse_args()

    # 1) 별자리 선 (HIP 번호 목록) + 그림 기준점
    sky = json.loads(fetch(LINES_URL))
    constellations = []
    line_hips = set()   # 선이나 그림 기준점에 쓰여서 등급과 상관없이 꼭 넣어야 하는 별
    for c in sky["constellations"]:
        abbr = c["id"].split()[-1]                      # "CON modern Ori" -> "Ori"
        lines = parse_lines(c.get("lines", []))
        for seg in lines:
            line_hips.update(seg)
        entry = {"id": abbr, "lines": lines}
        # 그림: 픽셀 좌표 3개 <-> 별 3개 대응. 이걸로 그림을 하늘에 겹친다 (StarCore/Art.swift)
        img = c.get("image")
        if img and len(img.get("anchors", [])) == 3:
            entry["art"] = {
                "file": os.path.basename(img["file"]),
                "path": img["file"],    # 다운로드용, 출력 전에 지움
                "width": img["size"][0],
                "height": img["size"][1],
                "anchors": [{"x": a["pos"][0], "y": a["pos"][1], "hip": int(a["hip"])} for a in img["anchors"]],
            }
            line_hips.update(a["hip"] for a in entry["art"]["anchors"])
        constellations.append(entry)

    # 2) 한국어/영어 이름
    names = {f["id"]: f["properties"] for f in json.loads(fetch(NAMES_URL))["features"]}
    for c in constellations:
        p = names.get(c["id"], {})
        c["nameKo"] = p.get("ko") or p.get("name") or c["id"]
        c["nameEn"] = p.get("en") or p.get("name") or c["id"]

    # 2-1) 한국 전통 별자리 (천상열차분야지도, 312개)
    #   id: P01 = 자미원, S01 = 태미원, H01 = 천시원, 01A~28x = 28수 (StarCore/KoreanSky.swift 참고)
    #   원본에 id가 겹치는 게 있어서(H19: 여상, 종대부) 두 번째부터 b, c...를 붙인다.
    #   종대부(宗大夫)는 천상열차분야지도가 중국 목록에 더한, 한국 지도에만 있는 별자리
    korean, seen = [], set()
    for c in json.loads(fetch(KOREAN_URL))["constellations"]:
        ko, hanja = split_korean_name(c["common_name"]["native"])
        lines = parse_lines(c.get("lines", []))
        for seg in lines:
            line_hips.update(seg)
        cid = c["id"].split()[-1]
        for suffix in "bcdefg":
            if cid not in seen:
                break
            cid = c["id"].split()[-1] + suffix
        seen.add(cid)
        entry = {"id": cid, "nameKo": ko, "nameEn": c["common_name"]["english"], "lines": lines}
        if hanja:
            entry["nameHanja"] = hanja
        korean.append(entry)

    # 3) 별: 밝은 별 + 별자리 선에 쓰이는 별은 등급 상관없이 포함
    stars = []
    for row in csv.DictReader(io.StringIO(fetch(HYG_URL))):
        if row["id"] == "0" or not row["hip"]:        # 태양, HIP 번호 없는 별 제외
            continue
        hip, mag = int(row["hip"]), float(row["mag"])
        if mag > args.mag and hip not in line_hips:
            continue
        star = {
            "hip": hip,
            "ra": round(float(row["ra"]) * 15.0, 5),   # 시(h) -> 도(°)
            "dec": round(float(row["dec"]), 5),
            "mag": round(mag, 2),
        }
        if row["proper"]:
            star["name"] = row["proper"]
        if row["ci"]:
            star["ci"] = round(float(row["ci"]), 3)    # 색지수 (별 색깔 표현용)
        stars.append(star)

    found = {s["hip"] for s in stars}
    missing = line_hips - found
    if missing:
        print(f"경고: 선 데이터에 있지만 카탈로그에 없는 별 {len(missing)}개 {sorted(missing)} -> 그 별에서 선을 끊음")
        for c in constellations + korean:
            c["lines"] = split_at_missing(c["lines"], found)
            if "art" in c and not all(a["hip"] in found for a in c["art"]["anchors"]):
                print(f"  {c['id']}: 그림 기준점 별이 없어서 그림 제외")
                del c["art"]

    # 4) 별자리 그림 PNG
    arts = [c["art"] for c in constellations if "art" in c]
    if not args.no_art:
        os.makedirs(args.art_dir, exist_ok=True)
        for art in arts:
            dest = os.path.join(args.art_dir, art["file"])
            if not os.path.exists(dest):
                with urllib.request.urlopen(ART_BASE + art["path"]) as r, open(dest, "wb") as f:
                    f.write(r.read())
        print(f"그림 {len(arts)}개 -> {os.path.normpath(args.art_dir)}")
    for art in arts:
        del art["path"]

    stars.sort(key=lambda s: s["mag"])
    out = {"epoch": "J2000", "stars": stars, "constellations": constellations,
           "skyCultures": {"korean": {"name": "한국 전통 (천상열차분야지도)", "license": "GPL-2.0",
                                      "constellations": korean}}}
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print(f"완료: 별 {len(stars)}개, 별자리 {len(constellations)}개 + 한국 전통 {len(korean)}개 -> {args.out}")


if __name__ == "__main__":
    main()
