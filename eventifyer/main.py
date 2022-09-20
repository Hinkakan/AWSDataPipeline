import json
import os
import boto3
import shutil
import logging
import pandas as pd
from distutils.log import error
import datetime

# Set up logging
logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)


def deleteDir(tmpfiles):
    # Delete any old tmpfiles
    try:
        shutil.rmtree(os.path.abspath(tmpfiles), ignore_errors=True)
    except:
        logger.info("No files to remove")
    else:
        logger.info("Cleaned old files and directory")


def createDir(tmpfiles):
    # Create tmp files directory
    try:
        os.mkdir(os.path.abspath(tmpfiles))
    except:
        logger.debug("Directory already exist")
    else:
        logger.info("Created files directory")


def send_event(parent):
    # Temp function to imitate sending data as json event to handler
    filepath = os.path.abspath(os.path.join(parent, "test.json"))
    with open(filepath, "r") as f:
        event = json.loads(f.read())
    return event


def s3_download_file(bucket, obj, dest):
    s3 = session.client("s3")

    try:
        s3.download_file(
            Bucket=bucket,
            Key=obj,
            Filename=dest
        )
    except:
        logger.info(f"Error downloading {obj} to {dest}...")
        logger.debug(error)
    else:
        logger.info(f"Successfully downloaded {obj} to {dest}...")


def send_to_sqs(payload):
    sqs = session.client("sqs")
    ts = datetime.datetime.utcnow().isoformat()
    # Set this up as environment variable for lambda
    Queue_Url = "https://sqs.eu-central-1.amazonaws.com/173471538789/PipelineSQSQueue"
    print(ts)
    response = sqs.send_message(
        QueueUrl=Queue_Url,
        MessageBody=payload,
        MessageAttributes={
            "_MessageSent": {
                "DataType": "String",
                "StringValue": ts
            }
        }
    )
    id = response["MessageId"]
    httpStatus = response["ResponseMetadata"]["HTTPStatusCode"]
    logger.info(f"Message {id} sent with status: {httpStatus}...")


def handler(event, context):
    # Fish out bucket and object name from event payload
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    obj = event["Records"][0]["s3"]["object"]["key"]
    logger.info(f"Get {obj} from {bucket}...")
    obj = "data_1663585237.3305495.csv"  # Delete for actual lambda
    bucket = "stagingbucket010001"  # Delete for actual lambda
    dest = os.path.abspath(os.path.join(cwd, tmpfiles, obj))

    # Download file
    s3_download_file(bucket, obj, dest)

    # Eventify data
    df = pd.read_csv(dest)
    rows = len(df.index)

    for i in range(0, rows):
        tmp_df = df
        row = tmp_df.iloc[[i], :]

        # Convert to JSON
        payload = row.to_json(orient="records")
        send_to_sqs(payload)

    # SQS part (documenation https://boto3.amazonaws.com/v1/documentation/api/latest/guide/sqs-example-sending-receiving-msgs.html
    # https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/sqs.html#SQS.Client.send_message)
    # https: // sqs.eu-central-1.amazonaws.com/173471538789/PipelineSQSQueue


### START OF CODE ###
cwd = os.getcwd()
parent = os.path.join(cwd, os.pardir)
tmpfiles = os.path.join(cwd, "tmp")

session = boto3.Session(region_name="eu-central-1")

# Clean up any old data and create tmp directory
deleteDir(tmpfiles)
createDir(tmpfiles)  # Not needed for lambda

e = send_event(parent)

handler(e, None)


# Code for retrieving sqs messages

# res = sqs.receive_message(
#     QueueUrl=Queue_Url,
#     AttributeNames=["All"],
#     MessageAttributeNames=[
#         "_MessageSent"
#     ],
#     MaxNumberOfMessages=1,
#     WaitTimeSeconds=10
# )
# print(res)
