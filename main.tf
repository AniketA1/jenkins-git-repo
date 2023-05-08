terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
 shared_credentials_files = ["/root/.aws/credentials"]
 region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "terraform_vpc" {
  cidr_block = "10.10.0.0/16"
  tags = {
        Name = "terraform_vpc"
}
}

#creating public subnet
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.terraform_vpc.id
  cidr_block = "10.10.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform_public_subnet"
  }
}

#creating private subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.terraform_vpc.id
  cidr_block = "10.10.2.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "terraform_private_subnet"
  }
}

#creating igw
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = "terraform-igw"
  }
}

#creating elastic ip
resource "aws_eip" "nat_eip" {
  vpc        = true
}

#creating nat gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.private.id

  tags = {
    Name        = "terraform_nat"
  }
}
#route table private
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name        = "terraform-private-route-table"
  }
}

# Routing tables to route traffic for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name        = "terraform-public-route-table"
  }
}

# Route for Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Route for NAT
resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

#security group for public instance
resource "aws_security_group" "public" {
  name = "public"
  description = "PublicSecurityGroup"
  vpc_id = aws_vpc.terraform_vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }
  tags = {
    "Name" = "PublicSecurityGroup"
  }
}

#private security group
resource "aws_security_group" "private" {
  name = "private"
  vpc_id=aws_vpc.terraform_vpc.id

  #Incoming traffic
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.public.id]
  }

  #Outgoing traffic
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
        Name = "Private-SG"
}
}
#pem file
resource "aws_key_pair" "pemkey" {
  key_name = "public key"
  public_key = file("/home/ubuntu/.ssh/id_rsa.pub")
}

#private instance
resource "aws_instance" "private-instance" {
  ami = "ami-0aa2b7722dc1b5612"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id
  key_name = aws_key_pair.pemkey.key_name
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.private.id]
  tags = {
  Name = "PrivateOS"
}
}


#public instance
resource "aws_instance" "public-instance" {
  ami           = "ami-0aa2b7722dc1b5612"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  associate_public_ip_address = true
  key_name = aws_key_pair.pemkey.key_name
  vpc_security_group_ids = [aws_security_group.public.id]
  tags = {
        Name = "PublicOS"
}

}
