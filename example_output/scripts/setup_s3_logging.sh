#!/bin/bash
# S3 Access Logging Setup Script
# Generated on 2025-06-18T20:41:04.183602
# PCI DSS Requirement: 10.2.1

set -e

echo "Setting up S3 access logging for PCI DSS compliance..."

# Variables
LOG_BUCKET="pci-s3-logs-bucket"
LOG_PREFIX="s3-access-logs"

# Create log bucket if it doesn't exist
if ! aws s3 ls "s3://$LOG_BUCKET" 2>&1 > /dev/null; then
    echo "Creating log bucket: $LOG_BUCKET"
    aws s3 mb "s3://$LOG_BUCKET" --region us-east-1
    
    # Enable versioning
    aws s3api put-bucket-versioning --bucket "$LOG_BUCKET" --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption --bucket "$LOG_BUCKET" --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'
    
    # Set lifecycle policy for cost optimization
    aws s3api put-bucket-lifecycle-configuration --bucket "$LOG_BUCKET" --lifecycle-configuration '{
        "Rules": [
            {
                "ID": "LogRetention",
                "Status": "Enabled",
                "Filter": {
                    "Prefix": ""
                },
                "Transitions": [
                    {
                        "Days": 30,
                        "StorageClass": "STANDARD_IA"
                    },
                    {
                        "Days": 90,
                        "StorageClass": "GLACIER"
                    }
                ],
                "Expiration": {
                    "Days": 365
                }
            }
        ]
    }'
fi

# Enable access logging for each bucket

echo "Enabling access logging for bucket: bucket1"
aws s3api put-bucket-logging \
    --bucket "bucket1" \
    --bucket-logging-status '{
        "LoggingEnabled": {
            "TargetBucket": "'$LOG_BUCKET'",
            "TargetPrefix": "'$LOG_PREFIX'/bucket1/"
        }
    }'

echo "Enabling access logging for bucket: bucket2"
aws s3api put-bucket-logging \
    --bucket "bucket2" \
    --bucket-logging-status '{
        "LoggingEnabled": {
            "TargetBucket": "'$LOG_BUCKET'",
            "TargetPrefix": "'$LOG_PREFIX'/bucket2/"
        }
    }'

echo "Enabling access logging for bucket: bucket3"
aws s3api put-bucket-logging \
    --bucket "bucket3" \
    --bucket-logging-status '{
        "LoggingEnabled": {
            "TargetBucket": "'$LOG_BUCKET'",
            "TargetPrefix": "'$LOG_PREFIX'/bucket3/"
        }
    }'


echo "S3 access logging setup complete!"
echo "Log bucket: $LOG_BUCKET"
echo "Log prefix: $LOG_PREFIX"