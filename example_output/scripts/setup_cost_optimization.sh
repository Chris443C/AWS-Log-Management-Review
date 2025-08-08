#!/bin/bash
# Cost Optimization Setup Script
# Generated on 2025-06-18T20:41:04.193562

set -e

echo "Setting up cost optimization for log management..."

# Create CloudWatch budget for log costs
BUDGET_NAME="Log-Management-Budget"
BUDGET_CONFIG='{
    "BudgetName": "'$BUDGET_NAME'",
    "BudgetLimit": {
        "Amount": "100",
        "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST",
    "CostFilters": {
        "Service": ["Amazon S3", "Amazon CloudWatch", "AWS CloudTrail"]
    },
    "NotificationsWithSubscribers": [
        {
            "Notification": {
                "ComparisonOperator": "GREATER_THAN",
                "NotificationType": "ACTUAL",
                "Threshold": 80,
                "ThresholdType": "PERCENTAGE"
            },
            "Subscribers": [
                {
                    "Address": "admin@example.com",
                    "SubscriptionType": "EMAIL"
                }
            ]
        }
    ]
}'

aws budgets create-budget \
    --account-id 123456789012 \
    --budget "$BUDGET_CONFIG"

echo "Cost optimization setup complete!"
echo "Budget created: $BUDGET_NAME"