import boto3
import logging
import os
from distutils.log import error

from symbol import try_stmt

# Set up logging
logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

# Initialise session
session = boto3.Session(region_name="eu-central-1")
logger.info("Boto3 session started...")

# Set parameters
queue_url = os.environ["queue_url"]

def retrieveMessages(sqs_client, queue_url):

    try:
        res = sqs_client.receive_message(
            QueueUrl = queue_url,
            AttributeNames = [
                "All"
            ],
            MessageAttributeNames = [
                "_MessageSent"
            ],
            MaxNumberOfMessages = 1,
            VisibilityTimeout = 12,
            WaitTimeSeconds = 10    # Long polling time
        )
        logger.info("Messages received...")
    except:
        logger.info("Error polling for messages...")
    else:
        logger.info("SQS call returned...")

    return res

def str_to_dict(payload):
    import json

    payload = payload.replace("[","")
    payload = payload.replace("]","")
    payloadjson = json.loads(payload)

    return payloadjson

def DeleteReceivedMessage(sqs_client, queue_url, receipt_handle):

    try:
        res = sqs_client.delete_message(
            QueueUrl = queue_url,
            ReceiptHandle = receipt_handle
        )
    except sqs_client.exceptions.ReceiptHandleIsInvalid:
        logger.debug(f"ReceiptHandle {receipt_handle} was invalid")
    except:
        logger.info("Something went wrong with the delete call...")
        logger.debug(error)
    else:
        logger.info("Message deleted from SQS queue...")
        return res


def handler(event, context):

    # tmp directory create
    cwd = os.getcwd()
    parent = os.path.join(cwd, os.pardir)
    grandparent = os.path.join(parent, os.pardir)
    tmpfiles = os.path.join(grandparent, "tmp")

    ### RETRIEVE MESSAGES
    # Set up client
    sqs = session.client("sqs")
    logger.info("Sqs client initiated...")

    # Retrieve messages
    res = retrieveMessages(sqs, queue_url)
    # Check for message content
    logger.info(res)
    if "Messages" not in res:
        logger.info("No new messages, exit function...")
        return None

    payload = res["Messages"][0]["Body"]
    # Create dict from payload string
    payload = str_to_dict(payload)
    # Add timestamp
    ts = res["Messages"][0]["MessageAttributes"]["_MessageSent"]
    payload["_MessageSent"] = ts
    # Get receipt handle
    receipt_handle = res["Messages"][0]["ReceiptHandle"]

    # Write to DB (Spoof)
    filepath = os.path.join(tmpfiles,"testdump.csv")
    try:
        with open(filepath, "w") as f:
            for key in payload.keys():
                f.write("%s,%s\n"%(key,payload[key]))
    except:
        logger.debug("write to csv failed")
    else:
        logger.info(f"Data written to db... {filepath}")
        res = DeleteReceivedMessage(sqs, queue_url, receipt_handle)
        