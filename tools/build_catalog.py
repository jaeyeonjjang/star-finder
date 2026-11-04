"""
별자리 앱용 데이터 생성 스크립트
- 별: HYG Database v4.1 (CC BY-SA 4.0)
- 별자리 선: Stellarium modern sky culture (GPL-2.0)
- 별자리 한국어 이름: d3-celestial (BSD-3-Clause)

사용법: python3 build_catalog.py [--mag 6.0] [--out stars.json]
"""
import argparse, csv, io, json, urllib.request

HYG_URL = "https://raw.githubusercontent.com/astronexus/HYG-Database/main/hyg/CURRENT/hygdata_v41.csv"
LINES_URL = "https://raw.githubusercontent.com/Stellarium/stellarium/master/skycultures/modern/index.json"
NAMES_URL = "https://raw.githubusercontent.com/ofrohn/d3-celestial/master/data/constellations.json"


def fetch(url: str) -> str:
    print(f"다운로드: {url}")
    with urllib.request.urlopen(url) as r:
        return r.read().decode("utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mag", type=float, default=6.0, help="이 등급보다 밝은 별만 포함 (기본 6.0, 맨눈 한계)")
    ap.add_argument("--out", default="stars.json")
    args = ap.parse_args()

    # 1) 별자리 선 (HIP 번호 목록)
    sky = json.loads(fetch(LINES_URL))
    constellations = []
    line_hips = set()
    for c in sky["constellations"]:
        abbr = c["id"].split()[-1]                      # "CON modern Ori" -> "Ori"
        lines = [[int(h) for h in seg if isinstance(h, int) or str(h).isdigit()]
                 for seg in c.get("lines", [])]
        lines = [seg for seg in lines if len(seg) >= 2]
        for seg in lines:
            line_hips.update(seg)
        constellations.append({"id": abbr, "lines": lines})

    # 2) 한국어/영어 이름
    names = {f["id"]: f["properties"] for f in json.loads(fetch(NAMES_URL))["features"]}
    for c in constellations:
        p = names.get(c["id"], {})
        c["nameKo"] = p.get("ko") or p.get("name") or c["id"]
        c["nameEn"] = p.get("en") or p.get("name") or c["id"]

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
        print(f"경고: 선 데이터에 있지만 카탈로그에 없는 별 {len(missing)}개 -> 해당 선 제거")
        for c in constellations:
            c["lines"] = [seg for seg in c["lines"] if all(h in found for h in seg)]

    stars.sort(key=lambda s: s["mag"])
    out = {"epoch": "J2000", "stars": stars, "constellations": constellations}
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print(f"완료: 별 {len(stars)}개, 별자리 {len(constellations)}개 -> {args.out}")


if __name__ == "__main__":
    main()
