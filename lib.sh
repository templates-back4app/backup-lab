# Every destruction event gets a fresh stack, so all five locations always start
# in the same state.
ROWS=500
OFFSITE="${OFFSITE:-$HOME/.backup-lab-offsite}"
export OFFSITE
dc() { docker compose "$@"; }

wait_db() { for _ in $(seq 1 90); do
  dc exec -T db mongosh --quiet --eval 'db.runCommand({ping:1})' >/dev/null 2>&1 && return 0; sleep 0.5
done; echo "db never came up" >&2; return 1; }

fresh() {
  dc down -v >/dev/null 2>&1 || true
  rm -rf ./project-backups "$OFFSITE"; mkdir -p ./project-backups "$OFFSITE"
  dc up -d >/dev/null
  wait_db
}

seed() {
  dc exec -T db mongosh app --quiet --eval "
    db.orders.deleteMany({});
    const d=[]; for (let i=0;i<$ROWS;i++) d.push({n:i, ref:'ORD-'+i});
    db.orders.insertMany(d); print('    seeded ' + db.orders.countDocuments() + ' orders');"
}

backup() {
  dc exec -T db sh -c '
    for d in /backup/in-container /backup/in-data-volume /backup/other-volume /backup/in-project; do
      mkdir -p "$d" && mongodump --quiet --db app --archive="$d/app.archive"
    done' >/dev/null
  # the fifth leaves through a container the database has no access to
  dc exec -T db mongodump --quiet --db app --archive > "$OFFSITE/app.archive"
  echo "    one dump, written to all five locations"
}

# a backup counts only if restoring it gives the rows back
restores() { # reads an archive on stdin, prints the restored row count or nothing
  dc exec -T db sh -c 'cat > /tmp/r.archive 2>/dev/null
    [ -s /tmp/r.archive ] || exit 1
    mongorestore --quiet --drop --nsFrom "app.*" --nsTo "restored.*" --archive=/tmp/r.archive >/dev/null 2>&1 \
      && mongosh restored --quiet --eval "print(db.orders.countDocuments())"' 2>/dev/null | tr -dc '0-9'
}

cell() { # label, then a command that writes the archive to stdout
  local label="$1"; shift
  local tmp=/tmp/backup-lab-check.archive
  if ! "$@" > "$tmp" 2>/dev/null || [ ! -s "$tmp" ]; then
    printf '    %-36s %s\n' "$label" "gone"; return; fi
  local n; n=$(restores < "$tmp")
  if [ "$n" = "$ROWS" ]; then printf '    %-36s %s\n' "$label" "restored $n rows"
  else printf '    %-36s %s\n' "$label" "present, restored ${n:-nothing}"; fi
}

report() {
  cell "1. inside the container"            dc exec -T db cat /backup/in-container/app.archive
  cell "2. in the data volume"              dc exec -T db cat /backup/in-data-volume/app.archive
  cell "3. another volume, same host"       dc exec -T db cat /backup/other-volume/app.archive
  cell "4. in the project folder"           cat ./project-backups/app.archive
  cell "5. where the database cannot reach" cat "$OFFSITE/app.archive"
}
