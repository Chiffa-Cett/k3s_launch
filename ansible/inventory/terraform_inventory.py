#!/usr/bin/env python3

import json
import subprocess
from pathlib import Path


TERRAFORM_DIR = Path(__file__).resolve().parents[2] / "terraform"


def get_terraform_outputs():
    result = subprocess.run(
        ["terraform", "output", "-json"],
        cwd=TERRAFORM_DIR,
        capture_output=True,
        text=True,
        check=True,
    )

    return json.loads(result.stdout)


def build_inventory():
    outputs = get_terraform_outputs()

    server_public_ip = outputs["server_public_ip"]["value"]
    server_private_ip = outputs["server_private_ip"]["value"]
    worker_private_ips = outputs["worker_private_ips"]["value"]

    ssh_key = str(Path.home() / ".ssh" / "my_keys.pem")

    # SSH connection to private Workers through the public K3s Server.
    proxy_command = (
        f"-o ProxyCommand=\"ssh "
        f"-i {ssh_key} "
        f"-o IdentitiesOnly=yes "
        f"-W %h:%p "
        f"ubuntu@{server_public_ip}\""
    )

    inventory = {
        "_meta": {
            "hostvars": {
                "k3s-server": {
                    "ansible_host": server_public_ip,
                    "k3s_private_ip": server_private_ip,
                }
            }
        },
        "k3s_server": {
            "hosts": ["k3s-server"]
        },
        "k3s_agents": {
            "hosts": []
        },
        "all": {
            "vars": {
                "ansible_user": "ubuntu",
                "ansible_ssh_private_key_file": ssh_key,
                "ansible_ssh_common_args": "-o IdentitiesOnly=yes",
                "ansible_python_interpreter": "/usr/bin/python3",
            }
        },
    }

    for index, private_ip in enumerate(worker_private_ips, start=1):
        hostname = f"k3s-worker-{index}"

        inventory["k3s_agents"]["hosts"].append(hostname)

        inventory["_meta"]["hostvars"][hostname] = {
            "ansible_host": private_ip,
            "ansible_ssh_common_args": (
                f"-o IdentitiesOnly=yes {proxy_command}"
            ),
        }

    return inventory


if __name__ == "__main__":
    import sys

    if "--list" in sys.argv:
        print(json.dumps(build_inventory(), indent=2))

    elif "--host" in sys.argv:
        print("{}")
