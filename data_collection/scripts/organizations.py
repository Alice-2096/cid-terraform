""" Get Account info from AWS Organizations and store on s3 bucket
"""
import os
import re
import json
import logging
import datetime
from functools import lru_cache

import boto3
from botocore.exceptions import ClientError
from botocore.client import Config

BUCKET = os.environ['BUCKET_NAME']
ROLE = os.environ['ROLENAME']
PREFIX = os.environ['PREFIX']
REGIONS = ["us-east-1"] #This MUST be us-east-1 regardless of region of Lambda

logger = logging.getLogger(__name__)
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO').upper(), logging.INFO))

def lambda_handler(event, context):
    logger.info(f"Event data {json.dumps(event)}")
    if 'account' not in event:
        raise ValueError(
            "Please do not trigger this Lambda manually."
            "Find the corresponding state machine in Step Functions and Trigger from there."
        )
    account = json.loads(event["account"])
    try:
        process_management_acc(account["account_id"])
    except Exception as exc:
        logger.warning(exc)

def process_management_acc(management_account_id):
    """Get info from management account and write to s3"""
    logger.info(f'Assuming role {ROLE} in {management_account_id}')
    cred = boto3.client('sts', region_name=REGIONS[0]).assume_role(
        RoleArn=f"arn:aws:iam::{management_account_id}:role/{ROLE}",
        RoleSessionName="data_collection"
    )['Credentials']
    client = boto3.client(
        "organizations",
        region_name=REGIONS[0],
        aws_access_key_id=cred['AccessKeyId'],
        aws_secret_access_key=cred['SecretAccessKey'],
        aws_session_token=cred['SessionToken'],
    )
    accounts = list(OrgController(client).iterate_accounts())
    logger.debug(f'Uploading {len(accounts)} records')
    s3_upload(management_account_id, accounts)


def s3_upload(payer_id, data):
    """Upload records to s3"""
    tmp_file = f'/tmp/accounts-{payer_id}.json'
    with open(tmp_file, 'w', encoding='utf-8') as file_:
        for line in data:
            file_.write(json.dumps(line, default=json_converter) + '\n')
    try:
        prefix = f"{PREFIX}/organization-data/payer_id={payer_id}/acc-org.json" # No time/date info. Each time we override data
        boto3.client('s3').upload_file(tmp_file, BUCKET, prefix)
        logger.info(f"Uploaded {len(data)} records in s3://{BUCKET}/{prefix}")
    except Exception as exc:
        logger.error(exc)

def json_converter(obj):
    """ Help json encode date"""
    if isinstance(obj, datetime.datetime):
        return obj.strftime("%Y-%m-%d %H:%M:%S")
    return obj

class OrgController():
    """ AWS Organizations controller """
    def __init__(self, client):
        self.org = client

    @lru_cache(maxsize=10000)
    def get_ou_name(self, id_):
        """get ou name"""
        resp = self.org.describe_organizational_unit(OrganizationalUnitId=id_)
        return resp['OrganizationalUnit']['Name']

    @lru_cache(maxsize=10000)
    def get_parent(self, id_):
        """list parents of account or ou"""
        return self.org.list_parents(ChildId=id_)['Parents'][0]

    @lru_cache(maxsize=10000)
    def get_ou_path(self, id_):
        """returns a list of OUs up to Root level"""
        path = []
        current = {'Id': id_}
        while current.get('Type') != 'ROOT':
            current = self.get_parent(current['Id'])
            if current.get('Type') == 'ORGANIZATIONAL_UNIT':
                current['Name'] = self.get_ou_name(current['Id'])
            elif current.get('Type') == 'ROOT':
                # If there are 2 or more orgs we can use a tag 'Name' to set the name of the root OU
                # otherwise we will use ID
                tags = self.get_tags(current["Id"])
                current['Name'] = tags.get('Name', f'ROOT({current["Id"]})')
            path.append(current)
        return path[::-1]

    @lru_cache(maxsize=10000)
    def get_tags(self, id_, athena_friendly=False):
        """returns a dict of tags"""
        paginator = self.org.get_paginator("list_tags_for_resource")
        tags = sum([resp['Tags'] for resp in paginator.paginate(ResourceId=id_)], [])
        return {tag['Key']: tag['Value'] for tag in tags}

    @lru_cache(maxsize=10000)
    def get_hierarchy_tags(self, id_):
        """returns a dict of tags, updated according AWS Org hierarchy"""
        tags = {}
        full_path = self.get_ou_path(id_) + [{'Id': id_}]
        for level in full_path:
            tags.update(self.get_tags(level['Id'], athena_friendly=True))
        return tags

    def iterate_accounts(self):
        """iterate over accounts"""
        for page in self.org.get_paginator('list_accounts').paginate():
            for account in page['Accounts']:
                logger.info('processing %s', account['Id'])
                account['Hierarchy'] = self.get_ou_path(account['Id'])
                account['HierarchyPath'] = ' > '.join([
                    lvl.get('Name', lvl.get('Id')) for lvl in account['Hierarchy']
                ])
                account['HierarchyTags'] = [ {'Key': key, 'Value': value} for key, value in self.get_hierarchy_tags(account['Id']).items()]
                account['ManagementAccountId'] =  account['Arn'].split(':')[4]
                account['Parent'] = account['Hierarchy'][-1].get('Name')
                account['ParentId'] = account['Hierarchy'][-1].get('Id')
                account['ParentTags'] = [ {'Key': key, 'Value': value} for key, value in self.get_tags(account['ParentId']).items()]
                #account['Parent_Tags'] = self.get_tags(account['ParentId']) # Uncomment for Backward Compatibility
                logger.debug(json.dumps(account, indent=2, default=json_converter))
                yield account

def test():
    """ local test """
    client = boto3.client(
        'organizations',
        region_name="us-east-1", #MUST be us-east-1 regardless of region you have the Lambda
    )
    for account in OrgController(client).iterate_accounts():
        print(json.dumps(account, default=json_converter))
