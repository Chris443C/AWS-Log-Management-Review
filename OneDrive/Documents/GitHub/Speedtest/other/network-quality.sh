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
