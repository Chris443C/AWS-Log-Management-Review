#!/bin/bash
# IAM Monitoring Setup Script
# Generated on 2025-06-18T20:41:04.189173
# PCI DSS Requirement: 10.2.1

set -e

echo "Setting up IAM monitoring for PCI DSS compliance..."

# Enable credential reports
echo "Enabling IAM credential reports..."
aws iam generate-credential-report

# Create CloudWatch dashboard for IAM monitoring
DASHBOARD_NAME="IAM-Monitoring-Dashboard"
DASHBOARD_BODY='{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    ["AWS/IAM", "AccessDenied", "Service", "IAM"],
                    [".", "AccessKeyUsage", ".", "."],
                    [".", "CredentialUsage", ".", "."]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "us-east-1",
                "title": "IAM Access Metrics"
            }
        }
    ]
}'

aws cloudwatch put-dashboard \
    --dashboard-name "$DASHBOARD_NAME" \
    --dashboard-body "$DASHBOARD_BODY"

echo "IAM monitoring setup complete!"
echo "Dashboard created: $DASHBOARD_NAME"