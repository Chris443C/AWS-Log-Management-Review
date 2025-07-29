# System Architecture

## High-Level Overview
The Speedtest Monitoring System is composed of modular scripts, a web dashboard, an optional API server, and supporting automation. It is designed for reliability, extensibility, and ease of deployment on Raspberry Pi and Linux systems.

## Main Components
- **Speedtest Script:** Runs scheduled speed tests, logs results, generates dashboard
- **Web Dashboard:** Serves real-time and historical results via Apache
- **API Server (Optional):** Provides REST endpoints for mobile and integrations
- **PDF Export:** Generates PDF reports of dashboard charts
- **Archiving:** Archives CSV results for long-term storage
- **Security & Monitoring:** Firewall, log rotation, and system health scripts

## Data Flow
```
[cron] ──> [speedtest_to_web_fast.sh] ──> [results.csv] ──> [index.html]
   │                                         │
   │                                         └─> [archive_csv.sh] ──> [archive/]
   │
   └─> [api-setup.sh] (optional) ──> [API Server] ──> [Mobile App]
   │
   └─> [export_chart_pdf.js] ──> [PDF]
```

## Interactions
- **User:** Accesses dashboard via browser, downloads CSV/PDF, or uses mobile app
- **System:** Runs speed tests, updates dashboard, archives data, sends alerts
- **API:** Enables mobile and third-party integrations

## Security
- UFW firewall, fail2ban, Apache hardening
- Log rotation and monitoring scripts

---

> For module details, see [modules.md](modules.md). For deployment, see [../setup/deployment.md](../setup/deployment.md). 