#Provider and Backend is specified in their own files.
#Whole infrastructure is divided into six modules, the variables 
#are passed from main variables file to each module's variable file
#the outputs required by another module are also passed from here using module.*.* syntax
module "vpc" {
    source    = "./modules/vpc"

    vpc-cidr  = var.vpc.cidr  #Specify vpc cidr in the variables.tf file
    owner     = var.environment.owner
}

module "rds" {
    source              = "./modules/rds"
    
    vpc-cidr            = var.vpc.cidr
    owner               = var.environment.owner
    PrivateSubnets      = module.vpc.private_subnets  #private subnets to create db subnet group
    DBName              = var.database.name  #database name
    DBUsername          = var.database.username  #database master username
    DBAllocatedStorage  = var.database.allocated_storage
    DBInstanceClass     = var.database.instance_class #type of database
    vpc_id              = module.vpc.vpc_id

}

#Secrets manager to store db secrets and then retrieve them during instance launch in user data
#Each value is exported from rds module and passed into secretsmanager to create the secret
module "secretsmanager" {
  source        = "./modules/secretsmanager"

  rds_name      = module.rds.rds_name
  rds_username  = module.rds.rds_username
  rds_password  = module.rds.rds_password
  rds_endpoint  = module.rds.rds_endpoint
  owner         = var.environment.owner
}

#ec2 module contains all the compute connfigurations such as launch template
#autoscaling group, load balancer, security groups for each etc.
module "ec2" {
  source                      = "./modules/ec2"
  owner                       = var.environment.owner
  vpc_id                      = module.vpc.vpc_id
  imageid                     = var.compute.image_id
  ec2instancetype             = var.compute.instance_type
  keypairname                 = var.compute.keypair_name #specify the key pair name that you already have in variables.tf
  db_secretmanager_name       = module.secretsmanager.db_secretmanager_name #secret name to be used in user data to retrieve secrets and make db connection
  PrivateSubnets              = module.vpc.private_subnets  #for instances
  PublicSubnets               = module.vpc.public_subnets   #public subnets for loadbalancer
  desiredcapacity             = var.compute.desired_capacity   #for autoscaling group
  minsize                     = var.compute.min_size   #for autoscaling group
  maxsize                     = var.compute.max_size   #for autoscaling group
  acmcert                     = module.route53.acmcert  #acm certificate to deploy on load balancer listeners for https

}

module "cloudwatch" {
  source              = "./modules/cloudwatch"
  owner               = var.environment.owner
  vpc_id              = module.vpc.vpc_id

  asg_name            = module.ec2.asg_name

  scaleInAdjustment   = var.scaling.scale_in_adjustment     #specify no of instances to remove
  scaleOutAdjustment  = var.scaling.scale_out_adjustment     #specify no of instances to add
  highthreshold       = var.scaling.high_threshold       #CPU high threshold
  lowthreshold        = var.scaling.low_threshold        #CPU low threshold
}

module "route53" {
  source    = "./modules/route53"
  owner     = var.environment.owner
  lb_dns    = module.ec2.lb_dns     #load balancer dns and zone from ec2 instance to create a record
  lb_zone   = module.ec2.lb_zone    #and point to the load balancer
}
