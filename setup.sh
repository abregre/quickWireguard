#!/bin/bash

# Quick WireGuard Setup Script

set -e

echo "WireGuard VPN - Quick Setup"

case "${1:-usage}" in
  init)
    echo "Initializing Terraform..."
    terraform init
    ;;
  plan)
    echo "Planning deployment..."
    terraform plan
    ;;
  apply)
    echo "Applying configuration..."
    terraform apply -auto-approve
    ;;
  destroy)
    echo "Destroying infrastructure..."
    terraform destroy -auto-approve
    ;;
  ssh)
    echo "Connecting to the instance via SSH..."
    SERVER_PUBLIC_DNS=$(terraform output -raw public_dns)
    if [ -z "$SERVER_PUBLIC_DNS" ]; then
      echo "Error: Could not get public DNS of the server. Ensure Terraform apply has been run successfully."
      exit 1
    fi
    SSH_KEY_PATH=$(terraform output -raw ssh_key_path)
    ssh -i "$SSH_KEY_PATH" ubuntu@"$SERVER_PUBLIC_DNS"
    ;;
  client-config)
    echo "Fetching client config from the EC2 instance..."
    SERVER_PUBLIC_DNS=$(terraform output -raw public_dns)
    if [ -z "$SERVER_PUBLIC_DNS" ]; then
      echo "Error: Could not get public DNS of the server. Ensure Terraform apply has been run successfully."
      exit 1
    fi
    SSH_KEY_PATH=$(terraform output -raw ssh_key_path)

    RETRIES=5
    DELAY=10
    for i in $(seq 1 $RETRIES); do
      echo "Attempt $i/$RETRIES: Checking for client config files on the server..."
      if ssh -o ConnectTimeout=10 -i "$SSH_KEY_PATH" ubuntu@"$SERVER_PUBLIC_DNS" "[ -f /home/ubuntu/wg0-client.conf ] && [ -f /home/ubuntu/wg0-client.conf.qr ]"; then
        echo "Client config files found. Fetching..."
        echo ""
        echo "==================== CLIENT CONFIG ===================="
        ssh -i "$SSH_KEY_PATH" ubuntu@"$SERVER_PUBLIC_DNS" "cat /home/ubuntu/wg0-client.conf"
        echo "====================================================="
        echo ""
        echo "==================== QR CODE =========================="
        ssh -i "$SSH_KEY_PATH" ubuntu@"$SERVER_PUBLIC_DNS" "cat /home/ubuntu/wg0-client.conf.qr"
        echo "====================================================="
        exit 0
      fi
      if [ $i -lt $RETRIES ]; then
        echo "Files not found yet. Retrying in $DELAY seconds..."
        sleep $DELAY
      fi
    done

    echo "Error: Client config files not found on the server after $RETRIES attempts."
    echo "Please check the user_data logs on the server for errors: ssh -i '$SSH_KEY_PATH' ubuntu@$SERVER_PUBLIC_DNS 'cat /tmp/user_data.log'"
    exit 1
    ;;
  *)
    echo "Usage: $0 {init|plan|apply|destroy|ssh|client-config}"
    echo ""
    echo "Commands:"
    echo "  init          - Initialize Terraform"
    echo "  plan          - Show what will be deployed"
    echo "  apply         - Deploy the WireGuard VPN"
    echo "  destroy       - Remove the deployment"
    echo "  ssh           - Connect to the instance via SSH"
    echo "  client-config - Get the client configuration"
    ;;
esac