terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
}

# Create S3 bucket for data
resource "aws_s3_bucket" "stagingBucket" {
  bucket        = "stagingbucket010001"
  force_destroy = true
}

# Docs for S3 event notification structure: https://docs.aws.amazon.com/AmazonS3/latest/userguide/notification-content-structure.html

# Create SQS queue for the individual messages
resource "aws_sqs_queue" "PipelineSQSQueue" {
  name                       = "PipelineSQSQueue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 3600
  receive_wait_time_seconds  = 10
}

module "identifyer_lambda" {
  source = ".\\tf-modules\\lambda"
  StagingbucketArn = aws_s3_bucket.stagingBucket.arn
  PipelineSqsQueueArn = aws_sqs_queue.PipelineSQSQueue.arn
  PipelineSqsQueueURL = aws_sqs_queue.PipelineSQSQueue.url
}

# lambda bundling articles
# https://medium.com/rockedscience/hard-lessons-from-deploying-lambda-functions-with-terraform-4b4f98b8fc39
# https://alek-cora-glez.medium.com/deploying-aws-lambda-function-with-terraform-custom-dependencies-7874407cd4fc

output "s3Bucket" {
  value = aws_s3_bucket.stagingBucket.bucket  
}

output "sqsURL" {
  value = aws_sqs_queue.PipelineSQSQueue.url  
}

output "sqsARN" {
  value = aws_sqs_queue.PipelineSQSQueue.arn
}

# Need to output the SQS ARN and use as environment variable for lambda
