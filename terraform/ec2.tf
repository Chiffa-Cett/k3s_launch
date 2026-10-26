# ==========================================
# Ubuntu 24.04 LTS AMI
# Получаем актуальный образ через AWS SSM
# ==========================================

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}


# ==========================================
# K3s Server — публичная подсеть
# ==========================================

resource "aws_instance" "server" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = "t3a.medium"
  key_name      = "my_keys"

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.server.id]
  associate_public_ip_address = true

  # Ограничиваем размер системного диска
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  # Не расходуем дополнительные платные CPU credits
  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = "k3s-server"
    Role = "server"
  }
}


# ==========================================
# K3s Workers — приватная подсеть
# ==========================================

resource "aws_instance" "workers" {
  count = 3

  ami = data.aws_ssm_parameter.ubuntu_ami.value

  # Первый Worker имеет больше RAM для Ollama
  instance_type = count.index == 0 ? "t3a.large" : "t3a.medium"

  key_name = "my_keys"

  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.workers.id]
  associate_public_ip_address = false

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = "k3s-worker-${count.index + 1}"
    Role = "worker"
  }
}
