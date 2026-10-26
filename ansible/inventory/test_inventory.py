#!/usr/bin/env python3

import json
import sys
from terraform_inventory import build_inventory


# Подменяем получение Terraform Outputs тестовыми данными
import terraform_inventory

terraform_inventory.get_terraform_outputs = lambda: {
    "server_public_ip": {"value": "203.0.113.10"},
    "server_private_ip": {"value": "10.20.1.10"},
    "worker_private_ips": {
        "value": [
            "10.20.2.10",
            "10.20.2.11",
            "10.20.2.12",
        ]
    },
}

if "--list" in sys.argv:
    print(json.dumps(build_inventory(), indent=2))
elif "--host" in sys.argv:
    print("{}")
