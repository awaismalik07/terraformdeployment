#Variable values to be used in testing environment

# General environment settings
environment = {
  region = "us-east-1"
  owner  = "awais"
}

# VPC configuration
vpc = {
  cidr = "10.0.0.0/16"
}

# Database configuration
database = {
  username         = "AwaisMalik"
  name             = "Wordpress"
  instance_class   = "db.t3.micro"
  allocated_storage = 20
}

# EC2 / AutoScaling configuration
compute = {
  image_id        = "ami-0360c520857e3138f"
  instance_type   = "t2.micro"
  keypair_name    = "awais-kp"
  desired_capacity = 3
  min_size        = 2
  max_size        = 4
}

# Scaling policies thresholds
scaling = {
  scale_in_adjustment  = -1
  scale_out_adjustment = 1
  high_threshold       = 70
  low_threshold        = 30
}
