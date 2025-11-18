# Quick WireGuard VPN on AWS

```
████████████████████████████████████████████████████████████████████████████████
████████████████████████████████████████████████████████████████████████████████
███                                                                          ███
███   ██████╗ ██╗   ██╗██╗ ██████╗██╗  ██╗                                   ███
███  ██╔═══██╗██║   ██║██║██╔════╝██║ ██╔╝                                   ███
███  ██║   ██║██║   ██║██║██║     █████╔╝                                    ███
███  ╚██████╔╝╚██████╔╝██║╚██████╗██║  ██╗                                   ███
███   ╚══▀▀═╝  ╚═════╝ ╚═╝ ╚═════╝╚═╝  ╚═╝                                   ███
███  ██║██║██║██║██║██║██║██║██║██║██║██║██                                  ███
███                                                                          ███
███  ██╗    ██╗██╗██████╗ ███████╗ ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗   ██
███  ██║    ██║██║██╔══██╗██╔════╝██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗  ██
███  ██║ █╗ ██║██║██████╔╝█████╗  ██║  ███╗██║   ██║███████║██████╔╝██║  ██║  ██
███  ██║███╗██║██║██╔══██╗██╔══╝  ██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║  ██
███  ╚███╔███╔╝██║██║  ██║███████╗╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝  ██
███   ╚══╝╚══╝ ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝   ██
███                                                                          ███
████████████████████████████████████████████████████████████████████████████████
████████████████████████████████████████████████████████████████████████████████
```
This project uses Terraform to quickly deploy a personal WireGuard VPN server on an AWS EC2 instance. It's designed to be simple to set up and manage.

## What this does

*   Creates a new EC2 instance with a security group that allows SSH and WireGuard (UDP port 51820) traffic.
*   Installs WireGuard on the server.
*   Generates server and a single client key pair.
*   Creates a WireGuard configuration file for the server and a client configuration file for you to use.
*   (Optional) Creates a Route 53 'A' record pointing your domain name to the VPN server's public IP.

## Prerequisites

Before you begin, make sure you have the following:

*   **AWS Account**: You'll need an AWS account to create the resources.
*   **AWS CLI**: The [AWS Command Line Interface](https://aws.amazon.com/cli/) installed and configured with your credentials. You can configure it by running `aws configure`.
*   **Terraform**: [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) must be installed on your local machine.
*   **An EC2 Key Pair**: You need an [EC2 Key Pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) in your AWS account to be able to connect to the EC2 instance via SSH.

## Setup & Deployment

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd quick-wireguard-aws
    ```

2.  **Configure your variables**:
    Create a file named `terraform.tfvars` and add the following content. This file will hold your specific configuration and is ignored by git.

    ```terraform
    aws_region     = "ap-south-1"
    instance_type  = "t3.micro"
    ssh_key_path   = "/path/to/your/private/key.pem"
    # key_name       = "your-ec2-key-name"  # Optional: AWS key pair name (if not provided, derived from SSH key path filename)
    wg_default_dns = "8.8.8.8,1.1.1.1"

    // Optional: for creating a DNS record in Route 53
    // hosted_zone_id = "your-route53-hosted-zone-id"
    // domain_name    = "vpn.yourdomain.com"
    ```

    **Variable Explanations**:
    *   `aws_region` (required): The AWS region where you want to deploy the server (e.g., "us-east-1"). Default: "us-east-1"
    *   `instance_type` (required): The EC2 instance type for the server (e.g., "t3.micro"). Default: "t3.micro"
    *   `ssh_key_path` (required): The path to your SSH private key file for accessing the server.
    *   `key_name` (optional): The name of the EC2 key pair in AWS. If not provided, it will be automatically derived from the SSH key path filename (without extension). For example, if your SSH key is named "my-key.pem", the key_name will be "my-key".
    *   `wg_default_dns` (required): The DNS servers that your VPN client will use. Default: "8.8.8.8,8.8.4.4"
    *   `hosted_zone_id` (optional): If you want to create a DNS record, provide the ID of your Route 53 hosted zone here.
    *   `domain_name` (optional): The domain name that will point to your VPN server's IP address.

3.  **Deploy the infrastructure**:
    This project comes with a helper script `setup.sh` to simplify the process.

    ```bash
    # Initialize Terraform (downloads the necessary providers)
    ./setup.sh init

    # (Optional) See what Terraform will create
    ./setup.sh plan

    # Apply the configuration to create the resources on AWS
    ./setup.sh apply
    ```
    The `apply` command will take a few minutes to complete.

## How to use the VPN

1.  **Get the client configuration**:
    Once the `apply` command is finished, run the following command to retrieve the client configuration:

    ```bash
    ./setup.sh client-config
    ```
    This command SSHes into the newly created server and fetches the client configuration. It will output both the configuration file content and a QR code for easy import into mobile clients. It might take a minute for the server to be ready and the files to be available, so the script will try a few times if it doesn't find them immediately.

2.  **Connect to the VPN**:
    You have two options to connect:

    *   **Using the configuration file**: Copy the text from the "CLIENT CONFIG" section in your terminal and save it to a file named `wg0-client.conf` on your local machine. Use your favorite WireGuard client (e.g., the official [WireGuard client](https://www.wireguard.com/install/)) and import this file.

    *   **Using the QR code**: If you are using a mobile WireGuard client, you can simply scan the QR code displayed in your terminal to automatically configure the client.

## Managing the Server

*   **SSH into the server**:
    You can connect to the server via SSH to troubleshoot or perform manual configurations:

    ```bash
    ./setup.sh ssh
    ```
    The script will automatically use the SSH key path you provided in your terraform.tfvars file.

## Cleanup

To avoid ongoing charges from AWS, you can destroy all the resources created by this project when you no longer need them:

```bash
./setup.sh destroy
```

This will permanently delete the EC2 instance and all associated resources.
