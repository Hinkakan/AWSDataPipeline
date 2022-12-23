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

  backend "s3" {
    bucket = "hinkakanterraformbackend"
    key    = "awsdatapipeline"
    region = "eu-central-1"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
}

# CREATE S3 BUCKET
resource "aws_s3_bucket" "stagingBucket" {
  bucket        = "stagingbucket010001_${terraform.workspace}"
  force_destroy = true
}

# CREATE SQS QUEUE
resource "aws_sqs_queue" "PipelineSQSQueue" {
  name                       = "PipelineSQSQueue_${terraform.workspace}"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 3600
  receive_wait_time_seconds  = 10
}

### GENERIC LAMBDA LOGGING POLICY
# Role for sending logs
resource "aws_iam_policy" "function_logging_policy" {
  name = "lambda_function_logging_policy_${terraform.workspace}"
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

### CREATE SERVERLESS AURORA RDS ###

module "aurora_rds" {
  source             = ".\\tf-modules\\AuroraServerless"
  cluster_identifier = "aurorapostgres${terraform.workspace}"
  database_name      = "pipelinedb"
  master_username    = "bjarki"
}

### CREATE EVENTIFYER LAMBDA

# Role policy
resource "aws_iam_policy" "eventifyer_role_policy" {
  name = "eventifyer_role_policy_${terraform.workspace}"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : [
          "s3:GetObject"
        ],
        Effect : "Allow"
        Resource : "${aws_s3_bucket.stagingBucket.arn}/*"
      },
      {
        Action : [
          "sqs:SendMessage"
        ],
        Effect : "Allow",
        Resource : "${aws_sqs_queue.PipelineSQSQueue.arn}"
      }
    ]
  })
}

module "eventifyer_lambda" {
  # depends_on = [
  #   aws_iam_policy.eventifyer_role_policy
  # ]
  #### This breaks the data.archive thing
  source                   = "./tf-modules/lambda"
  functionName             = "eventifyer_${terraform.workspace}"
  FunctionRolePolicyArn    = aws_iam_policy.eventifyer_role_policy.arn
  FunctionLoggingPolicyArn = aws_iam_policy.function_logging_policy.arn
  EnvironmentVars = {
    queue_url = aws_sqs_queue.PipelineSQSQueue.url
  }
}

# Bucket notification trigger for lambda
resource "aws_lambda_permission" "notification_permission" {
  action        = "lambda:InvokeFunction"
  function_name = module.eventifyer_lambda.lambda_function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.stagingBucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.stagingBucket.id

  lambda_function {
    lambda_function_arn = module.eventifyer_lambda.lambda_arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.notification_permission,
    module.eventifyer_lambda
  ]
}

### CREATE BATCHINGESTER LAMBDA

# resource "aws_iam_policy" "batchingester_role_policy" {
#   name = "batchingester_role_policy_${terraform.workspace}"
#   policy = jsonencode({
#     Version: "2012-10-17",
#     Statement: [
#       {
#         Action: [
#           "sqs:ReceiveMessage",
#           "sqs:DeleteMessage",
#           "sqs:GetQueueAttributes"
#         ],
#         Effect: "Allow",
#         Resource: "${aws_sqs_queue.PipelineSQSQueue.arn}"
#       }
#     ]
#   })  
# }

# module "batchingester_lambda" {
#   source = "./tf-modules/lambda"
#   functionName = "batchingester_${terraform.workspace}"
#   FunctionRolePolicyArn = aws_iam_policy.batchingester_role_policy.arn
#   FunctionLoggingPolicyArn = aws_iam_policy.function_logging_policy.arn
#   EnvironmentVars = {
#     queue_url = aws_sqs_queue.PipelineSQSQueue.url
#     cluster_arn = module.aurora_rds.cluster_arn
#     secret_arn = module.aurora_rds.secret_arn
#   }
# }

# module "batchingester_scheduler" {
#   source = "./tf-modules/EventBridge"
#   cron_expression = "cron(0/5 * * * ? *)"
#   lambda_function_name = module.batchingester_lambda.lambda_function_name
#   lambda_arn = module.batchingester_lambda.lambda_arn
# }

# # Attach policy to lambda role that allows the use of DataApi from RDS cluster
# resource "aws_iam_role_policy_attachment" "DataAPIRolePolicyAttachmentBatchIngester" {
#   role = module.batchingester_lambda.lambda_role_name
#   policy_arn = module.aurora_rds.DataAPIRolePolicyArn
# }

#######################################################################################
### ONLY HAVE EITHER STREAMINGINGESTER OR BATCHINGESTER ACTIVATED AT A TIME ###

## CREATE STREAMINGINGESTER LAMBDA

resource "aws_iam_policy" "streamingingester_role_policy" {
  name = "streamingingester_role_policy_${terraform.workspace}"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Effect : "Allow",
        Resource : "${aws_sqs_queue.PipelineSQSQueue.arn}"
      }
    ]
  })
}

module "streamingingester_lambda" {
  source                   = "./tf-modules/lambda"
  functionName             = "streamingingester_${terraform.workspace}"
  FunctionRolePolicyArn    = aws_iam_policy.streamingingester_role_policy.arn
  FunctionLoggingPolicyArn = aws_iam_policy.function_logging_policy.arn
  EnvironmentVars = {
    queue_url   = aws_sqs_queue.PipelineSQSQueue.url
    cluster_arn = module.aurora_rds.cluster_arn
    secret_arn  = module.aurora_rds.secret_arn
  }
}

# Add trigger to the Lambda
resource "aws_lambda_event_source_mapping" "streamingingester_sqs_trigger" {
  event_source_arn = aws_sqs_queue.PipelineSQSQueue.arn
  function_name    = module.streamingingester_lambda.lambda_function_name
  batch_size       = 1
}

# Attach policy to lambda role that allows the use of DataApi from RDS cluster
resource "aws_iam_role_policy_attachment" "DataAPIRolePolicyAttachmentStreamingIngester" {
  role       = module.streamingingester_lambda.lambda_role_name
  policy_arn = module.aurora_rds.DataAPIRolePolicyArn
}

#################################
