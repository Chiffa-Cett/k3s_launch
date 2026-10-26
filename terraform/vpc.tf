# ==========================================
# VPC — основная сеть нашего K3s-кластера
# ==========================================

resource "aws_vpc" "k3s" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "k3s-lab-vpc"
  }
}


# ==========================================
# Public Subnet — для K3s Server (Master)
# ==========================================

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.k3s.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "k3s-public-subnet"
  }
}


# ==========================================
# Private Subnet — для трёх K3s Workers
# ==========================================

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.k3s.id
  cidr_block              = "10.20.2.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "k3s-private-subnet"
  }
}

