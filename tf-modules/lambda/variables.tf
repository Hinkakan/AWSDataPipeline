# variable "rolename" {
#     type = string
#     description = "Name of the lambdas execution role"  
# }

# variable "rolepolicyarn" {
#   type = string
#   description = "Arn of the role policy for the lambda"
# }

variable "StagingbucketArn" {
  type = string
}

variable "PipelineSqsQueueArn" {
  type = string
}

variable "PipelineSqsQueueURL" {
  type = string
}