# AWS Log Management Review Tool

A comprehensive tool for reviewing and managing AWS logs in alignment with PCI DSS v4.0.1 requirements, with a focus on cost optimization and automated remediation.

## Overview

This tool provides a complete solution for:
- **Analyzing** AWS logging configurations for PCI DSS compliance
- **Generating** detailed reports with findings and recommendations
- **Creating** automated remediation scripts
- **Optimizing** log management costs while maintaining compliance

## Features

### 🔍 **Comprehensive Analysis**
- CloudTrail configuration and compliance
- S3 access logging setup
- CloudWatch Logs retention policies
- RDS CloudWatch logging
- IAM monitoring and credential reports

### 📊 **Professional Reporting**
- HTML reports with executive summaries
- JSON/YAML export options
- PCI DSS compliance scoring
- Cost estimation and optimization recommendations

### 🛠️ **Automated Remediation**
- Bash scripts for each recommendation
- Master script to run all remediations
- Configurable templates for different environments

### 💰 **Cost Optimization**
- Storage tier recommendations
- Retention policy optimization
- Log filtering strategies
- Budget monitoring setup

## Quick Start

### 1. Installation

```bash
# Clone the repository
git clone <repository-url>
cd AWS-Log-Management-Review

# Install dependencies
pip install -r requirements.txt

# Configure AWS credentials
aws configure
```

### 2. Run Analysis

```bash
# Run the main analysis
python aws_log_review.py --profile default --region us-east-1

# Generate JSON output
python aws_log_review.py --output json

# Generate YAML output
python aws_log_review.py --output yaml
```

### 3. Generate Reports

```bash
# Generate HTML report
python report_generator.py \
    --findings-file findings.json \
    --recommendations-file recommendations.json \
    --output-format html \
    --generate-scripts

# Generate all report formats
python report_generator.py \
    --findings-file findings.json \
    --recommendations-file recommendations.json \
    --output-format all
```

### 4. Generate Remediation Scripts

```bash
# Generate remediation scripts
python scripts/generate_remediation_scripts.py \
    --findings-file findings.json \
    --output-dir scripts
```

## Usage Examples

### Basic Analysis
```bash
# Run analysis with default settings
python aws_log_review.py
```

### Profile-Specific Analysis
```bash
# Use specific AWS profile
python aws_log_review.py --profile production --region us-west-2
```

### Generate Comprehensive Report
```bash
# Generate HTML report with script information
python report_generator.py \
    --findings-file findings.json \
    --recommendations-file recommendations.json \
    --output-format html \
    --generate-scripts \
    --output-dir reports
```

### Apply Remediations
```bash
# Run all remediation scripts
./scripts/run_all_remediation.sh

# Or run individual scripts
./scripts/setup_cloudtrail.sh
./scripts/setup_s3_logging.sh
```

## Configuration

### PCI DSS Configuration
The tool uses `config/pci_dss_config.yaml` for PCI DSS requirements and best practices. You can customize:

- Logging event requirements
- Retention policies
- Cost optimization strategies
- Monitoring and alerting thresholds

### AWS Permissions
The tool requires the following AWS permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudtrail:*",
                "s3:GetBucketLogging",
                "s3:PutBucketLogging",
                "logs:*",
                "rds:DescribeDBInstances",
                "rds:ModifyDBInstance",
                "iam:GenerateCredentialReport",
                "iam:ListAccessAnalyzers",
                "cloudwatch:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## Output Files

### Analysis Output
- `findings.json` - Detailed analysis findings
- `recommendations.json` - Generated recommendations

### Reports
- `reports/aws_log_review_report.html` - Professional HTML report
- `reports/aws_log_review_report.json` - JSON format report
- `reports/aws_log_review_report.yaml` - YAML format report

### Remediation Scripts
- `scripts/setup_cloudtrail.sh` - CloudTrail configuration
- `scripts/setup_s3_logging.sh` - S3 access logging
- `scripts/setup_cloudwatch_retention.sh` - CloudWatch retention policies
- `scripts/setup_rds_logging.sh` - RDS CloudWatch logging
- `scripts/setup_iam_monitoring.sh` - IAM monitoring
- `scripts/setup_monitoring_alerts.sh` - CloudWatch alarms
- `scripts/setup_cost_optimization.sh` - Cost optimization
- `scripts/run_all_remediation.sh` - Master remediation script

## PCI DSS Compliance

The tool addresses PCI DSS v4.0.1 Requirement 10 (Logging and Monitoring):

### 10.2 Logging Events
- ✅ All individual access to cardholder data
- ✅ All actions taken by any individual with root or administrative privileges
- ✅ Access to all audit trails
- ✅ Invalid logical access attempts
- ✅ Use of identification and authentication mechanisms
- ✅ Initialization of the audit logs
- ✅ Creation and deletion of system-level objects

### 10.5 Audit Trail Protection
- ✅ Retain audit trail history for at least one year
- ✅ Protect audit trail files from unauthorized modifications
- ✅ Promptly back up audit trail files to a centralized log server

## Cost Optimization

The tool provides several strategies to minimize log management costs:

### Storage Optimization
- S3 lifecycle policies for automatic tiering
- CloudWatch Logs retention policies
- Log filtering to reduce storage

### Monitoring Optimization
- CloudTrail Insights for cost reduction
- Centralized logging to reduce duplication
- Automated cleanup of old logs

### Budget Management
- CloudWatch budgets for log costs
- Cost alerts and notifications
- Regular cost reviews

## Troubleshooting

### Common Issues

1. **AWS Credentials Not Found**
   ```bash
   # Configure AWS credentials
   aws configure
   ```

2. **Permission Denied Errors**
   - Ensure your AWS user/role has the required permissions
   - Check the IAM policy requirements above

3. **Template File Not Found**
   ```bash
   # Ensure all files are in the correct locations
   ls -la templates/report_template.html
   ls -la config/pci_dss_config.yaml
   ```

4. **Script Execution Errors**
   ```bash
   # Make scripts executable
   chmod +x scripts/*.sh
   ```

### Debug Mode
```bash
# Run with debug output
python aws_log_review.py --debug
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions or support:
- Check the troubleshooting section above
- Review the PCI DSS configuration file
- Ensure AWS permissions are correctly configured
- Test in a non-production environment first

## Security Notes

- Always test remediation scripts in a non-production environment
- Review generated scripts before execution
- Ensure proper IAM permissions are in place
- Monitor costs after implementing changes
- Regularly review and update configurations

## Version History

- **v1.0.0** - Initial release with basic analysis and reporting
- **v1.1.0** - Added cost optimization features
- **v1.2.0** - Enhanced PCI DSS compliance mapping
- **v1.3.0** - Added automated remediation scripts 