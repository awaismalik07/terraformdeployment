output "rds_endpoint" {
  value = aws_db_instance.RDSInstance.endpoint
}

output "rds_username" {
  value = aws_db_instance.RDSInstance.username
}

output "rds_password" {
  value = aws_db_instance.RDSInstance.password
  sensitive = true
}

output "rds_name" {
    value = aws_db_instance.RDSInstance.db_name
}