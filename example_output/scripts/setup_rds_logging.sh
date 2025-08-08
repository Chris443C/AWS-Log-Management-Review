#!/bin/bash
# RDS CloudWatch Logging Setup Script
# Generated on 2025-06-18T20:41:04.187221
# PCI DSS Requirement: 10.2.1

set -e

echo "Setting up RDS CloudWatch logging for PCI DSS compliance..."

# Enable CloudWatch logging for RDS instances

echo "Enabling CloudWatch logging for RDS instance: db-instance-1"
aws rds modify-db-instance \
    --db-instance-identifier "db-instance-1" \
    --enable-cloudwatch-logs-exports "error,general,slow-query" \
    --apply-immediately

echo "Enabling CloudWatch logging for RDS instance: db-instance-2"
aws rds modify-db-instance \
    --db-instance-identifier "db-instance-2" \
    --enable-cloudwatch-logs-exports "error,general,slow-query" \
    --apply-immediately


echo "RDS CloudWatch logging setup complete!"