#!/usr/bin/env python3
"""
Remediation Script Generator
Generates executable scripts to apply AWS log management recommendations.
"""

import json
import yaml
import os
import click
from datetime import datetime
from typing import Dict, List, Any
from jinja2 import Template

class RemediationScriptGenerator:
    def __init__(self, config_file: str = "config/pci_dss_config.yaml"):
        """Initialize the script generator with PCI DSS configuration."""
        self.config = self._load_config(config_file)
        self.templates = self._load_templates()
        
    def _load_config(self, config_file: str) -> Dict[str, Any]:
        """Load PCI DSS configuration."""
        try:
            with open(config_file, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            print(f"Warning: Configuration file {config_file} not found. Using defaults.")
            return {}
    
    def _load_templates(self) -> Dict[str, str]:
        """Load script templates."""
        return {
            'cloudtrail_setup': '''#!/bin/bash
# CloudTrail Setup Script
# Generated on {{ timestamp }}
# PCI DSS Requirement: {{ pci_reference }}

set -e

echo "Setting up CloudTrail for PCI DSS compliance..."

# Variables
TRAIL_NAME="{{ trail_name }}"
S3_BUCKET="{{ s3_bucket }}"
CLOUDWATCH_LOG_GROUP="{{ cloudwatch_log_group }}"

# Create S3 bucket if it doesn't exist
if ! aws s3 ls "s3://$S3_BUCKET" 2>&1 > /dev/null; then
    echo "Creating S3 bucket: $S3_BUCKET"
    aws s3 mb "s3://$S3_BUCKET" --region {{ region }}
    
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
aws cloudtrail create-trail \\
    --name "$TRAIL_NAME" \\
    --s3-bucket-name "$S3_BUCKET" \\
    --is-multi-region-trail \\
    --enable-log-file-validation \\
    --cloud-watch-logs-log-group-arn "arn:aws:logs:{{ region }}:{{ account_id }}:log-group:$CLOUDWATCH_LOG_GROUP:*" \\
    --cloud-watch-logs-role-arn "arn:aws:iam::{{ account_id }}:role/CloudTrail-CloudWatchLogs-Role"

# Start logging
aws cloudtrail start-logging --name "$TRAIL_NAME"

echo "CloudTrail setup complete!"
echo "Trail Name: $TRAIL_NAME"
echo "S3 Bucket: $S3_BUCKET"
echo "CloudWatch Log Group: $CLOUDWATCH_LOG_GROUP"
''',

            's3_logging_setup': '''#!/bin/bash
# S3 Access Logging Setup Script
# Generated on {{ timestamp }}
# PCI DSS Requirement: {{ pci_reference }}

set -e

echo "Setting up S3 access logging for PCI DSS compliance..."

# Variables
LOG_BUCKET="{{ log_bucket }}"
LOG_PREFIX="{{ log_prefix }}"

# Create log bucket if it doesn't exist
if ! aws s3 ls "s3://$LOG_BUCKET" 2>&1 > /dev/null; then
    echo "Creating log bucket: $LOG_BUCKET"
    aws s3 mb "s3://$LOG_BUCKET" --region {{ region }}
    
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
{% for bucket in buckets %}
echo "Enabling access logging for bucket: {{ bucket }}"
aws s3api put-bucket-logging \\
    --bucket "{{ bucket }}" \\
    --bucket-logging-status '{
        "LoggingEnabled": {
            "TargetBucket": "'$LOG_BUCKET'",
            "TargetPrefix": "'$LOG_PREFIX'/{{ bucket }}/"
        }
    }'
{% endfor %}

echo "S3 access logging setup complete!"
echo "Log bucket: $LOG_BUCKET"
echo "Log prefix: $LOG_PREFIX"
''',

            'cloudwatch_retention_setup': '''#!/bin/bash
# CloudWatch Logs Retention Setup Script
# Generated on {{ timestamp }}
# PCI DSS Requirement: {{ pci_reference }}

set -e

echo "Setting up CloudWatch Logs retention policies for PCI DSS compliance..."

# Set retention policies for log groups
{% for log_group in log_groups %}
echo "Setting retention policy for: {{ log_group }}"
aws logs put-retention-policy \\
    --log-group-name "{{ log_group }}" \\
    --retention-in-days {{ retention_days }}
{% endfor %}

echo "CloudWatch Logs retention policies set successfully!"
''',

            'rds_logging_setup': '''#!/bin/bash
# RDS CloudWatch Logging Setup Script
# Generated on {{ timestamp }}
# PCI DSS Requirement: {{ pci_reference }}

set -e

echo "Setting up RDS CloudWatch logging for PCI DSS compliance..."

# Enable CloudWatch logging for RDS instances
{% for instance in instances %}
echo "Enabling CloudWatch logging for RDS instance: {{ instance }}"
aws rds modify-db-instance \\
    --db-instance-identifier "{{ instance }}" \\
    --enable-cloudwatch-logs-exports "error,general,slow-query" \\
    --apply-immediately
{% endfor %}

echo "RDS CloudWatch logging setup complete!"
''',

            'iam_monitoring_setup': '''#!/bin/bash
# IAM Monitoring Setup Script
# Generated on {{ timestamp }}
# PCI DSS Requirement: {{ pci_reference }}

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
                "region": "{{ region }}",
                "title": "IAM Access Metrics"
            }
        }
    ]
}'

aws cloudwatch put-dashboard \\
    --dashboard-name "$DASHBOARD_NAME" \\
    --dashboard-body "$DASHBOARD_BODY"

echo "IAM monitoring setup complete!"
echo "Dashboard created: $DASHBOARD_NAME"
''',

            'monitoring_alerts_setup': '''#!/bin/bash
# Monitoring and Alerting Setup Script
# Generated on {{ timestamp }}
# PCI DSS Requirement: {{ pci_reference }}

set -e

echo "Setting up monitoring and alerting for PCI DSS compliance..."

# Create SNS topic for alerts
TOPIC_NAME="PCI-Compliance-Alerts"
TOPIC_ARN=$(aws sns create-topic --name "$TOPIC_NAME" --query 'TopicArn' --output text)

echo "Created SNS topic: $TOPIC_ARN"

# Create CloudWatch alarms
{% for alert in alerts %}
echo "Creating alarm: {{ alert.name }}"
aws cloudwatch put-metric-alarm \\
    --alarm-name "{{ alert.name }}" \\
    --alarm-description "{{ alert.description }}" \\
    --metric-name "{{ alert.metric_name }}" \\
    --namespace "{{ alert.namespace }}" \\
    --statistic "{{ alert.statistic }}" \\
    --period {{ alert.period }} \\
    --threshold {{ alert.threshold }} \\
    --comparison-operator "{{ alert.comparison_operator }}" \\
    --evaluation-periods {{ alert.evaluation_periods }} \\
    --alarm-actions "$TOPIC_ARN" \\
    --region {{ region }}
{% endfor %}

echo "Monitoring and alerting setup complete!"
echo "SNS Topic: $TOPIC_ARN"
''',

            'cost_optimization_setup': '''#!/bin/bash
# Cost Optimization Setup Script
# Generated on {{ timestamp }}

set -e

echo "Setting up cost optimization for log management..."

# Create CloudWatch budget for log costs
BUDGET_NAME="Log-Management-Budget"
BUDGET_CONFIG='{
    "BudgetName": "'$BUDGET_NAME'",
    "BudgetLimit": {
        "Amount": "{{ budget_amount }}",
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
                    "Address": "{{ alert_email }}",
                    "SubscriptionType": "EMAIL"
                }
            ]
        }
    ]
}'

aws budgets create-budget \\
    --account-id {{ account_id }} \\
    --budget "$BUDGET_CONFIG"

echo "Cost optimization setup complete!"
echo "Budget created: $BUDGET_NAME"
'''
        }
    
    def generate_cloudtrail_script(self, findings: Dict[str, Any], output_dir: str = "scripts") -> str:
        """Generate CloudTrail setup script."""
        template = Template(self.templates['cloudtrail_setup'])
        
        script_content = template.render(
            timestamp=datetime.now().isoformat(),
            pci_reference="10.2.1-10.2.7",
            trail_name="pci-compliance-trail",
            s3_bucket="pci-logs-bucket",
            cloudwatch_log_group="/aws/cloudtrail/pci-compliance",
            region=self.region,
            account_id=self.account_id
        )
        
        script_path = os.path.join(output_dir, "setup_cloudtrail.sh")
        os.makedirs(output_dir, exist_ok=True)
        
        with open(script_path, 'w') as f:
            f.write(script_content)
        
        os.chmod(script_path, 0o755)
        return script_path
    
    def generate_s3_logging_script(self, buckets: List[str], output_dir: str = "scripts") -> str:
        """Generate S3 logging setup script."""
        template = Template(self.templates['s3_logging_setup'])
        
        script_content = template.render(
            timestamp=datetime.now().isoformat(),
            pci_reference="10.2.1",
            log_bucket="pci-s3-logs-bucket",
            log_prefix="s3-access-logs",
            region=self.region,
            buckets=buckets
        )
        
        script_path = os.path.join(output_dir, "setup_s3_logging.sh")
        os.makedirs(output_dir, exist_ok=True)
        
        with open(script_path, 'w') as f:
            f.write(script_content)
        
        os.chmod(script_path, 0o755)
        return script_path
    
    def generate_cloudwatch_retention_script(self, log_groups: List[str], output_dir: str = "scripts") -> str:
        """Generate CloudWatch retention script."""
        template = Template(self.templates['cloudwatch_retention_setup'])
        
        script_content = template.render(
            timestamp=datetime.now().isoformat(),
            pci_reference="10.5.1.2",
            log_groups=log_groups,
            retention_days=365
        )
        
        script_path = os.path.join(output_dir, "setup_cloudwatch_retention.sh")
        os.makedirs(output_dir, exist_ok=True)
        
        with open(script_path, 'w') as f:
            f.write(script_content)
        
        os.chmod(script_path, 0o755)
        return script_path
    
    def generate_rds_logging_script(self, instances: List[str], output_dir: str = "scripts") -> str:
        """Generate RDS logging script."""
        template = Template(self.templates['rds_logging_setup'])
        
        script_content = template.render(
            timestamp=datetime.now().isoformat(),
            pci_reference="10.2.1",
            instances=instances
        )
        
        script_path = os.path.join(output_dir, "setup_rds_logging.sh")
        os.makedirs(output_dir, exist_ok=True)
        
        with open(script_path, 'w') as f:
            f.write(script_content)
        
        os.chmod(script_path, 0o755)
        return script_path
    
    def generate_iam_monitoring_script(self, output_dir: str = "scripts") -> str:
        """Generate IAM monitoring script."""
        template = Template(self.templates['iam_monitoring_setup'])
        
        script_content = template.render(
            timestamp=datetime.now().isoformat(),
            pci_reference="10.2.1",
            region=self.region
        )
        
        script_path = os.path.join(output_dir, "setup_iam_monitoring.sh")
        os.makedirs(output_dir, exist_ok=True)
        
        with open(script_path, 'w') as f:
            f.write(script_content)
        
        os.chmod(script_path, 0o755)
        return script_path
    
    def generate_monitoring_alerts_script(self, output_dir: str = "scripts") -> str:
        """Generate monitoring alerts script."""
        template = Template(self.templates['monitoring_alerts_setup'])
        
        alerts = [
            {
                'name': 'CloudTrail-Delivery-Failure',
                'description': 'CloudTrail log delivery failure',
                'metric_name': 'DeliveryErrors',
                'namespace': 'AWS/CloudTrail',
                'statistic': 'Sum',
                'period': 300,
                'threshold': 1,
                'comparison_operator': 'GreaterThanThreshold',
                'evaluation_periods': 1
            },
            {
                'name': 'S3-Access-Denied',
                'description': 'S3 access denied attempts',
                'metric_name': '4xxError',
                'namespace': 'AWS/S3',
                'statistic': 'Sum',
                'period': 300,
                'threshold': 10,
                'comparison_operator': 'GreaterThanThreshold',
                'evaluation_periods': 2
            }
        ]
        
        script_content = template.render(
            timestamp=datetime.now().isoformat(),
            pci_reference="10.4.1",
            region=self.region,
            alerts=alerts
        )
        
        script_path = os.path.join(output_dir, "setup_monitoring_alerts.sh")
        os.makedirs(output_dir, exist_ok=True)
        
        with open(script_path, 'w') as f:
            f.write(script_content)
        
        os.chmod(script_path, 0o755)
        return script_path
    
    def generate_cost_optimization_script(self, output_dir: str = "scripts") -> str:
        """Generate cost optimization script."""
        template = Template(self.templates['cost_optimization_setup'])
        
        script_content = template.render(
            timestamp=datetime.now().isoformat(),
            budget_amount="100",
            alert_email="admin@example.com",
            account_id="123456789012"
        )
        
        script_path = os.path.join(output_dir, "setup_cost_optimization.sh")
        os.makedirs(output_dir, exist_ok=True)
        
        with open(script_path, 'w') as f:
            f.write(script_content)
        
        os.chmod(script_path, 0o755)
        return script_path
    
    def generate_master_script(self, findings: Dict[str, Any], output_dir: str = "scripts") -> str:
        """Generate a master script that runs all remediation scripts."""
        master_script = f'''#!/bin/bash
# Master Remediation Script
# Generated on {datetime.now().isoformat()}
# PCI DSS Log Management Compliance

set -e

echo "Starting PCI DSS Log Management Remediation..."
echo "=============================================="

# Check AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Create scripts directory if it doesn't exist
mkdir -p {output_dir}

# Run remediation scripts based on findings
'''

        # Add script execution based on findings
        if not findings.get('cloudtrail', {}).get('enabled', False):
            master_script += '''
echo "Setting up CloudTrail..."
./setup_cloudtrail.sh
'''
        
        if findings.get('s3_logging', {}).get('buckets_without_logging'):
            master_script += '''
echo "Setting up S3 access logging..."
./setup_s3_logging.sh
'''
        
        if findings.get('cloudwatch_logs', {}).get('log_groups_without_retention'):
            master_script += '''
echo "Setting up CloudWatch retention policies..."
./setup_cloudwatch_retention.sh
'''
        
        if findings.get('rds_logging', {}).get('instances_without_logging'):
            master_script += '''
echo "Setting up RDS CloudWatch logging..."
./setup_rds_logging.sh
'''
        
        master_script += '''
echo "Setting up IAM monitoring..."
./setup_iam_monitoring.sh

echo "Setting up monitoring and alerting..."
./setup_monitoring_alerts.sh

echo "Setting up cost optimization..."
./setup_cost_optimization.sh

echo "=============================================="
echo "PCI DSS Log Management Remediation Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Review the generated configurations"
echo "2. Test the logging and monitoring setup"
echo "3. Update the scripts with your specific values (bucket names, etc.)"
echo "4. Run the scripts in your AWS environment"
echo "5. Document the implementation for compliance"
'''

        script_path = os.path.join(output_dir, "run_all_remediation.sh")
        os.makedirs(output_dir, exist_ok=True)
        
        with open(script_path, 'w') as f:
            f.write(master_script)
        
        os.chmod(script_path, 0o755)
        return script_path
    
    def generate_all_scripts(self, findings: Dict[str, Any], output_dir: str = "scripts") -> List[str]:
        """Generate all remediation scripts based on findings."""
        generated_scripts = []
        
        # Generate individual scripts
        if not findings.get('cloudtrail', {}).get('enabled', False):
            script_path = self.generate_cloudtrail_script(findings, output_dir)
            generated_scripts.append(script_path)
        
        if findings.get('s3_logging', {}).get('buckets_without_logging'):
            script_path = self.generate_s3_logging_script(
                findings['s3_logging']['buckets_without_logging'], 
                output_dir
            )
            generated_scripts.append(script_path)
        
        if findings.get('cloudwatch_logs', {}).get('log_groups_without_retention'):
            script_path = self.generate_cloudwatch_retention_script(
                findings['cloudwatch_logs']['log_groups_without_retention'],
                output_dir
            )
            generated_scripts.append(script_path)
        
        if findings.get('rds_logging', {}).get('instances_without_logging'):
            script_path = self.generate_rds_logging_script(
                findings['rds_logging']['instances_without_logging'],
                output_dir
            )
            generated_scripts.append(script_path)
        
        # Always generate these scripts as they're generally needed
        script_path = self.generate_iam_monitoring_script(output_dir)
        generated_scripts.append(script_path)
        
        script_path = self.generate_monitoring_alerts_script(output_dir)
        generated_scripts.append(script_path)
        
        script_path = self.generate_cost_optimization_script(output_dir)
        generated_scripts.append(script_path)
        
        # Generate master script
        script_path = self.generate_master_script(findings, output_dir)
        generated_scripts.append(script_path)
        
        return generated_scripts

@click.command()
@click.option('--findings-file', required=True, help='JSON file containing analysis findings')
@click.option('--output-dir', default='scripts', help='Directory to output generated scripts')
def main(findings_file: str, output_dir: str):
    """Generate remediation scripts based on analysis findings."""
    
    try:
        # Load findings
        with open(findings_file, 'r') as f:
            findings = json.load(f)
        
        # Generate scripts
        generator = RemediationScriptGenerator()
        generated_scripts = generator.generate_all_scripts(findings, output_dir)
        
        print(f"Generated {len(generated_scripts)} remediation scripts:")
        for script in generated_scripts:
            print(f"  - {script}")
        
        print(f"\nTo apply all remediations, run: ./{output_dir}/run_all_remediation.sh")
        
    except Exception as e:
        print(f"Error: {str(e)}")
        exit(1)

if __name__ == '__main__':
    main() 