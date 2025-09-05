#this file exports the secret name to be used by ec2 module

#Create a secret to store the credentials
resource "aws_secretsmanager_secret" "rds_secret" {
  name = "${var.owner}-${terraform.workspace}-DB_secret"
  
  description = "Secret to store RDS Credentials"
}

#using version store the secrets coming from rds module
resource "aws_secretsmanager_secret_version" "rds_secret_value" {
    secret_id = aws_secretsmanager_secret.rds_secret.id #Attch to secret
    
    secret_string = jsonencode({
        username = "${var.rds_username}"
        password = "${var.rds_password}"
        dbname = "${var.rds_name}"
        endpoint = "${var.rds_endpoint}"
    })
  
}