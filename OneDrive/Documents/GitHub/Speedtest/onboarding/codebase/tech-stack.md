# Technology Stack Details

## Overview
This project leverages a modern, modular stack optimized for Raspberry Pi and Linux environments, with extensibility for cloud and mobile integration.

## Core Technologies
- **Bash (>=4.4):** Orchestration scripts for automation and system tasks
- **Node.js (>=16):** JavaScript runtime for PDF export, API server, and fast-cli
- **npm (>=8):** Package management for Node.js dependencies
- **fast-cli (>=3):** Internet speed testing via Fast.com (Netflix)
- **Puppeteer (>=21):** Headless browser automation for PDF/chart export and fast-cli
- **Chromium (>=92):** Headless browser for Puppeteer/fast-cli
- **Python 3 (>=3.7):** Legacy scripts and optional integrations
- **Apache2 (>=2.4):** Web server for dashboard and API
- **Chart.js (>=4):** Frontend charting for dashboard visualization
- **Marp (>=2):** Markdown presentation generation
- **Android (Kotlin, Retrofit):** Mobile client for real-time monitoring

## Supporting Tools
- **cron:** Scheduled automation of speed tests and archiving
- **systemd:** Service management for API and web server
- **curl, grep, awk, sed:** Data processing and HTTP requests
- **npm packages:**
  - `express`, `cors`, `helmet`, `rate-limiter-flexible`, `node-cron` (API server)
  - `puppeteer`, `fast-cli` (PDF export, speed tests)

## Version Management
- Use `nvm` or system package manager for Node.js
- Use `pip` for Python dependencies (legacy only)
- All major scripts check for minimum version requirements

## Extensibility
- Can integrate with SQLite/PostgreSQL for persistent storage
- API server supports mobile and third-party integrations
- Presentation layer can be extended with Marp themes/assets

---

> For installation and setup, see [../setup/development.md](../setup/development.md). For architecture, see [architecture.md](architecture.md). 