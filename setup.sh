#!/usr/bin/env bash
# One-command bootstrap for the Attack-Defense CTF demo.
# Yeu cau: Docker Desktop dang chay + Python 3.
#
#   ./setup.sh
#
# Sau khi xong: mo http://localhost:8080 (scoreboard).
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# --- 0) kiem tra moi truong ---
command -v docker >/dev/null || { echo "Chua co docker"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker daemon chua chay. Mo Docker Desktop roi chay lai."; exit 1; }
PY="$(command -v python3 || true)"
[ -n "$PY" ] || { echo "Chua co python3"; exit 1; }

# --- 1) dich vu 2 doi ---
say "Khoi dong dich vu 2 doi (team1, team2) tren mang adrange"
bash range/up.sh

# --- 2) venv cho control.py cua ForcAD ---
say "Chuan bi virtualenv cho ForcAD control.py"
cd "$ROOT/forcad"
[ -d .venv ] || "$PY" -m venv .venv
./.venv/bin/pip -q install --upgrade pip >/dev/null
./.venv/bin/pip -q install click PyYAML 'pydantic>=2.5,<3'

# --- 3) setup + start ForcAD ---
say "Khoi tao cau hinh ForcAD (sinh mat khau admin)"
./.venv/bin/python control.py setup

say "Build & chay ForcAD (lan dau co the mat vai phut de tai/build image)"
./.venv/bin/python control.py start -w 2

# --- 4) cho initializer + in thong tin ---
say "Cho he thong khoi tao..."
for _ in $(seq 1 40); do
  if curl -s --max-time 4 http://localhost:8080/api/client/teams/ 2>/dev/null | grep -q Team; then break; fi
  sleep 3
done

say "XONG!"
echo "  Scoreboard : http://localhost:8080"
echo "  Admin      : http://localhost:8080/admin/  (user 'forcad', mat khau o buoc 'control.py setup' ben tren)"
echo "  Flower     : http://localhost:8080/flower/"
echo
echo "  Token nop flag cua cac doi:"
./.venv/bin/python control.py print_tokens 2>/dev/null | sed 's/^/    /' || true
echo
echo "  Xem huong dan tan cong/phong thu: HUONG_DAN.md"
