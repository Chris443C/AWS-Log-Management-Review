#!/bin/bash
# Health check for Speedtest API
URL="http://localhost:3000/api/health"
if ! curl -sf "$URL" | grep -q healthy; then
  echo "Speedtest API not healthy, restarting..."
  sudo systemctl restart speedtest-api
  # Optional: send an alert (email, webhook, etc.)
fi 