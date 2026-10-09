#!/usr/bin/env bash
# Bring up both teams' vulnerable service stacks on the shared `adrange` network.
set -e
cd "$(dirname "$0")"

docker network inspect adrange >/dev/null 2>&1 || docker network create adrange

for t in team1 team2; do
  echo ">>> Starting $t"
  TEAM=$t docker compose -p "$t" -f docker-compose.team.yml up -d --build
done

echo
echo "Teams up. Each is reachable on the adrange network as:"
echo "  team1:5000 / team1:8083   (bouquets / otkritki)"
echo "  team2:5000 / team2:8083"
