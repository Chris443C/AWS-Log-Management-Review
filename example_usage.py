#!/usr/bin/env python3
"""
Example Usage of AWS Log Management Review Tool
This script demonstrates how to use the tool with sample data.
"""

import json
import os
from datetime import datetime

def create_sample_findings():
    """Create sample findings for demonstration purposes."""
    return {
        "cloudtrail": {
            "enabled": False,
            "multi_region": False,
            "log_file_validation": False,
            "s3_bucket": None,
            "issues": [
                {
                    "severity": "HIGH",
                    "description": "No CloudTrail trails found",
                    "pci_reference": "10.2.1-10.2.7",
                    "recommendation": "Enable CloudTrail for API activity logging"
                }
            ]
        },
        "s3_logging": {
            "buckets_analyzed": 5,
            "buckets_with_logging": 2,
            "buckets_without_logging": ["bucket1", "bucket2", "bucket3"],
            "issues": [
                {
                    "severity": "MEDIUM",
                    "description": "S3 bucket bucket1 does not have access logging enabled",
                    "pci_reference": "10.2.1",
                    "recommendation": "Enable access logging for bucket bucket1"
                },
                {
                    "severity": "MEDIUM",
                    "description": "S3 bucket bucket2 does not have access logging enabled",
                    "pci_reference": "10.2.1",
                    "recommendation": "Enable access logging for bucket bucket2"
                },
                {
                    "severity": "MEDIUM",
                    "description": "S3 bucket bucket3 does not have access logging enabled",
                    "pci_reference": "10.2.1",
                    "recommendation": "Enable access logging for bucket bucket3"
                }
            ]
        },
        "cloudwatch_logs": {
            "log_groups": 8,
            "log_groups_with_retention": 3,
            "log_groups_without_retention": ["/aws/lambda/app1", "/aws/lambda/app2", "/aws/rds/instance1", "/aws/rds/instance2", "/aws/ec2/security"],
            "issues": [
                {
                    "severity": "MEDIUM",
                    "description": "CloudWatch Log Group /aws/lambda/app1 has no retention policy",
                    "pci_reference": "10.5.1.2",
                    "recommendation": "Set retention policy for log group /aws/lambda/app1"
                },
                {
                    "severity": "MEDIUM",
                    "description": "CloudWatch Log Group /aws/lambda/app2 has no retention policy",
                    "pci_reference": "10.5.1.2",
                    "recommendation": "Set retention policy for log group /aws/lambda/app2"
                },
                {
                    "severity": "MEDIUM",
                    "description": "CloudWatch Log Group /aws/rds/instance1 has no retention policy",
                    "pci_reference": "10.5.1.2",
                    "recommendation": "Set retention policy for log group /aws/rds/instance1"
                },
                {
                    "severity": "MEDIUM",
                    "description": "CloudWatch Log Group /aws/rds/instance2 has no retention policy",
                    "pci_reference": "10.5.1.2",
                    "recommendation": "Set retention policy for log group /aws/rds/instance2"
                },
                {
                    "severity": "MEDIUM",
                    "description": "CloudWatch Log Group /aws/ec2/security has no retention policy",
                    "pci_reference": "10.5.1.2",
                    "recommendation": "Set retention policy for log group /aws/ec2/security"
                }
            ]
        },
        "rds_logging": {
            "instances": 3,
            "instances_with_logging": 1,
            "instances_without_logging": ["db-instance-1", "db-instance-2"],
            "issues": [
                {
                    "severity": "MEDIUM",
                    "description": "RDS instance db-instance-1 does not have CloudWatch logging enabled",
                    "pci_reference": "10.2.1",
                    "recommendation": "Enable CloudWatch logging for RDS instance db-instance-1"
                },
                {
                    "severity": "MEDIUM",
                    "description": "RDS instance db-instance-2 does not have CloudWatch logging enabled",
                    "pci_reference": "10.2.1",
                    "recommendation": "Enable CloudWatch logging for RDS instance db-instance-2"
                }
            ]
        },
        "iam_logging": {
            "credential_reports_enabled": False,
            "access_analyzer_enabled": False,
            "issues": [
                {
                    "severity": "MEDIUM",
                    "description": "IAM credential reports not enabled",
                    "pci_reference": "10.2.1",
                    "recommendation": "Enable IAM credential reports for access monitoring"
                },
                {
                    "severity": "MEDIUM",
                    "description": "IAM Access Analyzer not enabled",
                    "pci_reference": "10.2.1",
                    "recommendation": "Enable IAM Access Analyzer for policy analysis"
                }
            ]
        },
        "timestamp": datetime.now().isoformat(),
        "total_issues": 12
    }

def create_sample_recommendations():
    """Create sample recommendations based on findings."""
    return [
        {
            "priority": "HIGH",
            "category": "CloudTrail",
            "title": "Enable CloudTrail",
            "description": "Enable CloudTrail for comprehensive API activity logging",
            "pci_reference": "10.2.1-10.2.7",
            "script": "setup_cloudtrail.sh",
            "estimated_cost": "Low (CloudTrail is free for first 5GB/month)"
        },
        {
            "priority": "MEDIUM",
            "category": "S3",
            "title": "Enable S3 Access Logging",
            "description": "Enable access logging for 3 S3 buckets",
            "pci_reference": "10.2.1",
            "script": "setup_s3_logging.sh",
            "estimated_cost": "Low (S3 access logs are inexpensive)"
        },
        {
            "priority": "MEDIUM",
            "category": "CloudWatch",
            "title": "Set Log Retention Policies",
            "description": "Set retention policies for 5 log groups",
            "pci_reference": "10.5.1.2",
            "script": "setup_cloudwatch_retention.sh",
            "estimated_cost": "Low (reduces storage costs)"
        },
        {
            "priority": "MEDIUM",
            "category": "RDS",
            "title": "Enable RDS CloudWatch Logging",
            "description": "Enable CloudWatch logging for 2 RDS instances",
            "pci_reference": "10.2.1",
            "script": "setup_rds_logging.sh",
            "estimated_cost": "Low"
        },
        {
            "priority": "MEDIUM",
            "category": "IAM",
            "title": "Enable IAM Monitoring",
            "description": "Configure IAM credential reports and access analyzer",
            "pci_reference": "10.2.1",
            "script": "setup_iam_monitoring.sh",
            "estimated_cost": "Free"
        },
        {
            "priority": "LOW",
            "category": "Monitoring",
            "title": "Set Up Monitoring Alerts",
            "description": "Configure CloudWatch alarms for security events",
            "pci_reference": "10.4.1",
            "script": "setup_monitoring_alerts.sh",
            "estimated_cost": "Low"
        },
        {
            "priority": "LOW",
            "category": "Cost",
            "title": "Implement Cost Optimization",
            "description": "Set up budgets and cost monitoring for log management",
            "pci_reference": "N/A",
            "script": "setup_cost_optimization.sh",
            "estimated_cost": "Free"
        }
    ]

def run_example():
    """Run the complete example workflow."""
    print("🚀 AWS Log Management Review - Example Usage")
    print("=" * 60)
    
    # Create output directory
    output_dir = "example_output"
    os.makedirs(output_dir, exist_ok=True)
    
    # Create sample data
    print("📝 Creating sample findings and recommendations...")
    findings = create_sample_findings()
    recommendations = create_sample_recommendations()
    
    # Save sample data
    findings_file = os.path.join(output_dir, "findings.json")
    recommendations_file = os.path.join(output_dir, "recommendations.json")
    
    with open(findings_file, 'w') as f:
        json.dump(findings, f, indent=2, default=str)
    
    with open(recommendations_file, 'w') as f:
        json.dump(recommendations, f, indent=2, default=str)
    
    print(f"✅ Sample data saved to:")
    print(f"   - {findings_file}")
    print(f"   - {recommendations_file}")
    
    # Generate reports
    print("\n📊 Generating reports...")
    try:
        from report_generator import ReportGenerator
        
        generator = ReportGenerator()
        
        # Generate HTML report
        html_file = os.path.join(output_dir, "reports", "example_report.html")
        os.makedirs(os.path.dirname(html_file), exist_ok=True)
        generator.generate_html_report(findings, recommendations, html_file, generate_scripts=True)
        print(f"✅ HTML report generated: {html_file}")
        
        # Generate JSON report
        json_file = os.path.join(output_dir, "reports", "example_report.json")
        generator.generate_json_report(findings, recommendations, json_file)
        print(f"✅ JSON report generated: {json_file}")
        
        # Generate YAML report
        yaml_file = os.path.join(output_dir, "reports", "example_report.yaml")
        generator.generate_yaml_report(findings, recommendations, yaml_file)
        print(f"✅ YAML report generated: {yaml_file}")
        
    except ImportError:
        print("⚠️  Report generator not available. Skipping report generation.")
    
    # Generate scripts
    print("\n🛠️  Generating remediation scripts...")
    try:
        from scripts.generate_remediation_scripts import RemediationScriptGenerator
        
        generator = RemediationScriptGenerator()
        scripts_dir = os.path.join(output_dir, "scripts")
        generated_scripts = generator.generate_all_scripts(findings, scripts_dir)
        
        print(f"✅ Generated {len(generated_scripts)} scripts:")
        for script in generated_scripts:
            print(f"   - {script}")
            
    except ImportError:
        print("⚠️  Script generator not available. Skipping script generation.")
    
    # Display summary
    print(f"\n{'='*60}")
    print("📋 EXAMPLE COMPLETE - SUMMARY")
    print(f"{'='*60}")
    
    print(f"Sample findings created with {findings['total_issues']} issues")
    print(f"Sample recommendations created: {len(recommendations)}")
    
    print(f"\nFiles generated in {output_dir}/:")
    for root, dirs, files in os.walk(output_dir):
        for file in files:
            file_path = os.path.join(root, file)
            print(f"   - {file_path}")
    
    print(f"\n{'='*60}")
    print("🎯 NEXT STEPS")
    print(f"{'='*60}")
    print("1. Review the generated reports to understand the format")
    print("2. Examine the sample findings and recommendations")
    print("3. Test the remediation scripts in a safe environment")
    print("4. Customize the configuration for your AWS environment")
    print("5. Run the actual analysis against your AWS account")
    
    print(f"\n{'='*60}")
    print("✅ Example completed successfully!")
    print(f"{'='*60}")

if __name__ == '__main__':
    run_example() 