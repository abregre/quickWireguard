output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.wireguard_server.id
}

output "public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.wireguard_server.public_ip
}

output "public_dns" {
  description = "The public DNS name of the EC2 instance"
  value       = aws_instance.wireguard_server.public_dns
}

output "ssh_key_path" {
  description = "The path to the SSH private key"
  value       = var.ssh_key_path
}
