# ==========================================
# Security Group для K3s Server
# ==========================================

resource "aws_security_group" "server" {
  name        = "k3s-server-sg"
  description = "Security group for K3s server"
  vpc_id      = aws_vpc.k3s.id

  tags = {
    Name = "k3s-server-sg"
  }
}

# ==========================================
# Security Group для K3s Workers
# ==========================================

resource "aws_security_group" "workers" {
  name        = "k3s-workers-sg"
  description = "Security group for K3s workers"
  vpc_id      = aws_vpc.k3s.id

  tags = {
    Name = "k3s-workers-sg"
  }
}

# ==========================================
# SSH: только с текущего IP администратора
# ==========================================

resource "aws_vpc_security_group_ingress_rule" "server_ssh" {
  security_group_id = aws_security_group.server.id

  description = "SSH from administrator"
  cidr_ipv4   = "${var.admin_ip}/32"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

# ==========================================
# Внутренний трафик между Server и Workers
# ==========================================

resource "aws_vpc_security_group_ingress_rule" "server_from_workers" {
  security_group_id            = aws_security_group.server.id
  referenced_security_group_id = aws_security_group.workers.id

  description = "Internal K3s traffic from workers"
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "workers_from_server" {
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = aws_security_group.server.id

  description = "Internal K3s traffic from server"
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "workers_from_workers" {
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = aws_security_group.workers.id

  description = "Internal traffic between workers"
  ip_protocol = "-1"
}

# ==========================================
# Исходящий трафик
# ==========================================

resource "aws_vpc_security_group_egress_rule" "server_outbound" {
  security_group_id = aws_security_group.server.id

  description = "Allow outbound IPv4"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_egress_rule" "workers_outbound" {
  security_group_id = aws_security_group.workers.id

  description = "Allow outbound IPv4 via NAT"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
