# Create random password
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "/@"
}

# Create Serverless Aurora cluster
resource "aws_rds_cluster" "rdsCluster" {
  cluster_identifier = var.cluster_identifier
  apply_immediately = true
  backup_retention_period = 1
  database_name = var.database_name
  engine = "aurora-postgresql"
  engine_mode = "serverless"
  enable_http_endpoint = true
  #engine_version = "14"
  master_username = var.master_username #"bjarki"
  master_password = random_password.password.result
  skip_final_snapshot = true

  scaling_configuration {
    auto_pause = true
    min_capacity = 2
    max_capacity = 2
    seconds_until_auto_pause = 300
    timeout_action = "ForceApplyCapacityChange"
  }
}

# Create password secret
resource "aws_secretsmanager_secret" "dbsecret" {
  name = "dbsecret"
  recovery_window_in_days = 0
  force_overwrite_replica_secret = true
}

# Add values to above secret
resource "aws_secretsmanager_secret_version" "dbsecretversion" {
  secret_id = aws_secretsmanager_secret.dbsecret.id
  secret_string = jsonencode({
    "engine": "postgres",
    "host": "${aws_rds_cluster.rdsCluster.endpoint}",
    "username": "${aws_rds_cluster.rdsCluster.master_username}",
    "password": "${random_password.password.result}",
    "dbname": "${aws_rds_cluster.rdsCluster.database_name}",
    "port": "${aws_rds_cluster.rdsCluster.port}"
  })
}

# Data API policy role
data "aws_iam_policy_document" "DataAPIRolePolicyDoc" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    effect = "Allow"
    resources = [
      "${aws_secretsmanager_secret.dbsecret.arn}"
    ]
  }
  statement {
    actions = [
      "rds-data:*"
    ]
    effect = "Allow"
    resources = [
      "${aws_rds_cluster.rdsCluster.arn}"
    ]
  }
}

resource "aws_iam_policy" "DataAPIRolePolicy" {
  name = "DataAPIRolePolicy"
  policy = data.aws_iam_policy_document.DataAPIRolePolicyDoc.json
}
