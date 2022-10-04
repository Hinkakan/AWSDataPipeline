variable "cron_expression" {
  type = string
  description = "Cron-based schedule e.g cron(1/1 * * * ? *)"
}

variable "lambda_function_name" {
    description = "Name of lambda function to invoke"
    type = string
}

variable "lambda_arn" {
  description = "ARN of the lamda to invoke"
  type = string
}