# Create an scheduled EventBridge Lambda invocation for a target arn
resource "aws_cloudwatch_event_rule" "LambdaSchedule" {
  name = "${var.lambda_function_name}Schedule"
  schedule_expression = var.cron_expression 
}

resource "aws_lambda_permission" "eventbridge_permission" {
  action = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.LambdaSchedule.arn
}

resource "aws_cloudwatch_event_target" "LambdaScheduleTarget" {
  rule = aws_cloudwatch_event_rule.LambdaSchedule.name
  arn = var.lambda_arn
}