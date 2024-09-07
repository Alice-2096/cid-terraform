import os
import json
import urllib3
import logging

import boto3

logger = logging.getLogger(__name__)
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO').upper(), logging.INFO))

OFFERS_URL = 'https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/index.json'
BASE_URL = '/'.join(OFFERS_URL.split('/')[:3])
CODE_BUCKET = os.environ['CODE_BUCKET']
BUCKET_NAME = os.environ["BUCKET_NAME"]
PREFIX = os.environ["DEST_PREFIX"]
REGIONS = [r.strip() for r in os.environ["REGIONS"].split(',') if r]
TMP_FILE = "/tmp/data.json"
RDS_GRAVITON_PATH = os.environ["RDS_GRAVITON_PATH"]

def get_json(url):
    return json.loads(urllib3.PoolManager().request('GET', url).data)

def upload_pricing(service, path):
    s3 = boto3.client('s3')
    http = urllib3.PoolManager()
    offers = get_json(OFFERS_URL)['offers']

    errors = ''

    logger.info(f'Getting regional pricing for {service}')
    try:
        if service == 'AWSComputeSavingsPlan':
            url = offers['AmazonEC2']['currentSavingsPlanIndexUrl']
        else:
            url = offers[service]['currentRegionIndexUrl']
        regions = get_json(BASE_URL + url)["regions"]
    except Exception as exc:
        err = f'{service}: {exc}'
        logger.warning(err)
        return {
            'statusCode': 500,
            'errors': err,
        }
    logger.debug(f"Regions {json.dumps(regions)}")
    if isinstance(regions, dict): # pricing data has different formats
        regions = regions.values()

    # pull pricing for each region
    for region in regions:
        region_code = region["regionCode"]
        if REGIONS and (region_code not in REGIONS):
            logger.debug(f'Filtering out {region_code}')
            continue
        try:
            version_url =  region.get("versionUrl") or region.get("currentVersionUrl")
            assert version_url
            region_url = BASE_URL + version_url.replace(".json", ".csv")

            # Starting Download
            file_obj = http.request('GET', region_url, preload_content=False)

            # Skip 5 lines
            for _ in range(5):
                file_obj.readline()

            # Upload
            key = f"pricing/pricing-{path}-data/region={region_code}/index.csv"
            res = s3.upload_fileobj(Fileobj=file_obj, Bucket=BUCKET_NAME, Key=key)
            logger.debug(f'{res} Uploaded to s3://{BUCKET_NAME}/{key}')
        except Exception as exc:
            err = f'{service}/{region_code}: {exc}'
            logger.warning(err)
            logger.exception(exc)
            errors += err + '\n'
            raise
    return {
        'statusCode': 200,
        'errors': errors,
    }

def s3copy(src_bucket, src_key, dest_bucket, dest_key):
    boto3.resource('s3').Bucket(dest_bucket).copy({
          'Bucket': src_bucket,
          'Key': src_key
        },
        dest_key
    )
    print(f'added file {dest_key}')

def process_region_list(regions):
    logger.info(f"Processing region list {regions}")
    ssm_client = boto3.client('ssm')
    lines = []
    for region in regions:
        long_name = ssm_client.get_parameter(Name=f"/aws/service/global-infrastructure/regions/{region}/longName")["Parameter"]["Value"]
        lines.append(",".join([region,long_name,f"rds.{region}.amazonaws.com","HTTPS"]))

    with open(TMP_FILE, "w") as f:
        f.write("Region,Long Name,Endpoint,Protocol\n")
        f.write("\n".join(lines))

    # Upload
    key = f"pricing/pricing-regionnames-data/pricing_region_names/pricing_region_names.csv"
    res = boto3.client('s3').upload_file(TMP_FILE, Bucket=BUCKET_NAME, Key=key)
    logger.info(f"Uploaded pricing_region_names")
    return {
        'statusCode': 200
    }

def lambda_handler(event, context):
    logger.info(f"Incoming event: {event}")
    try:
        service = event['service']
        path = event['path']
    except Exception as exc:
        logger.error('please provide service and path')
        raise Exception(f'({type(exc).__name__}) raised. Please provide service and path parameters.')

    if service == "RegionNames":
        res = process_region_list(REGIONS)
        return {
            'statusCode': 200,
            'body': {service: res}
        }
    else:
        res = upload_pricing(service, path)

    # FIXME: move it to separate lambda?
    try:
        s3copy(
            CODE_BUCKET, RDS_GRAVITON_PATH,
            BUCKET_NAME, 'pricing/pricing-rdsgraviton-data/rds_graviton_mapping.csv',
        )
    except Exception as exc:
        res['errors'] += f'rds_graviton_mapping: {exc}'

    return {
        'statusCode': 200,
        'body': {service: res}
    }
