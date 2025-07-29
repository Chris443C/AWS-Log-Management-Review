# Module Breakdown

## Core Modules

### speedtest_to_web_fast.sh
- **Purpose:** Main speedtest runner and dashboard generator (uses fast-cli)
- **Inputs:** None (runs fast-cli, pings, updates CSV)
- **Outputs:** results.csv, index.html (dashboard)
- **Interfaces:** Cron, web browser

### setup-fast-speedtest.sh / setup-pi.sh
- **Purpose:** Automated environment and dependency setup
- **Inputs:** None (interactive script)
- **Outputs:** Installs dependencies, configures system
- **Interfaces:** Shell, user

### api-setup.sh
- **Purpose:** REST API server for mobile and integrations
- **Inputs:** HTTP requests
- **Outputs:** JSON API responses
- **Interfaces:** Mobile app, browser, third-party tools

### security-setup.sh
- **Purpose:** Security hardening, firewall, log rotation
- **Inputs:** None (scripted)
- **Outputs:** Configured firewall, fail2ban, logrotate
- **Interfaces:** System, admin

### export_chart_pdf.js
- **Purpose:** Exports dashboard charts as PDF using Puppeteer
- **Inputs:** Dashboard URL
- **Outputs:** PDF file
- **Interfaces:** Node.js, web browser

### archive_csv.sh
- **Purpose:** Archives results.csv to archive directory
- **Inputs:** results.csv
- **Outputs:** archive/results_YYYY-MM-DD.csv
- **Interfaces:** Cron, admin

## Supporting Modules
- **enhanced-monitoring.sh:** System metrics collection
- **verify-setup.sh:** System and dependency verification
- **fix-apache.sh:** Apache port conflict resolution
- **install-fast-cli-deps.sh:** Installs Chromium, Puppeteer, and configures fast-cli

## Mobile App
- **SpeedtestMonitor (Android):** Kotlin app for real-time monitoring
- **Interfaces:** REST API, user

---

> For dependencies, see [dependencies.md](dependencies.md). For workflows, see [../workflows/development.md](../workflows/development.md). 