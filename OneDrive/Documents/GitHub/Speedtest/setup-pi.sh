#!/bin/bash
set -euo pipefail

# =========================
# Configuration Variables
# =========================
LOG_FILE="/var/log/speedtest-setup.log"
DATA_DIR="/var/www/html/speedtest"
WEB_USER="www-data"
PI_USER="pi"

# =========================
# Logging Functions
# =========================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_header() {
    echo "================================
$1
================================" | tee -a "$LOG_FILE"
    log "HEADER: $1"
}

log_info() {
    echo "[INFO] $*" | tee -a "$LOG_FILE"
    log "INFO: $*"
}

log_error() {
    echo "[ERROR] $*" | tee -a "$LOG_FILE"
    log "ERROR: $*"
}

log_success() {
    echo "[SUCCESS] $*" | tee -a "$LOG_FILE"
    log "SUCCESS: $*"
}

log_warning() {
    echo "[WARNING] $*" | tee -a "$LOG_FILE"
    log "WARNING: $*"
}

# =========================
# Error Handling
# =========================
handle_error() {
    log_error "Setup failed at line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

# =========================
# Check Node.js Version
# =========================
check_node_version() {
    log_info "Checking Node.js version..."
    
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version | sed 's/v//')
        log_info "Current Node.js version: $NODE_VERSION"
        
        # Parse version for comparison
        IFS='.' read -r major minor patch <<< "$NODE_VERSION"
        
        if [ "$major" -lt 16 ]; then
            log_error "Node.js version $NODE_VERSION is too old. Puppeteer requires Node.js 16.13.2+"
            log_info "Will use alternative PDF export method"
            return 1
        else
            log_info "Node.js version is compatible with Puppeteer"
            return 0
        fi
    else
        log_error "Node.js not found"
        return 1
    fi
}

# =========================
# Update Node.js (if needed)
# =========================
update_nodejs() {
    log_header "Updating Node.js"
    
    # Stop any running Node.js processes
    pkill -f node 2>/dev/null || true
    
    # Remove old Node.js packages
    log_info "Removing old Node.js installation..."
    sudo apt-get remove --purge -y nodejs npm 2>/dev/null || true
    sudo apt-get autoremove -y
    
    # Clean up any remaining files
    sudo rm -rf /usr/local/bin/npm /usr/local/bin/node 2>/dev/null || true
    sudo rm -rf /usr/bin/npm /usr/bin/node 2>/dev/null || true
    
    log_info "Adding NodeSource repository..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    
    log_info "Installing Node.js 18.x..."
    sudo apt-get install -y nodejs
    
    # Configure npm for pi user
    log_info "Configuring npm..."
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global"
    
    # Add to PATH if not already there
    if ! grep -q "npm-global" "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
        log_info "Added npm global path to .bashrc"
    fi
    
    # Source the updated bashrc
    export PATH="$HOME/.npm-global/bin:$PATH"
    
    log_info "Verifying installation..."
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    log_info "Node.js: $NODE_VERSION, npm: $NPM_VERSION"
    
    # Test basic functionality
    if node -e "console.log('Node.js is working')" 2>/dev/null; then
        log_info "Node.js installation verified successfully"
        return 0
    else
        log_error "Node.js installation verification failed"
        return 1
    fi
}

# =========================
# Install wkhtmltopdf Alternative
# =========================
install_wkhtmltopdf_alternative() {
    log_info "Installing wkhtmltopdf as alternative PDF export method..."
    
    if sudo apt-get install -y wkhtmltopdf; then
        log_success "wkhtmltopdf installed successfully"
        
        # Create alternative export script
        log_info "Creating wkhtmltopdf export script..."
        cat > export_pdf_wkhtmltopdf.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Configurable paths
WKHTMLTOPDF="${WKHTMLTOPDF:-/usr/bin/wkhtmltopdf}"
URL="${SPEEDTEST_URL:-http://localhost/speedtest/}"
EXPORT_DIR="${EXPORT_DIR:-/var/www/html/speedtest/exports}"
LOG_FILE="${LOG_FILE:-/var/log/export_pdf.log}"
today=$(date +%Y-%m-%d)
PDF_PATH="$EXPORT_DIR/speedtest_${today}.pdf"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Ensure export directory exists
mkdir -p "$EXPORT_DIR"

# Check if wkhtmltopdf exists
if [ ! -x "$WKHTMLTOPDF" ]; then
    log "ERROR: wkhtmltopdf not found at $WKHTMLTOPDF"
    echo "wkhtmltopdf not found. See log for details."
    exit 1
fi

# Export PDF
log "Exporting PDF to $PDF_PATH"
if "$WKHTMLTOPDF" \
    --page-size A4 \
    --orientation Landscape \
    --margin-top 10mm \
    --margin-right 10mm \
    --margin-bottom 10mm \
    --margin-left 10mm \
    --enable-local-file-access \
    "$URL" \
    "$PDF_PATH"; then
    log "PDF export completed successfully"
else
    log "ERROR: PDF export failed"
    echo "PDF export failed. See log for details."
    exit 1
fi
EOF
        
        chmod +x export_pdf_wkhtmltopdf.sh
        log_success "Alternative PDF export script created: export_pdf_wkhtmltopdf.sh"
        return 0
    else
        log_error "wkhtmltopdf installation failed"
        return 1
    fi
}

# =========================
# Install Puppeteer Robustly
# =========================
install_puppeteer_robust() {
    local PUPPETEER_VERSION="19.11.1"
    local TIMEOUT_MINUTES=30
    
    log_info "Installing Puppeteer version $PUPPETEER_VERSION..."
    log_info "This may take up to $TIMEOUT_MINUTES minutes on Raspberry Pi..."
    
    # Check available disk space (need at least 500MB)
    local AVAILABLE_SPACE=$(df . | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 500000 ]; then
        log_warning "Low disk space: ${AVAILABLE_SPACE}KB available (need at least 500MB)"
        log_warning "Puppeteer installation may fail due to insufficient space"
    else
        log_success "Sufficient disk space available: ${AVAILABLE_SPACE}KB"
    fi
    
    # Clean previous installation
    log_info "Cleaning previous Puppeteer installation..."
    if [ -d "node_modules/puppeteer" ]; then
        rm -rf node_modules/puppeteer
    fi
    if [ -f "package-lock.json" ]; then
        rm -f package-lock.json
    fi
    npm cache clean --force 2>/dev/null || true
    
    # Configure npm for Raspberry Pi
    log_info "Configuring npm for Raspberry Pi..."
    npm config set registry https://registry.npmjs.org/
    npm config set fetch-retries 5
    npm config set fetch-retry-mintimeout 20000
    npm config set fetch-retry-maxtimeout 120000
    npm config set progress false
    
    # Create package.json if it doesn't exist
    if [ ! -f "package.json" ]; then
        log_info "Creating package.json..."
        cat > package.json <<EOF
{
  "name": "speedtest-monitor",
  "version": "1.0.0",
  "description": "Internet speed monitoring and reporting",
  "main": "export_chart_pdf.js",
  "scripts": {
    "start": "node export_chart_pdf.js"
  },
  "dependencies": {
    "puppeteer": "$PUPPETEER_VERSION"
  }
}
EOF
    fi
    
    # Install with timeout
    log_info "Starting Puppeteer installation (timeout: ${TIMEOUT_MINUTES} minutes)..."
    if timeout "${TIMEOUT_MINUTES}m" npm install --no-audit --no-fund --loglevel=error; then
        log_success "Puppeteer installation completed successfully"
        
        # Test the installation
        if [ -d "node_modules/puppeteer" ]; then
            if node -e "const puppeteer = require('puppeteer'); console.log('Puppeteer version:', puppeteer.version);" 2>/dev/null; then
                log_success "Puppeteer test passed"
                return 0
            else
                log_warning "Puppeteer installed but test failed"
            fi
        fi
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_error "Puppeteer installation timed out after ${TIMEOUT_MINUTES} minutes"
        else
            log_error "Puppeteer installation failed with exit code $exit_code"
        fi
    fi
    
    # Fall back to wkhtmltopdf if Puppeteer fails
    log_warning "Puppeteer installation failed, falling back to wkhtmltopdf"
    install_wkhtmltopdf_alternative
    return 1
}

# =========================
# Install Ookla Speedtest CLI (Official PackageCloud Repo)
# =========================
install_ookla_speedtest_cli() {
    log_header "Installing Ookla Speedtest CLI"
    
    # Remove any old Bintray repo if present
    if [ -f /etc/apt/sources.list.d/speedtest.list ]; then
        log_info "Removing deprecated Bintray repository..."
        sudo rm /etc/apt/sources.list.d/speedtest.list
    fi
    
    # Add the new official PackageCloud repository
    log_info "Adding Ookla official PackageCloud repository..."
    if curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash; then
        log_success "Ookla PackageCloud repository added."
    else
        log_error "Failed to add Ookla PackageCloud repository."
        return 1
    fi
    
    # Install the CLI
    log_info "Installing speedtest CLI package..."
    if sudo apt-get install -y speedtest; then
        log_success "Ookla Speedtest CLI installed successfully."
    else
        log_error "Failed to install Ookla Speedtest CLI."
        return 1
    fi
    
    # Test the installation
    if speedtest --accept-license --accept-gdpr -f csv >/dev/null 2>&1; then
        log_success "Ookla Speedtest CLI test passed."
    else
        log_error "Ookla Speedtest CLI test failed. Please check installation."
        return 1
    fi
}

# =========================
# Install Dependencies
# =========================
install_dependencies() {
    log_header "Installing System Dependencies"
    
    log_info "Updating package list..."
    sudo apt-get update
    
    log_info "Installing required packages..."
    sudo apt-get install -y \
        apache2 \
        curl \
        wget \
        git \
        bc \
        cron \
        logrotate
    
    install_ookla_speedtest_cli
    
    log_info "Installing Node.js dependencies..."
    if check_node_version; then
        # Node.js is compatible, install Puppeteer with proper handling
        install_puppeteer_robust
    else
        log_info "Using alternative PDF export method (wkhtmltopdf)"
        install_wkhtmltopdf_alternative
    fi
}

# =========================
# Configure Apache Server
# =========================
configure_apache_server() {
    log_info "Configuring Apache server..."
    
    # Set ServerName to suppress warning
    if [ ! -f "/etc/apache2/conf-available/fqdn.conf" ]; then
        log_info "Creating ServerName configuration..."
        sudo tee /etc/apache2/conf-available/fqdn.conf > /dev/null <<EOF
ServerName localhost
EOF
        sudo a2enconf fqdn
    fi
    
    # Ensure default site is disabled
    if [ -L "/etc/apache2/sites-enabled/000-default.conf" ]; then
        log_info "Disabling default Apache site..."
        sudo a2dissite 000-default.conf
    fi
    
    # Create speedtest site configuration
    log_info "Creating speedtest site configuration..."
    sudo tee /etc/apache2/sites-available/speedtest.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName speedtest.local
    DocumentRoot /var/www/html/speedtest
    
    <Directory /var/www/html/speedtest>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/speedtest_error.log
    CustomLog \${APACHE_LOG_DIR}/speedtest_access.log combined
</VirtualHost>
EOF
    
    # Enable speedtest site
    sudo a2ensite speedtest.conf
    
    # Enable Apache to start on boot
    sudo systemctl enable apache2
    
    # Test Apache configuration
    if sudo apache2ctl configtest; then
        log_success "Apache configuration is valid"
    else
        log_error "Apache configuration has errors"
        return 1
    fi
}

# =========================
# Start Apache Server
# =========================
start_apache_server() {
    log_info "Starting Apache server..."
    
    # Check if port 80 is available
    if sudo netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        log_warning "Port 80 is already in use, stopping conflicting services..."
        stop_conflicting_services
    fi
    
    # Try to start Apache
    if sudo systemctl start apache2; then
        # Check if it's running
        if systemctl is-active --quiet apache2; then
            log_success "Apache started successfully on port 80"
            return 0
        else
            log_error "Apache failed to start properly"
            return 1
        fi
    else
        log_error "Failed to start Apache"
        return 1
    fi
}

# =========================
# Stop Conflicting Services
# =========================
stop_conflicting_services() {
    log_info "Stopping conflicting services..."
    
    # Common services that might use port 80
    local services=("nginx" "lighttpd" "httpd" "apache2")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_info "Stopping $service..."
            sudo systemctl stop "$service" 2>/dev/null || true
        fi
    done
    
    # Kill any remaining processes on port 80
    local pids=$(sudo lsof -ti:80 2>/dev/null || echo "")
    if [ -n "$pids" ]; then
        log_info "Killing processes using port 80: $pids"
        echo "$pids" | xargs -r sudo kill -9
    fi
    
    # Wait a moment for processes to stop
    sleep 2
}

# =========================
# Configure Apache Alternative Port
# =========================
configure_apache_alternative_port() {
    log_info "Configuring Apache to use alternative port 8080..."
    
    # Change Apache to use port 8080
    sudo sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
    
    # Update speedtest site configuration
    sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/speedtest.conf
    
    # Test configuration
    if sudo apache2ctl configtest; then
        log_success "Alternative port configuration is valid"
        
        # Start Apache
        if sudo systemctl start apache2; then
            log_success "Apache started on port 8080"
            log_info "Web dashboard available at: http://$(hostname -I | awk '{print $1}'):8080/speedtest/"
            return 0
        else
            log_error "Failed to start Apache on alternative port"
            return 1
        fi
    else
        log_error "Alternative port configuration has errors"
        return 1
    fi
}

# =========================
# Setup Web Server
# =========================
setup_web_server() {
    log_header "Setting up Web Server"
    
    log_info "Creating data directory..."
    if sudo mkdir -p /var/www/html/speedtest; then
        log_success "Created /var/www/html/speedtest"
    else
        log_error "Failed to create /var/www/html/speedtest"
        exit 1
    fi
    
    log_info "Setting permissions..."
    if sudo chown -R pi:www-data /var/www/html/speedtest && sudo chmod -R 775 /var/www/html/speedtest; then
        log_success "Permissions set for /var/www/html/speedtest (owner: pi, group: www-data, mode: 775)"
    else
        log_error "Failed to set permissions for /var/www/html/speedtest"
        exit 1
    fi
    
    log_info "Creating log directory..."
    sudo mkdir -p /var/log
    sudo touch /var/log/speedtest_to_web.log
    sudo touch /var/log/export_pdf.log
    sudo touch /var/log/archive_csv.log
    sudo chown pi:pi /var/log/speedtest_to_web.log
    sudo chown pi:pi /var/log/export_pdf.log
    sudo chown pi:pi /var/log/archive_csv.log
    
    # Copy index.html to web directory
    log_info "Copying dashboard files to web directory..."
    if [ -f "index.html" ]; then
        sudo cp index.html /var/www/html/speedtest/
        sudo chown pi:www-data /var/www/html/speedtest/index.html
        sudo chmod 664 /var/www/html/speedtest/index.html
        log_success "Dashboard copied to /var/www/html/speedtest/index.html"
    else
        log_warning "index.html not found in current directory"
    fi

    # Copy manifest.json to web directory
    if [ -f "manifest.json" ]; then
        sudo cp manifest.json /var/www/html/speedtest/
        sudo chown pi:www-data /var/www/html/speedtest/manifest.json
        sudo chmod 664 /var/www/html/speedtest/manifest.json
        log_success "manifest.json copied to /var/www/html/speedtest/manifest.json"
    else
        log_warning "manifest.json not found in current directory"
    fi

    # Copy icons to web directory
    if [ -d "icons" ]; then
        sudo mkdir -p /var/www/html/speedtest/icons
        sudo cp icons/* /var/www/html/speedtest/icons/
        sudo chown -R pi:www-data /var/www/html/speedtest/icons
        sudo chmod -R 664 /var/www/html/speedtest/icons/*
        log_success "Icons copied to /var/www/html/speedtest/icons/"
    else
        log_warning "icons directory not found in current directory"
    fi
    
    log_info "Configuring Apache..."
    
    # Configure Apache properly
    configure_apache_server
    
    # Try to start Apache
    if ! start_apache_server; then
        log_warning "Apache failed to start on port 80, trying alternative port"
        configure_apache_alternative_port
    fi
}

# =========================
# Setup Cron Jobs
# =========================
setup_cron_jobs() {
    log_header "Setting up Cron Jobs"
    
    log_info "Creating cron jobs..."
    
    # Speedtest every 10 minutes (ensure only one entry)
    (crontab -l 2>/dev/null | grep -v 'speedtest_to_web.sh'; echo "*/10 * * * * /home/pi/Speedtest/speedtest_to_web.sh >> /home/pi/Speedtest/cron.log 2>&1") | sort | uniq | crontab -
    log_info "Cron job for speedtest_to_web.sh added (every 10 minutes)."
    
    # Archive CSV daily at 2 AM
    (crontab -l 2>/dev/null | grep -v 'archive_csv.sh'; echo "0 2 * * * /home/pi/Speedtest/archive_csv.sh") | sort | uniq | crontab -
    
    # Export PDF daily at 3 AM
    if [ -d "node_modules/puppeteer" ]; then
        (crontab -l 2>/dev/null | grep -v 'export_pdf.sh'; echo "0 3 * * * /home/pi/Speedtest/export_pdf.sh") | sort | uniq | crontab -
        log_info "PDF export cron job added (Puppeteer)"
    elif [ -f "export_pdf_wkhtmltopdf.sh" ]; then
        (crontab -l 2>/dev/null | grep -v 'export_pdf_wkhtmltopdf.sh'; echo "0 3 * * * /home/pi/Speedtest/export_pdf_wkhtmltopdf.sh") | sort | uniq | crontab -
        log_info "PDF export cron job added (wkhtmltopdf)"
    else
        log_info "Skipping PDF export cron job (no PDF export method available)"
    fi
    
    log_info "Cron jobs configured successfully"
}

# =========================
# Create Alternative PDF Export
# =========================
create_alternative_pdf_export() {
    if ! check_node_version; then
        log_header "Creating Alternative PDF Export"
        
        log_info "Creating wkhtmltopdf-based export script..."
        cat > export_pdf_wkhtmltopdf.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Configurable paths
WKHTMLTOPDF="${WKHTMLTOPDF:-/usr/bin/wkhtmltopdf}"
URL="${SPEEDTEST_URL:-http://localhost/speedtest/}"
EXPORT_DIR="${EXPORT_DIR:-/var/www/html/speedtest/exports}"
LOG_FILE="${LOG_FILE:-/var/log/export_pdf.log}"
today=$(date +%Y-%m-%d)
PDF_PATH="$EXPORT_DIR/speedtest_${today}.pdf"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Ensure export directory exists
mkdir -p "$EXPORT_DIR"

# Check if wkhtmltopdf exists
if [ ! -x "$WKHTMLTOPDF" ]; then
    log "ERROR: wkhtmltopdf not found at $WKHTMLTOPDF"
    echo "wkhtmltopdf not found. See log for details."
    exit 1
fi

# Export PDF
log "Exporting PDF to $PDF_PATH"
if "$WKHTMLTOPDF" \
    --page-size A4 \
    --orientation Landscape \
    --margin-top 10mm \
    --margin-right 10mm \
    --margin-bottom 10mm \
    --margin-left 10mm \
    --enable-local-file-access \
    "$URL" \
    "$PDF_PATH"; then
    log "PDF export completed successfully"
else
    log "ERROR: PDF export failed"
    echo "PDF export failed. See log for details."
    exit 1
fi
EOF
        
        chmod +x export_pdf_wkhtmltopdf.sh
        log_info "Alternative PDF export script created: export_pdf_wkhtmltopdf.sh"
        
        # Update cron job to use alternative script
        log_info "Updating cron job to use alternative PDF export..."
        (crontab -l 2>/dev/null | grep -v "export_pdf.sh"; echo "0 3 * * * /home/pi/Speedtest/export_pdf_wkhtmltopdf.sh") | crontab -
    fi
}

# =========================
# Test Installation
# =========================
test_installation() {
    log_header "Testing Installation"
    
    log_info "Testing Ookla Speedtest CLI..."
    if command -v speedtest >/dev/null 2>&1; then
        log_info "Ookla Speedtest CLI is available"
        if timeout 30 speedtest --accept-license --accept-gdpr -f csv >/dev/null 2>&1; then
            log_success "Ookla Speedtest CLI test passed"
        else
            log_warning "Ookla Speedtest CLI test timed out or failed (this may be normal if no internet)"
        fi
    else
        log_error "Ookla Speedtest CLI not found"
        return 1
    fi
    
    log_info "Testing web server..."
    if curl -s http://localhost/speedtest/ >/dev/null 2>&1; then
        log_info "Web server is accessible"
    else
        log_info "Web server not yet accessible (normal for first run)"
    fi
    
    log_info "Testing cron service..."
    if systemctl is-active --quiet cron; then
        log_info "Cron service is running"
    else
        log_error "Cron service is not running"
        return 1
    fi
}

# =========================
# Setup Scripts
# =========================
setup_scripts() {
    log_header "Setting up Scripts"
    
    log_info "Setting up speedtest_to_web.sh..."
    
    # Ensure speedtest_to_web.sh is executable
    if [ -f "speedtest_to_web.sh" ]; then
        chmod +x speedtest_to_web.sh
        log_success "speedtest_to_web.sh is executable"
        
        # Verify the script has the correct Ookla CLI path
        if grep -q 'SPEEDTEST_BIN="/usr/local/bin/speedtest"' speedtest_to_web.sh; then
            log_success "speedtest_to_web.sh has correct Ookla CLI path"
        else
            log_warning "speedtest_to_web.sh may need manual update for Ookla CLI path"
        fi
    else
        log_warning "speedtest_to_web.sh not found in current directory"
    fi
    
    # Ensure other scripts are executable
    for script in archive_csv.sh export_pdf.sh export_pdf_wkhtmltopdf.sh; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            log_success "$script is executable"
        fi
    done
    
    log_info "Scripts setup complete"
}

# =========================
# Run Enhanced Monitoring and API Setup
# =========================
run_enhanced_monitoring_and_api() {
    log_header "Running Enhanced Monitoring and API Setup"
    
    # Run enhanced-monitoring.sh
    if [ -f "enhanced-monitoring.sh" ]; then
        log_info "Running enhanced-monitoring.sh..."
        chmod +x enhanced-monitoring.sh
        ./enhanced-monitoring.sh || { log_error "enhanced-monitoring.sh failed"; exit 1; }
        log_success "enhanced-monitoring.sh completed successfully."
    else
        log_warning "enhanced-monitoring.sh not found. Skipping."
    fi
    
    # Run api-setup.sh
    if [ -f "api-setup.sh" ]; then
        log_info "Running api-setup.sh..."
        chmod +x api-setup.sh
        ./api-setup.sh || { log_error "api-setup.sh failed"; exit 1; }
        log_success "api-setup.sh completed successfully."
    else
        log_warning "api-setup.sh not found. Skipping."
    fi
}

# =========================
# Main Setup Process
# =========================
main() {
    log_header "Raspberry Pi Speedtest Setup"
    
    log_info "Starting setup process..."
    
    # Check if running as pi user
    if [ "$(whoami)" != "pi" ]; then
        log_error "This script must be run as the 'pi' user"
        exit 1
    fi
    
    # Check Node.js version and update if needed
    if ! check_node_version; then
        log_info "Node.js version is incompatible. Attempting to update..."
        update_nodejs
        
        # Check again after update
        if ! check_node_version; then
            log_error "Node.js update failed or version is still incompatible"
            log_info "Will proceed with wkhtmltopdf alternative"
        else
            log_info "Node.js updated successfully and is now compatible"
        fi
    fi
    
    # Install dependencies
    install_dependencies
    
    # Setup scripts
    setup_scripts
    
    # Setup web server
    setup_web_server
    
    # Create alternative PDF export if needed
    create_alternative_pdf_export
    
    # Setup cron jobs
    setup_cron_jobs
    
    # Test installation
    test_installation
    
    # Run enhanced monitoring and API setup
    run_enhanced_monitoring_and_api
    
    log_header "Setup Complete"
    log_info "Speedtest monitoring system is ready!"
    
    # Determine web server URL
    if systemctl is-active --quiet apache2; then
        if sudo netstat -tlnp 2>/dev/null | grep -q ":8080 "; then
            log_info "Web dashboard: http://$(hostname -I | awk '{print $1}'):8080/speedtest/"
        else
            log_info "Web dashboard: http://$(hostname -I | awk '{print $1}')/speedtest/"
        fi
    else
        log_warning "Web server is not running"
    fi
    
    log_info "Log files: /var/log/speedtest_*.log"
    log_info "Cron log: /home/pi/Speedtest/cron.log"
    
    # Show PDF export status
    if [ -d "node_modules/puppeteer" ]; then
        log_info "PDF export: Enabled (Puppeteer)"
    elif [ -f "export_pdf_wkhtmltopdf.sh" ]; then
        log_info "PDF export: Enabled (wkhtmltopdf)"
    else
        log_warning "PDF export: Not available"
    fi
}

# Run main function
main "$@" 