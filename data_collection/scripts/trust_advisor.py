import os
import json
from datetime import date, datetime
from json import JSONEncoder

import boto3
from botocore.client import Config
import logging

PREFIX = os.environ["PREFIX"]
BUCKET = os.environ["BUCKET_NAME"]
ROLE_NAME = os.environ['ROLENAME']
COSTONLY = os.environ.get('COSTONLY', 'no').lower() == 'yes'
TMP_FILE = "/tmp/data.json"
REGIONS = ["us-east-1"]

#config to avoid ThrottlingException
config = Config(
  retries = {
      'max_attempts': 10,
      'mode': 'standard'
  }
)

logger = logging.getLogger(__name__)
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO').upper(), logging.INFO))

def lambda_handler(event, context):
    collection_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    if 'account' not in event:
        raise ValueError(
            "Please do not trigger this Lambda manually."
            "Find the corresponding state machine in Step Functions and Trigger from there."
        )
    try:
        account = json.loads(event["account"])
        account_id = account["account_id"]
        account_name = account["account_name"]
        payer_id = account["payer_id"]
        logger.info(f"Collecting data for account: {account_id}")
        read_ta(account_id, account_name)
        upload_to_s3(account_id, payer_id)
    except Exception as e:
        logging.warning(e)

def upload_to_s3(account_id, payer_id):
    if os.path.getsize(TMP_FILE) == 0:
        print(f"No data in file for {PREFIX}")
        return
    d = datetime.now()
    month = d.strftime("%m")
    year = d.strftime("%Y")
    _date = d.strftime("%d%m%Y-%H%M%S")
    key = f"{PREFIX}/{PREFIX}-data/payer_id={payer_id}/year={year}/month={month}/{PREFIX}-{account_id}-{_date}.json"
    try:
        boto3.client("s3").upload_file(TMP_FILE, BUCKET, key)
        print(f"Data for {account_id} in s3 - {key}")
    except Exception as e:
        print(f"{type(e)}: {e}")

def assume_role(account_id, service, region, role):
    assumed = boto3.client('sts', region_name=region).assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/{role}",
        RoleSessionName='data_collection'
    )
    creds = assumed['Credentials']
    return boto3.client(service, region_name=region,
        aws_access_key_id=creds['AccessKeyId'],
        aws_secret_access_key=creds['SecretAccessKey'],
        aws_session_token=creds['SessionToken'],
        config=config,
    )

def _json_serial(self, obj):
    if isinstance(obj, (datetime, date)): return obj.isoformat()
    return JSONEncoder.default(self, obj)

def read_ta(account_id, account_name):
    f = open(TMP_FILE, "w")
    support = assume_role(account_id, "support", REGIONS[0], ROLE_NAME)
    checks = support.describe_trusted_advisor_checks(language="en")["checks"]
    for check in checks:
        if (COSTONLY and check.get("category") != "cost_optimizing"): continue
        try:
            result = support.describe_trusted_advisor_check_result(checkId=check["id"], language="en")['result']
            if result.get("status") == "not_available": continue
            dt = result['timestamp']
            ts = datetime.strptime(dt, '%Y-%m-%dT%H:%M:%SZ').strftime('%s')
            for resource in result["flaggedResources"]:
                output = {}
                if "metadata" in resource:
                    output.update(dict(zip(check["metadata"], resource["metadata"])))
                    del resource['metadata']
                resource["Region"] = resource.pop("region") if "region" in resource else '-'
                resource["Status"] = resource.pop("status") if "status" in resource else '-'
                output.update({"AccountId":account_id, "AccountName":account_name, "Category": check["category"], 'DateTime': dt, 'Timestamp': ts, "CheckName": check["name"], "CheckId": check["id"]})
                output.update(resource)
                output = {k.lower(): v for k, v in output.items()}
                f.write(json.dumps(output, default=_json_serial) + "\n")
        except Exception as e:
            print(f'{type(e)}: {e}')