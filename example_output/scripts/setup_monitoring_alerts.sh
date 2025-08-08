#!/bin/bash
# Monitoring and Alerting Setup Script
# Generated on 2025-06-18T20:41:04.192136
# PCI DSS Requirement: 10.4.1

set -e

echo "Setting up monitoring and alerting for PCI DSS compliance..."

# Create SNS topic for alerts
TOPIC_NAME="PCI-Compliance-Alerts"
TOPIC_ARN=$(aws sns create-topic --name "$TOPIC_NAME" --query 'TopicArn' --output text)

echo "Created SNS topic: $TOPIC_ARN"

# Create CloudWatch alarms

echo "Creating alarm: CloudTrail-Delivery-Failure"
aws cloudwatch put-metric-alarm \
    --alarm-name "CloudTrail-Delivery-Failure" \
    --alarm-description "CloudTrail log delivery failure" \
    --metric-name "DeliveryErrors" \
    --namespace "AWS/CloudTrail" \
    --statistic "Sum" \
    --period 300 \
    --threshold 1 \
    --comparison-operator "GreaterThanThreshold" \
    --evaluation-periods 1 \
    --alarm-actions "$TOPIC_ARN" \
    --region us-east-1

echo "Creating alarm: S3-Access-Denied"
aws cloudwatch put-metric-alarm \
    --alarm-name "S3-Access-Denied" \
    --alarm-description "S3 access denied attempts" \
    --metric-name "4xxError" \
    --namespace "AWS/S3" \
    --statistic "Sum" \
    --period 300 \
    --threshold 10 \
    --comparison-operator "GreaterThanThreshold" \
    --evaluation-periods 2 \
    --alarm-actions "$TOPIC_ARN" \
    --region us-east-1


echo "Monitoring and alerting setup complete!"
echo "SNS Topic: $TOPIC_ARN"