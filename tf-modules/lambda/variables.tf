variable "functionName" {
  description = "Name to give the function, will be used as input many places"
  type        = string
}

variable "FunctionRolePolicyArn" {
  description = "role specification to be sent attached to the lambda"
  type        = string
}

variable "FunctionLoggingPolicyArn" {
  description = "Generic policy that gives permissions to log events. Same for all lambdas. Generated in rool module"
  type        = string
}

variable "EnvironmentVars" {
  description = "The environment variables needed for the lambda"
  type        = map(any)
}
