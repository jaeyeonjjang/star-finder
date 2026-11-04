#!/usr/bin/env bash
# 브라우저 시뮬레이터 실행: sky.json 생성 -> 로컬 서버 -> Windows 브라우저 열기
# 사용법: simulator/run.sh [StarSim 옵션]   예) simulator/run.sh --date 2026-12-25T21:00:00+09:00
# 끝낼 때: Ctrl+C
set -e
cd "$(dirname "$0")"
source ~/.local/share/swiftly/env.sh 2>/dev/null || true
swift run -c release StarSim "$@" 2>&1 | grep -v -e '^\[' -e 'safeExec'

PORT=8000
URL="http://localhost:$PORT/simulator/web/"
cd ..   # 저장소 루트를 서버로 열어야 assets/ 그림도 보인다
echo "브라우저에서 열기: $URL"
(sleep 1; explorer.exe "$URL" >/dev/null 2>&1 || true) &
python3 -m http.server $PORT --bind 127.0.0.1
