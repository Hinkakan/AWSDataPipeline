output "cluster_arn" {
  description = "Cluster arn for the Aurora serverless RDS"
  value = aws_rds_cluster.rdsCluster.arn
}

output "secret_arn" {
  description = "secret arn for rds database user credentials"
  value = aws_secretsmanager_secret.dbsecret.arn
}

output "DataAPIRolePolicyArn" {
  description = "Arn of the Data API role policy. To be used to attached to lambda"
  value = aws_iam_policy.DataAPIRolePolicy.arn
}
