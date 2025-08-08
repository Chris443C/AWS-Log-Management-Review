#!/usr/bin/env python3
"""
AWS Log Management Review Tool
Analyzes AWS resources for PCI DSS compliance and generates recommendations.
"""

import boto3
import json
import yaml
import click
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn
import os
import sys

console = Console()

class AWSLogReviewer:
    def __init__(self, profile: str = None, region: str = None):
        """Initialize AWS clients and configuration."""
        self.session = boto3.Session(profile_name=profile, region_name=region)
        self.ec2 = self.session.client('ec2')
        self.s3 = self.session.client('s3')
        self.cloudtrail = self.session.client('cloudtrail')
        self.cloudwatch = self.session.client('cloudwatch')
        self.iam = self.session.client('iam')
        self.rds = self.session.client('rds')
        self.elbv2 = self.session.client('elbv2')
        self.wafv2 = self.session.client('wafv2')
        
        self.findings = []
        self.recommendations = []
        self.scripts = []
        
    def analyze_cloudtrail(self) -> Dict[str, Any]:
        """Analyze CloudTrail configuration and compliance."""
        console.print("[bold blue]Analyzing CloudTrail Configuration...[/bold blue]")
        
        findings = {
            'enabled': False,
            'multi_region': False,
            'log_file_validation': False,
            's3_bucket': None,
            'issues': []
        }
        
        try:
            trails = self.cloudtrail.list_trails()
            
            if not trails.get('Trails'):
                findings['issues'].append({
                    'severity': 'HIGH',
                    'description': 'No CloudTrail trails found',
                    'pci_reference': '10.2.1-10.2.7',
                    'recommendation': 'Enable CloudTrail for API activity logging'
                })
                return findings
            
            for trail in trails['Trails']:
                trail_info = self.cloudtrail.get_trail(Name=trail['Name'])
                trail_status = self.cloudtrail.get_trail_status(Name=trail['Name'])
                
                if trail_status.get('IsLogging'):
                    findings['enabled'] = True
                    findings['s3_bucket'] = trail_info['Trail']['S3BucketName']
                    
                    if trail_info['Trail'].get('IsMultiRegionTrail'):
                        findings['multi_region'] = True
                    
                    if trail_info['Trail'].get('LogFileValidationEnabled'):
                        findings['log_file_validation'] = True
                    else:
                        findings['issues'].append({
                            'severity': 'MEDIUM',
                            'description': f'Log file validation not enabled for trail {trail["Name"]}',
                            'pci_reference': '10.5.2',
                            'recommendation': 'Enable log file validation for integrity checking'
                        })
                else:
                    findings['issues'].append({
                        'severity': 'HIGH',
                        'description': f'CloudTrail {trail["Name"]} is not logging',
                        'pci_reference': '10.2.1-10.2.7',
                        'recommendation': 'Enable logging for CloudTrail'
                    })
                    
        except Exception as e:
            findings['issues'].append({
                'severity': 'HIGH',
                'description': f'Error analyzing CloudTrail: {str(e)}',
                'pci_reference': '10.2.1-10.2.7',
                'recommendation': 'Check CloudTrail permissions and configuration'
            })
            
        return findings
    
    def analyze_s3_logging(self) -> Dict[str, Any]:
        """Analyze S3 bucket logging configuration."""
        console.print("[bold blue]Analyzing S3 Logging Configuration...[/bold blue]")
        
        findings = {
            'buckets_analyzed': 0,
            'buckets_with_logging': 0,
            'buckets_without_logging': [],
            'issues': []
        }
        
        try:
            buckets = self.s3.list_buckets()
            
            for bucket in buckets['Buckets']:
                findings['buckets_analyzed'] += 1
                
                try:
                    logging_status = self.s3.get_bucket_logging(Bucket=bucket['Name'])
                    
                    if 'LoggingEnabled' in logging_status:
                        findings['buckets_with_logging'] += 1
                    else:
                        findings['buckets_without_logging'].append(bucket['Name'])
                        findings['issues'].append({
                            'severity': 'MEDIUM',
                            'description': f'S3 bucket {bucket["Name"]} does not have access logging enabled',
                            'pci_reference': '10.2.1',
                            'recommendation': f'Enable access logging for bucket {bucket["Name"]}'
                        })
                        
                except self.s3.exceptions.NoSuchBucketLoggingConfiguration:
                    findings['buckets_without_logging'].append(bucket['Name'])
                    findings['issues'].append({
                        'severity': 'MEDIUM',
                        'description': f'S3 bucket {bucket["Name"]} does not have access logging enabled',
                        'pci_reference': '10.2.1',
                        'recommendation': f'Enable access logging for bucket {bucket["Name"]}'
                    })
                    
        except Exception as e:
            findings['issues'].append({
                'severity': 'HIGH',
                'description': f'Error analyzing S3 logging: {str(e)}',
                'pci_reference': '10.2.1',
                'recommendation': 'Check S3 permissions and configuration'
            })
            
        return findings
    
    def analyze_cloudwatch_logs(self) -> Dict[str, Any]:
        """Analyze CloudWatch Logs configuration."""
        console.print("[bold blue]Analyzing CloudWatch Logs...[/bold blue]")
        
        findings = {
            'log_groups': 0,
            'log_groups_with_retention': 0,
            'log_groups_without_retention': [],
            'issues': []
        }
        
        try:
            log_groups = self.cloudwatch.describe_log_groups()
            
            for log_group in log_groups['logGroups']:
                findings['log_groups'] += 1
                
                if 'retentionInDays' in log_group:
                    findings['log_groups_with_retention'] += 1
                else:
                    findings['log_groups_without_retention'].append(log_group['logGroupName'])
                    findings['issues'].append({
                        'severity': 'MEDIUM',
                        'description': f'CloudWatch Log Group {log_group["logGroupName"]} has no retention policy',
                        'pci_reference': '10.5.1.2',
                        'recommendation': f'Set retention policy for log group {log_group["logGroupName"]}'
                    })
                    
        except Exception as e:
            findings['issues'].append({
                'severity': 'HIGH',
                'description': f'Error analyzing CloudWatch Logs: {str(e)}',
                'pci_reference': '10.2.1',
                'recommendation': 'Check CloudWatch Logs permissions and configuration'
            })
            
        return findings
    
    def analyze_rds_logging(self) -> Dict[str, Any]:
        """Analyze RDS logging configuration."""
        console.print("[bold blue]Analyzing RDS Logging Configuration...[/bold blue]")
        
        findings = {
            'instances': 0,
            'instances_with_logging': 0,
            'instances_without_logging': [],
            'issues': []
        }
        
        try:
            instances = self.rds.describe_db_instances()
            
            for instance in instances['DBInstances']:
                findings['instances'] += 1
                
                # Check if logging is enabled
                if instance.get('EnableCloudwatchLogsExports'):
                    findings['instances_with_logging'] += 1
                else:
                    findings['instances_without_logging'].append(instance['DBInstanceIdentifier'])
                    findings['issues'].append({
                        'severity': 'MEDIUM',
                        'description': f'RDS instance {instance["DBInstanceIdentifier"]} does not have CloudWatch logging enabled',
                        'pci_reference': '10.2.1',
                        'recommendation': f'Enable CloudWatch logging for RDS instance {instance["DBInstanceIdentifier"]}'
                    })
                    
        except Exception as e:
            findings['issues'].append({
                'severity': 'HIGH',
                'description': f'Error analyzing RDS logging: {str(e)}',
                'pci_reference': '10.2.1',
                'recommendation': 'Check RDS permissions and configuration'
            })
            
        return findings
    
    def analyze_iam_logging(self) -> Dict[str, Any]:
        """Analyze IAM logging and access patterns."""
        console.print("[bold blue]Analyzing IAM Logging...[/bold blue]")
        
        findings = {
            'credential_reports_enabled': False,
            'access_analyzer_enabled': False,
            'issues': []
        }
        
        try:
            # Check credential reports
            try:
                self.iam.generate_credential_report()
                findings['credential_reports_enabled'] = True
            except:
                findings['issues'].append({
                    'severity': 'MEDIUM',
                    'description': 'IAM credential reports not enabled',
                    'pci_reference': '10.2.1',
                    'recommendation': 'Enable IAM credential reports for access monitoring'
                })
            
            # Check access analyzer
            try:
                analyzers = self.iam.list_access_analyzers()
                if analyzers.get('analyzers'):
                    findings['access_analyzer_enabled'] = True
                else:
                    findings['issues'].append({
                        'severity': 'MEDIUM',
                        'description': 'IAM Access Analyzer not enabled',
                        'pci_reference': '10.2.1',
                        'recommendation': 'Enable IAM Access Analyzer for policy analysis'
                    })
            except:
                findings['issues'].append({
                    'severity': 'MEDIUM',
                    'description': 'IAM Access Analyzer not available or enabled',
                    'pci_reference': '10.2.1',
                    'recommendation': 'Enable IAM Access Analyzer for policy analysis'
                })
                
        except Exception as e:
            findings['issues'].append({
                'severity': 'HIGH',
                'description': f'Error analyzing IAM logging: {str(e)}',
                'pci_reference': '10.2.1',
                'recommendation': 'Check IAM permissions and configuration'
            })
            
        return findings
    
    def generate_recommendations(self, findings: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate recommendations based on findings."""
        recommendations = []
        
        # CloudTrail recommendations
        if not findings['cloudtrail']['enabled']:
            recommendations.append({
                'priority': 'HIGH',
                'category': 'CloudTrail',
                'title': 'Enable CloudTrail',
                'description': 'Enable CloudTrail for comprehensive API activity logging',
                'pci_reference': '10.2.1-10.2.7',
                'script': self._generate_cloudtrail_script(),
                'estimated_cost': 'Low (CloudTrail is free for first 5GB/month)'
            })
        
        if not findings['cloudtrail']['multi_region']:
            recommendations.append({
                'priority': 'MEDIUM',
                'category': 'CloudTrail',
                'title': 'Enable Multi-Region CloudTrail',
                'description': 'Enable multi-region CloudTrail for comprehensive coverage',
                'pci_reference': '10.2.1-10.2.7',
                'script': self._generate_multi_region_cloudtrail_script(),
                'estimated_cost': 'Low'
            })
        
        # S3 Logging recommendations
        if findings['s3_logging']['buckets_without_logging']:
            recommendations.append({
                'priority': 'MEDIUM',
                'category': 'S3',
                'title': 'Enable S3 Access Logging',
                'description': f'Enable access logging for {len(findings["s3_logging"]["buckets_without_logging"])} S3 buckets',
                'pci_reference': '10.2.1',
                'script': self._generate_s3_logging_script(findings['s3_logging']['buckets_without_logging']),
                'estimated_cost': 'Low (S3 access logs are inexpensive)'
            })
        
        # CloudWatch Logs recommendations
        if findings['cloudwatch_logs']['log_groups_without_retention']:
            recommendations.append({
                'priority': 'MEDIUM',
                'category': 'CloudWatch',
                'title': 'Set Log Retention Policies',
                'description': f'Set retention policies for {len(findings["cloudwatch_logs"]["log_groups_without_retention"])} log groups',
                'pci_reference': '10.5.1.2',
                'script': self._generate_cloudwatch_retention_script(findings['cloudwatch_logs']['log_groups_without_retention']),
                'estimated_cost': 'Low (reduces storage costs)'
            })
        
        # RDS Logging recommendations
        if findings['rds_logging']['instances_without_logging']:
            recommendations.append({
                'priority': 'MEDIUM',
                'category': 'RDS',
                'title': 'Enable RDS CloudWatch Logging',
                'description': f'Enable CloudWatch logging for {len(findings["rds_logging"]["instances_without_logging"])} RDS instances',
                'pci_reference': '10.2.1',
                'script': self._generate_rds_logging_script(findings['rds_logging']['instances_without_logging']),
                'estimated_cost': 'Low'
            })
        
        return recommendations
    
    def _generate_cloudtrail_script(self) -> str:
        """Generate CloudTrail setup script."""
        return '''#!/bin/bash
# Enable CloudTrail
aws cloudtrail create-trail \\
    --name "pci-compliance-trail" \\
    --s3-bucket-name "your-log-bucket-name" \\
    --is-multi-region-trail \\
    --enable-log-file-validation

aws cloudtrail start-logging --name "pci-compliance-trail"

echo "CloudTrail enabled successfully"'''
    
    def _generate_multi_region_cloudtrail_script(self) -> str:
        """Generate multi-region CloudTrail script."""
        return '''#!/bin/bash
# Enable multi-region CloudTrail
aws cloudtrail update-trail \\
    --name "pci-compliance-trail" \\
    --is-multi-region-trail

echo "Multi-region CloudTrail enabled"'''
    
    def _generate_s3_logging_script(self, buckets: List[str]) -> str:
        """Generate S3 logging script."""
        script = '''#!/bin/bash
# Enable S3 access logging for buckets
'''
        for bucket in buckets:
            script += f'''aws s3api put-bucket-logging \\
    --bucket "{bucket}" \\
    --bucket-logging-status '{{"LoggingEnabled": {{"TargetBucket": "your-log-bucket-name", "TargetPrefix": "{bucket}/"}}}}'

'''
        script += 'echo "S3 access logging enabled for all buckets"'
        return script
    
    def _generate_cloudwatch_retention_script(self, log_groups: List[str]) -> str:
        """Generate CloudWatch retention script."""
        script = '''#!/bin/bash
# Set retention policies for CloudWatch log groups
'''
        for log_group in log_groups:
            script += f'''aws logs put-retention-policy \\
    --log-group-name "{log_group}" \\
    --retention-in-days 365

'''
        script += 'echo "Retention policies set for all log groups"'
        return script
    
    def _generate_rds_logging_script(self, instances: List[str]) -> str:
        """Generate RDS logging script."""
        script = '''#!/bin/bash
# Enable CloudWatch logging for RDS instances
'''
        for instance in instances:
            script += f'''aws rds modify-db-instance \\
    --db-instance-identifier "{instance}" \\
    --enable-cloudwatch-logs-exports "error,general,slow-query" \\
    --apply-immediately

'''
        script += 'echo "CloudWatch logging enabled for all RDS instances"'
        return script
    
    def run_analysis(self) -> Dict[str, Any]:
        """Run complete analysis of AWS logging configuration."""
        console.print(Panel.fit("[bold green]AWS Log Management Review - PCI DSS Compliance[/bold green]"))
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
        ) as progress:
            
            task1 = progress.add_task("Analyzing CloudTrail...", total=None)
            cloudtrail_findings = self.analyze_cloudtrail()
            progress.update(task1, completed=True)
            
            task2 = progress.add_task("Analyzing S3 Logging...", total=None)
            s3_findings = self.analyze_s3_logging()
            progress.update(task2, completed=True)
            
            task3 = progress.add_task("Analyzing CloudWatch Logs...", total=None)
            cloudwatch_findings = self.analyze_cloudwatch_logs()
            progress.update(task3, completed=True)
            
            task4 = progress.add_task("Analyzing RDS Logging...", total=None)
            rds_findings = self.analyze_rds_logging()
            progress.update(task4, completed=True)
            
            task5 = progress.add_task("Analyzing IAM Logging...", total=None)
            iam_findings = self.analyze_iam_logging()
            progress.update(task5, completed=True)
        
        # Compile all findings
        all_findings = {
            'cloudtrail': cloudtrail_findings,
            's3_logging': s3_findings,
            'cloudwatch_logs': cloudwatch_findings,
            'rds_logging': rds_findings,
            'iam_logging': iam_findings,
            'timestamp': datetime.now().isoformat(),
            'total_issues': sum(len(f.get('issues', [])) for f in [cloudtrail_findings, s3_findings, cloudwatch_findings, rds_findings, iam_findings])
        }
        
        # Generate recommendations
        recommendations = self.generate_recommendations(all_findings)
        
        return {
            'findings': all_findings,
            'recommendations': recommendations
        }

@click.command()
@click.option('--profile', help='AWS profile to use')
@click.option('--region', help='AWS region to analyze')
@click.option('--output', default='report', help='Output format: report, json, yaml')
@click.option('--generate-scripts', is_flag=True, help='Generate remediation scripts')
def main(profile: str, region: str, output: str, generate_scripts: bool):
    """AWS Log Management Review Tool for PCI DSS Compliance."""
    
    try:
        reviewer = AWSLogReviewer(profile=profile, region=region)
        results = reviewer.run_analysis()
        
        if output == 'json':
            print(json.dumps(results, indent=2, default=str))
        elif output == 'yaml':
            print(yaml.dump(results, default_flow_style=False, default_style=''))
        else:
            # Generate detailed report
            generate_report(results, generate_scripts)
            
    except Exception as e:
        console.print(f"[bold red]Error: {str(e)}[/bold red]")
        sys.exit(1)

def generate_report(results: Dict[str, Any], generate_scripts: bool):
    """Generate a detailed report with findings and recommendations."""
    
    console.print("\n" + "="*80)
    console.print("[bold blue]AWS LOG MANAGEMENT REVIEW REPORT[/bold blue]")
    console.print("="*80)
    
    # Executive Summary
    console.print("\n[bold green]EXECUTIVE SUMMARY[/bold green]")
    console.print(f"Analysis Date: {results['findings']['timestamp']}")
    console.print(f"Total Issues Found: {results['findings']['total_issues']}")
    console.print(f"Recommendations Generated: {len(results['recommendations'])}")
    
    # Findings Summary
    console.print("\n[bold green]FINDINGS SUMMARY[/bold green]")
    
    # CloudTrail
    ct = results['findings']['cloudtrail']
    console.print(f"CloudTrail: {'✓ Enabled' if ct['enabled'] else '✗ Not Enabled'}")
    if ct['enabled']:
        console.print(f"  - Multi-Region: {'✓ Yes' if ct['multi_region'] else '✗ No'}")
        console.print(f"  - Log Validation: {'✓ Enabled' if ct['log_file_validation'] else '✗ Disabled'}")
    
    # S3 Logging
    s3 = results['findings']['s3_logging']
    console.print(f"S3 Access Logging: {s3['buckets_with_logging']}/{s3['buckets_analyzed']} buckets enabled")
    
    # CloudWatch Logs
    cw = results['findings']['cloudwatch_logs']
    console.print(f"CloudWatch Logs: {cw['log_groups_with_retention']}/{cw['log_groups']} log groups have retention policies")
    
    # RDS Logging
    rds = results['findings']['rds_logging']
    console.print(f"RDS CloudWatch Logging: {rds['instances_with_logging']}/{rds['instances']} instances enabled")
    
    # Detailed Issues
    console.print("\n[bold green]DETAILED ISSUES[/bold green]")
    
    all_issues = []
    for category, findings in results['findings'].items():
        if category != 'timestamp' and category != 'total_issues':
            for issue in findings.get('issues', []):
                all_issues.append({
                    'category': category.upper(),
                    'severity': issue['severity'],
                    'description': issue['description'],
                    'pci_reference': issue['pci_reference']
                })
    
    if all_issues:
        table = Table(show_header=True, header_style="bold magenta")
        table.add_column("Category")
        table.add_column("Severity")
        table.add_column("Description")
        table.add_column("PCI Reference")
        
        for issue in all_issues:
            severity_color = "red" if issue['severity'] == 'HIGH' else "yellow" if issue['severity'] == 'MEDIUM' else "green"
            table.add_row(
                issue['category'],
                f"[{severity_color}]{issue['severity']}[/{severity_color}]",
                issue['description'],
                issue['pci_reference']
            )
        
        console.print(table)
    else:
        console.print("[green]✓ No issues found![/green]")
    
    # Recommendations
    console.print("\n[bold green]RECOMMENDATIONS[/bold green]")
    
    if results['recommendations']:
        for i, rec in enumerate(results['recommendations'], 1):
            priority_color = "red" if rec['priority'] == 'HIGH' else "yellow" if rec['priority'] == 'MEDIUM' else "green"
            
            console.print(f"\n[bold]{i}. {rec['title']}[/bold]")
            console.print(f"   Priority: [{priority_color}]{rec['priority']}[/{priority_color}]")
            console.print(f"   Category: {rec['category']}")
            console.print(f"   Description: {rec['description']}")
            console.print(f"   PCI Reference: {rec['pci_reference']}")
            console.print(f"   Estimated Cost: {rec['estimated_cost']}")
            
            if generate_scripts:
                script_filename = f"remediation_script_{i}_{rec['category'].lower()}.sh"
                with open(script_filename, 'w') as f:
                    f.write(rec['script'])
                console.print(f"   [blue]Script generated: {script_filename}[/blue]")
    
    # PCI DSS Compliance Summary
    console.print("\n[bold green]PCI DSS COMPLIANCE SUMMARY[/bold green]")
    
    pci_requirements = {
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
    
    compliance_table = Table(show_header=True, header_style="bold magenta")
    compliance_table.add_column("PCI Requirement")
    compliance_table.add_column("Description")
    compliance_table.add_column("Status")
    
    for req, desc in pci_requirements.items():
        # Simple compliance check - in a real implementation, this would be more sophisticated
        status = "✓ Compliant" if req not in [issue['pci_reference'] for issue in all_issues] else "✗ Non-Compliant"
        status_color = "green" if "Compliant" in status else "red"
        
        compliance_table.add_row(
            req,
            desc,
            f"[{status_color}]{status}[/{status_color}]"
        )
    
    console.print(compliance_table)
    
    # Cost Optimization Recommendations
    console.print("\n[bold green]COST OPTIMIZATION RECOMMENDATIONS[/bold green]")
    console.print("• Use S3 Lifecycle policies to transition logs to cheaper storage tiers")
    console.print("• Implement log filtering to reduce storage costs")
    console.print("• Consider CloudWatch Logs Insights for efficient log analysis")
    console.print("• Use CloudTrail Insights to reduce CloudTrail costs")
    console.print("• Implement log retention policies to automatically delete old logs")
    
    console.print("\n" + "="*80)
    console.print("[bold blue]Report generation complete![/bold blue]")
    console.print("="*80)

if __name__ == '__main__':
    main() 