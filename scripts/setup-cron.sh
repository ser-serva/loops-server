#!/usr/bin/env bash
# setup-cron.sh — Install a scheduled cron job to run backup.sh for Loops Server
#
# Usage:
#   ./scripts/setup-cron.sh [SCHEDULE]
#
#   SCHEDULE options:
#     daily   — Run backup daily at 3:00 AM (default)
#     weekly  — Run backup weekly on Sundays at 3:00 AM
#     custom  — Prompt for a custom cron expression
#
# Run from the loops-server/ directory or supply absolute paths.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOPS_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
LOG_FILE="/var/log/loops-backup.log"

# ── Usage ─────────────────────────────────────────────────────────────────
usage() {
    echo "Usage: $0 [daily|weekly|custom]"
    echo ""
    echo "  daily   Run backup daily at 3:00 AM (default)"
    echo "  weekly  Run backup weekly on Sundays at 3:00 AM"
    echo "  custom  Prompt for a custom cron schedule"
    echo ""
    echo "Examples:"
    echo "  $0 daily"
    echo "  $0 weekly"
}

# ── Validate 5-field cron expression ─────────────────────────────────────
validate_cron() {
    local expr="$1"
    if [[ $(echo "$expr" | wc -w) -ne 5 ]]; then
        echo "ERROR: cron expression must have 5 fields (minute hour day month weekday)"
        return 1
    fi
}

# ── Create log file ──────────────────────────────────────────────────────
setup_log_file() {
    if [[ ! -f "$LOG_FILE" ]]; then
        sudo touch "$LOG_FILE"
    fi
    sudo chown "$USER:$USER" "$LOG_FILE"
    echo "Log file: $LOG_FILE"
}

# ── Add cron entry ────────────────────────────────────────────────────────
add_cron_job() {
    local schedule="$1"
    local cron_cmd="cd $LOOPS_DIR && ./scripts/backup.sh >> $LOG_FILE 2>&1"
    local cron_entry="$schedule $cron_cmd"

    echo "Installing cron job: $cron_entry"

    if crontab -l 2>/dev/null | grep -q "loops-server.*backup.sh\|scripts/backup.sh"; then
        echo "WARNING: A Loops backup cron job already exists:"
        crontab -l 2>/dev/null | grep "backup.sh" || true
        echo ""
        read -rp "Replace it? (y/N): " replace
        if [[ $replace =~ ^[Yy]$ ]]; then
            crontab -l 2>/dev/null | grep -v "backup.sh" | crontab -
            echo "Previous entry removed."
        else
            echo "Keeping existing job. Exiting."
            exit 0
        fi
    fi

    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    echo "Cron job added successfully."
}

# ── Main ──────────────────────────────────────────────────────────────────
echo "Loops Server Backup Cron Setup"
echo "================================"

# Pre-flight: backup script must exist
if [[ ! -f "$BACKUP_SCRIPT" ]]; then
    echo "ERROR: backup script not found at $BACKUP_SCRIPT"
    exit 1
fi
chmod +x "$BACKUP_SCRIPT"

SCHEDULE_TYPE="${1:-daily}"

case "$SCHEDULE_TYPE" in
    daily)
        CRON_SCHEDULE="0 3 * * *"
        DESCRIPTION="daily at 3:00 AM"
        ;;
    weekly)
        CRON_SCHEDULE="0 3 * * 0"
        DESCRIPTION="weekly on Sundays at 3:00 AM"
        ;;
    custom)
        echo "Enter a cron schedule (minute hour day month weekday):"
        echo "  Example — 0 3 * * *  (daily at 3 AM)"
        echo "  Example — 0 */12 * * *  (every 12 hours)"
        read -rp "Cron schedule: " CRON_SCHEDULE
        validate_cron "$CRON_SCHEDULE"
        DESCRIPTION="custom: $CRON_SCHEDULE"
        ;;
    -h|--help)
        usage; exit 0 ;;
    *)
        echo "ERROR: unknown schedule '$SCHEDULE_TYPE'"
        usage; exit 1 ;;
esac

echo ""
echo "Configuration:"
echo "  Backup script : $BACKUP_SCRIPT"
echo "  Schedule      : $DESCRIPTION"
echo "  Log file      : $LOG_FILE"
echo ""

read -rp "Proceed? (y/N): " confirm
[[ $confirm =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

setup_log_file
add_cron_job "$CRON_SCHEDULE"

echo ""
echo "Setup complete! Active cron jobs:"
crontab -l

echo ""
echo "To test manually:   $BACKUP_SCRIPT"
echo "To watch logs:      tail -f $LOG_FILE"
echo "To remove later:    crontab -e  # delete the loops backup line"
