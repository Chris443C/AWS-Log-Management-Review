#!/bin/bash
set -euo pipefail

# Enhanced monitoring features for Speedtest system
LOG_FILE="${LOG_FILE:-/var/log/speedtest-enhanced.log}"

# =============
# Logging Setup
# =============
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$message"
    
    # Try to write to log file, but don't fail if we can't
    if [[ -w "$LOG_FILE" ]] || [[ -w "$(dirname "$LOG_FILE")" ]]; then
        echo "$message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

print_status() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
    log "INFO: $1"
}

print_header() {
    echo -e "\033[0;34m================================\033[0m"
    echo -e "\033[0;34m$1\033[0m"
    echo -e "\033[0;34m================================\033[0m"
    log "HEADER: $1"
}

# Email Alerting Setup
setup_email_alerts() {
    print_header "Setting up Email Alerts"
    
    print_status "Installing mail utilities..."
    sudo apt install -y mailutils
    
    print_status "Creating alert script..."
    sudo tee /usr/local/bin/speedtest-alert.sh > /dev/null <<'EOF'
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
EOF
    
    sudo chmod +x /usr/local/bin/speedtest-alert.sh
    
    print_status "Adding alert check to cron (runs after each speedtest)..."
    (crontab -l 2>/dev/null; echo "*/15 * * * * /usr/local/bin/speedtest-alert.sh") | crontab -
}

# Performance Metrics Collection
setup_performance_metrics() {
    print_header "Setting up Performance Metrics"
    
    print_status "Creating system metrics collection script..."
    sudo tee /usr/local/bin/collect-metrics.sh > /dev/null <<'EOF'
#!/bin/bash
# System Performance Metrics Collection

METRICS_FILE="/var/www/html/speedtest/system-metrics.json"
DATE=$(date -Iseconds)

# Collect system metrics
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
TEMPERATURE=$(vcgencmd measure_temp | cut -d'=' -f2 | cut -d"'" -f1)
UPTIME=$(uptime -p | sed 's/up //')

# Create metrics JSON
cat > "$METRICS_FILE" <<JSON
{
  "timestamp": "$DATE",
  "system": {
    "cpu_usage": $CPU_USAGE,
    "memory_usage": $MEMORY_USAGE,
    "disk_usage": $DISK_USAGE,
    "temperature": "$TEMPERATURE",
    "uptime": "$UPTIME"
  }
}
JSON
EOF
    
    sudo chmod +x /usr/local/bin/collect-metrics.sh
    
    print_status "Adding metrics collection to cron (every 5 minutes)..."
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/collect-metrics.sh") | crontab -
}

# Enhanced Dashboard with System Metrics
enhance_dashboard() {
    print_header "Enhancing Dashboard with System Metrics"
    
    print_status "Creating enhanced dashboard..."
    sudo tee /var/www/html/speedtest/enhanced.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Enhanced Speedtest Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric-card { background: #f5f5f5; padding: 15px; border-radius: 8px; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; color: #333; }
        .metric-label { color: #666; margin-top: 5px; }
        .warning { color: red; font-weight: bold; }
        .good { color: green; }
        .chart-container { margin: 20px 0; }
        .tabs { display: flex; margin-bottom: 20px; }
        .tab { padding: 10px 20px; cursor: pointer; border: 1px solid #ddd; background: #f9f9f9; }
        .tab.active { background: #007cba; color: white; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Enhanced Speedtest Dashboard</h1>
        
        <div class="metrics-grid" id="systemMetrics">
            <!-- System metrics will be populated here -->
        </div>
        
        <div class="tabs">
            <div class="tab active" onclick="showTab('speed')">Speed Test</div>
            <div class="tab" onclick="showTab('system')">System Metrics</div>
        </div>
        
        <div id="speedTab" class="tab-content active">
            <div class="chart-container">
                <canvas id="speedChart" width="1000" height="400"></canvas>
            </div>
        </div>
        
        <div id="systemTab" class="tab-content">
            <div class="chart-container">
                <canvas id="systemChart" width="1000" height="400"></canvas>
            </div>
        </div>
    </div>

    <script>
        // Tab functionality
        function showTab(tabName) {
            document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
            
            event.target.classList.add('active');
            document.getElementById(tabName + 'Tab').classList.add('active');
        }

        // Load system metrics
        function loadSystemMetrics() {
            fetch('system-metrics.json')
                .then(response => response.json())
                .then(data => {
                    const metrics = data.system;
                    document.getElementById('systemMetrics').innerHTML = `
                        <div class="metric-card">
                            <div class="metric-value ${metrics.cpu_usage > 80 ? 'warning' : 'good'}">${metrics.cpu_usage}%</div>
                            <div class="metric-label">CPU Usage</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value ${metrics.memory_usage > 80 ? 'warning' : 'good'}">${metrics.memory_usage}%</div>
                            <div class="metric-label">Memory Usage</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value ${metrics.disk_usage > 80 ? 'warning' : 'good'}">${metrics.disk_usage}%</div>
                            <div class="metric-label">Disk Usage</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">${metrics.temperature}</div>
                            <div class="metric-label">Temperature</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">${metrics.uptime}</div>
                            <div class="metric-label">Uptime</div>
                        </div>
                    `;
                })
                .catch(error => console.error('Error loading system metrics:', error));
        }

        // Load speed test data
        function loadSpeedData() {
            fetch('results.csv')
                .then(response => response.text())
                .then(data => {
                    const lines = data.trim().split('\n').filter(l => l && !l.includes('Vodafone'));
                    const labels = [];
                    const ping = [], download = [], upload = [], pointColors = [];

                    lines.slice(1).forEach(line => {
                        const [timestamp, p, d, u] = line.split(',');
                        labels.push(timestamp);
                        const dNum = parseFloat(d);
                        ping.push(parseFloat(p));
                        download.push(dNum);
                        upload.push(parseFloat(u));
                        pointColors.push(dNum < 495 ? 'red' : 'green');
                    });

                    const ctx = document.getElementById('speedChart').getContext('2d');
                    new Chart(ctx, {
                        type: 'line',
                        data: {
                            labels: labels,
                            datasets: [
                                {
                                    label: 'Download (Mbps)',
                                    data: download,
                                    borderColor: 'green',
                                    pointBackgroundColor: pointColors,
                                    fill: false,
                                    tension: 0.1
                                },
                                {
                                    label: 'Upload (Mbps)',
                                    data: upload,
                                    borderColor: 'blue',
                                    fill: false,
                                    tension: 0.1
                                },
                                {
                                    label: 'Ping (ms)',
                                    data: ping,
                                    borderColor: 'orange',
                                    fill: false,
                                    tension: 0.1
                                }
                            ]
                        },
                        options: {
                            responsive: true,
                            scales: {
                                x: { ticks: { maxTicksLimit: 20 } },
                                y: { beginAtZero: true }
                            },
                            plugins: {
                                legend: { labels: { usePointStyle: true } }
                            }
                        }
                    });
                });
        }

        // Initialize dashboard
        loadSystemMetrics();
        loadSpeedData();
        
        // Refresh metrics every 30 seconds
        setInterval(loadSystemMetrics, 30000);
    </script>
</body>
</html>
EOF
    
    print_status "Enhanced dashboard created at: /var/www/html/speedtest/enhanced.html"
}

# Network Quality Monitoring
setup_network_monitoring() {
    print_header "Setting up Network Quality Monitoring"
    
    print_status "Creating network quality test script..."
    sudo tee /usr/local/bin/network-quality.sh > /dev/null <<'EOF'
#!/bin/bash
# Network Quality Monitoring

LOG_FILE="/var/log/network-quality.log"
RESULTS_FILE="/var/www/html/speedtest/network-quality.json"

# Test DNS resolution
dns_test() {
    local start_time=$(date +%s.%N)
    if nslookup google.com > /dev/null 2>&1; then
        local end_time=$(date +%s.%N)
        echo "scale=2; ($end_time - $start_time) * 1000" | bc
    else
        echo "999"
    fi
}

# Test HTTP response time
http_test() {
    local start_time=$(date +%s.%N)
    if curl -s --max-time 10 http://httpbin.org/delay/1 > /dev/null; then
        local end_time=$(date +%s.%N)
        echo "scale=2; ($end_time - $start_time) * 1000" | bc
    else
        echo "999"
    fi
}

# Run tests
DNS_TIME=$(dns_test)
HTTP_TIME=$(http_test)
DATE=$(date -Iseconds)

# Create results JSON
cat > "$RESULTS_FILE" <<JSON
{
  "timestamp": "$DATE",
  "dns_response_time": $DNS_TIME,
  "http_response_time": $HTTP_TIME,
  "network_quality": "$(if (( $(echo "$DNS_TIME < 100" | bc -l) && $(echo "$HTTP_TIME < 2000" | bc -l) )); then echo "good"; else echo "poor"; fi)"
}
JSON

echo "[$(date)] DNS: ${DNS_TIME}ms, HTTP: ${HTTP_TIME}ms" >> "$LOG_FILE"
EOF
    
    sudo chmod +x /usr/local/bin/network-quality.sh
    
    print_status "Adding network quality test to cron (every 30 minutes)..."
    (crontab -l 2>/dev/null; echo "*/30 * * * * /usr/local/bin/network-quality.sh") | crontab -
}

# Main execution
main() {
    print_header "Enhanced Monitoring Setup"
    
    setup_email_alerts
    setup_performance_metrics
    enhance_dashboard
    setup_network_monitoring
    
    print_header "Enhanced Monitoring Setup Complete!"
    echo "Additional features added:"
    echo "• Email alerts for poor performance"
    echo "• System performance metrics collection"
    echo "• Enhanced dashboard with system monitoring"
    echo "• Network quality monitoring"
    echo ""
    echo "Access enhanced dashboard at: http://$(hostname -I | awk '{print $1}')/speedtest/enhanced.html"
}

main "$@" 