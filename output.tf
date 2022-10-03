output "rds_endpoint" {
  description = "Endpoint for the serverless RDS"
  value = aws_rds_cluster.aurorapostgres.endpoint
}

output "rds_port" {
  description = "Port for the serverless RDS"
  value = aws_rds_cluster.aurorapostgres.port
}

output "rds_dbname" {
  description = "Database name for the serverless RDS"
  value = aws_rds_cluster.aurorapostgres.database_name
}

output "rds_masterusername" {
  description = "Master username for the serverless RDS"
  value = aws_rds_cluster.aurorapostgres.master_username
}