terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
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
  message_retention_seconds  = 600
  receive_wait_time_seconds  = 10
}
