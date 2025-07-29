# Raspberry Pi Speedtest Web Logger

This setup logs internet speed test results every 10 minutes on a Raspberry Pi and serves them on a local web page, with charts and CSV download.

## Features
- Run speed tests every 10 minutes
- Logs Ping, Download, and Upload
- Displays results as a chart with Chart.js
- Highlights slow download (<495 Mbps)
- Offers downloadable CSV
- Weekly archiving (optional)

## Installation

1. **Install Dependencies**
```bash
sudo apt update
sudo apt install python3-pip nginx -y
pip3 install --user speedtest-cli
```

2. **Set Permissions**
```bash
sudo mkdir -p /var/www/html/speedtest
sudo chown -R <your-user>:<your-user> /var/www/html/speedtest
chmod -R 755 /var/www/html/speedtest
```

3. **Set Cron Job**
```bash
crontab -e
```
Add:
```cron
*/10 * * * * /home/<your-user>/speedtest_to_web.sh
```

## Access

Visit: `http://<raspberry-pi-ip>/speedtest/`

Example: `http://192.168.1.154/speedtest/`

## Notes

- Make sure `speedtest-cli` is located in `~/.local/bin/speedtest-cli`
- You can edit the account label directly in the script.
