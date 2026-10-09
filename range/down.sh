#!/usr/bin/env bash
# Tear down both teams' stacks (keeps the adrange network and volumes).
set -e
cd "$(dirname "$0")"

for t in team1 team2; do
  echo ">>> Stopping $t"
  TEAM=$t docker compose -p "$t" -f docker-compose.team.yml down
done
