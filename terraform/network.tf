# ==========================================
# Internet Gateway
# ==========================================

resource "aws_internet_gateway" "k3s" {
  vpc_id = aws_vpc.k3s.id

  tags = {
    Name = "k3s-lab-igw"
  }
}


# ==========================================
# Public Route Table
# ==========================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.k3s.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k3s.id
  }

  tags = {
    Name = "k3s-public-rt"
  }
}


# ==========================================
# Public Route Table Association
# ==========================================

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


# ==========================================
# Elastic IP для NAT Gateway
# ==========================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "k3s-nat-eip"
  }
}


# ==========================================
# NAT Gateway в публичной подсети
# ==========================================

resource "aws_nat_gateway" "k3s" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  depends_on = [
    aws_internet_gateway.k3s
  ]

  tags = {
    Name = "k3s-lab-nat"
  }
}


# ==========================================
# Private Route Table
# ==========================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.k3s.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.k3s.id
  }

  tags = {
    Name = "k3s-private-rt"
  }
}


# ==========================================
# Private Route Table Association
# ==========================================

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
