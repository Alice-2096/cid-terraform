import os
import json
import logging
from functools import partial
import boto3

ROLE_NAME = os.environ['ROLE_NAME']
RESOURCE_PREFIX = os.environ['RESOURCE_PREFIX']
MANAGEMENT_ACCOUNT_IDS = os.environ['MANAGEMENT_ACCOUNT_IDS']
BUCKET = os.environ['BUCKET_NAME']
PREDEF_ACCOUNT_LIST_KEY = os.environ['PREDEF_ACCOUNT_LIST_KEY']
LINKED_ACCOUNT_LIST_KEY = os.environ['LINKED_ACCOUNT_LIST_KEY']
PAYER_ACCOUNT_LIST_KEY = os.environ['PAYER_ACCOUNT_LIST_KEY']
TMP_FILE = "/tmp/data.json"

logger = logging.getLogger(__name__)
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO').upper(), logging.INFO))

def lambda_handler(event, context):  # pylint: disable=unused-argument
    logger.info(f"Incoming event: {event}")
    # Need to confirm that the Lambda concurrency limit is sufficient to avoid throttling
    lambda_limit = boto3.client('lambda').get_account_settings()['AccountLimit']['ConcurrentExecutions']
    if lambda_limit < 500:
        message = (f'Lambda concurrent executions limit of {lambda_limit} is not sufficient to run the Data Collection framework. '
                   'Please increase the limit to at least 500 (1000 is recommended). '
                   'See https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html.')
        logger.error(message)
        raise Exception(message)  # pylint: disable=broad-exception-raised

    functions = {  # Keep keys same as boto3 services
        'linked': iterate_linked_accounts,
        'payers': partial(iterate_admins_accounts, None),
        'organizations': partial(iterate_admins_accounts, 'organizations'),
        'compute-optimizer': partial(iterate_admins_accounts, 'compute-optimizer'),
        'backup': partial(iterate_admins_accounts, 'backup'),
    }
    account_type = event.get("Type", '').lower()
    if account_type not in functions:
        raise Exception(f"Lambda event must have 'Type' parameter with value = ({list(functions.keys())})")  # pylint: disable=broad-exception-raised

    account_iterator = functions[account_type]

    with open(TMP_FILE, "w") as f:
        count = 0
        f.write("[\n")
        for account in account_iterator():
            if count > 0:
                f.write(",\n")
            f.write(json.dumps(account))
            count += 1
        f.write("\n]")

    if count == 0:
        raise Exception('No accounts found. Check the log.')  # pylint: disable=broad-exception-raised

    key = LINKED_ACCOUNT_LIST_KEY if account_type == 'linked' else PAYER_ACCOUNT_LIST_KEY
    s3 = boto3.client('s3')
    s3.upload_file(TMP_FILE, Bucket=BUCKET, Key=key)

    return {'statusCode': 200, 'accountList': key, 'bucket': BUCKET}

def get_all_payers():
    for payer_id in MANAGEMENT_ACCOUNT_IDS.split(','):
        yield payer_id.strip()

def iterate_admins_accounts(service=None):
    ssm = boto3.client('ssm')
    for payer_id in get_all_payers():
        account_id = payer_id  # Default
        if service:
            ssm_key = f'/cid/{RESOURCE_PREFIX}config/delegated-admin/{service}/{payer_id}'
            try:
                account_id = ssm.get_parameter(Name=ssm_key)['Parameter']['Value']
            except ssm.exceptions.ParameterNotFound:
                logger.warning(f'Not found ssm parameter {ssm_key}. Will use Management Account Id {payer_id}')
        yield {"account": json.dumps({'account_id': account_id, 'account_name': '', 'payer_id': payer_id})}

def iterate_linked_accounts():
    defined_accounts, ext = get_defined_list(BUCKET, PREDEF_ACCOUNT_LIST_KEY)
    try:
        if defined_accounts:
            logger.info(f'Using defined account list instead of payer organization')
            for account_data in defined_accounts:
                if ext == "json":
                    account = json.loads(account_data)
                    yield format_account(account['account_id'], account['account_name'], account['payer_id'])
                else:
                    account = account_data.split(',')
                    yield format_account(account[0], account[1], account[2])
        else:
            logger.info(f'Using payer organization for the account list')
            for org_account_data in iterate_admins_accounts('organizations'):
                org_account = json.loads(org_account_data['account'])
                organizations = get_client_with_role(service="organizations", account_id=org_account['account_id'], region="us-east-1")  # MUST be us-east-1
                for account in organizations.get_paginator("list_accounts").paginate().search("Accounts[?Status=='ACTIVE']"):
                    yield format_account(account.get('Id'), account.get('Name'), org_account['payer_id'])
    except Exception as exc:  # pylint: disable=broad-exception-caught
        logger.error(f'{org_account}: {exc}')

def get_defined_list(bucket, key):
    s3 = boto3.client("s3")
    exts = [".json", ".csv"]
    for ext in exts:
        try:
            accts = s3.get_object(Bucket=bucket, Key=f"{key}{ext}")
            return accts['Body'].read().decode('utf-8').strip('\n').split('\n'), ext
        except Exception as exc:  # pylint: disable=broad-exception-caught
            continue
    logger.debug(f'Predefined account list not retrieved or not being used')
    return None, None

def format_account(account_id, account_name, payer_id):
    return {
        "account": json.dumps({
            'account_id': account_id,
            'account_name': account_name,
            'payer_id': payer_id,
        })
    }

def get_client_with_role(account_id, service, region):
    credentials = boto3.client('sts').assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/{ROLE_NAME}",
        RoleSessionName="data_collection"
    )['Credentials']
    return boto3.client(
        service,
        region_name=region,
        aws_access_key_id=credentials['AccessKeyId'],
        aws_secret_access_key=credentials['SecretAccessKey'],
        aws_session_token=credentials['SessionToken'],
    )
