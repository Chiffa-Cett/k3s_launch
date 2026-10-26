[README.md](https://github.com/user-attachments/files/33950583/README.md)
# K3s AI Lab on AWS

**A reproducible, four-node Kubernetes lab built with Terraform and Ansible, running Ollama and OpenWebUI on AWS EC2.**

This project demonstrates an end-to-end DevOps workflow: provision cloud infrastructure, configure a lightweight Kubernetes cluster, deploy a self-hosted AI application, validate connectivity, and tear everything down cleanly.

> **Lab project, not a production deployment.** The setup prioritizes hands-on learning and controlled cost over high availability, hardened security, and durable cloud storage.

## Architecture

```text
Local workstation (Ubuntu / VS Code)
  |  Terraform + Ansible + kubectl
  |  SSH (22) / SSH tunnels
  v
AWS VPC — us-east-2, single Availability Zone
  |
  +-- Public subnet (10.20.1.0/24)
  |     +-- K3s server / control plane (t3a.medium)
  |     |     +-- Public IP for SSH access
  |     |     +-- Kubernetes API (6443, reached via SSH tunnel)
  |     +-- NAT Gateway + Internet Gateway
  |
  +-- Private subnet (10.20.2.0/24)
        +-- Worker 1 (t3a.large)  --> Ollama + Qwen2.5 0.5B
        +-- Worker 2 (t3a.medium) --> OpenWebUI
        +-- Worker 3 (t3a.medium) --> Additional workloads / model-pull Job

Within Kubernetes:
  Browser -> Traefik Ingress -> OpenWebUI Service -> OpenWebUI Pod
                                         |
                                         v
                                 Ollama Service -> Ollama Pod
```

The three worker instances have **no public IP addresses**. Ansible reaches them through the K3s server using SSH `ProxyCommand`. Private instances use a NAT Gateway for outbound internet access. The Kubernetes API is accessed locally through an SSH tunnel rather than exposing port 6443 publicly.

## Tech stack

| Layer | Technology |
| --- | --- |
| Cloud infrastructure | AWS EC2, VPC, subnets, route tables, Internet Gateway, NAT Gateway, security groups |
| Infrastructure as Code | Terraform (AWS provider) |
| Configuration management | Ansible with dynamic Terraform inventory |
| Kubernetes | K3s, containerd |
| Ingress | Traefik (bundled with K3s) |
| Storage | K3s `local-path` PersistentVolumes |
| AI inference | Ollama, `qwen2.5:0.5b` |
| Chat interface | OpenWebUI |
| Local administration | SSH, `kubectl`, VS Code Remote SSH |

## Repository layout

```text
homework_k3s_launch/
├── terraform/
│   ├── providers.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── network.tf
│   ├── security_groups.tf
│   ├── ec2.tf
│   └── outputs.tf
├── ansible/
│   ├── inventory/
│   │   └── terraform_inventory.py
│   ├── group_vars/
│   │   └── all.yml
│   ├── roles/
│   │   ├── k3s_server/tasks/main.yml
│   │   └── k3s_agent/tasks/main.yml
│   └── site.yml
├── kubernetes/
│   ├── namespace.yml
│   ├── ollama-pvc.yml
│   ├── openwebui-pvc.yml
│   ├── ollama.yml
│   ├── openwebui.yml
│   ├── ingress.yml
│   └── ollama-model-job.yml
├── get-k3s-config.sh
├── connect-k3s.sh
├── deploy.sh
└── README.md
```

## Prerequisites

- AWS account with permissions and sufficient EC2 vCPU quota to create four instances, a VPC, and a NAT Gateway.
- AWS CLI authenticated to the intended account (`aws login` or another supported authentication method).
- Terraform, Ansible, Python 3, `kubectl`, OpenSSH, and `curl` installed on the local Linux environment.
- An **existing AWS EC2 key pair named `my_keys`** in `us-east-2`, with its matching private key at `~/.ssh/my_keys.pem`.
- Network access to AWS, K3s installation endpoints, and container registries.

This repository assumes the AWS region **`us-east-2` (Ohio)** and the local SSH key path above. Adjust the Terraform configuration, inventory, and scripts if your environment differs.

Protect the SSH key:

```bash
chmod 600 ~/.ssh/my_keys.pem
aws sts get-caller-identity
```

**Cost warning:** EC2 instances, NAT Gateway, public IPv4 addresses, storage, and data transfer can incur charges. In particular, **NAT Gateway continues to cost money even when EC2 instances are stopped**. Destroy the lab when finished.

## Deployment

Run commands from the repository root unless stated otherwise.

### 1. Provision AWS infrastructure

```bash
terraform -chdir=terraform init
terraform -chdir=terraform validate

# Allow SSH only from your current public IPv4 address.
export TF_VAR_admin_ip="$(curl -4 -fsS https://checkip.amazonaws.com)"

terraform -chdir=terraform plan -out=/tmp/k3s-lab.tfplan
terraform -chdir=terraform apply /tmp/k3s-lab.tfplan
terraform -chdir=terraform output
```

Terraform provisions one public control-plane instance, three private workers, the required network routes, and security-group rules. Save and apply the plan only after reviewing the resources and expected charges.

### 2. Confirm SSH access

```bash
SERVER_IP="$(terraform -chdir=terraform output -raw server_public_ip)"
ssh -i ~/.ssh/my_keys.pem -o IdentitiesOnly=yes \
  "ubuntu@${SERVER_IP}" 'hostname && whoami'
```

On first connection, verify the SSH host-key fingerprint using a trusted source before accepting it. Private worker SSH host keys may also require first-time verification before Ansible can connect non-interactively.

### 3. Install K3s with Ansible

```bash
ansible-inventory -i ansible/inventory/terraform_inventory.py --graph
ansible all -i ansible/inventory/terraform_inventory.py -m ansible.builtin.ping

ansible-playbook \
  -i ansible/inventory/terraform_inventory.py \
  ansible/site.yml
```

The playbook installs K3s on the control plane, joins the three agents using the server token, and labels workers for workload placement:

- `k3s-worker-1`: `workload=ollama`
- `k3s-worker-2`: `workload=openwebui`

Verify the cluster directly on the server:

```bash
ssh -i ~/.ssh/my_keys.pem -o IdentitiesOnly=yes \
  "ubuntu@${SERVER_IP}" 'sudo k3s kubectl get nodes -o wide'
```

### 4. Connect local kubectl securely

Retrieve the cluster configuration:

```bash
./get-k3s-config.sh
```

This saves `~/.kube/k3s-aws-lab.yaml` with restricted permissions, without replacing the default `~/.kube/config`. The script refuses to overwrite an existing lab kubeconfig.

Open a **separate terminal** and keep the SSH tunnel running:

```bash
./connect-k3s.sh
```

In another terminal:

```bash
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml get nodes -o wide
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml get nodes -L workload
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml get pods -n kube-system
```

All four nodes should be `Ready`; CoreDNS, Traefik, and `local-path-provisioner` should be running.

### 5. Deploy the AI workloads

With the Kubernetes API tunnel still open:

```bash
./deploy.sh
```

The script creates namespace `ai`, provisions two PVCs, deploys Ollama and OpenWebUI, creates the Traefik Ingress, and runs a Job to pull **`qwen2.5:0.5b`** into Ollama.

Check the result:

```bash
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml get pods -n ai -o wide
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml get pvc,pv -n ai
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml get ingress -n ai -o wide
```

Expected: Ollama on worker 1, OpenWebUI on worker 2, the model-pull Job `Completed`, and both PVCs `Bound`.

## Access OpenWebUI

### Option A: Kubernetes port-forward (simplest)

Keep the API tunnel open and run:

```bash
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml \
  -n ai port-forward svc/openwebui 18081:80
```

Open **http://127.0.0.1:18081** in a browser running in the *same network environment*. If the browser is on Windows and `kubectl` runs inside a VMware Ubuntu guest, forward port **18081** using **VS Code Remote SSH → Ports → Open in Browser**.

The first OpenWebUI user can complete the initial administrator setup. Use a unique password.

### Option B: Verify Traefik Ingress through SSH

In another terminal:

```bash
SERVER_IP="$(terraform -chdir=terraform output -raw server_public_ip)"
ssh -i ~/.ssh/my_keys.pem -o IdentitiesOnly=yes \
  -o ExitOnForwardFailure=yes -N \
  -L 127.0.0.1:18080:127.0.0.1:80 \
  "ubuntu@${SERVER_IP}"
```

Test the host-based Ingress route from the Ubuntu environment:

```bash
curl -I -H 'Host: chat.k3s.local' http://127.0.0.1:18080/
```

An HTTP `200 OK` confirms the Traefik route reaches OpenWebUI. The custom `Host` header is required because the Ingress matches **`chat.k3s.local`**. This option verifies Ingress; Option A is simpler for browser access.

## Validate inference

From a terminal with Kubernetes API access:

```bash
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml \
  exec -n ai deployment/ollama -- \
  ollama run qwen2.5:0.5b 'Explain Kubernetes in one sentence.'
```

You can also select `qwen2.5:0.5b` in OpenWebUI and send a chat message. The 0.5B model is intentionally small for a CPU-only lab; answer quality and latency are limited and are **not** a measure of Kubernetes correctness.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Ansible worker SSH prompts or fails | Verify worker host keys; ensure the inventory `ProxyCommand` specifies the key for the jump host. |
| A workload remains `Pending` | Check `kubectl get nodes -L workload`, PVC status, and `kubectl describe pod -n ai <pod-name>`. |
| Local `kubectl` cannot connect | Confirm `./connect-k3s.sh` is still running and local port `6443` is available. |
| OpenWebUI does not open in Windows | Remember that Windows and VMware Ubuntu have different `localhost` addresses; use VS Code port forwarding. |
| Ingress returns `404` | Verify the HTTP `Host: chat.k3s.local` header and Ingress rules. |
| Slow or unexpected AI response | Inspect `kubectl logs -n ai deployment/ollama --tail=50` and `kubectl top pods -n ai`; the small CPU-only model has limited capabilities. |

Useful diagnostics:

```bash
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml get events -n ai --sort-by=.lastTimestamp
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml logs -n ai deployment/ollama --tail=50
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml logs -n ai deployment/openwebui --tail=50
kubectl --kubeconfig ~/.kube/k3s-aws-lab.yaml top pods -n ai
```

## Cleanup — avoid ongoing AWS charges

**Destroy the infrastructure when the lab is finished:**

```bash
terraform -chdir=terraform destroy \
  -var "admin_ip=$(curl -4 -fsS https://checkip.amazonaws.com)"
```

Review the destruction plan and type `yes` to confirm. Wait for Terraform to report `Destroy complete!`, then check:

```bash
terraform -chdir=terraform state list
```

The state list should be empty. Also review the AWS Console/Billing for unexpected remaining resources or delayed charges. Stop the local SSH tunnels and `kubectl port-forward` processes with `Ctrl+C`.

> **Data lifecycle:** The `local-path` volumes reside on the EC2 nodes. Destroying the lab deletes those instances and their local application data, including downloaded models and OpenWebUI state. The Terraform, Ansible, Kubernetes manifests, and scripts remain in your local repository.

## Security and design notes

- SSH access to the public control plane is restricted to the administrator's current public IPv4 address.
- Worker instances have private addresses only; Kubernetes API access is tunneled over SSH.
- This lab uses a single availability zone, one control-plane node, and node-local storage: **no high availability or disaster recovery**.
- The sample web access uses plain HTTP *inside a local tunnel*; production deployments require appropriate TLS, authentication, secrets management, monitoring, and network policies.
- Never commit `*.pem`, kubeconfig files, Terraform state/plan files, credentials, or secrets. Review `.gitignore` before publishing.

## Outcome

Successfully demonstrated a complete **provision → configure → deploy → verify → destroy** workflow. The cluster ran four `Ready` K3s nodes, scheduled Ollama and OpenWebUI onto dedicated workers, provisioned persistent volumes, routed HTTP through Traefik, and generated responses from a self-hosted model before all **22 Terraform-managed AWS resources** were destroyed.
