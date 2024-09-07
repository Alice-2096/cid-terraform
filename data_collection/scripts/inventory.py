""" Scan linked accounts and store instances info to s3 bucket
Supported types: ebs, snapshots, ami, rds instances
"""
import os
import json
import logging
from functools import partial, lru_cache
from datetime import datetime, date, timezone

import boto3
from botocore.client import Config

TMP_FILE = "/tmp/data.json"
PREFIX = os.environ['PREFIX']
BUCKET = os.environ["BUCKET_NAME"]
ROLENAME = os.environ['ROLENAME']
REGIONS = [r.strip() for r in os.environ["REGIONS"].split(',') if r]
TRACKING_TAGS = os.environ.get("TRACKING_TAGS")
TAG_LIST = TRACKING_TAGS.split(",") if TRACKING_TAGS else []

logger = logging.getLogger(__name__)
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO').upper(), logging.INFO))

def to_json(obj):
    """json helper for date time data"""
    return json.dumps(
        obj,
        default=lambda x:
            x.isoformat() if isinstance(x, (date, datetime)) else None
    )

@lru_cache(maxsize=10000)
def assume_session(account_id, region):
    """assume role in account"""
    credentials = boto3.client('sts', region_name=region).assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/{ROLENAME}" ,
        RoleSessionName="data_collection"
    )['Credentials']
    return boto3.session.Session(
        aws_access_key_id=credentials['AccessKeyId'],
        aws_secret_access_key=credentials['SecretAccessKey'],
        aws_session_token=credentials['SessionToken']
    )

def paginated_scan(service, account_id, function_name, region, params=None, obj_name=None):
    """ paginated scan """
    obj_name = obj_name or function_name.split('_')[-1].capitalize() + '[*]'
    session = assume_session(account_id, region)
    client = session.client(service, region_name=region)
    try:
        yield from client.get_paginator(function_name).paginate(**(params or {})).search(obj_name)
    except Exception as exc:  #pylint: disable=broad-exception-caught
        logger.info(f'Error in scan {function_name}/{account_id}: {exc}')

def opensearch_domains_scan(account_id, region):
    """ special treatment for opensearch_scan """
    service = 'opensearch'
    session = assume_session(account_id, region)
    client = session.client(service, region_name=region)
    try:
        domain_names = [name.get('DomainName') for name in client.list_domain_names().get('DomainNames', [])]
        for domain_name in domain_names:
            domain = client.describe_domain(DomainName=domain_name)['DomainStatus']
            yield {
                'DomainName': domain['DomainName'],
                'DomainId': domain['DomainId'],
                'EngineVersion': domain['EngineVersion'],
                'InstanceType': domain['ClusterConfig']['InstanceType'],
                'InstanceCount': domain['ClusterConfig']['InstanceCount'],
            }
    except Exception as exc:  #pylint: disable=broad-exception-caught
        logger.info(f'scan {service}/{account_id}/{region}: {exc}')

def eks_clusters_scan(account_id, region):
    """special function to scan EKS clusters"""
    service = "eks"
    session = assume_session(account_id, region)
    client = session.client(service, region_name=region)
    try:
        for cluster_name in (
            client.get_paginator("list_clusters")
            .paginate(
                PaginationConfig={
                    "PageSize": 100,
                }
            )
            .search("clusters")
        ):
            cluster = client.describe_cluster(name=cluster_name)
            yield {
                "Arn": cluster["cluster"]["arn"],
                "Name": cluster["cluster"]["name"],
                "CreatedAt": datetime.strftime(
                    cluster["cluster"]["createdAt"].astimezone(tz=timezone.utc), "%Y-%m-%dT%H:%M:%SZ"
                ),
                "Version": cluster["cluster"]["version"],
            }
    except Exception as exc: #pylint: disable=W0718
        logger.error(f"Cannot get info from {account_id}/{region}: {type(exc)}-{exc}")
    return []

def lambda_handler(event, context): #pylint: disable=unused-argument
    """ this lambda collects ami, snapshots and volumes from linked accounts
    and must be called from the corresponding Step Function to orchestrate
    """
    logger.info(f"Event data: {event}")
    if 'account' not in event or 'params' not in event  :
        raise ValueError(
            "Please do not trigger this Lambda manually."
            "Find the corresponding state machine in Step Functions and Trigger from there."
        )
    params = [p for p in event.get('params', '').split() if p]
    name = params[0]

    sub_modules = {
        'opensearch-domains': opensearch_domains_scan, # special function for opensearch
        'elasticache-clusters': partial(
            paginated_scan,
            service='elasticache',
            function_name='describe_cache_clusters',
            obj_name='CacheClusters'
            # fields=['CacheClusterId', 'CacheNodeType', 'EngineVersion', 'Engine', 'NumCacheNodes', 'PreferredAvailabilityZone', 'CacheClusterCreateTime'],
        ),
        'rds-db-clusters': partial(
            paginated_scan,
            service='rds',
            function_name='describe_db_clusters',
            obj_name='DBClusters[*]'
        ),
        'rds-db-instances': partial(
            paginated_scan,
            service='rds',
            function_name='describe_db_instances',
            obj_name='DBInstances[*]'
        ),
        'rds-db-snapshots': partial(
            paginated_scan,
            service='rds',
            function_name='describe_db_snapshots',
            obj_name='DBSnapshots[*]'
        ),
        'ebs': partial(
            paginated_scan,
            service='ec2',
            function_name='describe_volumes'
        ),
        'ami': partial(
            paginated_scan,
            service='ec2',
            function_name='describe_images',
            params={'Owners': ['self']}
        ),
        'snapshot': partial(
            paginated_scan,
            service='ec2',
            function_name='describe_snapshots',
            params={'OwnerIds': ['self']}
        ),
        'ec2-instances': partial(
            paginated_scan,
            service='ec2',
            function_name='describe_instances',
            obj_name='Reservations[*].Instances[*][]'
        ),
        'vpc': partial(
            paginated_scan,
            service='ec2',
            function_name='describe_vpcs'
        ),
        'lambda-functions' : partial(
          paginated_scan,
          service='lambda',
          function_name='list_functions',
          obj_name='Functions[*]'
        ),
        'eks': eks_clusters_scan
    }

    account = json.loads(event["account"])
    account_id = account["account_id"]
    payer_id = account["payer_id"]
    func = sub_modules[name]
    counter = 0
    logger.info(f"Collecting {name} for account {account_id}")
    collection_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(TMP_FILE, "w", encoding='utf-8') as file_:
            for region in REGIONS:
                logger.info(f"Collecting in {region}")
                for counter, obj in enumerate(func(account_id=account_id,region=region), start=counter + 1):
                    obj['accountid'] = account_id
                    if len(TAG_LIST) > 0 and "Tags" in obj:
                        logger.debug(f"Tags enabled and found tags {obj['Tags']}")
                        for tag in obj["Tags"]:
                            if tag["Key"] in TAG_LIST:
                                obj[f"tag_{tag['Key']}"] = tag["Value"]
                    obj['collection_date'] = collection_date
                    obj['region'] = region
                    if 'Environment' in obj and name == 'lambda-functions':
                        obj['Environment'] = to_json(obj['Environment']) # this property breaks crawler as it has a different key structure
                    file_.write(to_json(obj) + "\n")
        logger.info(f"Collected {counter} total {name} instances")
        upload_to_s3(name, account_id, payer_id)
    except Exception as exc:   #pylint: disable=broad-exception-caught
        logger.info(f"{name}: {type(exc)} - {exc}" )

def upload_to_s3(name, account_id, payer_id):
    """upload"""
    if os.path.getsize(TMP_FILE) == 0:
        logger.info(f"No data in file for {name}")
        return
    key =  datetime.now().strftime(
        f"{PREFIX}/{PREFIX}-{name}-data/payer_id={payer_id}"
        f"/year=%Y/month=%m/day=%d/{account_id}-%Y-%m-%d.json"
    )
    s3client = boto3.client("s3", config=Config(s3={"addressing_style": "path"}))
    try:
        s3client.upload_file(TMP_FILE, BUCKET, key)
        logger.info(f"Data {account_id} in s3 - {BUCKET}/{key}")
    except Exception as exc:  #pylint: disable=broad-exception-caught
        logger.info(exc)
