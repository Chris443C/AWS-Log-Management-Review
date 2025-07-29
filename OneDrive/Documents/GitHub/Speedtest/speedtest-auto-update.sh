#!/bin/bash
set -e
cd /home/pi/Speedtest
if [ -d .git ]; then
  echo "Pulling latest code..."
  git pull
else
  echo "Not a git repo, skipping pull."
fi
if [ -d /var/www/html/speedtest/api ]; then
  echo "Updating Node.js dependencies..."
  cd /var/www/html/speedtest/api && npm install --no-audit --no-fund
else
  echo "No API dir."
fi
echo "Restarting API service..."
sudo systemctl restart speedtest-api || echo "No API service."
echo "Reloading Apache..."
sudo systemctl reload apache2 || echo "No Apache."
echo "Update complete!" 