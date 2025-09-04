#This file exports the rds details in outputs.tf file
#to be used by secrets manager module to store secrets

#To generate a random password for rds instance
data "aws_secretsmanager_random_password" "DBPassword" {
  password_length = 16
  exclude_punctuation = true  
}

#Security group for rds instance, Specify vpc id and description here.
#the ingress and egress rules are created seperately and attached with the security group 
resource "aws_security_group" "RDSSecurityGroup" {
    name = "${var.owner}=${terraform.workspace}-RDSSecurityGroup"
    description = "Allow Connection on PORT 3306"
    vpc_id = var.vpc_id

    tags = {
        Name = "${var.owner}=${terraform.workspace}-RDSSecurityGroup"
    }

}
#To allow incoming reqs on port 3306 to communicate with db. Specified cidr clock as vpc so that only instances in vpc can connect
resource "aws_security_group_rule" "RDSSecurityGroupIngress1" {
    type = "ingress"
    security_group_id = aws_security_group.RDSSecurityGroup.id
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = [var.vpc-cidr]
}

#RDS subnet group to create rds instance in. specify two or more private subnets
resource "aws_db_subnet_group" "RDSSubnetGroup" {
  name       = "rds_subnetgroup"
  subnet_ids = [
    var.PrivateSubnets[0],
    var.PrivateSubnets[1]
  ]

  tags = {
    Name = "${var.owner}-${terraform.workspace}-RDSSubnetGroup"
  }
}

#RDS Instance 
resource "aws_db_instance" "RDSInstance" {
    identifier           = "${var.owner}-${terraform.workspace}-rds"
    allocated_storage    = var.DBAllocatedStorage
    db_name              = "${var.DBName}"
    engine               = "mysql"
    engine_version       = "8.0"
    instance_class       = "${var.DBInstanceClass}"
    username             = "${var.DBUsername}"
    password             = data.aws_secretsmanager_random_password.DBPassword.random_password
    db_subnet_group_name = aws_db_subnet_group.RDSSubnetGroup.name
    parameter_group_name = "default.mysql8.0"
    skip_final_snapshot  = true
    publicly_accessible  = false
    vpc_security_group_ids = [aws_security_group.RDSSecurityGroup.id]   #Attach security group
    depends_on = [aws_security_group.RDSSecurityGroup]      #dependency so that security group is created first
}