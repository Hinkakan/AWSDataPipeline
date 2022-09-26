output "lambda_arn" {
  description = "ARN of the lambda created"
  value = aws_lambda_function.LambdaFunction.arn
}