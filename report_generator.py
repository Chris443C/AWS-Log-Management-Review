#!/usr/bin/env python3
"""
Report Generator for AWS Log Management Review
Generates professional HTML reports with findings and recommendations.
"""

import json
import yaml
import click
from datetime import datetime
from typing import Dict, List, Any
from jinja2 import Template
import os

class ReportGenerator:
    def __init__(self, template_file: str = "templates/report_template.html"):
        """Initialize the report generator with HTML template."""
        self.template_file = template_file
        self.template = self._load_template()
        
    def _load_template(self) -> Template:
        """Load the HTML report template."""
        try:
            with open(self.template_file, 'r') as f:
                return Template(f.read())
        except FileNotFoundError:
            raise FileNotFoundError(f"Template file {self.template_file} not found")
    
    def calculate_compliance_score(self, findings: Dict[str, Any]) -> int:
        """Calculate overall compliance score based on findings."""
        total_issues = findings.get('total_issues', 0)
        
        # Define weights for different severity levels
        severity_weights = {
            'HIGH': 3,
            'MEDIUM': 2,
            'LOW': 1
        }
        
        # Calculate weighted score
        weighted_issues = 0
        for category, category_findings in findings.items():
            if category not in ['timestamp', 'total_issues']:
                for issue in category_findings.get('issues', []):
                    severity = issue.get('severity', 'MEDIUM')
                    weighted_issues += severity_weights.get(severity, 1)
        
        # Calculate score (100 - weighted issues, minimum 0)
        max_possible_issues = 50  # Arbitrary baseline
        score = max(0, 100 - (weighted_issues / max_possible_issues) * 100)
        
        return int(score)
    
    def estimate_monthly_cost(self, findings: Dict[str, Any]) -> str:
        """Estimate monthly cost for log management."""
        base_cost = 50  # Base cost for CloudTrail and basic logging
        
        # Add costs based on findings
        if not findings.get('cloudtrail', {}).get('enabled', False):
            base_cost += 5  # CloudTrail cost
        
        s3_buckets = findings.get('s3_logging', {}).get('buckets_analyzed', 0)
        base_cost += s3_buckets * 2  # S3 access logs cost
        
        cloudwatch_logs = findings.get('cloudwatch_logs', {}).get('log_groups', 0)
        base_cost += cloudwatch_logs * 1  # CloudWatch Logs cost
        
        rds_instances = findings.get('rds_logging', {}).get('instances', 0)
        base_cost += rds_instances * 3  # RDS CloudWatch logging cost
        
        return f"${base_cost:.0f}"
    
    def get_pci_requirements(self) -> Dict[str, str]:
        """Get PCI DSS requirements mapping."""
        return {
            '10.2.1': 'All individual access to cardholder data',
            '10.2.2': 'All actions taken by any individual with root or administrative privileges',
            '10.2.3': 'Access to all audit trails',
            '10.2.4': 'Invalid logical access attempts',
            '10.2.5': 'Use of identification and authentication mechanisms',
            '10.2.6': 'Initialization of the audit logs',
            '10.2.7': 'Creation and deletion of system-level objects',
            '10.5.1.2': 'Retain audit trail history for at least one year',
            '10.5.2': 'Protect audit trail files from unauthorized modifications',
            '10.5.3': 'Promptly back up audit trail files to a centralized log server'
        }
    
    def get_non_compliant_requirements(self, findings: Dict[str, Any]) -> List[str]:
        """Get list of non-compliant PCI requirements."""
        non_compliant = []
        
        # Check each requirement based on findings
        all_issues = []
        for category, category_findings in findings.items():
            if category not in ['timestamp', 'total_issues']:
                for issue in category_findings.get('issues', []):
                    all_issues.append(issue)
        
        # Map issues to PCI requirements
        for issue in all_issues:
            pci_ref = issue.get('pci_reference', '')
            if pci_ref and pci_ref not in non_compliant:
                non_compliant.append(pci_ref)
        
        return non_compliant
    
    def generate_html_report(self, findings: Dict[str, Any], recommendations: List[Dict[str, Any]], 
                           output_file: str = "aws_log_review_report.html", 
                           generate_scripts: bool = False) -> str:
        """Generate HTML report from findings and recommendations."""
        
        # Calculate metrics
        compliance_score = self.calculate_compliance_score(findings)
        estimated_cost = self.estimate_monthly_cost(findings)
        total_recommendations = len(recommendations)
        total_issues = findings.get('total_issues', 0)
        
        # Get PCI requirements
        pci_requirements = self.get_pci_requirements()
        non_compliant_requirements = self.get_non_compliant_requirements(findings)
        
        # Prepare all issues for template
        all_issues = []
        for category, category_findings in findings.items():
            if category not in ['timestamp', 'total_issues']:
                for issue in category_findings.get('issues', []):
                    all_issues.append({
                        'category': category.upper().replace('_', ' '),
                        'severity': issue.get('severity', 'MEDIUM'),
                        'description': issue.get('description', ''),
                        'pci_reference': issue.get('pci_reference', '')
                    })
        
        # Prepare generated scripts info
        generated_scripts = []
        if generate_scripts:
            script_files = [
                {'name': 'setup_cloudtrail.sh', 'description': 'Configure CloudTrail with multi-region logging'},
                {'name': 'setup_s3_logging.sh', 'description': 'Enable S3 access logging for all buckets'},
                {'name': 'setup_cloudwatch_retention.sh', 'description': 'Set retention policies for CloudWatch Logs'},
                {'name': 'setup_rds_logging.sh', 'description': 'Enable RDS CloudWatch logging'},
                {'name': 'setup_iam_monitoring.sh', 'description': 'Configure IAM monitoring and credential reports'},
                {'name': 'setup_monitoring_alerts.sh', 'description': 'Set up CloudWatch alarms and SNS notifications'},
                {'name': 'setup_cost_optimization.sh', 'description': 'Configure cost optimization and budgets'},
                {'name': 'run_all_remediation.sh', 'description': 'Master script to run all remediations'}
            ]
            generated_scripts = script_files
        
        # Render template
        html_content = self.template.render(
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            total_issues=total_issues,
            total_recommendations=total_recommendations,
            compliance_score=compliance_score,
            estimated_cost=estimated_cost,
            cloudtrail=findings.get('cloudtrail', {}),
            s3_logging=findings.get('s3_logging', {}),
            cloudwatch_logs=findings.get('cloudwatch_logs', {}),
            rds_logging=findings.get('rds_logging', {}),
            all_issues=all_issues,
            recommendations=recommendations,
            pci_requirements=pci_requirements,
            non_compliant_requirements=non_compliant_requirements,
            generate_scripts=generate_scripts,
            generated_scripts=generated_scripts
        )
        
        # Write to file
        with open(output_file, 'w') as f:
            f.write(html_content)
        
        return output_file
    
    def generate_json_report(self, findings: Dict[str, Any], recommendations: List[Dict[str, Any]], 
                           output_file: str = "aws_log_review_report.json") -> str:
        """Generate JSON report from findings and recommendations."""
        
        report_data = {
            'metadata': {
                'generated_at': datetime.now().isoformat(),
                'tool_version': '1.0.0',
                'pci_dss_version': 'v4.0.1'
            },
            'summary': {
                'total_issues': findings.get('total_issues', 0),
                'total_recommendations': len(recommendations),
                'compliance_score': self.calculate_compliance_score(findings),
                'estimated_monthly_cost': self.estimate_monthly_cost(findings)
            },
            'findings': findings,
            'recommendations': recommendations,
            'pci_compliance': {
                'requirements': self.get_pci_requirements(),
                'non_compliant_requirements': self.get_non_compliant_requirements(findings)
            }
        }
        
        with open(output_file, 'w') as f:
            json.dump(report_data, f, indent=2, default=str)
        
        return output_file
    
    def generate_yaml_report(self, findings: Dict[str, Any], recommendations: List[Dict[str, Any]], 
                           output_file: str = "aws_log_review_report.yaml") -> str:
        """Generate YAML report from findings and recommendations."""
        
        report_data = {
            'metadata': {
                'generated_at': datetime.now().isoformat(),
                'tool_version': '1.0.0',
                'pci_dss_version': 'v4.0.1'
            },
            'summary': {
                'total_issues': findings.get('total_issues', 0),
                'total_recommendations': len(recommendations),
                'compliance_score': self.calculate_compliance_score(findings),
                'estimated_monthly_cost': self.estimate_monthly_cost(findings)
            },
            'findings': findings,
            'recommendations': recommendations,
            'pci_compliance': {
                'requirements': self.get_pci_requirements(),
                'non_compliant_requirements': self.get_non_compliant_requirements(findings)
            }
        }
        
        with open(output_file, 'w') as f:
            yaml.dump(report_data, f, default_flow_style=False, default_style='')
        
        return output_file

@click.command()
@click.option('--findings-file', required=True, help='JSON file containing analysis findings')
@click.option('--recommendations-file', required=True, help='JSON file containing recommendations')
@click.option('--output-format', default='html', type=click.Choice(['html', 'json', 'yaml', 'all']), 
              help='Output format for the report')
@click.option('--output-dir', default='reports', help='Directory to output generated reports')
@click.option('--generate-scripts', is_flag=True, help='Include script generation information in report')
def main(findings_file: str, recommendations_file: str, output_format: str, output_dir: str, generate_scripts: bool):
    """Generate reports from analysis findings and recommendations."""
    
    try:
        # Load findings and recommendations
        with open(findings_file, 'r') as f:
            findings = json.load(f)
        
        with open(recommendations_file, 'r') as f:
            recommendations = json.load(f)
        
        # Create output directory
        os.makedirs(output_dir, exist_ok=True)
        
        # Generate reports
        generator = ReportGenerator()
        generated_files = []
        
        if output_format in ['html', 'all']:
            html_file = os.path.join(output_dir, "aws_log_review_report.html")
            generated_file = generator.generate_html_report(
                findings, recommendations, html_file, generate_scripts
            )
            generated_files.append(generated_file)
            print(f"HTML report generated: {generated_file}")
        
        if output_format in ['json', 'all']:
            json_file = os.path.join(output_dir, "aws_log_review_report.json")
            generated_file = generator.generate_json_report(
                findings, recommendations, json_file
            )
            generated_files.append(generated_file)
            print(f"JSON report generated: {generated_file}")
        
        if output_format in ['yaml', 'all']:
            yaml_file = os.path.join(output_dir, "aws_log_review_report.yaml")
            generated_file = generator.generate_yaml_report(
                findings, recommendations, yaml_file
            )
            generated_files.append(generated_file)
            print(f"YAML report generated: {generated_file}")
        
        print(f"\nGenerated {len(generated_files)} report(s) in {output_dir}/")
        
        if output_format == 'html' or output_format == 'all':
            print(f"\nTo view the HTML report, open: {os.path.join(output_dir, 'aws_log_review_report.html')}")
        
    except Exception as e:
        print(f"Error: {str(e)}")
        exit(1)

if __name__ == '__main__':
    main() 