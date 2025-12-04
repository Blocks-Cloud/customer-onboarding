import json
import subprocess
import datetime
import time
import sys

def run_aws_cmd(cmd):
    try:
        output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode("utf-8")
        return json.loads(output) if output.strip().startswith("{") else output
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {cmd}\nOutput: {e.output.decode()}")
        sys.exit(1)

def get_tag_status(tag_key):
    cmd = f"aws ce list-cost-allocation-tags --tag-keys {tag_key} --type AWSGenerated --region us-east-1"
    res = run_aws_cmd(cmd)
    for tag in res.get("CostAllocationTags", []):
        if tag["TagKey"] == tag_key:
            return tag["Status"]
    return None

def check_backfill_history():
    print("Checking for existing backfills...")
    cmd = "aws ce list-cost-allocation-tag-backfill-history --region us-east-1"
    try:
        res = run_aws_cmd(cmd)
        for backfill in res.get("BackfillHistory", []):
            if backfill["BackfillStatus"] == "PROCESSING":
                print("A backfill is already processing. Skipping new request.")
                sys.exit(0)
    except Exception as e:
        print(f"Warning: Could not list backfill history: {e}")

check_backfill_history()

print("Checking status of aws:createdBy...")
target_tag = "aws:createdBy"
status = get_tag_status(target_tag)

if status == "Active":
    print(f"Tag {target_tag} is already Active. Searching for another inactive AWS-managed tag...")
    cmd = "aws ce list-cost-allocation-tags --type AWSGenerated --region us-east-1"
    res = run_aws_cmd(cmd)
    
    found_alt = False
    for tag in res.get("CostAllocationTags", []):
        if tag["Status"] == "Inactive":
            target_tag = tag["TagKey"]
            print(f"Found inactive tag to activate: {target_tag}")
            found_alt = True
            break
    
    if not found_alt:
        print("No inactive AWS-managed tags found. Proceeding with aws:createdBy.")

print(f"Activating tag: {target_tag}")
activate_cmd = f"aws ce update-cost-allocation-tags-status --cost-allocation-tags-status TagKey=\"{target_tag}\",Status=Active --region us-east-1"
subprocess.run(activate_cmd, shell=True, check=True)

current_date = datetime.datetime.now(datetime.timezone.utc)
backfill_from = datetime.datetime(current_date.year - 1, current_date.month, 1, 0, 0, 0)
backfill_date_str = backfill_from.strftime("%Y-%m-%dT%H:%M:%SZ")

print(f"Starting cost allocation tag backfill from: {backfill_date_str}")

backfill_cmd = f"aws ce start-cost-allocation-tag-backfill --backfill-from \"{backfill_date_str}\" --region us-east-1"

output = run_aws_cmd(backfill_cmd)
print(json.dumps(output, indent=4))
