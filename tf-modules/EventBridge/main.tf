### NOT USED IN CURRENT IMPLENETATION ###

# Create an scheduled EventBridge Lambda invocation for a target arn
resource "aws_cloudwatch_event_rule" "IngesterSchedule" {
  name = "IngesterSchedule"
  schedule_expression = var.cron_expression 
}

resource "aws_lambda_permission" "eventbridge_permission" {
  action = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.IngesterSchedule.arn
}

resource "aws_cloudwatch_event_target" "IngesterScheduleTarget" {
  rule = aws_cloudwatch_event_rule.IngesterSchedule.name
  arn = module.ingester_lambda.lambda_arn
}