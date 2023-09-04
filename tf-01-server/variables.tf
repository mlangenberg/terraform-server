variable "tailscale_key" {
  type      = string
  sensitive = true
}

variable "server_name" {
  type = string
}

variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "smtp_host" {
  type = string
}

variable "smtp_user" {
  type = string
}

variable "smtp_password" {
  type      = string
  sensitive = true
}

variable "notifications_email" {
  type = string
}
