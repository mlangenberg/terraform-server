variable "acme_email" {
  type = string
}

variable "cloudflare_api_email" {
  type = string
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "domain" {
  type = string
}

variable "adguardhome_subdomain" {
  type = string
}
