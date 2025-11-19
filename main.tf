terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "wireguard_sg" {
  name        = "wireguard-sg"
  description = "Allow WireGuard and SSH traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Derive key name from the SSH key path if not explicitly provided
locals {
  # Extract filename without extension from SSH key path
  key_filename = basename(var.ssh_key_path)
  # Remove the file extension (.pem, .key, or .ppk) - fixed regex
  key_name_stripped = replace(local.key_filename, "/\\.(pem|key|ppk)$/", "")
  # Use provided key_name if not empty, otherwise use the derived name
  effective_key_name = var.key_name != "" ? var.key_name : local.key_name_stripped
}

resource "aws_instance" "wireguard_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = local.effective_key_name

  vpc_security_group_ids = [aws_security_group.wireguard_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /tmp/user_data.log) 2>&1
              
              echo "Starting user_data script"

              apt-get update -y
              apt-get install -y wireguard-tools qrencode
              
              echo "Installed wireguard-tools and qrencode"

              # Enable IP forwarding
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
              sysctl -p

              echo "Enabled IP forwarding"

              # Generate server keys
              wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
              echo "Generated server keys"

              # Generate client keys
              wg genkey | tee /home/ubuntu/client_private_key | wg pubkey > /home/ubuntu/client_public_key
              echo "Generated client keys"

              # Create server config
              cat > /etc/wireguard/wg0.conf << EOT
              [Interface]
              Address = 10.0.0.1/24
              SaveConfig = true
              PostUp = iptables -A FORWARD -i %i -j ACCEPT; \
                      iptables -t nat -A POSTROUTING -o $(ip route get 1.1.1.1 | awk '{print $5; exit}') -j MASQUERADE
              PostDown = iptables -D FORWARD -i %i -j ACCEPT; \
                      iptables -t nat -D POSTROUTING -o $(ip route get 1.1.1.1 | awk '{print $5; exit}') -j MASQUERADE

              ListenPort = 51820
              PrivateKey = $(cat /etc/wireguard/server_private_key)

              [Peer]
              PublicKey = $(cat /home/ubuntu/client_public_key)
              AllowedIPs = 10.0.0.2/32
              EOT
              echo "Created server config"

              # Get Public IP
              PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

              # Create client config
              cat > /home/ubuntu/wg0-client.conf << EOT
              [Interface]
              PrivateKey = $(cat /home/ubuntu/client_private_key)
              Address = 10.0.0.2/32
              DNS = ${var.wg_default_dns}

              [Peer]
              PublicKey = $(cat /etc/wireguard/server_public_key)
              AllowedIPs = 0.0.0.0/0
              Endpoint = $PUBLIC_IP:51820
              EOT
              echo "Created client config"

              # Generate QR code
              qrencode -t ANSIUTF8 < /home/ubuntu/wg0-client.conf > /home/ubuntu/wg0-client.conf.qr
              echo "Generated QR code"
              
              chown ubuntu:ubuntu /home/ubuntu/client_private_key
              chown ubuntu:ubuntu /home/ubuntu/client_public_key
              chown ubuntu:ubuntu /home/ubuntu/wg0-client.conf
              chown ubuntu:ubuntu /home/ubuntu/wg0-client.conf.qr
              echo "Changed ownership of client files"

              # Start WireGuard
              systemctl enable wg-quick@wg0
              systemctl start wg-quick@wg0
              echo "Started WireGuard"

              echo "Finished user_data script"
              EOF

  tags = {
    Name = "WireGuard-Server"
  }
}

resource "aws_route53_record" "vpn_dns_record" {
  count = var.domain_name != "" && var.hosted_zone_id != "" ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_instance.wireguard_server.public_ip]
}
