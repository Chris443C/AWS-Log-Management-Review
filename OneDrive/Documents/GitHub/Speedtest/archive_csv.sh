#!/bin/bash
set -euo pipefail

# Configurable paths
DATA_DIR="${DATA_DIR:-/var/www/html/speedtest}"
CSV_FILE="$DATA_DIR/results.csv"
ARCHIVE_DIR="$DATA_DIR/archive"
LOG_FILE="${LOG_FILE:-/var/log/archive_csv.log}"
ARCHIVE_FILE="$ARCHIVE_DIR/results_$(date +%Y-%m-%d).csv"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Ensure directories exist
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Check if source CSV exists
if [ ! -f "$CSV_FILE" ]; then
    log "ERROR: Source CSV $CSV_FILE does not exist."
    echo "Source CSV does not exist. See log for details."
    exit 1
fi

# Archive the CSV
if cp "$CSV_FILE" "$ARCHIVE_FILE"; then
    log "Archived $CSV_FILE to $ARCHIVE_FILE."
else
    log "ERROR: Failed to archive $CSV_FILE to $ARCHIVE_FILE."
    echo "Failed to archive CSV. See log for details."
    exit 1
fi
