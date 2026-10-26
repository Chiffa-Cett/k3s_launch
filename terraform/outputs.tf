# Публичный IP K3s Server
# Используем для SSH-подключения из нашей Ubuntu VM
output "server_public_ip" {
  description = "Public IPv4 address of the K3s server"
  value       = aws_instance.server.public_ip
}

# Приватный IP K3s Server
# Workers будут подключаться к K3s по этому адресу
output "server_private_ip" {
  description = "Private IPv4 address of the K3s server"
  value       = aws_instance.server.private_ip
}

# Приватные IP всех трёх Workers
# Используем для Ansible inventory
output "worker_private_ips" {
  description = "Private IPv4 addresses of K3s workers"
  value       = aws_instance.workers[*].private_ip
}
