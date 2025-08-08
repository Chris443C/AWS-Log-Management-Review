#!/usr/bin/env python3
"""
Complete AWS Log Management Analysis Workflow
Runs the entire analysis, report generation, and script creation process.
"""

import os
import sys
import json
import click
import subprocess
from datetime import datetime
from pathlib import Path

def run_command(command, description):
    """Run a command and handle errors."""
    print(f"\n{'='*60}")
    print(f"🔄 {description}")
    print(f"{'='*60}")
    print(f"Running: {command}")
    
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {description} completed successfully")
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} failed")
        print(f"Error: {e.stderr}")
        return None

def create_directories():
    """Create necessary directories."""
    directories = ['reports', 'scripts', 'config', 'templates']
    for directory in directories:
        Path(directory).mkdir(exist_ok=True)
        print(f"📁 Created directory: {directory}")

def check_dependencies():
    """Check if required dependencies are installed."""
    print(f"\n{'='*60}")
    print("🔍 Checking Dependencies")
    print(f"{'='*60}")
    
    required_packages = [
        'boto3', 'click', 'jinja2', 'pyyaml', 'rich', 'tabulate'
    ]
    
    missing_packages = []
    for package in required_packages:
        try:
            __import__(package)
            print(f"✅ {package}")
        except ImportError:
            print(f"❌ {package} - not installed")
            missing_packages.append(package)
    
    if missing_packages:
        print(f"\n⚠️  Missing packages: {', '.join(missing_packages)}")
        print("Please install them using: pip install -r requirements.txt")
        return False
    
    return True

def check_aws_credentials():
    """Check if AWS credentials are configured."""
    print(f"\n{'='*60}")
    print("🔍 Checking AWS Credentials")
    print(f"{'='*60}")
    
    try:
        result = subprocess.run(['aws', 'sts', 'get-caller-identity'], 
                              capture_output=True, text=True, check=True)
        identity = json.loads(result.stdout)
        print(f"✅ AWS credentials configured")
        print(f"   Account: {identity.get('Account', 'Unknown')}")
        print(f"   User/Role: {identity.get('Arn', 'Unknown')}")
        return True
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        print("❌ AWS credentials not configured or invalid")
        print("Please run: aws configure")
        return False

@click.command()
@click.option('--profile', default='default', help='AWS profile to use')
@click.option('--region', default='us-east-1', help='AWS region to analyze')
@click.option('--output-dir', default='output', help='Output directory for all files')
@click.option('--generate-scripts', is_flag=True, help='Generate remediation scripts')
@click.option('--skip-analysis', is_flag=True, help='Skip analysis and use existing findings')
@click.option('--skip-reports', is_flag=True, help='Skip report generation')
@click.option('--skip-scripts', is_flag=True, help='Skip script generation')
def main(profile, region, output_dir, generate_scripts, skip_analysis, skip_reports, skip_scripts):
    """Run complete AWS Log Management Analysis workflow."""
    
    print("🚀 AWS Log Management Review - Complete Analysis Workflow")
    print("=" * 80)
    print(f"Profile: {profile}")
    print(f"Region: {region}")
    print(f"Output Directory: {output_dir}")
    print(f"Generate Scripts: {generate_scripts}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)
    
    # Create output directory
    Path(output_dir).mkdir(exist_ok=True)
    
    # Check dependencies
    if not check_dependencies():
        print("\n❌ Dependencies check failed. Please install missing packages.")
        sys.exit(1)
    
    # Check AWS credentials
    if not check_aws_credentials():
        print("\n❌ AWS credentials check failed. Please configure AWS credentials.")
        sys.exit(1)
    
    # Create necessary directories
    create_directories()
    
    # Step 1: Run AWS Log Analysis
    if not skip_analysis:
        findings_file = os.path.join(output_dir, "findings.json")
        recommendations_file = os.path.join(output_dir, "recommendations.json")
        
        # Run the main analysis
        analysis_command = f"python aws_log_review.py --profile {profile} --region {region} --output json"
        analysis_output = run_command(analysis_command, "Running AWS Log Analysis")
        
        if analysis_output is None:
            print("\n❌ Analysis failed. Exiting.")
            sys.exit(1)
        
        # Save findings and recommendations to separate files
        try:
            analysis_data = json.loads(analysis_output)
            findings = analysis_data.get('findings', {})
            recommendations = analysis_data.get('recommendations', [])
            
            with open(findings_file, 'w') as f:
                json.dump(findings, f, indent=2, default=str)
            
            with open(recommendations_file, 'w') as f:
                json.dump(recommendations, f, indent=2, default=str)
            
            print(f"✅ Analysis results saved to:")
            print(f"   - {findings_file}")
            print(f"   - {recommendations_file}")
            
        except json.JSONDecodeError as e:
            print(f"❌ Failed to parse analysis output: {e}")
            sys.exit(1)
    else:
        print("\n⏭️  Skipping analysis (using existing findings)")
        findings_file = os.path.join(output_dir, "findings.json")
        recommendations_file = os.path.join(output_dir, "recommendations.json")
        
        if not os.path.exists(findings_file) or not os.path.exists(recommendations_file):
            print("❌ Existing findings files not found. Please run analysis first.")
            sys.exit(1)
    
    # Step 2: Generate Reports
    if not skip_reports:
        reports_dir = os.path.join(output_dir, "reports")
        Path(reports_dir).mkdir(exist_ok=True)
        
        # Generate HTML report
        html_command = f"python report_generator.py --findings-file {findings_file} --recommendations-file {recommendations_file} --output-format html --output-dir {reports_dir}"
        if generate_scripts:
            html_command += " --generate-scripts"
        
        run_command(html_command, "Generating HTML Report")
        
        # Generate JSON report
        json_command = f"python report_generator.py --findings-file {findings_file} --recommendations-file {recommendations_file} --output-format json --output-dir {reports_dir}"
        run_command(json_command, "Generating JSON Report")
        
        # Generate YAML report
        yaml_command = f"python report_generator.py --findings-file {findings_file} --recommendations-file {recommendations_file} --output-format yaml --output-dir {reports_dir}"
        run_command(yaml_command, "Generating YAML Report")
        
        print(f"✅ Reports generated in: {reports_dir}")
    else:
        print("\n⏭️  Skipping report generation")
    
    # Step 3: Generate Remediation Scripts
    if not skip_scripts and generate_scripts:
        scripts_dir = os.path.join(output_dir, "scripts")
        Path(scripts_dir).mkdir(exist_ok=True)
        
        scripts_command = f"python scripts/generate_remediation_scripts.py --findings-file {findings_file} --output-dir {scripts_dir}"
        run_command(scripts_command, "Generating Remediation Scripts")
        
        # Make scripts executable
        if os.path.exists(scripts_dir):
            chmod_command = f"chmod +x {scripts_dir}/*.sh"
            run_command(chmod_command, "Making Scripts Executable")
        
        print(f"✅ Scripts generated in: {scripts_dir}")
    else:
        print("\n⏭️  Skipping script generation")
    
    # Step 4: Generate Summary
    print(f"\n{'='*80}")
    print("📋 ANALYSIS COMPLETE - SUMMARY")
    print(f"{'='*80}")
    
    # Count files generated
    files_generated = []
    
    if os.path.exists(findings_file):
        files_generated.append(f"📄 {findings_file}")
    
    if os.path.exists(recommendations_file):
        files_generated.append(f"📄 {recommendations_file}")
    
    reports_dir = os.path.join(output_dir, "reports")
    if os.path.exists(reports_dir):
        for file in os.listdir(reports_dir):
            if file.endswith(('.html', '.json', '.yaml')):
                files_generated.append(f"📊 {os.path.join(reports_dir, file)}")
    
    scripts_dir = os.path.join(output_dir, "scripts")
    if os.path.exists(scripts_dir):
        for file in os.listdir(scripts_dir):
            if file.endswith('.sh'):
                files_generated.append(f"🛠️  {os.path.join(scripts_dir, file)}")
    
    print(f"Generated {len(files_generated)} files:")
    for file in files_generated:
        print(f"   {file}")
    
    # Display next steps
    print(f"\n{'='*80}")
    print("🎯 NEXT STEPS")
    print(f"{'='*80}")
    
    html_report = os.path.join(output_dir, "reports", "aws_log_review_report.html")
    if os.path.exists(html_report):
        print(f"1. 📊 Review the HTML report: {html_report}")
    
    master_script = os.path.join(output_dir, "scripts", "run_all_remediation.sh")
    if os.path.exists(master_script):
        print(f"2. 🛠️  Review and test remediation scripts: {master_script}")
        print("   ⚠️  Always test scripts in a non-production environment first!")
    
    print("3. 🔍 Review findings and prioritize remediation")
    print("4. 📈 Monitor costs after implementing changes")
    print("5. 🔄 Schedule regular compliance reviews")
    
    print(f"\n{'='*80}")
    print("✅ Complete Analysis Workflow Finished Successfully!")
    print(f"{'='*80}")

if __name__ == '__main__':
    main() 