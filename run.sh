#!/usr/bin/env bash
# One dump, written to five places that differ only in what can reach them.
# Then four ways of losing the data, each against a fresh stack.
#
#   ./run.sh
#
# Needs Docker. Every run destroys and rebuilds everything it uses.
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh
trap 'dc down -v >/dev/null 2>&1 || true' EXIT

event() { echo ""; echo "  $1"; echo ""; }

# --- 1. the agent runs a destructive command with the app's own credentials
fresh; seed >/dev/null; backup >/dev/null
event "AN AGENT DROPS THE DATABASE  (the app's own credentials)"
dc exec -T db mongosh app --quiet --eval 'db.dropDatabase()' >/dev/null
left=$(dc exec -T db mongosh app --quiet --eval 'print(db.orders.countDocuments())' | tr -dc '0-9')
echo "    rows left in the database: ${left:-0}"
report

# --- 2. the container is replaced, which is what a deploy does
fresh; seed >/dev/null; backup >/dev/null
event "THE CONTAINER IS REPLACED  (every deploy)"
dc rm -sf db >/dev/null 2>&1; dc up -d db >/dev/null; wait_db
report

# --- 3. an agent tidying up removes the volumes
fresh; seed >/dev/null; backup >/dev/null
event "THE VOLUMES ARE REMOVED  (docker compose down -v)"
cp ./project-backups/app.archive /tmp/keep-project.archive 2>/dev/null
dc down -v >/dev/null 2>&1; dc up -d >/dev/null; wait_db
mkdir -p ./project-backups; cp /tmp/keep-project.archive ./project-backups/app.archive 2>/dev/null
report

# --- 4. an agent runs a destructive command with the access the app has
fresh; seed >/dev/null; backup >/dev/null
event "AN AGENT RUNS rm -rf WITH THE ACCESS THE APP HAS"
# everything mounted into the database container, which is everything it can see
dc exec -T db sh -c 'rm -rf /data/db/* /backup/in-container /backup/in-data-volume /backup/other-volume /backup/in-project' >/dev/null 2>&1
dc rm -sf db >/dev/null 2>&1; dc up -d db >/dev/null; wait_db
report

# --- 5. the folder you were working in is deleted
fresh; seed >/dev/null; backup >/dev/null
event "THE PROJECT FOLDER IS DELETED"
rm -rf ./project-backups
report
echo ""
