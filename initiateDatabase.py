import boto3

session = boto3.Session(region_name="eu-central-1")
rds = session.client("rds-data")
secret = session.client("secretsmanager")

cluster_arn = "arn:aws:rds:eu-central-1:173471538789:cluster:aurorapostgres"
secret_arn = "arn:aws:secretsmanager:eu-central-1:173471538789:secret:dbsecret-6C4xNT"

secretvalue = secret.get_secret_value(
    SecretId = secret_arn
)

print(secretvalue)

SQL = "CREATE TABLE ds (Id INT,Race VARCHAR(50),Class VARCHAR(50),Role VARCHAR(50),Faction VARCHAR(50),First_Expansion VARCHAR(50), _MessageSent VARCHAR(50))"

res = rds.execute_statement(
    resourceArn = cluster_arn,
    secretArn = secret_arn,
    database = "pipelinedb",
    sql = SQL
)

print(res)