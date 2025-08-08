#!/bin/bash
# CloudWatch Logs Retention Setup Script
# Generated on 2025-06-18T20:41:04.185443
# PCI DSS Requirement: 10.5.1.2

set -e

echo "Setting up CloudWatch Logs retention policies for PCI DSS compliance..."

# Set retention policies for log groups

echo "Setting retention policy for: /aws/lambda/app1"
aws logs put-retention-policy \
    --log-group-name "/aws/lambda/app1" \
    --retention-in-days 365

echo "Setting retention policy for: /aws/lambda/app2"
aws logs put-retention-policy \
    --log-group-name "/aws/lambda/app2" \
    --retention-in-days 365

echo "Setting retention policy for: /aws/rds/instance1"
aws logs put-retention-policy \
    --log-group-name "/aws/rds/instance1" \
    --retention-in-days 365

echo "Setting retention policy for: /aws/rds/instance2"
aws logs put-retention-policy \
    --log-group-name "/aws/rds/instance2" \
    --retention-in-days 365

echo "Setting retention policy for: /aws/ec2/security"
aws logs put-retention-policy \
    --log-group-name "/aws/ec2/security" \
    --retention-in-days 365


echo "CloudWatch Logs retention policies set successfully!"