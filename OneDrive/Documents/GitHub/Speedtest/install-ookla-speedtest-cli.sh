#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/install-ookla-speedtest-cli.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "==== Installing Ookla Speedtest CLI ===="

ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]]; then
  URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-arm64.tgz"
else
  URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-armhf.tgz"
fi

log "Downloading Ookla Speedtest CLI from $URL..."
wget -O speedtest.tgz "$URL"
tar -xzf speedtest.tgz

log "Installing Ookla Speedtest CLI to /usr/local/bin/speedtest..."
sudo mv speedtest /usr/local/bin/
sudo chmod +x /usr/local/bin/speedtest
rm speedtest.tgz

log "Testing Ookla Speedtest CLI installation..."
if /usr/local/bin/speedtest --version; then
    log "Ookla Speedtest CLI installed successfully."
else
    log "ERROR: Ookla Speedtest CLI installation failed."
    exit 1
fi

log "==== Ookla Speedtest CLI installation complete. ====" 