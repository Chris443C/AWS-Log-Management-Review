#!/bin/bash
set -euo pipefail

# API and mobile app support for Speedtest system
LOG_FILE="${LOG_FILE:-/var/log/speedtest-api.log}"

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

# Setup Node.js API Server
setup_api_server() {
    print_header "Setting up REST API Server"
    
    print_status "Creating API server directory..."
    sudo mkdir -p /var/www/html/speedtest/api
    
    print_status "Setting proper permissions for API directory..."
    sudo chown -R pi:pi /var/www/html/speedtest/api
    sudo chmod -R 755 /var/www/html/speedtest/api
    
    print_status "Creating package.json for API server..."
    tee /var/www/html/speedtest/api/package.json > /dev/null <<EOF
{
  "name": "speedtest-api",
  "version": "1.0.0",
  "description": "REST API for Speedtest monitoring",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "rate-limiter-flexible": "^2.4.2",
    "node-cron": "^3.0.2"
  },
  "keywords": ["speedtest", "api", "monitoring"],
  "author": "Speedtest Monitor",
  "license": "MIT"
}
EOF
    
    print_status "Creating API server..."
    tee /var/www/html/speedtest/api/server.js > /dev/null <<'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { RateLimiterMemory } = require('rate-limiter-flexible');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const PDF_PATH = '/var/www/html/speedtest/exports/speedtest_' + (new Date().toISOString().split('T')[0]) + '.pdf';

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const rateLimiter = new RateLimiterMemory({
    keyGenerator: (req) => req.ip,
    points: 100, // Number of requests
    duration: 60, // Per 60 seconds
});

const rateLimiterMiddleware = (req, res, next) => {
    rateLimiter.consume(req.ip)
        .then(() => next())
        .catch(() => res.status(429).json({ error: 'Too many requests' }));
};

app.use(rateLimiterMiddleware);

// Data file paths
const CSV_FILE = '/var/www/html/speedtest/results.csv';
const METRICS_FILE = '/var/www/html/speedtest/system-metrics.json';
const NETWORK_FILE = '/var/www/html/speedtest/network-quality.json';

// Helper function to read CSV data
function readCSVData() {
    try {
        if (!fs.existsSync(CSV_FILE)) {
            return [];
        }
        const data = fs.readFileSync(CSV_FILE, 'utf8');
        const lines = data.trim().split('\n');
        if (lines.length < 2) return [];
        const headers = lines[0].split(',');
        return lines.slice(1).map(line => {
            const cols = line.split(',');
            const row = {};
            headers.forEach((h, i) => row[h.trim()] = cols[i] ? cols[i].trim() : '');
            return {
                timestamp: row['Timestamp'],
                ping: parseFloat(row['Ping (ms)']),
                download: parseFloat(row['Download (Mbps)']),
                upload: parseFloat(row['Upload (Mbps)']),
                server: row['Server Name'],
                isp: row['ISP'],
                // add more fields as needed
            };
        });
    } catch (error) {
        console.error('Error reading CSV:', error);
        return [];
    }
}

// API Routes

// Get latest speedtest result
app.get('/api/latest', (req, res) => {
    try {
        const data = readCSVData();
        if (data.length === 0) {
            return res.status(404).json({ error: 'No data available' });
        }
        
        const latest = data[data.length - 1];
        res.json({
            success: true,
            data: latest,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get speedtest history
app.get('/api/history', (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 100;
        const data = readCSVData();
        
        res.json({
            success: true,
            data: data.slice(-limit),
            count: data.length,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get system metrics
app.get('/api/metrics', (req, res) => {
    try {
        if (!fs.existsSync(METRICS_FILE)) {
            return res.status(404).json({ error: 'System metrics not available' });
        }
        
        const metrics = JSON.parse(fs.readFileSync(METRICS_FILE, 'utf8'));
        res.json({
            success: true,
            data: metrics,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get network quality
app.get('/api/network', (req, res) => {
    try {
        if (!fs.existsSync(NETWORK_FILE)) {
            return res.status(404).json({ error: 'Network quality data not available' });
        }
        
        const network = JSON.parse(fs.readFileSync(NETWORK_FILE, 'utf8'));
        res.json({
            success: true,
            data: network,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get summary statistics
app.get('/api/summary', (req, res) => {
    try {
        const data = readCSVData();
        if (data.length === 0) {
            return res.status(404).json({ error: 'No data available' });
        }
        
        const downloads = data.map(d => d.download);
        const uploads = data.map(d => d.upload);
        const pings = data.map(d => d.ping);
        
        const summary = {
            total_tests: data.length,
            latest_test: data[data.length - 1],
            averages: {
                download: downloads.reduce((a, b) => a + b, 0) / downloads.length,
                upload: uploads.reduce((a, b) => a + b, 0) / uploads.length,
                ping: pings.reduce((a, b) => a + b, 0) / pings.length
            },
            best: {
                download: Math.max(...downloads),
                upload: Math.max(...uploads),
                ping: Math.min(...pings)
            },
            worst: {
                download: Math.min(...downloads),
                upload: Math.min(...uploads),
                ping: Math.max(...pings)
            }
        };
        
        res.json({
            success: true,
            data: summary,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Export PDF endpoint
app.get('/api/export-pdf', (req, res) => {
    exec('/home/pi/Speedtest/export_pdf.sh', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: 'PDF export failed', details: stderr });
        }
        res.download(PDF_PATH, 'speedtest.pdf');
    });
});
// Also support /speedtest/api/export-pdf for Apache proxy compatibility
app.get('/speedtest/api/export-pdf', (req, res) => {
    exec('/home/pi/Speedtest/export_pdf.sh', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: 'PDF export failed', details: stderr });
        }
        res.download(PDF_PATH, 'speedtest.pdf');
    });
});

// Run Test Now endpoint
app.post('/api/run-test', (req, res) => {
    exec('/home/pi/Speedtest/speedtest_to_web.sh', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: 'Speedtest failed', details: stderr });
        }
        const data = readCSVData();
        res.json({ success: true, data: data[data.length - 1] });
    });
});
// Also support /speedtest/api/run-test for Apache proxy compatibility
app.post('/speedtest/api/run-test', (req, res) => {
    exec('/home/pi/Speedtest/speedtest_to_web.sh', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: 'Speedtest failed', details: stderr });
        }
        const data = readCSVData();
        res.json({ success: true, data: data[data.length - 1] });
    });
});

// Auto-Update endpoint
app.post('/api/auto-update', (req, res) => {
    exec('/usr/local/bin/speedtest-auto-update.sh', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: 'Auto-update failed', details: stderr });
        }
        res.json({ success: true, output: stdout });
    });
});
app.post('/speedtest/api/auto-update', (req, res) => {
    exec('/usr/local/bin/speedtest-auto-update.sh', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: 'Auto-update failed', details: stderr });
        }
        res.json({ success: true, output: stdout });
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something went wrong!' });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Endpoint not found' });
});

// Start server
app.listen(PORT, () => {
    console.log(`Speedtest API server running on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});
EOF
    
    print_status "Installing API dependencies..."
    cd /var/www/html/speedtest/api
    npm install --no-audit --no-fund
    
    print_status "Creating systemd service for API..."
    sudo tee /etc/systemd/system/speedtest-api.service > /dev/null <<EOF
[Unit]
Description=Speedtest API Server
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/var/www/html/speedtest/api
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
    
    print_status "Enabling and starting API service..."
    sudo systemctl daemon-reload
    sudo systemctl enable speedtest-api
    sudo systemctl start speedtest-api
    
    print_status "Setting final permissions..."
    sudo chown -R www-data:www-data /var/www/html/speedtest/api
    sudo chmod -R 755 /var/www/html/speedtest/api
    
    print_status "API server status:"
    sudo systemctl status speedtest-api --no-pager
}

# Setup Webhook Notifications
setup_webhooks() {
    print_header "Setting up Webhook Notifications"
    
    print_status "Creating webhook notification script..."
    sudo tee /usr/local/bin/webhook-notify.sh > /dev/null <<'EOF'
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
EOF
    
    sudo chmod +x /usr/local/bin/webhook-notify.sh
    
    print_status "Adding webhook notification to cron..."
    (crontab -l 2>/dev/null; echo "*/15 * * * * /usr/local/bin/webhook-notify.sh") | crontab -
}

# Create Mobile App Support
create_mobile_support() {
    print_header "Creating Mobile App Support"
    
    print_status "Creating mobile-optimized dashboard..."
    sudo tee /var/www/html/speedtest/mobile.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Speedtest Mobile</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; }
        .header { background: #007cba; color: white; padding: 20px; text-align: center; }
        .metric-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; padding: 15px; }
        .metric-card { background: white; padding: 15px; border-radius: 10px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric-value { font-size: 1.5em; font-weight: bold; color: #333; }
        .metric-label { color: #666; font-size: 0.9em; margin-top: 5px; }
        .chart-container { background: white; margin: 15px; padding: 15px; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .good { color: #28a745; }
        .warning { color: #ffc107; }
        .danger { color: #dc3545; }
        .refresh-btn { background: #007cba; color: white; border: none; padding: 10px 20px; border-radius: 5px; margin: 15px; width: calc(100% - 30px); }
    </style>
</head>
<body>
    <div class="header">
        <h1>Speedtest Monitor</h1>
        <p id="lastUpdate">Loading...</p>
    </div>
    
    <div class="metric-grid" id="metrics">
        <!-- Metrics will be populated here -->
    </div>
    
    <div class="chart-container">
        <canvas id="speedChart"></canvas>
    </div>
    
    <button class="refresh-btn" onclick="loadData()">Refresh Data</button>

    <script>
        function loadData() {
            // Load latest data
            fetch('/speedtest/api/latest')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const result = data.data;
                        document.getElementById('metrics').innerHTML = `
                            <div class="metric-card">
                                <div class="metric-value ${result.download > 100 ? 'good' : result.download > 50 ? 'warning' : 'danger'}">${result.download}</div>
                                <div class="metric-label">Download (Mbps)</div>
                            </div>
                            <div class="metric-card">
                                <div class="metric-value ${result.upload > 10 ? 'good' : result.upload > 5 ? 'warning' : 'danger'}">${result.upload}</div>
                                <div class="metric-label">Upload (Mbps)</div>
                            </div>
                            <div class="metric-card">
                                <div class="metric-value ${result.ping < 20 ? 'good' : result.ping < 50 ? 'warning' : 'danger'}">${result.ping}</div>
                                <div class="metric-label">Ping (ms)</div>
                            </div>
                            <div class="metric-card">
                                <div class="metric-value">${new Date(result.timestamp).toLocaleTimeString()}</div>
                                <div class="metric-label">Last Test</div>
                            </div>
                        `;
                        document.getElementById('lastUpdate').textContent = `Last updated: ${new Date().toLocaleTimeString()}`;
                    }
                })
                .catch(error => {
                    console.error('Error loading data:', error);
                    document.getElementById('metrics').innerHTML = '<div style="grid-column: 1/-1; text-align: center; color: red;">Error loading data</div>';
                });
        }

        // Load data on page load
        loadData();
        
        // Refresh every 30 seconds
        setInterval(loadData, 30000);
    </script>
</body>
</html>
EOF
    
    print_status "Creating PWA manifest..."
    sudo tee /var/www/html/speedtest/manifest.json > /dev/null <<EOF
{
  "name": "Speedtest Monitor",
  "short_name": "Speedtest",
  "description": "Internet speed monitoring dashboard",
  "start_url": "/speedtest/mobile.html",
  "display": "standalone",
  "background_color": "#007cba",
  "theme_color": "#007cba",
  "icons": [
    {
      "src": "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📊</text></svg>",
      "sizes": "192x192",
      "type": "image/svg+xml"
    }
  ]
}
EOF
}

# Setup API Proxy in Apache
setup_api_proxy() {
    print_header "Setting up API Proxy in Apache"
    
    print_status "Enabling required Apache modules..."
    sudo a2enmod proxy
    sudo a2enmod proxy_http
    
    print_status "Creating API proxy configuration..."
    sudo tee /etc/apache2/sites-available/speedtest-api.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName api.speedtest.local
    ProxyPreserveHost On
    ProxyPass / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/
    
    ErrorLog \${APACHE_LOG_DIR}/speedtest_api_error.log
    CustomLog \${APACHE_LOG_DIR}/speedtest_api_access.log combined
</VirtualHost>
EOF
    
    print_status "Enabling API site..."
    sudo a2ensite speedtest-api.conf
    
    print_status "Restarting Apache..."
    sudo systemctl restart apache2
}

# Main execution
main() {
    print_header "API and Mobile App Setup"
    
    setup_api_server
    setup_webhooks
    create_mobile_support
    setup_api_proxy
    
    print_header "API and Mobile App Setup Complete!"
    echo "Additional features added:"
    echo "• REST API server on port 3000"
    echo "• Webhook notifications"
    echo "• Mobile-optimized dashboard"
    echo "• PWA support"
    echo ""
    echo "API endpoints:"
    echo "  http://$(hostname -I | awk '{print $1}'):3000/api/latest"
    echo "  http://$(hostname -I | awk '{print $1}'):3000/api/history"
    echo "  http://$(hostname -I | awk '{print $1}'):3000/api/metrics"
    echo "  http://$(hostname -I | awk '{print $1}'):3000/api/summary"
    echo ""
    echo "Mobile dashboard:"
    echo "  http://$(hostname -I | awk '{print $1}')/speedtest/mobile.html"
}

main "$@" 