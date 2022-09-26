# variable "rolename" {
#     type = string
#     description = "Name of the lambdas execution role"  
# }

# variable "rolepolicyarn" {
#   type = string
#   description = "Arn of the role policy for the lambda"
# }

variable "PipelineSqsQueueURL" {
  type = string
}

variable "functionName" {
  description = "Name to give the function, will be used as input many places"
  type = string
}

variable "FunctionRolePolicyArn" {
  description = "role specification to be sent attached to the lambda"
  type = string
}

variable "FunctionLoggingPolicyArn" {
  description = "Generic policy that gives permissions to log events. Same for all lambdas. Generated in rool module"
  type = string  
}