import boto3
import logging
import os
import json

# Set up logging
logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

# Initialise session
session = boto3.Session(region_name="eu-central-1")
logger.info("Boto3 session started...")

# Set parameters
queue_url = os.environ["queue_url"]

# Since retrieval of messages and deletion of successfully parsed messages is build in the sqs trigger, we do not need that part here

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

def handler(event, context):

    logger.info(f"Received message: {event}")
    # Parse out data from message
    payload = event["Records"][0]["body"][0]
    print(payload)
    # Create dict from payload string
    payload = json.loads(payload)
    # Add timestamp
    ts = event["Records"][0]["messageAttributes"]["_MessageSent"]["stringValue"]
    payload["_MessageSent"] = ts

    ### WRITE TO DB ###
    # Initiate Boto Client
    rds = session.client("rds-data")
    write_to_db(rds, payload)
