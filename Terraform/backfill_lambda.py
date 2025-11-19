"""
Lambda function to request CUR 2.0 historical data backfill via AWS Support case.
"""
import os
import json
import boto3
from botocore.exceptions import ClientError


def lambda_handler(event, context):
    """
    Creates an AWS Support case requesting historical CUR data backfill.
    
    Returns:
        dict: Response with status and case ID or skip reason
    """
    export_name = os.environ.get("EXPORT_NAME", "unknown-export")
    months = int(os.environ.get("BACKFILL_MONTHS", "12"))
    severity = os.environ.get("SEVERITY", "low")
    
    # Support API only available in us-east-1
    support = boto3.client("support", region_name="us-east-1")
    
    try:
        # Discover available services and categories
        service_code = "service-cost-and-usage-report-cur"
        category_code = "backfill-a-report"
        issue_type = "customer-service"
        language = "en"
        # Create the support case
        subject = f"Request historical data backfill for CUR 2.0 export '{export_name}'"
        body = (
            f"Hello AWS Support,\n\n"
            f"Please backfill {months} months of historical Cost and Usage Report data "
            f"into the CUR 2.0 export named '{export_name}'.\n\n"
            f"This export was created using AWS BCM Data Exports (CUR 2.0) and stores "
            f"data in Parquet format.\n\n"
            f"Thank you!"
        )
        
        response = support.create_case(
            subject=subject,
            serviceCode=service_code,
            severityCode=severity,
            categoryCode=category_code,
            communicationBody=body,
            language=language,
            issueType=issue_type
        )
        
        case_id = response.get("caseId", "")
        print(f"Successfully created support case: {case_id}")
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "success": True,
                "caseId": case_id,
                "message": f"Support case {case_id} created for {months} months backfill"
            })
        }
        
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "")
        error_msg = e.response.get("Error", {}).get("Message", "")
        
        # Handle cases where support is not available
        if error_code in ("SubscriptionRequiredException", "AccessDeniedException") or "AccessDenied" in error_code:
            print(f"Support access not available: {error_code} - {error_msg}")
            return {
                "statusCode": 200,
                "body": json.dumps({
                    "success": True,
                    "skipped": True,
                    "reason": error_code,
                    "message": f"Support case creation skipped: {error_msg}. Open a case manually or upgrade support plan."
                })
            }
        
        # Re-raise unexpected errors
        print(f"Error creating support case: {error_code} - {error_msg}")
        raise
    
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "success": False,
                "error": str(e)
            })
        }