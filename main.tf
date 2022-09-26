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

# CREATE S3 BUCKET
resource "aws_s3_bucket" "stagingBucket" {
  bucket        = "stagingbucket010001"
  force_destroy = true
}

# Docs for S3 event notification structure: https://docs.aws.amazon.com/AmazonS3/latest/userguide/notification-content-structure.html

# CREATE SQS QUEUE
resource "aws_sqs_queue" "PipelineSQSQueue" {
  name                       = "PipelineSQSQueue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 3600
  receive_wait_time_seconds  = 10
}

### GENERIC LAMBDA LOGGING POLICY
# Role for sending logs
resource "aws_iam_policy" "function_logging_policy" {
  name = "lambda_function_logging_policy"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

### CREATE EVENTIFYER LAMBDA

# Role policy
resource "aws_iam_policy" "eventifyer_role_policy" {
  name = "eventifyer_role_policy"
  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Action: [
          "s3:GetObject"
        ],
        Effect: "Allow"
        Resource: "${aws_s3_bucket.stagingBucket.arn}/*"
      },
      {
        Action: [
          "sqs:SendMessage"
        ],
        Effect: "Allow",
        Resource: "${aws_sqs_queue.PipelineSQSQueue.arn}"
      }
    ]
  })
}

module "eventifyer_lambda" {
  # depends_on = [
  #   aws_iam_policy.eventifyer_role_policy
  # ]
  #### This breaks the data.archive thing
  source = ".\\tf-modules\\lambda"
  functionName = "Eventifyer"
  FunctionRolePolicyArn = aws_iam_policy.eventifyer_role_policy.arn
  PipelineSqsQueueURL = aws_sqs_queue.PipelineSQSQueue.url
  FunctionLoggingPolicyArn = aws_iam_policy.function_logging_policy.arn
}

### CREATE INGESTER LAMBDA
resource "aws_iam_policy" "ingester_role_policy" {
  name = "ingester_role_policy"
  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Action: [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage"
        ],
        Effect: "Allow",
        Resource: "${aws_sqs_queue.PipelineSQSQueue.arn}"
      }
    ]
  })  
}

# data "aws_iam_policy_document" "ingester_role_policy_document" {
#   statement {
#     actions = [
#       "sqs:ReceiveMessage",
#       "sqs:DeleteMessage"
#     ]
#     effect = "Allow"
#     resources = ["${aws_sqs_queue.PipelineSQSQueue.arn}"]
#   }
# }

# resource "aws_iam_policy" "ingester_role_policy" {
#   name = "ingester_role_policy"
#   policy = data.aws_iam_policy_document.ingester_role_policy_document.json
# }

module "ingester_lamda" {
  source = ".\\tf-modules\\lambda"
  functionName = "Ingester"
  PipelineSqsQueueURL = aws_sqs_queue.PipelineSQSQueue.url
  FunctionRolePolicyArn = aws_iam_policy.ingester_role_policy.arn
  FunctionLoggingPolicyArn = aws_iam_policy.function_logging_policy.arn
}

### CREATE BUCKET NOTIFICATION

resource "aws_lambda_permission" "notification_permission" {
  action = "lambda:InvokeFunction"
  function_name = module.eventifyer_lambda.lambda_arn
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.stagingBucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.stagingBucket.id

  lambda_function {
    lambda_function_arn = module.eventifyer_lambda.lambda_arn
    events = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.notification_permission,
    module.eventifyer_lambda
  ]
}

# lambda bundling articles
# https://medium.com/rockedscience/hard-lessons-from-deploying-lambda-functions-with-terraform-4b4f98b8fc39
# https://alek-cora-glez.medium.com/deploying-aws-lambda-function-with-terraform-custom-dependencies-7874407cd4fc


# Need to output the SQS ARN and use as environment variable for lambda
