variable "aws_region" {
  description = "The AWS region to deploy the resources in"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "The name of the EC2 key pair to use for SSH access (derived from SSH key path if not provided)"
  type        = string
  default     = ""
}

variable "wg_default_dns" {
  description = "DNS server to use for clients"
  type        = string
  default     = "8.8.8.8,1.1.1.1"
}

variable "hosted_zone_id" {
  description = "The ID of the Route 53 hosted zone to create the DNS record in (optional)"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "The domain name to create a DNS record for (optional)"
  type        = string
  default     = ""
}

variable "ssh_key_path" {
  description = "The path to the SSH private key to use for SSH access"
  type        = string
}
