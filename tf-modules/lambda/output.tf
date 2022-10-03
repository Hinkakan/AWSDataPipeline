output "lambda_arn" {
  description = "ARN of the lambda created"
  value = aws_lambda_function.LambdaFunction.arn
}

output "lambda_role_name" {
  description = "The role used by the lambda"
  value = aws_iam_role.lambda_role.name
}

output "lambda_function_name" {
  description = "The role used by the lambda"
  value = aws_lambda_function.LambdaFunction.function_name
}