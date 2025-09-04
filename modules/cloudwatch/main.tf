
#Scale in policy removes instances. no of instances to be reomved is specidied in scaling adjustment
resource "aws_autoscaling_policy" "ASG-ScaleInPolicy" {
  name = "${var.owner}-${terraform.workspace}-ScaleInPolicy"
  autoscaling_group_name = var.asg_name     #ASG name to attach the policy to
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = var.scaleInAdjustment
  cooldown = 150
}

#Scale out policy adds instances. no of instances to be added is specified in scaling adjustment
resource "aws_autoscaling_policy" "ASG-ScaleOutPolicy" {
  name = "${var.owner}-${terraform.workspace}-ScaleOutPolicy"
  autoscaling_group_name = var.asg_name   #ASG name to attach the policy to
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = var.scaleOutAdjustment
  cooldown = 150
}

#Alarm for High CPU utilization
resource "aws_cloudwatch_metric_alarm" "HighCpuAlarm" {
  alarm_name                = "${var.owner}-${terraform.workspace}-HighCpuAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1 #minutes
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 120 #seconds
  statistic                 = "Average"
  threshold                 = var.highthreshold
  alarm_description         = "This metric monitors ec2 cpu utilization"
  insufficient_data_actions = []

  dimensions = {
    AutoScalingGroupName = var.asg_name   #dimension is the object to get the data points from, can be an instance or asg, lb etc
  }

  alarm_actions = [aws_autoscaling_policy.ASG-ScaleOutPolicy.arn] #which policy to be called when alarm triggers

  tags = {
    Name = "${var.owner}-${terraform.workspace}-HighCpuAlarm"
  }
}


resource "aws_cloudwatch_metric_alarm" "LowCpuAlarm" {
  alarm_name                = "${var.owner}-${terraform.workspace}-LowCpuAlarm"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = 1 #minutes
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 120 #seconds
  statistic                 = "Average"
  threshold                 = var.lowthreshold
  alarm_description         = "This metric monitors ec2 cpu utilization"
  insufficient_data_actions = []

  dimensions = {
    AutoScalingGroupName = var.asg_name #dimension is the object to get the data points from, can be an instance or asg, lb etc
  }

  alarm_actions = [aws_autoscaling_policy.ASG-ScaleInPolicy.arn] #which policy to be called when alarm triggers

  tags = {
    Name = "${var.owner}-${terraform.workspace}-HighCpuAlarm"
  }
}

