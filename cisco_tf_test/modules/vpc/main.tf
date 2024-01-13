### Network

# Internet VPC
resource "aws_vpc" "application_vpc" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"  #assuming this is required for VPC communication, the terraform version will need to be corrected to allow the use of this deprecated feature

  tags = {
    Name = "${var.environment}_application_vpc"
  }
}

# Subnets
resource "aws_subnet" "public_subnets" {
  vpc_id                  = aws_vpc.application_vpc.id
  cidr_block              = element(var.public_subnet_cidr_blocks, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true
  count                   = length(var.public_subnet_cidr_blocks) #this needed to be defined. Added the variable pointer using the length function to determine number of CIDR blocks

  tags = {
    Name = "${var.environment}_public_subnet_${substr(element(var.availability_zones, count.index), -1, 1)}"
  }
}

resource "aws_subnet" "private_subnets" { #this resource needed to be defined completely. Used same structure as public, getting number of cidr blocks, etc
  # Implement this resource
  vpc_id                  = aws_vpc.application_vpc.id
  cidr_block              = element(var.private_subnet_cidr_blocks, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false
  count                   = length(var.private_subnet_cidr_blocks)

  tags = {
    Name = "${var.environment}_private_subnet_${substr(element(var.availability_zones, count.index), -1, 1)}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.application_vpc.id

  tags = {
    Name = "${var.environment}_internet_gw"
  }
}

# route tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.application_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id #adding missing aws gateway identifier
  }

  tags = {
    Name = "${var.environment}_public_rt"
  }
}

# NAT EIPs
resource "aws_eip" "nat_eip" {
  vpc   = true
  count = length(aws_subnet.public_subnets)

  tags = {
    Name = "${var.environment}_nat_eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = element(aws_eip.nat_eip.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnets.*.id, count.index)
  count         = length(aws_subnet.public_subnets)

  tags = {
    Name = "${var.environment}_nat_gw"
  }
}

resource "aws_route_table" "lambda_function_rt" {
  vpc_id = aws_vpc.application_vpc.id
  count  = length(aws_nat_gateway.nat_gw)

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat_gw.*.id, count.index)
  }

  tags = {
    Name = "${var.environment}_lambda_function_rt_${substr(element(var.availability_zones, count.index), -1, 1)}"
  }
}

 #private subnet route table associations
resource "aws_route_table_association" "private_rta" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = element(aws_subnet.private_subnets.*.id, count.index)
  route_table_id = element(aws_route_table.lambda_function_rt.*.id, count.index) #Select current route_table_id using count.index for subnet association. 
}


# public subnet route table associations
resource "aws_route_table_association" "public_rta" {
  subnet_id      = element(aws_subnet.public_subnets.*.id, count.index)
  route_table_id = aws_route_table.public_rt.id
  count          = length(aws_subnet.public_subnets)
}
