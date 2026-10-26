# ==========================================
# IP-адрес администратора
# Используется для ограничения SSH-доступа
# к публичному K3s Server
# ==========================================

variable "admin_ip" {
  description = "Public IPv4 address of the administrator"
  type        = string

  validation {
    condition     = can(cidrhost("${var.admin_ip}/32", 0))
    error_message = "admin_ip must be a valid IPv4 address."
  }
}
