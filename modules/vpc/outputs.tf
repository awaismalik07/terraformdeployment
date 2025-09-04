output "public_subnets" {
    value = aws_subnet.PublicSubnets.*.id
}

output "private_subnets" {
    value = aws_subnet.PrivateSubnets.*.id
}

output "vpc_id" {
    value = aws_vpc.AwaisVpc.id
}