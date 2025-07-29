#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
set -euo pipefail

# =========================
# Configurable Paths & Vars
# =========================
DATA_DIR="${DATA_DIR:-/var/www/html/speedtest}"
CSV_FILE="$DATA_DIR/results.csv"
HTML_FILE="$DATA_DIR/index.html"
ARCHIVE_DIR="$DATA_DIR/archive"
LOG_FILE="${LOG_FILE:-/var/log/speedtest_to_web.log}"
ACCOUNT_LABEL="${ACCOUNT_LABEL:-Vodafone Account VFP2575408}"
SPEEDTEST_BIN="/usr/local/bin/speedtest"

# Check if speedtest binary exists and is executable
if [ ! -x "$SPEEDTEST_BIN" ]; then
  echo "ERROR: speedtest binary not found or not executable at $SPEEDTEST_BIN" >&2
  exit 1
fi

# =============
# Logging Setup
# =============
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# =============
# Directory Prep
# =============
mkdir -p "$DATA_DIR" "$ARCHIVE_DIR" "$(dirname "$LOG_FILE")"

# =============
# Run Ookla Speedtest CLI
# =============
SPEEDTEST_ERROR=""
if ! RESULT=$($SPEEDTEST_BIN --accept-license --accept-gdpr -f csv 2> >(SPEEDTEST_ERROR=$(cat); typeset -p SPEEDTEST_ERROR >&2)); then
    log "ERROR: Ookla speedtest CLI failed to run. Exit code: $? Output: $RESULT Error: $SPEEDTEST_ERROR"
    echo "Speedtest failed to run. See log for details."
    exit 1
fi
log "RAW RESULT: $RESULT"
echo "RAW RESULT: $RESULT"
RESULT=$(echo "$RESULT" | sed 's/\"//g')

# =============
# Parse Results (CSV format)
# Ookla CLI CSV columns: Server Name, Server ID, Latency (Ping), Jitter, Packet Loss, Download, Upload, Bytes Sent, Bytes Received, Result URL, ISP, External IP, Internal IP, Interface, Idle Latency, Download Latency, Upload Latency, Download Retrans, Upload Retrans, Download Min RTT, Upload Min RTT
IFS=',' read -r SERVER_NAME SERVER_ID PING JITTER PACKET_LOSS DOWNLOAD UPLOAD BYTES_SENT BYTES_RECEIVED RESULT_URL ISP EXTERNAL_IP INTERNAL_IP INTERFACE IDLE_LATENCY DL_LATENCY UL_LATENCY DL_RETRANS UL_RETRANS DL_MIN_RTT UL_MIN_RTT <<< "$RESULT"

# Defensive: Ensure variables are numeric for awk
if [[ -z "$DOWNLOAD" || ! "$DOWNLOAD" =~ ^[0-9.]+$ ]]; then DOWNLOAD=0; fi
if [[ -z "$UPLOAD" || ! "$UPLOAD" =~ ^[0-9.]+$ ]]; then UPLOAD=0; fi
if [[ -z "$PING" || ! "$PING" =~ ^[0-9.]+$ ]]; then PING=0; fi
if [[ -z "$JITTER" || ! "$JITTER" =~ ^[0-9.]+$ ]]; then JITTER=0; fi
if [[ -z "$IDLE_LATENCY" || ! "$IDLE_LATENCY" =~ ^[0-9.]+$ ]]; then IDLE_LATENCY=0; fi
if [[ -z "$DL_LATENCY" || ! "$DL_LATENCY" =~ ^[0-9.]+$ ]]; then DL_LATENCY=0; fi
if [[ -z "$UL_LATENCY" || ! "$UL_LATENCY" =~ ^[0-9.]+$ ]]; then UL_LATENCY=0; fi
if [[ -z "$BYTES_RECEIVED" || ! "$BYTES_RECEIVED" =~ ^[0-9.]+$ ]]; then BYTES_RECEIVED=0; fi
if [[ -z "$BYTES_SENT" || ! "$BYTES_SENT" =~ ^[0-9.]+$ ]]; then BYTES_SENT=0; fi

# Convert download/upload from bytes to Mbps (Ookla CLI outputs bytes, not bits)
DOWNLOAD_MBPS=$(awk "BEGIN {printf \"%.2f\", ($DOWNLOAD*8)/1000000}")
UPLOAD_MBPS=$(awk "BEGIN {printf \"%.2f\", ($UPLOAD*8)/1000000}")
PING_MS=$(awk "BEGIN {printf \"%.2f\", $PING}")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# =============
# Validate Results
# =============
if [[ -z "$DOWNLOAD_MBPS" || -z "$UPLOAD_MBPS" || -z "$PING_MS" ]]; then
    log "ERROR: Incomplete speedtest results. Raw output: $RESULT"
    echo "Speedtest failed or returned incomplete results. See log for details."
    exit 1
fi

# =============
# Initialize CSV
# =============
if [ ! -f "$CSV_FILE" ]; then
    echo "Timestamp,Server Name,Server ID,ISP,Ping (ms),Jitter,Idle Latency,Download (Mbps),Upload (Mbps),Bytes Received,Bytes Sent,Download Latency,Upload Latency,Result URL" > "$CSV_FILE"
    log "Initialized new CSV file at $CSV_FILE."
fi

# =============
# Append to CSV
# =============
echo "$TIMESTAMP,${SERVER_NAME//\"/},${SERVER_ID//\"/},${ISP//\"/},$PING_MS,$JITTER,$IDLE_LATENCY,$DOWNLOAD_MBPS,$UPLOAD_MBPS,$BYTES_RECEIVED,$BYTES_SENT,$DL_LATENCY,$UL_LATENCY,${RESULT_URL//\"/}" >> "$CSV_FILE"
log "Appended result: $TIMESTAMP,${SERVER_NAME//\"/},${SERVER_ID//\"/},${ISP//\"/},$PING_MS,$JITTER,$IDLE_LATENCY,$DOWNLOAD_MBPS,$UPLOAD_MBPS,$BYTES_RECEIVED,$BYTES_SENT,$DL_LATENCY,$UL_LATENCY,${RESULT_URL//\"/}"

# After parsing and before appending to CSV, print the parsed results

echo "Parsed Speedtest Results:"
echo "  Timestamp: $TIMESTAMP"
echo "  Ping (ms): $PING_MS"
echo "  Download (Mbps): $DOWNLOAD_MBPS"
echo "  Upload (Mbps): $UPLOAD_MBPS"

# =============
# Generate HTML
# =============
# Remove or comment out all code that generates or overwrites index.html
# The script should only update the CSV and log files, not touch index.html

log "HTML dashboard updated at $HTML_FILE."
