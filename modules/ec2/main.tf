#This file exports asg name, lb dns and lb zone to be used by cloudwatch and route53 module

#Iam role for the ec2 intances to access the secrets manager
resource "aws_iam_role" "EC2Role" {
  name = "${var.owner}-${terraform.workspace}-EC2Role"

  assume_role_policy = jsonencode({   #role policy telling what this role is used for
    Version = "2012-10-17"            #can be specifed inline or using aws_iam_role_policy_document
    Statement = [
      {
        Action = "sts:AssumeRole"     #Can assume role
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"   #by an ec2 instance
        }
      },
    ]
  })

  tags = {
    Name = "${var.owner}-${terraform.workspace}-EC2Role"
  }
}

#Attach a aws defined poicy for secrets manger to the role
resource "aws_iam_role_policy_attachment" "SecretsManagerPolicyAttachment" {
    role = aws_iam_role.EC2Role.name
    policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

#Attach a aws defined poicy for SSM Management to the role
resource "aws_iam_role_policy_attachment" "SSMManagedPolicyAttachment" {
    role = aws_iam_role.EC2Role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#Create an instance profile to attach to the instance
resource "aws_iam_instance_profile" "EC2_iam_role_profile" {
    name = "${var.owner}-${terraform.workspace}-EC2Profile"
    role = aws_iam_role.EC2Role.name
}

#Security group for ec2 instance. specify vpc and description here only.
resource "aws_security_group" "EC2SecurityGroup" {
    name = "${var.owner}-${terraform.workspace}-ec2securitygroup"
    vpc_id = var.vpc_id
    description = "To Allow SSH and HTTP access"
    tags = {
        Name = "${var.owner}-${terraform.workspace}-EC2SecurityGroup" 
    }
}

#For SSH access to the instances from anywhere
resource "aws_security_group_rule" "EC2SGSSH" {
    security_group_id = aws_security_group.EC2SecurityGroup.id
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

#For HTTP access to the instances from anywhere
resource "aws_security_group_rule" "EC2SHHTTP" {
    security_group_id = aws_security_group.EC2SecurityGroup.id
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

#To Allow outbound access to the internet to download resources
resource "aws_security_group_rule" "EC2EGRESS" {
    security_group_id = aws_security_group.EC2SecurityGroup.id
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}

#launch template for the ec2 instaces to e used by ASG
resource "aws_launch_template" "EC2launchTemplate" {
    name = "${var.owner}-${terraform.workspace}-LaunchTemplate"
    image_id = var.imageid
    instance_type = var.ec2instancetype
    iam_instance_profile {
        arn = aws_iam_instance_profile.EC2_iam_role_profile.arn #iam roles
    }
    tags = {
      Name = "${var.owner}-${terraform.workspace}-LaunchTemplate"
    }
    vpc_security_group_ids = [aws_security_group.EC2SecurityGroup.id]
    key_name = var.keypairname
    user_data = base64encode(       #userdata script to be run on launch 
                  templatefile(
                    "${path.module}/userdata.sh", {   #path to the file
                        db_secrets_name = var.db_secretmanager_name   #specify variables to be used inside the file
                      }
                  )
                )
}

#AutoScaling Group to launch intances. Specify the min,max,desired, subnets and launch template
resource "aws_autoscaling_group" "EC2AutoScalingGroup" {
  vpc_zone_identifier = [
    var.PrivateSubnets[0],
    var.PrivateSubnets[1]
  ]
  desired_capacity   = var.desiredcapacity
  max_size           = var.maxsize
  min_size           = var.minsize

  launch_template {
    id      = aws_launch_template.EC2launchTemplate.id
    version = "$Latest"   #picks up latest version of the template
  }
  target_group_arns = [aws_lb_target_group.AlbTargetGroup.arn]    #Specify the target group to attach to the lb
  
}

#Security Group for the load balancer
resource "aws_security_group" "ALBSG" {
  vpc_id = var.vpc_id
  description = "Security Group for ALB"
  tags = {
    Name = "${var.owner}-${terraform.workspace}-ALB-SG"
  }  
}

#To Allow Http reqs to the load balancer
resource "aws_security_group_rule" "ALBSG-ingress" {
  security_group_id = aws_security_group.ALBSG.id
  type = "ingress"
  protocol = "tcp"
  from_port = 80
  to_port = 80
  cidr_blocks = ["0.0.0.0/0"]
  
}

#To Allow Https reqs to the load balancer
resource "aws_security_group_rule" "ALBSG-ingress2" {
  security_group_id = aws_security_group.ALBSG.id
  type = "ingress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  cidr_blocks = ["0.0.0.0/0"]
  
}
#To Allow load balancer to send all the outbound traffic to internet
resource "aws_security_group_rule" "ALBSG-egress" {
  security_group_id = aws_security_group.ALBSG.id
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

#Load Balancer, specify public subnets, security group and type
resource "aws_lb" "ApplicationLoadBalancer" {
  name               = "${var.owner}-${terraform.workspace}-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ALBSG.id]
  subnets            = var.PublicSubnets


  tags = {
    Environment = "${terraform.workspace}"
  }
}

# HTTPListener for load balancer. redirects the traffic to https
resource "aws_lb_listener" "ALB-Listener" {
  load_balancer_arn = aws_lb.ApplicationLoadBalancer.arn
  
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  
}

#Https listener, directs the traffic to the target group. deploy ssl certificate here
resource "aws_lb_listener" "alb-listener-https" {
  load_balancer_arn = aws_lb.ApplicationLoadBalancer.arn

  port = 443
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  certificate_arn = var.acmcert

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.AlbTargetGroup.arn
  
  }
  
}

#Target Group for the asg and lb. listens on port 80 and checks health on main path. specify target type here (instance)
resource "aws_lb_target_group" "AlbTargetGroup" {
  name        = "${var.owner}-${terraform.workspace}-alb-tg"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 5
  }

}

