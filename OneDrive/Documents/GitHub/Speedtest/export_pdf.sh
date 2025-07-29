#!/bin/bash
set -euo pipefail

# Configurable paths
NODE_PATH="${NODE_PATH:-node}"
SCRIPT_PATH="${SCRIPT_PATH:-$(dirname "$0")/export_chart_pdf.js}"
LOG_FILE="${LOG_FILE:-/var/log/export_pdf.log}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Check if Node.js and script exist
if ! command -v "$NODE_PATH" >/dev/null 2>&1; then
    log "ERROR: Node.js not found. Please ensure Node.js is installed."
    echo "Node.js not found. See log for details."
    exit 1
fi

if [ ! -f "$SCRIPT_PATH" ]; then
    log "ERROR: Script $SCRIPT_PATH not found."
    echo "Export script not found. See log for details."
    exit 1
fi

# Change to script directory for relative path resolution
cd "$(dirname "$SCRIPT_PATH")"

# Run the export script
if "$NODE_PATH" "$SCRIPT_PATH" >> "$LOG_FILE" 2>&1; then
    log "Successfully exported PDF."
else
    log "ERROR: PDF export failed."
    echo "PDF export failed. See log for details."
    exit 1
fi
