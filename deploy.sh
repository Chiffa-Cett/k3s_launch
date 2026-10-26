#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_FILE="$HOME/.kube/k3s-aws-lab.yaml"

# Explicitly use the AWS K3s cluster, never the default Minikube context.
KUBECTL=(kubectl --kubeconfig "$KUBECONFIG_FILE")

cd "$PROJECT_DIR"

echo "Checking Kubernetes connection..."
"${KUBECTL[@]}" cluster-info

echo "Creating namespace..."
"${KUBECTL[@]}" apply -f kubernetes/namespace.yml

echo "Creating persistent storage claims..."
"${KUBECTL[@]}" apply -f kubernetes/ollama-pvc.yml
"${KUBECTL[@]}" apply -f kubernetes/openwebui-pvc.yml

echo "Deploying Ollama..."
"${KUBECTL[@]}" apply -f kubernetes/ollama.yml

echo "Deploying OpenWebUI..."
"${KUBECTL[@]}" apply -f kubernetes/openwebui.yml

echo "Waiting for Ollama..."
"${KUBECTL[@]}" -n ai rollout status deployment/ollama --timeout=300s

echo "Waiting for OpenWebUI..."
"${KUBECTL[@]}" -n ai rollout status deployment/openwebui --timeout=300s

echo "Creating Ingress..."
"${KUBECTL[@]}" apply -f kubernetes/ingress.yml

echo "Starting model download Job..."
"${KUBECTL[@]}" apply -f kubernetes/ollama-model-job.yml

echo "Waiting for model download..."
"${KUBECTL[@]}" -n ai wait \
  --for=condition=complete \
  job/ollama-pull-model \
  --timeout=1800s

echo "Deployment completed."
