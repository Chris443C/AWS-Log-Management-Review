#!/bin/bash
# CloudTrail Setup Script
# Generated on 2025-06-18T20:41:04.175569
# PCI DSS Requirement: 10.2.1-10.2.7

set -e

echo "Setting up CloudTrail for PCI DSS compliance..."

# Variables
TRAIL_NAME="pci-compliance-trail"
S3_BUCKET="pci-logs-bucket"
CLOUDWATCH_LOG_GROUP="/aws/cloudtrail/pci-compliance"

# Create S3 bucket if it doesn't exist
if ! aws s3 ls "s3://$S3_BUCKET" 2>&1 > /dev/null; then
    echo "Creating S3 bucket: $S3_BUCKET"
    aws s3 mb "s3://$S3_BUCKET" --region us-east-1
    
    # Enable versioning
    aws s3api put-bucket-versioning --bucket "$S3_BUCKET" --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption --bucket "$S3_BUCKET" --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'
    
    # Set bucket policy for CloudTrail
    aws s3api put-bucket-policy --bucket "$S3_BUCKET" --policy '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AWSCloudTrailAclCheck",
                "Effect": "Allow",
                "Principal": {
                    "Service": "cloudtrail.amazonaws.com"
                },
                "Action": "s3:GetBucketAcl",
                "Resource": "arn:aws:s3:::'$S3_BUCKET'"
            },
            {
                "Sid": "AWSCloudTrailWrite",
                "Effect": "Allow",
                "Principal": {
                    "Service": "cloudtrail.amazonaws.com"
                },
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::'$S3_BUCKET'/AWSLogs/*",
                "Condition": {
                    "StringEquals": {
                        "s3:x-amz-acl": "bucket-owner-full-control"
                    }
                }
            }
        ]
    }'
fi

# Create CloudWatch Log Group if it doesn't exist
if ! aws logs describe-log-groups --log-group-name-prefix "$CLOUDWATCH_LOG_GROUP" --query 'logGroups[?logGroupName==`'$CLOUDWATCH_LOG_GROUP'`]' --output text | grep -q "$CLOUDWATCH_LOG_GROUP"; then
    echo "Creating CloudWatch Log Group: $CLOUDWATCH_LOG_GROUP"
    aws logs create-log-group --log-group-name "$CLOUDWATCH_LOG_GROUP"
    aws logs put-retention-policy --log-group-name "$CLOUDWATCH_LOG_GROUP" --retention-in-days 365
fi

# Create CloudTrail
echo "Creating CloudTrail: $TRAIL_NAME"
aws cloudtrail create-trail \
    --name "$TRAIL_NAME" \
    --s3-bucket-name "$S3_BUCKET" \
    --is-multi-region-trail \
    --enable-log-file-validation \
    --cloud-watch-logs-log-group-arn "arn:aws:logs:us-east-1:123456789012:log-group:$CLOUDWATCH_LOG_GROUP:*" \
    --cloud-watch-logs-role-arn "arn:aws:iam::123456789012:role/CloudTrail-CloudWatchLogs-Role"

# Start logging
aws cloudtrail start-logging --name "$TRAIL_NAME"

echo "CloudTrail setup complete!"
echo "Trail Name: $TRAIL_NAME"
echo "S3 Bucket: $S3_BUCKET"
echo "CloudWatch Log Group: $CLOUDWATCH_LOG_GROUP"