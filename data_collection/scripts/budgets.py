#Authors:
# Stephanie Gooch - initial version
# Mohideen - Added Budgets tag collection module
import os
import json
import logging
import datetime
from json import JSONEncoder
import sys

# update boto3 for list_tags_for_resource api
from pip._internal import main
main(['install', '-I', '-q', 'boto3', '--target', '/tmp/', '--no-cache-dir', '--disable-pip-version-check'])
sys.path.insert(0,'/tmp/')

import boto3 #pylint: disable=C0413

BUCKET = os.environ["BUCKET_NAME"]
PREFIX = os.environ["PREFIX"]
ROLE_NAME = os.environ['ROLE_NAME']
TMP_FILE = "/tmp/data.json"

logger = logging.getLogger(__name__)
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO').upper(), logging.INFO))

class DateTimeEncoder(JSONEncoder):
    """encoder for json with time object"""
    def default(self, o):
        if isinstance(o, (datetime.date, datetime.datetime)):
            return o.isoformat()
        return None

def assume_role(account_id, service, region):
    cred = boto3.client('sts', region_name=region).assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/{ROLE_NAME}",
        RoleSessionName="data_collection"
    )['Credentials']
    return boto3.client(
        service,
        aws_access_key_id=cred['AccessKeyId'],
        aws_secret_access_key=cred['SecretAccessKey'],
        aws_session_token=cred['SessionToken']
    )

def lambda_handler(event, context): #pylint: disable=W0613
    logger.info(f"Event data {json.dumps(event)}")
    if 'account' not in event:
        raise ValueError(
            "Please do not trigger this Lambda manually."
            "Find the corresponding state machine in Step Functions and Trigger from there."
        )
    collection_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    aws_partition = boto3.session.Session().get_partition_for_region(boto3.session.Session().region_name)
    account = json.loads(event["account"])
    account_id = account["account_id"]
    account_name = account["account_name"]
    payer_id = account["payer_id"]

    logger.info(f"Collecting data for account: {account_id}")
    budgets_client = assume_role(account_id, "budgets", "us-east-1") # must be us-east-1
    count = 0
    with open(TMP_FILE, "w", encoding='utf-8') as f:
        for budget in budgets_client.get_paginator("describe_budgets").paginate(AccountId=account_id).search('Budgets'):
            if not budget: continue
            budget['collection_time'] = collection_time

            # Fetch tags for the budget using List tag for resource API
            budget_name = budget['BudgetName']
            budget_tags = budgets_client.list_tags_for_resource(ResourceARN=f"arn:{aws_partition}:budgets::{account_id}:budget/{budget_name}")
            budget.update({
                'Account_ID': account_id,
                'Account_Name': account_name,
                'Tags': budget_tags.get('ResourceTags') or []
            })

            # Fetch CostFilters if available
            if 'CostFilters' not in budget or len(budget['CostFilters']) == 0 or 'PlannedBudgetLimits' not in budget:
                budget.update({'CostFilters': {'Filter': ['None']}})

            f.write(json.dumps(budget, cls=DateTimeEncoder) + "\n")
            count += 1
    logger.info(f"Budgets collected: {count}")
    s3_upload(account_id, payer_id)


def s3_upload(account_id, payer_id):
    if os.path.getsize(TMP_FILE) == 0:
        logger.info(f"No data in file for {PREFIX}")
        return
    key = datetime.datetime.now().strftime(f"{PREFIX}/{PREFIX}-data/payer_id={payer_id}/year=%Y/month=%m/budgets-{account_id}.json")
    boto3.client('s3').upload_file(TMP_FILE, BUCKET, key)
    logger.info(f"Budget data for {account_id} stored at s3://{BUCKET}/{key}")
