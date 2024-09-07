import os
import json
import logging
from datetime import date, timedelta, datetime

import boto3

BUCKET = os.environ['BUCKET_NAME']
ROLE_NAME = os.environ['ROLE_NAME']
MODULE_NAME = os.environ['PREFIX']
TMP_FILE = '/tmp/tmp.json'
REGION = "us-east-1"

logger = logging.getLogger(__name__)
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO').upper(), logging.INFO))

def lambda_handler(event, context): #pylint: disable=unused-argument
    logger.info(f"Incoming event: {json.dumps(event)}")
    key = "account"
    if key not in event:
        logger.error(f"Lambda event parameter '{key}' not defined (fatal) in {MODULE_NAME} module. Please do not trigger this Lambda manually. "
            f"Find the corresponding {MODULE_NAME} state machine in Step Functions and trigger from there."
        )
        raise RuntimeError(f"(MissingParameterError) Lambda event missing '{key}' parameter")

    account = json.loads(event[key])
    main(account, ROLE_NAME, MODULE_NAME, BUCKET)

    return {
        'statusCode': 200
    }

def main(account, role_name, module_name, bucket):
    start_date, end_date = calculate_dates(bucket, s3_path=f'{module_name}/cost-anomaly-data/')
    logger.info(f'Using start_date={start_date}, end_date={end_date}')

    data_uploaded = False
    account_id = account["account_id"]
    records = get_api_data(role_name, account_id, start_date, end_date)
    if len(records) > 0:
        count = process_records(records, TMP_FILE)
        if count > 0:
            upload_to_s3(account_id, bucket, module_name, TMP_FILE)
            data_uploaded = True
    if not data_uploaded:
        logger.info("No file uploaded because no new records were found")

def get_api_data(role_name, account_id, start_date, end_date):
    results = []
    client = get_client_with_role(role_name, account_id, region=REGION, service="ce")
    next_token = None
    while True: # operation get_anomalies cannot be paginated
        params = {
            "DateInterval": {
              'StartDate': str(start_date),
              'EndDate': str(end_date)
            },
            "MaxResults": 100,
        }
        if next_token:
            params['NextPageToken'] = next_token
        response = client.get_anomalies(**params)
        results += response['Anomalies']
        if 'NextPageToken' in response:
            next_token = response['NextPageToken']
        else:
            break
    logger.info(f"API results total {len(results)}")
    return results


def process_records(records, tmp_file):
    count = 0
    with open(tmp_file, "w", encoding='utf-8') as f:
        for record in records:
            data = parse_record(record)
            f.write(to_json(data) + "\n")
            count += 1
    logger.info(f"Processed a total of {count} new records for account")
    return count

def parse_record(record):
    logger.debug(f"Processing record {record}")
    result = {
        'AnomalyId': get_value_by_path(record, 'AnomalyId'),
        'AnomalyStartDate': get_value_by_path(record, 'AnomalyStartDate'),
        'AnomalyEndDate': get_value_by_path(record, 'AnomalyEndDate'),
        'DimensionValue': get_value_by_path(record, 'DimensionValue'),
        'MaxImpact': get_value_by_path(record, 'Impact/MaxImpact'),
        'TotalActualSpend': get_value_by_path(record, 'Impact/TotalActualSpend'),
        'TotalExpectedSpend': get_value_by_path(record, 'Impact/TotalExpectedSpend'),
        'TotalImpact': get_value_by_path(record, 'Impact/TotalImpact'),
        'TotalImpactpercentage': float(get_value_by_path(record, 'Impact/TotalImpactPercentage', 0.0)),
        'MonitorArn': get_value_by_path(record, 'MonitorArn'),
        'LinkedAccount': get_value_by_path(record, 'RootCauses/0/LinkedAccount'),
        'LinkedAccountName': get_value_by_path(record, 'RootCauses/0/LinkedAccountName'),
        'Region': get_value_by_path(record, 'RootCauses/0/Region'),
        'Service': get_value_by_path(record, 'RootCauses/0/Service'),
        'UsageType': get_value_by_path(record, 'RootCauses/0/UsageType')
    }
    logger.debug("Processing record complete")
    return result


def upload_to_s3(payer_id, bucket, module_name, tmp_file):
    key = datetime.now().strftime(f"{module_name}/{module_name}-data/payer_id={payer_id}/year=%Y/month=%m/day=%d/%Y-%m-%d.json")
    boto3.client('s3').upload_file(tmp_file, bucket, key)
    logger.info(f"Data stored to s3://{bucket}/{key}")


def get_value_by_path(data, path, default=None):
    logger.debug(f"Traversing for path {path}")
    keys = path.split("/")
    current = data
    for key in keys:
        if isinstance(current, dict) and key in current:
            current = current.get(key, default)
        elif isinstance(current, list) and key.isdigit():
            try:
                current = current[int(key)]
            except IndexError:
                logger.debug(f"Index value {key} within path {path} is not valid in get_value_by_path for data {data}, returning default of {default}")
                return default
        else:
            logger.debug(f"Key value {key} within path {path} is not valid in get_value_by_path for data {data}, returning default of {default}")
            return default
    return current


def get_client_with_role(role_name, account_id, service, region):
    logger.debug(f"Attempting to get '{service}' client with role '{role_name}' from account '{account_id}' in region '{region}'")
    credentials = boto3.client('sts').assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/{role_name}",
        RoleSessionName="data_collection"
    )['Credentials']
    logger.debug("Successfully assumed role, now getting client")
    client = boto3.client(
        service,
        region_name = region,
        aws_access_key_id=credentials['AccessKeyId'],
        aws_secret_access_key=credentials['SecretAccessKey'],
        aws_session_token=credentials['SessionToken'],
    )
    logger.debug(f"Successfully created '{service}' client with role '{role_name}' from account '{account_id}' in region '{region}'")
    return client

def to_json(obj):
    return json.dumps(
        obj,
        default=lambda x:
            x.isoformat() if isinstance(x, (date, datetime)) else None
    )

def calculate_dates(bucket, s3_path):
    end_date = datetime.now().date()
    start_date = datetime.now().date() - timedelta(days=90) #Cost anomalies are available for last 90days
    # Check the create time of objects in the S3 bucket
    paginator = boto3.client('s3').get_paginator('list_objects_v2')
    contents = sum( [page.get('Contents', []) for page in paginator.paginate(Bucket=bucket, Prefix=s3_path)], [])
    last_modified_date = get_last_modified_date(contents)
    if last_modified_date and last_modified_date >= start_date:
        start_date = last_modified_date
    return start_date, end_date

def get_last_modified_date(contents):
    last_modified_dates = [obj['LastModified'].date() for obj in contents]
    last_modified_dates_within_90_days = [date for date in last_modified_dates if date >= datetime.now().date() - timedelta(days=90)]
    if last_modified_dates_within_90_days:
        return max(last_modified_dates_within_90_days)
    return None
