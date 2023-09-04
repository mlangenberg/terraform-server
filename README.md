# My VPS

## Motivation

For running docker containers in the cloud, I want to be able to provision virtual machines using infrastructure as code, so that I don't have to manually follow step by step guides that can become quickly outdated.

After bootstrapping, I expect machines to:
 - [x] Have joined my [Tailscale](https://tailscale.com/) network.
 - [x] Be reachable via [Tailscale SSH](https://tailscale.com/tailscale-ssh/). 
 - [x] Can only be reached on port 80 and 443 via public internet.
 - [x] Be ready as a docker node to be managed with [Docker Context](https://docs.docker.com/engine/context/working-with-contexts/)
 - [x] Have a user `mlangenberg` configured with the fish shell.
 - [x] Automatically apply software updates.
 
To achieve this I want to use as few tools as possible, with the most important tools being [Terraform](https://www.terraform.io/) and [cloud-init](https://cloudinit.readthedocs.io/en/latest/index.html). Most cloud providers allow specifying a `cloud-config.yml` to configure software and users. This already covers most of my wishes, with the exception of automatically joining my Tailscale network. To setup a new server with a `cloud-config.yml` that includes a tailscale auth key, Terraform is used.

After Terraform provisions a new machine and the `cloud-config` is executed we have a clean machine, ready to run Docker containers. The full working Terraform configuration is shared in this repository, which you can use as inspiration for your own setup. Feedback is welcome as this is also my first time working with Terraform.

## External service providers

The Terraform configuration relies on the following external service providers.

 - **Hetzner** as primary cloud provider for hosting servers.
 - **Tailscale** as a VPN service to connect to servers from my private network.
 - **Amazon Simple Email Service (SES)** as an SMTP service for package update notifications.
 - **Cloudflare** as a DNS provider for managing DNS records. 

## Provisioning a new server

    cd tf-01-server
    cp terraform.tfvars.example terraform.tfvars
    terraform init
    terraform apply

It will take a few minutes before all packages are upgraded and the system is rebooted, but eventually the new server will be ready and join the Tailscale network.    

## Deploying AdGuard Home

Normally I use `docker-compose` with a remote context to deploy Docker containers, but I wanted to see if Terraform could be used for this as well. It turns out that this is certainly possible and I use it to deploy [AdGuard Home](https://hub.docker.com/r/adguard/adguardhome).

    cd tf-02-containers
    cp terraform.tfvars.example terraform.tfvars
    terraform init
    terraform apply

This will pull the images, create docker volumes and run the container for AdGuard Home and as well for [Traefik](https://traefik.io/traefik/). Traefik is used as a reverse proxy for handling TLS termination and uses Cloudflare for a [Let's Encrypt](https://letsencrypt.org/) DNS challenge to retrieve public TLS certificates. In addition a DNS record is created to point to the IP of the server that was created in the previous step, so that AdGuard Home can be reached using a proper domain name.

## AdGuard Home first install notes
Open a browser to port 3000 on the new machine and complete the setup wizard. Afterwards edit `AdGuardHome.yml`, change the properties noted below and restart the container to enable dns-over-http behind a reverse proxy.

```yaml
tls:
  enabled: true
  port_https: 0
  port_dns_over_tls: 0
  port_dns_over_quic: 0
  allow_unencrypted_doh: true
trusted_proxies:
  - 172.17.0.0/16
```

To edit `AdGuardHome.yml`, the following command can be used on the server.

```
sudo nano (docker volume inspect --format '{{.Mountpoint}}' adguardhome_conf)/AdGuardHome.yaml
docker restart adguardhome
```

## Configuring AdGuard Home clients

To generate a .mobileconfig for using DNS over HTTPS on macOS and iOS devices, visit:

```
https://adguardhome.example.com/apple/doh.mobileconfig?host=adguardhome.example.com&client_id=john-iphone
```

## Downloading and restoring a volume

To migrate AdGuard Home between servers, `bin/volume` is provided to download or restore a backup of a Docker volume.

    bin/volume download host-a adguardhome_conf backups/
    bin/volume restore host-b adguardhome_conf backups/adguardhome_conf_2023-09-03T21:48:37.tar

For the download command this will stop containers using the adguardhome_conf volume, create a temporary container based on alpine to mount the volume, create a tar archive, then remove the temporary container and start the stopped container again. For the restore command it will do the same, but copy a given tar file into the specified volume.

