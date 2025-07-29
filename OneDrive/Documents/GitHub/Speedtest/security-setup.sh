#!/bin/bash
set -euo pipefail

# Security setup for Speedtest monitoring system
LOG_FILE="${LOG_FILE:-/var/log/speedtest-security.log}"

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

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
    log "WARNING: $1"
}

print_header() {
    echo -e "\033[0;34m================================\033[0m"
    echo -e "\033[0;34m$1\033[0m"
    echo -e "\033[0;34m================================\033[0m"
    log "HEADER: $1"
}

# Setup UFW Firewall
setup_firewall() {
    print_header "Setting up UFW Firewall"
    
    print_status "Installing UFW..."
    sudo apt install -y ufw
    
    print_status "Setting default policies..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    print_status "Allowing SSH..."
    sudo ufw allow ssh
    
    print_status "Allowing HTTP/HTTPS..."
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    print_status "Enabling UFW..."
    sudo ufw --force enable
    
    print_status "Firewall status:"
    sudo ufw status
}

# Setup SSL Certificate (Let's Encrypt)
setup_ssl() {
    print_header "Setting up SSL Certificate"
    
    print_status "Installing Certbot..."
    sudo apt install -y certbot python3-certbot-apache
    
    print_status "Please enter your domain name (or press Enter to skip SSL):"
    read -r domain_name
    
    if [ -n "$domain_name" ]; then
        print_status "Obtaining SSL certificate for $domain_name..."
        sudo certbot --apache -d "$domain_name" --non-interactive --agree-tos --email admin@$domain_name
        
        print_status "Setting up automatic renewal..."
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
    else
        print_warning "SSL setup skipped. Using HTTP only."
    fi
}

# Security Headers and Apache Hardening
harden_apache() {
    print_header "Hardening Apache Configuration"
    
    print_status "Creating security headers configuration..."
    sudo tee /etc/apache2/conf-available/security-headers.conf > /dev/null <<EOF
# Security Headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"

# Content Security Policy
Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' cdn.jsdelivr.net; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self';"

# Remove server signature
ServerTokens Prod
ServerSignature Off
EOF
    
    print_status "Enabling security headers..."
    sudo a2enconf security-headers
    
    print_status "Restarting Apache..."
    sudo systemctl restart apache2
}

# Fail2ban Setup
setup_fail2ban() {
    print_header "Setting up Fail2ban"
    
    print_status "Installing Fail2ban..."
    sudo apt install -y fail2ban
    
    print_status "Creating Fail2ban configuration..."
    sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[apache]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache2/error.log
maxretry = 3
EOF
    
    print_status "Starting Fail2ban..."
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    
    print_status "Fail2ban status:"
    sudo fail2ban-client status
}

# Log Rotation
setup_log_rotation() {
    print_header "Setting up Log Rotation"
    
    print_status "Creating logrotate configuration..."
    sudo tee /etc/logrotate.d/speedtest > /dev/null <<EOF
/var/log/speedtest*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 pi pi
    postrotate
        systemctl reload apache2 > /dev/null 2>&1 || true
    endscript
}
EOF
}

# System Monitoring
setup_monitoring() {
    print_header "Setting up System Monitoring"
    
    print_status "Installing monitoring tools..."
    sudo apt install -y htop iotop nethogs
    
    print_status "Creating disk space monitoring script..."
    sudo tee /usr/local/bin/check-disk-space.sh > /dev/null <<'EOF'
#!/bin/bash
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "WARNING: Disk usage is ${DISK_USAGE}%" | logger -t speedtest-monitor
fi
EOF
    
    sudo chmod +x /usr/local/bin/check-disk-space.sh
    
    print_status "Adding disk space check to cron..."
    (crontab -l 2>/dev/null; echo "0 */6 * * * /usr/local/bin/check-disk-space.sh") | crontab -
}

# Backup Setup
setup_backup() {
    print_header "Setting up Backup System"
    
    print_status "Creating backup script..."
    sudo tee /usr/local/bin/backup-speedtest.sh > /dev/null <<'EOF'
#!/bin/bash
BACKUP_DIR="/home/pi/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

# Backup CSV data
cp /var/www/html/speedtest/results.csv "$BACKUP_DIR/results_$DATE.csv"

# Backup configuration
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" \
    /home/pi/Speedtest/*.sh \
    /home/pi/Speedtest/*.js \
    /home/pi/Speedtest/package.json \
    /etc/apache2/sites-available/speedtest.conf

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "*.csv" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE" | logger -t speedtest-backup
EOF
    
    sudo chmod +x /usr/local/bin/backup-speedtest.sh
    
    print_status "Adding daily backup to cron..."
    (crontab -l 2>/dev/null; echo "0 1 * * * /usr/local/bin/backup-speedtest.sh") | crontab -
}

# Main execution
main() {
    print_header "Speedtest Security Setup"
    
    setup_firewall
    setup_ssl
    harden_apache
    setup_fail2ban
    setup_log_rotation
    setup_monitoring
    setup_backup
    
    print_header "Security Setup Complete!"
    echo "Your Speedtest monitoring system is now secured with:"
    echo "• UFW firewall with SSH and web access"
    echo "• SSL certificate (if domain provided)"
    echo "• Apache security headers"
    echo "• Fail2ban intrusion prevention"
    echo "• Log rotation and monitoring"
    echo "• Automated backups"
}

main "$@" 