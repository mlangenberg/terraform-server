terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.38.2"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_server" "server" {
  name        = var.server_name
  image       = "ubuntu-22.04"
  server_type = "cax11"
  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }
  user_data = templatefile("cloud-config.yml.tftpl", {
    tailscale_key       = var.tailscale_key
    smtp_host           = var.smtp_host
    smtp_user           = var.smtp_user
    smtp_password       = var.smtp_password
    notifications_email = var.notifications_email
  })
  lifecycle {
    ignore_changes = [
      user_data
    ]
  }
}

output "server_name" {
  value = hcloud_server.server.name
}

output "server_ip" {
  value = hcloud_server.server.ipv4_address
}
