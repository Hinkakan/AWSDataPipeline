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
  visibility_timeout_seconds = 30
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
  FunctionLoggingPolicyArn = aws_iam_policy.function_logging_policy.arn
  EnvironmentVars = {
    queue_url = aws_sqs_queue.PipelineSQSQueue.url
  }
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

module "ingester_lambda" {
  source = ".\\tf-modules\\lambda"
  functionName = "Ingester"
  FunctionRolePolicyArn = aws_iam_policy.ingester_role_policy.arn
  FunctionLoggingPolicyArn = aws_iam_policy.function_logging_policy.arn
  EnvironmentVars = {
    queue_url = aws_sqs_queue.PipelineSQSQueue.url
    cluster_arn = aws_rds_cluster.aurorapostgres.arn
    secret_arn = aws_secretsmanager_secret.dbsecret.arn
  }
}

### CREATE BUCKET NOTIFICATION

resource "aws_lambda_permission" "notification_permission" {
  action = "lambda:InvokeFunction"
  function_name = module.eventifyer_lambda.lambda_function_name
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

### RDS CLUSTER

# Create random password
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "aws_rds_cluster" "aurorapostgres" {
  cluster_identifier = "aurorapostgres"
  apply_immediately = true
  backup_retention_period = 1
  database_name = "pipelinedb"
  engine = "aurora-postgresql"
  engine_mode = "serverless"
  enable_http_endpoint = true
  #engine_version = "14"
  master_username = "bjarki"
  master_password = random_password.password.result
  skip_final_snapshot = true

  scaling_configuration {
    auto_pause = true
    min_capacity = 2
    max_capacity = 2
    seconds_until_auto_pause = 300
    timeout_action = "ForceApplyCapacityChange"
  }
}

# Create password secret
resource "aws_secretsmanager_secret" "dbsecret" {
  name = "dbsecret"
  recovery_window_in_days = 0
  force_overwrite_replica_secret = true
}

resource "aws_secretsmanager_secret_version" "dbsecretversion" {
  secret_id = aws_secretsmanager_secret.dbsecret.id
  secret_string = jsonencode({
    "engine": "postgres",
    "host": "${aws_rds_cluster.aurorapostgres.endpoint}",
    "username": "${aws_rds_cluster.aurorapostgres.master_username}",
    "password": "${random_password.password.result}",
    "dbname": "${aws_rds_cluster.aurorapostgres.database_name}",
    "port": "${aws_rds_cluster.aurorapostgres.port}"
  })
}

# Data API policy role
data "aws_iam_policy_document" "DataAPIRolePolicyDoc" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    effect = "Allow"
    resources = [
      "${aws_secretsmanager_secret.dbsecret.arn}"
    ]
  }
  statement {
    actions = [
      "rds-data:*"
    ]
    effect = "Allow"
    resources = [
      "${aws_rds_cluster.aurorapostgres.arn}"
    ]
  }
}

resource "aws_iam_policy" "DataAPIRolePolicy" {
  name = "DataAPIRolePolicy"
  policy = data.aws_iam_policy_document.DataAPIRolePolicyDoc.json
}

resource "aws_iam_role_policy_attachment" "DataAPIRolePolicyAttachmentIngester" {
  role = module.ingester_lambda.lambda_role_name
  policy_arn = aws_iam_policy.DataAPIRolePolicy.arn
}

# https://stackoverflow.com/questions/65615404/how-to-create-aurora-serverless-database-cluster-with-secret-manager-in-terrafor

# connecting to aurora serverless using data api 
# https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/data-api.html# 


# Rule attempt
resource "aws_cloudwatch_event_rule" "IngesterSchedule" {
  name = "IngesterSchedule"
  schedule_expression = "cron(1/1 * * * ? *)"
}

resource "aws_lambda_permission" "eventbridge_permission" {
  action = "lambda:InvokeFunction"
  function_name = module.ingester_lambda.lambda_function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.IngesterSchedule.arn
}

resource "aws_cloudwatch_event_target" "IngesterScheduleTarget" {
  rule = aws_cloudwatch_event_rule.IngesterSchedule.name
  arn = module.ingester_lambda.lambda_arn
}