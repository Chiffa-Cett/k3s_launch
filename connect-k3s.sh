#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$PROJECT_DIR/terraform"
SSH_KEY="$HOME/.ssh/my_keys.pem"
KUBECONFIG_FILE="$HOME/.kube/k3s-aws-lab.yaml"

echo "Checking prerequisites..."

if [[ ! -f "$SSH_KEY" ]]; then
    echo "ERROR: SSH key not found: $SSH_KEY"
    exit 1
fi

if [[ ! -s "$KUBECONFIG_FILE" ]]; then
    echo "ERROR: K3s kubeconfig not found or empty: $KUBECONFIG_FILE"
    echo "Copy the kubeconfig from the K3s server first."
    exit 1
fi

echo "Reading K3s server IP from Terraform..."

SERVER_IP="$(terraform -chdir="$TERRAFORM_DIR" output -raw server_public_ip 2>/dev/null || true)"

if [[ -z "$SERVER_IP" ]]; then
    echo "ERROR: Terraform has no server_public_ip output."
    echo "The AWS infrastructure may not have been created yet."
    exit 1
fi

echo "Opening SSH tunnel to K3s server: $SERVER_IP"
echo "Local Kubernetes API: https://127.0.0.1:6443"
echo "Keep this terminal open while using kubectl."
echo "Press Ctrl+C to close the tunnel."

ssh \
    -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o ExitOnForwardFailure=yes \
    -N \
    -L 127.0.0.1:6443:127.0.0.1:6443 \
    "ubuntu@$SERVER_IP"
