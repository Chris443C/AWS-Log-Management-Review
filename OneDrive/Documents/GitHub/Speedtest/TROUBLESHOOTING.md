# Troubleshooting Guide

## Node.js Compatibility Issues

### Problem: Node.js Version Too Old
**Error Message:**
```
npm WARN notsup Unsupported engine for puppeteer@21.11.0: wanted: {"node":">=16.13.2"} (current: {"node":"10.24.1","npm":"6.14.12"})
```

**Solution:**
The Raspberry Pi is running Node.js 10.24.1, which is too old for modern Puppeteer versions. We have several solutions:

#### Option 1: Update Node.js (Recommended)
```bash
# Run the Node.js update script
./install-node-deps.sh
```

This script will:
- Detect your current Node.js version
- Update to Node.js 18.x if needed
- Install compatible Puppeteer version
- Fall back to wkhtmltopdf if Puppeteer fails

#### Option 2: Manual Node.js Update
```bash
# Add NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

# Install Node.js 18.x
sudo apt-get install -y nodejs

# Verify installation
node --version
npm --version
```

#### Option 3: Use wkhtmltopdf Alternative (No Node.js Update Required)
If you prefer not to update Node.js, we provide a wkhtmltopdf-based alternative:

```bash
# Install wkhtmltopdf
sudo apt-get install -y wkhtmltopdf

# Use the alternative export script
./export_pdf_wkhtmltopdf.sh
```

### Problem: Puppeteer Installation Fails
**Error Message:**
```
SyntaxError: await is only valid in async function
```

**Solution:**
This indicates Node.js version incompatibility. Use the compatibility script:

```bash
# Run the compatibility installation script
./install-node-deps.sh
```

### Problem: Permission Denied Errors
**Error Message:**
```
npm ERR! code EACCES
npm ERR! syscall access
```

**Solution:**
```bash
# Fix npm permissions
sudo chown -R $USER:$USER ~/.npm
sudo chown -R $USER:$USER ~/.config

# Or use npm with sudo (not recommended but sometimes necessary)
sudo npm install
```

## PDF Export Issues

### Problem: Puppeteer PDF Export Fails
**Solutions:**

1. **Use wkhtmltopdf alternative:**
   ```bash
   ./export_pdf_wkhtmltopdf.sh
   ```

2. **Check Puppeteer installation:**
   ```bash
   node -e "const puppeteer = require('puppeteer'); console.log('Puppeteer version:', puppeteer.version);"
   ```

3. **Reinstall Puppeteer with compatible version:**
   ```bash
   npm uninstall puppeteer
   npm install puppeteer@^19.11.1
   ```

### Problem: wkhtmltopdf PDF Export Fails
**Solutions:**

1. **Check wkhtmltopdf installation:**
   ```bash
   which wkhtmltopdf
   wkhtmltopdf --version
   ```

2. **Install wkhtmltopdf:**
   ```bash
   sudo apt-get update
   sudo apt-get install -y wkhtmltopdf
   ```

3. **Check web server accessibility:**
   ```bash
   curl -I http://localhost/speedtest/
   ```

## Web Server Issues

### Problem: Apache Not Running
**Solution:**
```bash
# Check Apache status
sudo systemctl status apache2

# Start Apache if not running
sudo systemctl start apache2

# Enable Apache to start on boot
sudo systemctl enable apache2
```

### Problem: Permission Denied for Web Directory
**Solution:**
```bash
# Fix web directory permissions
sudo chown -R www-data:www-data /var/www/html/speedtest
sudo chmod -R 755 /var/www/html/speedtest
```

### Problem: Cannot Access Web Dashboard
**Solutions:**

1. **Check if Apache is listening:**
   ```bash
   sudo netstat -tlnp | grep :80
   ```

2. **Check Apache error logs:**
   ```bash
   sudo tail -f /var/log/apache2/error.log
   ```

3. **Test local access:**
   ```bash
   curl http://localhost/speedtest/
   ```

4. **Check firewall settings:**
   ```bash
   sudo ufw status
   # If firewall is active, allow HTTP
   sudo ufw allow 80/tcp
   ```

## Speedtest Issues

### Problem: speedtest-cli Not Found
**Solution:**
```bash
# Install speedtest-cli
sudo apt-get update
sudo apt-get install -y speedtest-cli

# Or install via pip
pip3 install speedtest-cli
```

### Problem: Speedtest Fails
**Solutions:**

1. **Check internet connectivity:**
   ```bash
   ping -c 4 8.8.8.8
   ```

2. **Test speedtest-cli manually:**
   ```bash
   speedtest-cli --simple
   ```

3. **Check for proxy settings:**
   ```bash
   env | grep -i proxy
   ```

## Cron Job Issues

### Problem: Cron Jobs Not Running
**Solutions:**

1. **Check cron service:**
   ```bash
   sudo systemctl status cron
   sudo systemctl start cron
   sudo systemctl enable cron
   ```

2. **Check cron logs:**
   ```bash
   sudo tail -f /var/log/syslog | grep CRON
   ```

3. **Verify cron jobs:**
   ```bash
   crontab -l
   ```

4. **Test cron job manually:**
   ```bash
   /home/pi/Speedtest/speedtest_to_web.sh
   ```

## Log File Issues

### Problem: Cannot Write to Log Files
**Solution:**
```bash
# Create log directory and files
sudo mkdir -p /var/log
sudo touch /var/log/speedtest_to_web.log
sudo touch /var/log/export_pdf.log
sudo touch /var/log/archive_csv.log

# Set proper permissions
sudo chown pi:pi /var/log/speedtest*.log
sudo chmod 644 /var/log/speedtest*.log
```

## Performance Issues

### Problem: System Running Slow
**Solutions:**

1. **Check system resources:**
   ```bash
   top
   free -h
   df -h
   ```

2. **Reduce speedtest frequency:**
   Edit crontab to run less frequently:
   ```bash
   crontab -e
   # Change from */15 to */30 for every 30 minutes
   ```

3. **Optimize Apache configuration:**
   ```bash
   sudo nano /etc/apache2/apache2.conf
   # Reduce MaxKeepAliveRequests and KeepAliveTimeout
   ```

## Network Issues

### Problem: Cannot Connect from External Devices
**Solutions:**

1. **Find Raspberry Pi IP address:**
   ```bash
   hostname -I
   ```

2. **Check if port 80 is accessible:**
   ```bash
   sudo netstat -tlnp | grep :80
   ```

3. **Configure router port forwarding (if needed):**
   - Forward port 80 to Raspberry Pi's IP address

4. **Use dynamic DNS (if needed):**
   - Set up a dynamic DNS service for external access

## Complete Reset

If you need to start fresh:

```bash
# Stop all services
sudo systemctl stop apache2
sudo systemctl stop cron

# Remove cron jobs
crontab -r

# Clean up files
sudo rm -rf /var/www/html/speedtest
sudo rm -f /var/log/speedtest*.log

# Reinstall everything
./setup-pi.sh
```

## Getting Help

If you're still experiencing issues:

1. **Check all log files:**
   ```bash
   tail -f /var/log/speedtest*.log
   tail -f /var/log/apache2/error.log
   ```

2. **Run the diagnostic script:**
   ```bash
   ./install-node-deps.sh
   ```

3. **Check system information:**
   ```bash
   uname -a
   cat /etc/os-release
   node --version
   npm --version
   ```

4. **Document the error:**
   - Copy the exact error message
   - Note the steps that led to the error
   - Include system information 