output "db_secretmanager_name" {
  value = aws_secretsmanager_secret.rds_secret.name
}