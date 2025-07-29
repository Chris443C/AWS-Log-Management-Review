#!/bin/bash
# Speedtest Alert Script

ALERT_EMAIL="${ALERT_EMAIL:-admin@localhost}"
DOWNLOAD_THRESHOLD="${DOWNLOAD_THRESHOLD:-100}"
UPLOAD_THRESHOLD="${UPLOAD_THRESHOLD:-10}"
PING_THRESHOLD="${PING_THRESHOLD:-50}"

CSV_FILE="/var/www/html/speedtest/results.csv"
if [ ! -f "$CSV_FILE" ]; then
    exit 0
fi

# Get latest results
LATEST_LINE=$(tail -n 1 "$CSV_FILE")
if [[ "$LATEST_LINE" == *"Vodafone"* ]]; then
    LATEST_LINE=$(tail -n 2 "$CSV_FILE" | head -n 1)
fi

if [ -n "$LATEST_LINE" ]; then
    IFS=',' read -r timestamp ping download upload <<< "$LATEST_LINE"
    
    ALERT_MESSAGE=""
    
    if (( $(echo "$download < $DOWNLOAD_THRESHOLD" | bc -l) )); then
        ALERT_MESSAGE+="WARNING: Download speed is ${download} Mbps (below ${DOWNLOAD_THRESHOLD} Mbps threshold)\n"
    fi
    
    if (( $(echo "$upload < $UPLOAD_THRESHOLD" | bc -l) )); then
        ALERT_MESSAGE+="WARNING: Upload speed is ${upload} Mbps (below ${UPLOAD_THRESHOLD} Mbps threshold)\n"
    fi
    
    if (( $(echo "$ping > $PING_THRESHOLD" | bc -l) )); then
        ALERT_MESSAGE+="WARNING: Ping is ${ping} ms (above ${PING_THRESHOLD} ms threshold)\n"
    fi
    
    if [ -n "$ALERT_MESSAGE" ]; then
        echo -e "Subject: Speedtest Alert - $(hostname)\n\n$ALERT_MESSAGE\nTimestamp: $timestamp" | mail -s "Speedtest Alert" "$ALERT_EMAIL"
    fi
fi
