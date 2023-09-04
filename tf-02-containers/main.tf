terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.4.0"
    }
  }
}

data "terraform_remote_state" "server" {
  backend = "local"
  config = {
    path = "../tf-01-server/terraform.tfstate"
  }
}

provider "docker" {
  host = "ssh://${data.terraform_remote_state.server.outputs.server_name}"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "docker_volume" "adguardhome_conf" {
  name = "adguardhome_conf"
}

resource "docker_volume" "adguardhome_work" {
  name = "adguardhome_work"
}

data "docker_registry_image" "adguardhome" {
  name = "adguard/adguardhome"
}

resource "docker_image" "adguardhome" {
  name          = data.docker_registry_image.adguardhome.name
  pull_triggers = [data.docker_registry_image.adguardhome.sha256_digest]
}

resource "docker_container" "adguardhome" {
  image   = docker_image.adguardhome.image_id
  name    = "adguardhome"
  restart = "unless-stopped"

  # Adguard Home initial setup wizard
  ports {
    internal = 3000
    external = 3000
  }

  volumes {
    volume_name    = docker_volume.adguardhome_conf.name
    container_path = "/opt/adguardhome/conf"
  }
  volumes {
    volume_name    = docker_volume.adguardhome_work.name
    container_path = "/opt/adguardhome/work"
  }

  depends_on = [
    docker_volume.adguardhome_conf,
    docker_volume.adguardhome_work,
  ]

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.adguardhome.rule"
    value = "Host(`${var.adguardhome_subdomain}.${var.domain}`)"
  }
  labels {
    label = "traefik.http.routers.adguardhome.entrypoints"
    value = "web"
  }
  labels {
    label = "traefik.http.services.adguardhome.loadbalancer.server.port"
    value = "80"
  }
  labels {
    label = "traefik.http.routers.adguardhome.tls.certresolver"
    value = "zone"
  }
}

data "docker_registry_image" "traefik" {
  name = "traefik"
}

resource "docker_image" "traefik" {
  name          = data.docker_registry_image.traefik.name
  pull_triggers = [data.docker_registry_image.traefik.sha256_digest]
}

resource "docker_volume" "traefik" {
  name = "traefik"
}

resource "docker_container" "traefik" {
  image   = docker_image.traefik.image_id
  name    = "traefik"
  restart = "unless-stopped"

  env = [
    "CF_API_EMAIL=${var.cloudflare_api_email}",
    "CF_DNS_API_TOKEN=${var.cloudflare_api_token}"
  ]

  command = [
    "--accesslog=true",
    "--api.insecure=true",
    "--api.dashboard=true",
    "--providers.docker=true",
    "--providers.docker.exposedbydefault=false",
    "--entrypoints.web.address=:443",
    "--certificatesresolvers.zone.acme.dnschallenge=true",
    "--certificatesresolvers.zone.acme.dnschallenge.provider=cloudflare",
    "--certificatesresolvers.zone.acme.email=${var.acme_email}",
    "--certificatesresolvers.zone.acme.storage=/var/lib/acme/acme.json"
  ]

  volumes {
    volume_name    = docker_volume.traefik.name
    container_path = "/var/lib/acme"
  }

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = true
  }

  ports {
    internal = 443
    external = 443
  }

  # Traefik dashboard
  ports {
    internal = 8080
    external = 8080
  }

  depends_on = [
    docker_volume.traefik,
    docker_container.adguardhome
  ]
}

data "cloudflare_zone" "zone" {
  name = var.domain
}

resource "cloudflare_record" "adguardhome" {
  zone_id = data.cloudflare_zone.zone.id
  name    = var.adguardhome_subdomain
  type    = "A"
  value   = data.terraform_remote_state.server.outputs.server_ip
  proxied = true
}
