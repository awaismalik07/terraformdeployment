output "asg_name" {
  value = aws_autoscaling_group.EC2AutoScalingGroup.name
}

output "lb_dns" {
  value = aws_lb.ApplicationLoadBalancer.dns_name
}
output "lb_zone" {
  value = aws_lb.ApplicationLoadBalancer.zone_id
}