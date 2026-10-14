# Cloud & DevOps Lab

A hands-on lab where I work through the core cloud & DevOps skills step by step: Docker, CI/CD with GitHub Actions, Terraform, and Kubernetes. Every exercise is self-contained with clear tasks and expected outputs — built to actually run, not just to read.

## Learning path

| # | Exercise | What you practice |
|---|----------|-------------------|
| 01 | [Docker Basics](exercises/01-docker-basics/) | Containerize a Python web app: Dockerfile, build, run, volumes |
| 02 | [GitHub Actions CI](exercises/02-github-actions-ci/) | CI pipeline: lint, test, and Docker build on every push |
| 03 | [Terraform Basics](exercises/03-terraform-basics/) | Provision a Docker container with Terraform (IaC) |
| 04 | Kubernetes Basics | *coming soon* — deployments & services with k3d |

## How to use

Each exercise lives in its own folder under `exercises/` with a README that walks through the tasks. Work them in order — later exercises build on earlier ones.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running
- A terminal and a text editor
- Exercise 03 additionally needs [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5

## Repo structure

```
cloud-devops-lab/
├── README.md
└── exercises/
    ├── 01-docker-basics/        # Dockerfile + Python app
    │   ├── README.md
    │   ├── app.py
    │   ├── Dockerfile
    │   └── .dockerignore
    ├── 02-github-actions-ci/    # CI pipeline for the app
    │   ├── README.md
    │   ├── .github/workflows/ci.yml
    │   └── test_app.py
    └── 03-terraform-basics/     # IaC with the Docker provider
        ├── README.md
        ├── main.tf
        └── variables.tf
```

## Notes

This is a learning repo — commits are intentionally small and frequent so the history reads like a real learning journey. If you spot a mistake, open an issue or a PR.
