# Exercise 03 — Terraform Basics

Provision infrastructure with code. In this exercise you use Terraform with the Docker provider to declaratively create the same kind of container you built by hand in Exercise 01 — then change it and watch Terraform converge.

## Files

- `main.tf` — provider, image, and container resources
- `variables.tf` — input variables with defaults

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5 installed. Check with `terraform version`.
- Docker running (Terraform talks to your local Docker daemon).

## Task 1 — Read the configuration

Open `main.tf`:

```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "app" {
  name = "devops-lab-01:latest"
}

resource "docker_container" "app" {
  name  = var.container_name
  image = docker_image.app.image_id

  ports {
    internal = 5000
    external = var.host_port
  }
}
```

Key ideas:

- `terraform {}` declares **which providers** this configuration needs. Providers are plugins — here the community Docker provider by kreuzwerker.
- `resource` blocks describe **desired state**: "there shall be an image" and "there shall be a container". You never tell Terraform *how* to create them.
- `var.container_name` references an input variable (see `variables.tf`) — this keeps values configurable instead of hardcoded.

## Task 2 — Initialize

```bash
terraform init
```

Expected output ends with `Terraform has been successfully initialized!`. This downloads the Docker provider plugin into `.terraform/`.

## Task 3 — Plan

```bash
terraform plan
```

Expected output: `Plan: 2 to add, 0 to change, 0 to destroy.` — one image pull + one container. Review it: the plan is Terraform telling you exactly what it *would* do. Nothing has changed yet.

## Task 4 — Apply

```bash
terraform apply
```

Type `yes` when prompted. Expected output ends with `Apply complete! Resources: 2 added, 0 changed, 0 destroyed.`

Verify the app is up:

```bash
curl http://localhost:5000/health
```

Expected: `{"status":"ok"}`

Note: the image `devops-lab-01:latest` must exist locally (build it in Exercise 01 first) — the Docker provider will pull it if missing, but our local image isn't on any registry, so build it first.

## Task 5 — Change the desired state

Edit `variables.tf`: change the default `host_port` from `5000` to `5001`. Then:

```bash
terraform plan
```

Expected: `Plan: 0 to add, 1 to change, 0 to destroy.` — Terraform detected the drift between config and reality and plans to recreate the container with the new port mapping.

```bash
terraform apply -auto-approve
curl http://localhost:5001/health   # now answers on 5001
```

This is the core IaC loop: **edit config → plan → apply**.

## Task 6 — Destroy (cleanup)

```bash
terraform destroy -auto-approve
```

Expected: `Destroy complete! Resources: 2 destroyed.` Verify with `docker ps` — the container is gone. Always clean up lab resources.

## What you learned

- The Terraform workflow: `init` → `plan` → `apply` → `destroy`
- Providers, resources, and input variables
- Desired-state thinking: you declare *what*, Terraform figures out *how*
- Using `plan` output to review changes before applying them
