resource "aws_vpc" "hirata_automation_vpc" {
  cidr_block = "10.150.0.0/16"  # VPCのCIDRブロック
  enable_dns_support   = true  # DNSサポートを有効にする
  enable_dns_hostnames = true  # DNSホスト名を有効にする

  tags = {
    Name = "hirata_automation_vpc"
  }
}

resource "aws_internet_gateway" "hirata_automation_gw" {
  vpc_id = aws_vpc.hirata_automation_vpc.id
  tags = {
    Name = "hirata_automation_gw"
  }
}

resource "aws_route_table" "hirata_automation_public_rtb" {
  vpc_id = aws_vpc.hirata_automation_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hirata_automation_gw.id
  }
  
  tags = {
    Name = "hirata_automation_public_rtb"
    
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.hirata_automation_vpc.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [aws_route_table.hirata_automation_public_rtb.id]
  tags = {
    Name = "s3_vpc_endpoint"
  }
}

# Publicサブネット
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.hirata_automation_vpc.id
  cidr_block        = "10.150.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "hirata_automation_public_subnet_a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.hirata_automation_vpc.id
  cidr_block        = "10.150.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "hirata_automation_public_subnet_b"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.hirata_automation_public_rtb.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.hirata_automation_public_rtb.id
}

# Privateサブネット
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.hirata_automation_vpc.id
  cidr_block        = "10.150.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "hirata_automation_private_subnet_a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.hirata_automation_vpc.id
  cidr_block        = "10.150.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "hirata_automation_private_subnet_b"
  }
}

resource "aws_route_table" "hirata_automation_private_rtb" {
  vpc_id = aws_vpc.hirata_automation_vpc.id
  tags = {
    Name = "hirata_automation_private_rtb"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.hirata_automation_private_rtb.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.hirata_automation_private_rtb.id
}
