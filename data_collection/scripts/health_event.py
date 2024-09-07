import os
import json
import uuid
import logging
import jmespath
import socket
from datetime import date, datetime, timedelta, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO').upper(), logging.INFO))

BUCKET_NAME = os.environ['BUCKET_NAME']
ROLENAME = os.environ['ROLENAME']
PREFIX = os.environ['PREFIX']
REGIONS = [r.strip() for r in os.environ.get("REGIONS", "").split(',') if r]
if len(REGIONS) > 0:
    REGIONS.append('global')
LOOKBACK = int(os.environ['LOOKBACK'])
DETAIL_SM_ARN = os.environ['DETAIL_SM_ARN']
TMP_FILE = "/tmp/data.json"

mapping = {
    'payer_account_id': 'payer_account_id',
    'account_id': 'awsAccountId',
    'event_code': 'event.eventTypeCode',
    'event_category': 'event.eventTypeCategory',
    'event_scope': 'event.eventScopeCode',
    'status_code': 'event.statusCode',
    'service': 'event.service',
    'region': 'event.region',
    'event_description': 'eventDescription.latestDescription',
    'affected_entity_value': 'entityValue',
    'affected_entity_arn': 'entityArn',
    'affected_entity_status_code': 'entityStatusCode',
    'affected_entity_last_update': 'entityLastUpdatedTime',
    'affected_entity_url': 'entityUrl',
    'availability_zone': 'event.availabilityZone',
    'deprecated_versions': 'deprecated_versions',
    'tags': 'tags',
    'start_time': 'event.startTime',
    'end_time': 'event.endTime',
    'last_updated_time': 'event.lastUpdatedTime',
    'event_metadata': 'eventMetadata',
    'event_source': 'event_source',
    'event_arn': 'event.arn',
    'ingestion_time': 'ingestion_time',
}

time_fields_to_convert = ['start_time', 'end_time', 'last_updated_time', 'affected_entity_last_update']

def to_json(obj):
    """json helper for date, time and data"""
    def _date_transformer(obj):
        return obj.isoformat() if isinstance(obj, (date, datetime)) else None
    return json.dumps(obj, default=_date_transformer)

def chunks(lst, n):
    """Yield successive n-sized chunks from a list."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

def event_item_to_date(event, keys):
    for key in keys:
        if isinstance(event.get(key), int):
            event[key] = int_to_datetime(event[key])
    return event

def int_to_datetime(int_time):
    return datetime.datetime.utcfromtimestamp(int_time/1000)

def iterate_paginated_results(client, function, search, params=None):
    yield from client.get_paginator(function).paginate(**(params or {})).search(search)

def calculate_dates(bucket, s3_path):
    """ Timeboxes the range of events by seeking the most recent data collection date from the last 90 days """
    end_date = datetime.now(timezone.utc)
    start_date = end_date - timedelta(days=LOOKBACK)
    # Check the create time of objects in the S3 bucket
    contents = boto3.client('s3').get_paginator('list_objects_v2').paginate(
        Bucket=bucket,
        Prefix=s3_path
    ).search('Contents')
    start_date = max([obj['LastModified'] for obj in contents if obj] + [start_date])
    return start_date, end_date


def search(function, args=None, expression='@'):
    compiled = jmespath.compile(expression)
    args = args or {}
    while True:
        page = function(**args)
        results = compiled.search(dict(page))
        if isinstance(results, list):
            yield from results
        else:
            # Yield result directly if it is not a list.
            yield results
        if 'nextToken' in page and page['nextToken']:
            args['nextToken'] = page['nextToken']
        else:
            break

def pull_event_details(event, health_client):
    event_arn = event['arn']
    if event['eventScopeCode'] == 'PUBLIC':
        accounts = [None]
    else:
        accounts = list(search(
            function=health_client.describe_affected_accounts_for_organization,
            args={'eventArn': event_arn},
            expression='affectedAccounts',
        ))

    # describe_event_details_for_organization only can get 10 per call
    details = []
    affected_entities = []
    for account_chunk in list(chunks(accounts, 10)):
        if account_chunk[0]:
            filters = [{'eventArn':event_arn, 'awsAccountId': account} for account in account_chunk]
        else:
            filters = [{'eventArn':event_arn}]
        details += list(search(
            function=health_client.describe_event_details_for_organization,
            args=dict(
                organizationEventDetailFilters=filters
            ),
            expression='successfulSet',
        ))
        affected_entities += list(search(
            function=health_client.describe_affected_entities_for_organization,
            args=dict(
                organizationEntityFilters=filters
            ),
            expression='entities',
        ))

    # merge with details and affected entities
    event_details_per_affected = []
    if len(affected_entities) == 0:
        event = {**event, **details[0]}
        event_details_per_affected.append(event)
    for affected_entity in affected_entities:
        account = affected_entity['awsAccountId']
        event_arn = affected_entity['eventArn']
        affected_entity['entityStatusCode'] = affected_entity.pop('statusCode', None)
        affected_entity['entityLastUpdatedTime'] = affected_entity.pop('lastUpdatedTime', None)
        detail = jmespath.search(f"[?awsAccountId=='{account}']|[?event.arn=='{event_arn}']", details)
        for detail_rec in detail:
            metadata = detail_rec.get('eventMetadata') or {}
            deprecated_versions = metadata.pop('deprecated_versions', None)
            if deprecated_versions:
                event['deprecated_versions'] = deprecated_versions
            if len(metadata) == 0:
                event['eventMetadata'] = ""
        merged_dict = {**event, **affected_entity}
        if len(detail) > 0:
            merged_dict = {**merged_dict, **detail[0]}
        event_details_per_affected.append(merged_dict)
    return event_details_per_affected

def get_active_health_region():
    """
    Get the active AWS Health region from the global endpoint
    See: https://docs.aws.amazon.com/health/latest/ug/health-api.html#endpoints
    """

    default_region = "us-east-1"

    try:
        (active_endpoint, _, _) = socket.gethostbyname_ex("global.health.amazonaws.com")
    except socket.gaierror:
        return default_region

    split_active_endpoint = active_endpoint.split(".")
    if len(split_active_endpoint) < 2:
        return default_region

    active_region = split_active_endpoint[1]
    return active_region

def lambda_handler(event, context): #pylint: disable=unused-argument
    """ this lambda collects AWS Health Events data
    and must be called from the corresponding Step Function to orchestrate
    """
    logger.info(f"Event data: {event}")
    account = event.get('account')
    batch_input = event.get('BatchInput')
    items = event.get('Items')
    if not (account or batch_input):
        raise ValueError(
            "Please do not trigger this Lambda manually."
            "Find the corresponding state machine in Step Functions and Trigger from there."
        )
    is_summary_mode = batch_input == None
    logger.info(f"Executing in {'summary' if is_summary_mode else 'detail'} mode flow")
    account = json.loads(account) if is_summary_mode else batch_input.get('account')
    account_id = account["account_id"]

    creds = boto3.client('sts').assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/{ROLENAME}",
        RoleSessionName="data_collection"
    )['Credentials']
    health_client = boto3.client(
        'health',
        region_name=get_active_health_region(),
        aws_access_key_id=creds['AccessKeyId'],
        aws_secret_access_key=creds['SecretAccessKey'],
        aws_session_token=creds['SessionToken'],
    )

    count = 0
    if is_summary_mode:
        start_from, start_to = calculate_dates(BUCKET_NAME, f"{PREFIX}/{PREFIX}-summary-data/payer_id={account_id}")
        logger.info(f"Collecting events from {start_from} to {start_to}")
        args = {
            'maxResults':100,
            'filter': {
                'lastUpdatedTime': {
                    'from': start_from.strftime('%Y-%m-%dT%H:%M:%S%z'),
                },
            }
        }
        if len(REGIONS) > 0:
            args['filter']['regions'] = REGIONS

        ingestion_time = datetime.now(timezone.utc)
        try:
            with open(TMP_FILE, "w", encoding='utf-8') as f:
                f.write('eventArn,eventScopeCode\n')
                for _, h_event in enumerate(search(health_client.describe_events_for_organization, args, expression='events')):
                    f.write(f'{h_event["arn"]},{h_event["eventScopeCode"]}\n')
                    count += 1
            if count > 0:
                key = ingestion_time.strftime(f"{PREFIX}/{PREFIX}-summary-data/payer_id={account_id}/year=%Y/month=%m/day=%d/%Y-%m-%d.csv")
                boto3.client('s3').upload_file(TMP_FILE, BUCKET_NAME, key)
                logger.info(f'Uploaded {count} summary records to s3://{BUCKET_NAME}/{key}')
                # clear any previous runs for the same day
                bucket = boto3.resource('s3').Bucket(BUCKET_NAME)
                bucket.objects.filter(Prefix=ingestion_time.strftime(f"{PREFIX}/{PREFIX}-detail-data/payer_id={account_id}/year=%Y/month=%m/day=%d")).delete()
                sf = boto3.client('stepfunctions')
                sf_input = {
                    "bucket": BUCKET_NAME,
                    "file": key,
                    "account": account,
                    "ingestion_time": int(round(ingestion_time.timestamp()))
                }
                sf_input = json.dumps(sf_input).replace('"', '\"') #need to escape the json for SF
                sf.start_execution(stateMachineArn=DETAIL_SM_ARN, input=sf_input)
            else:
                logger.info(f"No records found")
        except Exception as exc:
            if 'Organizational View feature is not enabled' in str(exc):
                logger.error(f"Payer {account_id} does not have Organizational View. See https://docs.aws.amazon.com/health/latest/ug/enable-organizational-view-in-health-console.html")
            else:
                logger.error(f"Error: {exc}")

    elif items:
        ingestion_time = datetime.fromtimestamp(int(batch_input.get('ingestion_time')))

        with open(TMP_FILE, "w", encoding='utf-8') as f:
            for item in items:
                h_event = {'arn': item['eventArn'], 'eventScopeCode': item['eventScopeCode']}
                h_event['payer_account_id'] = account_id
                h_event['event_source'] = "aws.health"
                h_event['ingestion_time'] = ingestion_time
                all_detailed_events = pull_event_details(h_event, health_client)
                flatten_events = jmespath.search("[].{"+', '.join([f'{k}: {v}' for k, v in mapping.items()]) + "}", all_detailed_events)
                for flatten_event in flatten_events:
                    flatten_event = event_item_to_date(flatten_event, time_fields_to_convert)
                    # metadata structure can vary and cause schema change issues, force to string
                    metadata = flatten_event.get('event_metadata')
                    metadata = json.dumps(metadata) if (not isinstance(metadata, str)) and (metadata != None) else metadata
                    flatten_event['event_metadata'] = metadata
                    f.write(to_json(flatten_event) + '\n')
                    count += 1
        if count > 0:
            rand = uuid.uuid4()
            key = ingestion_time.strftime(f"{PREFIX}/{PREFIX}-detail-data/payer_id={account_id}/year=%Y/month=%m/day=%d/%Y-%m-%d-%H-%M-%S-{rand}.json")
            boto3.client('s3').upload_file(TMP_FILE, BUCKET_NAME, key)
            logger.info(f'Uploaded {count} summary records to s3://{BUCKET_NAME}/{key}')
    return {"status":"200","Recorded":f'"{count}"'}
