# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive AWS log management review tool designed for PCI DSS v4.0.1 compliance analysis. The tool analyzes AWS logging configurations, generates detailed reports, and creates automated remediation scripts while optimizing for cost efficiency.

## Core Architecture

### Main Components

**Analysis Engine** (`aws_log_review.py`)
- Main analysis module that examines AWS services for PCI DSS compliance
- Uses boto3 clients for: EC2, S3, CloudTrail, CloudWatch, IAM, RDS, ELBv2, WAF
- Generates findings and recommendations in JSON/YAML format
- Uses Rich library for formatted console output and progress tracking

**Report Generator** (`report_generator.py`)
- Creates professional HTML, JSON, and YAML reports
- Uses Jinja2 templating with `templates/report_template.html`
- Calculates compliance scores based on issue severity weighting
- Generates executive summaries and detailed findings

**Complete Workflow** (`run_complete_analysis.py`)
- Orchestrates the entire analysis pipeline
- Handles dependency checking, AWS credential validation
- Manages directory creation and file organization
- Coordinates analysis → report generation → script creation workflow

**Script Generator** (`scripts/generate_remediation_scripts.py`)
- Creates executable bash scripts for automated remediation
- Uses PCI DSS configuration from `config/pci_dss_config.yaml`
- Generates service-specific scripts (CloudTrail, S3, CloudWatch, etc.)

### Configuration System

**PCI DSS Configuration** (`config/pci_dss_config.yaml`)
- Defines PCI DSS v4.0.1 requirements mapping to AWS services
- Specifies retention requirements, protection requirements, and cost optimization strategies
- Contains compliance checklists and monitoring thresholds
- Used by all modules for consistent compliance checking

## Key Development Commands

### Installation and Setup
```bash
# Install dependencies
pip install -r requirements.txt

# Configure AWS credentials
aws configure
```

### Running Analysis
```bash
# Basic analysis with default settings
python aws_log_review.py

# Profile-specific analysis
python aws_log_review.py --profile production --region us-west-2

# Generate JSON/YAML output
python aws_log_review.py --output json
python aws_log_review.py --output yaml
```

### Report Generation
```bash
# Generate HTML report with scripts
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

### Complete Workflow
```bash
# Run full analysis pipeline
python run_complete_analysis.py --profile default --region us-east-1 --generate-scripts

# Skip analysis and use existing findings
python run_complete_analysis.py --skip-analysis --generate-scripts
```

### Script Generation and Execution
```bash
# Generate remediation scripts
python scripts/generate_remediation_scripts.py \
    --findings-file findings.json \
    --output-dir scripts

# Execute all remediation scripts
./example_output/scripts/run_all_remediation.sh

# Execute individual scripts
./example_output/scripts/setup_cloudtrail.sh
```

## Development Patterns

### Error Handling
- All modules implement comprehensive error handling for AWS API calls
- Use try/except blocks with specific exception handling for boto3 clients
- Console output uses Rich library for formatted error messages

### Configuration Management
- PCI DSS requirements are centralized in `config/pci_dss_config.yaml`
- All modules load this configuration for consistent compliance checking
- Service configurations are defined with severity levels and AWS service mappings

### Output Management
- Findings and recommendations are stored as separate JSON files
- Reports are generated in multiple formats (HTML, JSON, YAML)
- Scripts are organized by AWS service with a master execution script

### AWS Integration
- Uses boto3 session management for profile/region flexibility
- Implements credential validation and dependency checking
- Service clients are initialized once per analysis session

## Required AWS Permissions

The tool requires comprehensive AWS permissions for analysis:
- CloudTrail: full access for configuration analysis
- S3: GetBucketLogging, PutBucketLogging for access logging
- CloudWatch: full access for logs and metrics
- RDS: DescribeDBInstances, ModifyDBInstance for logging configuration
- IAM: GenerateCredentialReport, ListAccessAnalyzers for monitoring
- EC2, ELBv2, WAF: read permissions for security analysis

## Output Structure

### Generated Files
- `findings.json` - Detailed analysis findings by AWS service
- `recommendations.json` - Prioritized remediation recommendations
- `reports/aws_log_review_report.html` - Professional HTML report
- `scripts/setup_*.sh` - Service-specific remediation scripts
- `scripts/run_all_remediation.sh` - Master script for all remediations

### PCI DSS Compliance Focus
The tool specifically addresses PCI DSS v4.0.1 Requirement 10 (Logging and Monitoring):
- Event logging requirements (10.2.1-10.2.7)
- Retention requirements (10.5.1.2)
- Protection requirements (10.5.2-10.5.3)
- Review and monitoring requirements (10.4.1)