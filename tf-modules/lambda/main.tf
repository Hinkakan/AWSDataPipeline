### LAMBDA: EVENTIFYER ###

# Role
resource "aws_iam_role" "lambda_role" {
  name = "${var.functionName}_role"
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


# Attach role to lambda
resource "aws_iam_role_policy_attachment" "lambda_role_policy_attachment" {
  role = aws_iam_role.lambda_role.name
  policy_arn = var.FunctionRolePolicyArn
}

# # NOT NEEDED AS CREATED OWN PIPELINE BAT
# resource "null_resource" "install_python_dependencies" {
#   provisioner "local-exec" {
#     command = "D:\\Coding\\AWSDataPipeline\\tf-modules\\lambda\\scripts\\create_pkg.bat"
#   }

  
#   triggers = {
#       dependencies_versions = filemd5("${var.functionName}/main.py")
#     }
# }

# Zip lambda code
data "archive_file" "code" {
  #depends_on = [null_resource.install_python_dependencies]
  type        = "zip"
  source_dir  = "${path.root}/${var.functionName}_lambda_dist_pkg"
  output_path ="${var.functionName}.zip"
}

# lambda Function
resource "aws_lambda_function" "LambdaFunction" {
    depends_on = [data.archive_file.code]
    function_name = var.functionName
    role = aws_iam_role.lambda_role.arn
    runtime = "python3.9"
    filename = data.archive_file.code.output_path
    handler = "main.handler"
    timeout = 35
    source_code_hash = filebase64sha256(data.archive_file.code.output_path)

    environment {
      variables = var.EnvironmentVars
    }
}

# Cloudwatch log group for lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/${aws_lambda_function.LambdaFunction.function_name}"
  retention_in_days = 1
}

# Attach role
resource "aws_iam_role_policy_attachment" "attach_logging_policy" {
  role = aws_iam_role.lambda_role.name
  policy_arn = var.FunctionLoggingPolicyArn
}
