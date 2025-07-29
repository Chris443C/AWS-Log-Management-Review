#!/bin/bash
# Webhook Notification Script

WEBHOOK_URL="${WEBHOOK_URL:-}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-}"

if [ -z "$WEBHOOK_URL" ]; then
    exit 0
fi

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
    
    # Create JSON payload
    PAYLOAD=$(cat <<JSON
{
  "timestamp": "$timestamp",
  "ping": $ping,
  "download": $download,
  "upload": $upload,
  "hostname": "$(hostname)",
  "ip": "$(hostname -I | awk '{print $1}')"
}
JSON
)
    
    # Send webhook
    curl -X POST "$WEBHOOK_URL" \
         -H "Content-Type: application/json" \
         -H "X-Webhook-Secret: $WEBHOOK_SECRET" \
         -d "$PAYLOAD" \
         --silent --show-error
fi
