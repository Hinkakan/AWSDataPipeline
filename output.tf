output "rds_cluster_arn" {
  description = "Cluster arn for the Aurora serverless RDS"
  value = module.aurora_rds.cluster_arn
}

output "secret_arn" {
  description = "secret arn for rds database user credentials"
  value = module.aurora_rds.secret_arn
}