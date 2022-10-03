import boto3
import logging
import os

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
    except Exception as e:
        logger.info(e)
        raise
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

def write_to_db(rds_client, payload):
    
    cluster_arn = os.environ["cluster_arn"]
    secret_arn = os.environ["secret_arn"]
    table = "ds"

    # Build SQL Statement
    SQL = f"INSERT INTO {table} (Id, Race, Class, Role, Faction, First_Expansion, _MessageSent) VALUES ({payload['Id']}, '{payload['Race']}', '{payload['Class']}', '{payload['Role']}', '{payload['Faction']}', '{payload['First_Expansion']}', '{payload['_MessageSent']}')"

    try:
        logger.info(f"Writing: {SQL}")
        rds_client.execute_statement(
        resourceArn = cluster_arn,
        secretArn = secret_arn,
        database = "pipelinedb",
        sql = SQL
        )
    except Exception as e:
        logger.info("Error when writing to DB...")
        logger.info(e)
        raise
    else:
        logger.info("Successfully written to db..")
        return 200


def DeleteReceivedMessage(sqs_client, queue_url, receipt_handle):

    try:
        res = sqs_client.delete_message(
            QueueUrl = queue_url,
            ReceiptHandle = receipt_handle
        )
    except sqs_client.exceptions.ReceiptHandleIsInvalid:
        logger.debug(f"ReceiptHandle {receipt_handle} was invalid")
        raise
    except Exception as e:
        logger.info("Something went wrong with the delete call...")
        logger(e)
        raise
    else:
        logger.info("Message deleted from SQS queue...")
        return res


def handler(event, context):

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
    ts = res["Messages"][0]["MessageAttributes"]["_MessageSent"]["StringValue"]
    payload["_MessageSent"] = ts
    # Get receipt handle
    receipt_handle = res["Messages"][0]["ReceiptHandle"]

    ### WRITE TO DB ###
    # Initiate Boto Client
    rds = session.client("rds-data")
    if write_to_db(rds, payload) == 200:
        DeleteReceivedMessage(sqs, queue_url, receipt_handle)
