variable "cluster_identifier" {
  description = "Name of the cluster for ease of recognition"
  type = string
}

variable "database_name" {
  description = "Name of the database to create inside the cluster"
  type = string
}

variable "master_username" {
  description = "User name for the cluster master user"
  type = string
}

variable "secret_name" {
  description = "name of the cluster secret"
  type = string
}

variable "DataAPI_role_policy_name" {
  type = string
  description = "Name of the role policy for the DataAPI"
}