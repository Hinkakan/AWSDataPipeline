import pandas as pd
import os
import random
import logging
import shutil
import time
import boto3
from botocore.exceptions import ClientError

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

# Get directory paths
cwd = os.getcwd()
parent = os.path.join(cwd, os.pardir)
sourcepath = os.path.abspath(os.path.join(parent, "data", "Data.csv"))
tmpfiles = os.path.join(parent, "tmpfiles")


def deleteDir(tmpfiles):
    # Delete any old tmpfiles
    try:
        shutil.rmtree(tmpfiles, ignore_errors=True)
    except:
        logger.info("No files to remove")
    else:
        logger.info("Cleaned old files and directory")


def createDir(tmpfiles):
    # Create tmp files directory
    try:
        os.mkdir(tmpfiles)
    except:
        logger.debug("Directory already exist")
    else:
        logger.info("Created files directory")


def sendToS3(filepath, filename):

    # Create client
    session = boto3.Session(region_name="eu-central-1")
    s3 = session.client("s3")
    bucket = "stagingbucket010001"

    try:
        response = s3.upload_file(filepath, bucket, filename)
    except ClientError as e:
        logger.error(e)
    else:
        logger.info(f"Uploaded file {filename}, containing to S3")


def handler():

    deleteDir(tmpfiles)
    createDir(tmpfiles)

    df = pd.read_csv(sourcepath)

    # Generate 1 to 5 rows of data
    rows = random.randint(1, 5)
    logger.info(f"Generating {rows} rows of data")

    for i in range(rows):
        tmp_df = df     # iloc changes the dataframe, so need to make a copy
        rn = random.randint(0, 168)
        row = tmp_df.iloc[[rn], :]
        if i != 0:
            sample_df = pd.concat([sample_df, row])
        else:
            sample_df = row

    # Write data file to tmp directory
    ts = str(time.time())
    filename = f"data_{ts}.csv"
    destpath = os.path.join(tmpfiles, filename)
    sample_df.to_csv(destpath, index=False)

    # Send data to S3
    sendToS3(destpath, filename)

    deleteDir(tmpfiles)


handler()
