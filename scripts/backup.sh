#!/usr/bin/env bash
# backup.sh — Create backups of all Loops Server persistent volumes
#
# Backs up:
#   1. MySQL database (mysqldump via docker exec → compressed .sql.gz)
#   2. MinIO object data (./minio-data/ → rsync to backup dir)
#   3. Redis AOF journal (./redis-data/ → rsync to backup dir)
#   4. App storage       (./storage/    → rsync to backup dir; includes OAuth keys)
#
# Usage:
#   ./scripts/backup.sh [BACKUP_DIR]
#
#   BACKUP_DIR defaults to ./backups/
#   Run from the loops-server/ directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOPS_DIR="$(dirname "$SCRIPT_DIR")"

BACKUP_BASE="${1:-$LOOPS_DIR/backups}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_BASE/$TIMESTAMP"

# Load .env for DB credentials
ENV_FILE="$LOOPS_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env not found at $ENV_FILE"
    exit 1
fi
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

mkdir -p "$BACKUP_DIR"

echo "================================================="
echo "  Loops Server Backup — $TIMESTAMP"
echo "  Destination: $BACKUP_DIR"
echo "================================================="

# ── 1. MySQL Database ─────────────────────────────────────────────────────
echo ""
echo "[1/4] Backing up MySQL database (loops_server)..."
if docker ps --format "{{.Names}}" | grep -q "^loops-db$"; then
    docker exec loops-db \
        mysqldump -u root -p"${DB_ROOT_PASSWORD}" "${DB_DATABASE:-loops_server}" \
        | gzip > "$BACKUP_DIR/loops_db_${TIMESTAMP}.sql.gz"
    echo "      ✓ Database saved: loops_db_${TIMESTAMP}.sql.gz"
else
    echo "      ⚠ Container loops-db not running — skipping database backup"
fi

# ── 2. MinIO object data ──────────────────────────────────────────────────
echo ""
echo "[2/4] Backing up MinIO data (./minio-data/)..."
if [[ -d "$LOOPS_DIR/minio-data" ]]; then
    rsync -a --delete "$LOOPS_DIR/minio-data/" "$BACKUP_DIR/minio-data/"
    echo "      ✓ MinIO data synced"
else
    echo "      ⚠ minio-data/ not found — skipping"
fi

# ── 3. Redis AOF journal ──────────────────────────────────────────────────
echo ""
echo "[3/4] Backing up Redis data (./redis-data/)..."
if [[ -d "$LOOPS_DIR/redis-data" ]]; then
    rsync -a --delete "$LOOPS_DIR/redis-data/" "$BACKUP_DIR/redis-data/"
    echo "      ✓ Redis data synced"
else
    echo "      ⚠ redis-data/ not found — skipping"
fi

# ── 4. App storage (OAuth keys, logs, uploads) ────────────────────────────
echo ""
echo "[4/4] Backing up app storage (./storage/)..."
if [[ -d "$LOOPS_DIR/storage" ]]; then
    rsync -a --delete "$LOOPS_DIR/storage/" "$BACKUP_DIR/storage/"
    echo "      ✓ Storage synced"
else
    echo "      ⚠ storage/ not found — skipping"
fi

# ── Retention: keep only 5 most recent timestamped backup dirs ───────────
echo ""
echo "Pruning old backups (keeping 5 most recent)..."
# shellcheck disable=SC2012
ls -1dt "$BACKUP_BASE"/[0-9]*_[0-9]* 2>/dev/null | tail -n +6 | while read -r old; do
    echo "  Removing: $old"
    rm -rf "$old"
done

echo ""
echo "Backup complete!"
echo "  Location: $BACKUP_DIR"
echo ""
echo "Contents:"
ls -lh "$BACKUP_DIR"
