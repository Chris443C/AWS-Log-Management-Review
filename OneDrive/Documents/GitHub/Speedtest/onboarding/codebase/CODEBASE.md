# Codebase Architectural Summary

## Overview
The Speedtest Monitoring System is a modular, extensible platform for automated internet speed monitoring, reporting, and dashboarding on Raspberry Pi and Linux environments.

## Technology Stack
- **Backend:** Bash, Node.js, Puppeteer, Python (for legacy scripts)
- **Frontend:** HTML, Chart.js, Marp (for presentations)
- **Web Server:** Apache2
- **Database:** CSV (flat file), extensible to SQLite/PostgreSQL
- **Automation:** Cron, systemd
- **Mobile:** Android (Kotlin, Retrofit)

## Directory Structure
```
Speedtest/
├── api-setup.sh
├── archive_csv.sh
├── export_chart_pdf.js
├── export_pdf.sh
├── fix-apache.sh
├── install-fast-cli-deps.sh
├── install-node-deps.sh
├── install-puppeteer.sh
├── README.md
├── security-setup.sh
├── setup-fast-speedtest.sh
├── setup-pi.sh
├── speedtest_to_web.sh
├── speedtest_to_web_fast.sh
├── TROUBLESHOOTING.md
├── verify-setup.sh
└── ...
```

## Architecture Pattern
- **Script-driven orchestration** for speed tests, archiving, and reporting
- **Web dashboard** served via Apache with real-time charting
- **API server** (optional) for mobile and remote access
- **Modular scripts** for setup, security, and troubleshooting

## Key Modules
- **speedtest_to_web_fast.sh:** Main speedtest and dashboard generator (uses fast-cli)
- **setup-pi.sh / setup-fast-speedtest.sh:** Automated environment and dependency setup
- **api-setup.sh:** REST API server for mobile integration
- **security-setup.sh:** Hardening, firewall, and log rotation
- **export_chart_pdf.js:** PDF export of dashboard charts

## Setup & Development
- See [../setup/development.md](../setup/development.md) for environment setup
- Use [../setup/deployment.md](../setup/deployment.md) for deployment procedures
- For troubleshooting, see [../setup/troubleshooting.md](../setup/troubleshooting.md)

## Example: Running a Speedtest
```bash
./speedtest_to_web_fast.sh
# or via cron
*/15 * * * * /home/pi/Speedtest/speedtest_to_web_fast.sh
```

---

> For a full module breakdown, see [modules.md](modules.md). For dependencies, see [dependencies.md](dependencies.md). 