### LAMBDA: EVENTIFYER ###

# Role
resource "aws_iam_role" "identifyer_role" {
  name = "identifyer_role"
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  }
  EOF
}

# Role policy
resource "aws_iam_policy" "identifyer_role_policy" {
  name = "identifyer_role_policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": "${var.StagingbucketArn}/*"
    },
    {
        "Action": [
          "sqs:SendMessage"
        ],
        "Resource": "${var.PipelineSqsQueueArn}",
        "Effect": "Allow"
      }
  ]
}
EOF
}

# Attach role to lambda
resource "aws_iam_role_policy_attachment" "identifyer_role_policy_attachment" {
  role = aws_iam_role.identifyer_role.name
  policy_arn = aws_iam_policy.identifyer_role_policy.arn
}

resource "null_resource" "install_python_dependencies" {
  provisioner "local-exec" {
    command = "D:\\Coding\\AWSDataPipeline\\tf-modules\\lambda\\scripts\\create_pkg.bat"
  }
}

# Zip lambda code
data "archive_file" "code" {
  depends_on = [null_resource.install_python_dependencies]
  type        = "zip"
  source_dir = "D:\\Coding\\AWSDataPipeline\\lambda_dist_pkg"
  output_path ="identifyer.zip"
}

# Eventifyer lambda
resource "aws_lambda_function" "Eventifyer" {
    depends_on = [data.archive_file.code]
    function_name = "Eventifyer"
    role = aws_iam_role.identifyer_role.arn
    runtime = "python3.9"
    filename = data.archive_file.code.output_path
    handler = "main.handler"
    source_code_hash = data.archive_file.code.output_base64sha256

    environment {
      variables = {
        queue_url = var.PipelineSqsQueueURL
      }
  }
}