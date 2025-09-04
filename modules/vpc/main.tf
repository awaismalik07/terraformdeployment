#This file exports vpc id, public and private subnets in output.tf file for other modules to use

#Get all the AZs available in the region specified in provider.tf 
data "aws_availability_zones" "AZs" {
    state = "available"
    filter {
        name   = "opt-in-status"
        values = ["opt-in-not-required"]
    }
}

#Create Vpc, only specifing cidr block is necessary
resource "aws_vpc" "AwaisVpc" {
    cidr_block = var.vpc-cidr
    tags = {
        Name = "${var.owner}-Vpc"
    }
}

#Public subnets in all the available AZs. Loop through the AZs using count variable
resource "aws_subnet" "PublicSubnets" {
  count             = length(data.aws_availability_zones.AZs.names) #total AZs in count
  vpc_id            = aws_vpc.AwaisVpc.id
  availability_zone = data.aws_availability_zones.AZs.names[count.index]  #specifies different AZs available in list using count's index
  
  cidr_block        = cidrsubnet(aws_vpc.AwaisVpc.cidr_block, 8, count.index) #dynamic cidrs for subnets, (base cidr, no of bit to add in mask, index  of subnet)
  map_public_ip_on_launch = true #intances get public ip if launched in public subnet
  tags = {
    Name = "${var.owner}-${terraform.workspace}-PublicSubnet-${data.aws_availability_zones.AZs.names[count.index]}"
  }
}

#Same as public subnets, no public ip and the index of cidr start from the length of count so it doesnot concide with public subnets
resource "aws_subnet" "PrivateSubnets" {
  count             = length(data.aws_availability_zones.AZs.names)
  vpc_id            = aws_vpc.AwaisVpc.id
  availability_zone = data.aws_availability_zones.AZs.names[count.index]

  cidr_block        = cidrsubnet(aws_vpc.AwaisVpc.cidr_block, 8, count.index + length(data.aws_availability_zones.AZs.names))

  tags = {
    Name = "${var.owner}-${terraform.workspace}-PrivateSubnet-${data.aws_availability_zones.AZs.names[count.index]}"
  }
}

#Internet Gateway for public subnets, specify the vpc
resource "aws_internet_gateway" "InternetGateway" {
  vpc_id = aws_vpc.AwaisVpc.id

  tags = {
    Name = "${var.owner}-${terraform.workspace}-InternetGateway"
  }
}

#Elastic ip is needed to create nat gateway. specify domain as vpc for nat gateway
resource "aws_eip" "NatGatewayEip" {
  domain = "vpc"
}

#nat gateway for outbound access from private subnets. place it in one of the public subnets. i did it in first
resource "aws_nat_gateway" "NatGateway" {
  allocation_id = aws_eip.NatGatewayEip.id  #Elastic ip created above
  subnet_id     = aws_subnet.PublicSubnets[0].id

  tags = {
    Name = "${var.owner}-${terraform.workspace}-NatGateway"
  }

  depends_on = [aws_internet_gateway.InternetGateway]   #add the dependency because nat gateway uses internet gateway to communicate
}

#route table to route traffic from public subnets, all the traffic to internet is routed to internet gateway
resource "aws_route_table" "PublicRouteTable" {
  vpc_id = aws_vpc.AwaisVpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.InternetGateway.id
  }

  tags = {
    Name = "${var.owner}-${terraform.workspace}-PublicRouteTable"
  }
}
#route table to route traffic from private subnets, all the traffic to internet is routed to nat gateway
resource "aws_route_table" "PrivateRouteTable" {
  vpc_id = aws_vpc.AwaisVpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NatGateway.id
  }

  tags = {
    Name = "${var.owner}-${terraform.workspace}-PrivateRouteTable"
  }
}

#associate public route table with public subnets by looping through all the subnets
resource "aws_route_table_association" "PublicRouteTableAssociation" {
  count          = length(data.aws_availability_zones.AZs.names)
  subnet_id      = aws_subnet.PublicSubnets[count.index].id
  route_table_id = aws_route_table.PublicRouteTable.id
}

#associate private route table with private subnets by looping through all the subnets
resource "aws_route_table_association" "PrivateRouteTableAssociation" {
    count = length(data.aws_availability_zones.AZs.names)

  subnet_id      = aws_subnet.PrivateSubnets[count.index].id
  route_table_id = aws_route_table.PrivateRouteTable.id
}

