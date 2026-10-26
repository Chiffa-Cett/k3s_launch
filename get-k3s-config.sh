#!/usr/bin/env bash

set -euo pipefail
umask 077

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$PROJECT_DIR/terraform"
SSH_KEY="$HOME/.ssh/my_keys.pem"
KUBECONFIG_FILE="$HOME/.kube/k3s-aws-lab.yaml"

if [[ ! -f "$SSH_KEY" ]]; then
    echo "ERROR: SSH key not found."
    exit 1
fi

if [[ -e "$KUBECONFIG_FILE" ]]; then
    echo "ERROR: Kubeconfig already exists: $KUBECONFIG_FILE"
    echo "Refusing to overwrite it."
    exit 1
fi

SERVER_IP="$(terraform -chdir="$TERRAFORM_DIR" output -raw server_public_ip 2>/dev/null || true)"

if [[ -z "$SERVER_IP" ]]; then
    echo "ERROR: No server_public_ip in Terraform outputs."
    exit 1
fi

mkdir -p "$HOME/.kube"

TEMP_FILE="$(mktemp "$HOME/.kube/.k3s-aws-lab.XXXXXX")"
trap 'rm -f "$TEMP_FILE"' EXIT

echo "Retrieving kubeconfig from K3s server..."

ssh \
    -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o BatchMode=yes \
    "ubuntu@$SERVER_IP" \
    'sudo cat /etc/rancher/k3s/k3s.yaml' \
    > "$TEMP_FILE"

if [[ ! -s "$TEMP_FILE" ]]; then
    echo "ERROR: Retrieved kubeconfig is empty."
    exit 1
fi

if ! grep -q 'kind: Config' "$TEMP_FILE"; then
    echo "ERROR: Retrieved file does not look like a kubeconfig."
    exit 1
fi

chmod 600 "$TEMP_FILE"
ln "$TEMP_FILE" "$KUBECONFIG_FILE"

echo "Kubeconfig saved to: $KUBECONFIG_FILE"
echo "Permissions: 600"
