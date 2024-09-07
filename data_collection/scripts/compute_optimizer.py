import os
import json
import logging
from datetime import date
from functools import partial

# update boto3 version
import sys
from pip._internal import main
main(['install', '-I', '-q', 'boto3', '--target', '/tmp/', '--no-cache-dir', '--disable-pip-version-check'])
sys.path.insert(0,'/tmp/')

import boto3 #pylint: disable=wrong-import-position

BUCKET_PREFIX = os.environ["BUCKET_PREFIX"]
INCLUDE_MEMBER_ACCOUNTS = os.environ.get("INCLUDE_MEMBER_ACCOUNTS", 'yes').lower() == 'yes'
REGIONS = [r.strip() for r in os.environ.get("REGIONS").split(',') if r]
ROLE_NAME = os.environ['ROLE_NAME']
ARCH = os.environ.get('ARCH', 'AWS_ARM64,CURRENT').split(',')

logger = logging.getLogger(__name__)
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO').upper(), logging.INFO))

def lambda_handler(event, context): #pylint: disable=unused-argument
    logger.info(f"Event data {json.dumps(event)}")
    if 'account' not in event:
        raise ValueError(
            "Please do not trigger this Lambda manually."
            "Find the corresponding state machine in Step Functions and Trigger from there."
        )
    account = json.loads(event["account"])
    payer_id = account["account_id"]
    try:
        result_messages = []
        error_messages = []
        for region in REGIONS:
            credentials = boto3.client('sts', region_name=region).assume_role(
                RoleArn=f"arn:aws:iam::{payer_id}:role/{ROLE_NAME}",
                RoleSessionName="data_collection"
            )["Credentials"]
            co = boto3.client(
                "compute-optimizer",
                region_name=region,
                aws_access_key_id=credentials['AccessKeyId'],
                aws_secret_access_key=credentials['SecretAccessKey'],
                aws_session_token=credentials['SessionToken'],
            )
            export_funcs = {
                'ec2_instance': partial(co.export_ec2_instance_recommendations, recommendationPreferences={'cpuVendorArchitectures': ARCH}),
                'auto_scale':   partial(co.export_auto_scaling_group_recommendations, recommendationPreferences={'cpuVendorArchitectures': ARCH}),
                'lambda':       co.export_lambda_function_recommendations,
                'ebs_volume':   co.export_ebs_volume_recommendations,
                'ecs_service':  co.export_ecs_service_recommendations,
                'license':      co.export_license_recommendations,
                'rds_database': partial(co.export_rds_database_recommendations, recommendationPreferences={'cpuVendorArchitectures': ARCH}),
            }
            bucket = BUCKET_PREFIX + '.' + region
            logger.info(f"INFO: bucket={bucket}")
            for name, func in export_funcs.items():
                try:
                    res = func(
                        includeMemberAccounts=INCLUDE_MEMBER_ACCOUNTS,
                        s3DestinationConfig={
                            'bucket': bucket,
                            'keyPrefix': date.today().strftime(
                                f'compute_optimizer/compute_optimizer_{name}/payer_id={payer_id}/year=%Y/month=%-m'
                            ),
                        }
                    )
                    result_messages.append(f"{region} {name} export queued. JobId: {res['jobId']}")
                except co.exceptions.LimitExceededException:
                    result_messages.append(f"{region} {name} export is already in progress.")
                except Exception as exc: #pylint: disable=broad-exception-caught
                    error_messages.append(f"ERROR: {region} {name} - {exc}")
        if result_messages:
            logger.info("Success:\n"+"\n".join(result_messages))
        if error_messages:
            raise Exception(f"There were {len(error_messages)} errors, out of {len(result_messages) + len(error_messages)} exports: \n" + "\n".join(error_messages)) #pylint: disable=broad-exception-raised
    except Exception as exc: #pylint: disable=broad-exception-caught
        logger.error(f"Error {type(exc).__name__} with message {exc}")
