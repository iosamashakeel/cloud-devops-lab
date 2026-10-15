# Exercise 01 — Docker Basics

Build and run a containerized Python web app. By the end you will have written a Dockerfile, built an image, run a container, and understood layers, ports, and volumes.

## Files

- `app.py` — a tiny Flask web app
- `Dockerfile` — the image definition
- `.dockerignore` — keeps the build context small

## Prerequisites

Docker installed and running. Check with:

```bash
docker --version
```

Expected output: something like `Docker version 24.0.x, build ...`.

## Task 1 — Look at the app

Open `app.py`. It's a minimal Flask app exposing `/` and `/health`:

```bash
python3 app.py
```

Then visit http://localhost:5000 in your browser. You should see `Hello from the Docker lab!`. Stop it with `Ctrl+C`.

## Task 2 — Read the Dockerfile

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 5000
CMD ["python", "app.py"]
```

Key ideas:

- Each instruction creates a **layer**. Layers are cached — that's why we copy `requirements.txt` and install *before* copying the app code: dependency installs get reused when only code changes.
- `EXPOSE` documents the port; it doesn't publish it (that's `-p` at run time).

## Task 3 — Build the image

```bash
docker build -t devops-lab-01 .
```

Expected output ends with something like:

```
=> exporting to image
=> => naming to docker.io/library/devops-lab-01:latest
```

## Task 4 — Run the container

```bash
docker run -d -p 5000:5000 --name lab01 devops-lab-01
```

- `-d` runs detached (in the background)
- `-p 5000:5000` maps host port 5000 → container port 5000
- `--name lab01` gives the container a friendly name

Verify:

```bash
curl http://localhost:5000/health
```

Expected output: `{"status":"ok"}`

## Task 5 — Inspect and clean up

```bash
docker ps            # running containers — lab01 should be listed
docker logs lab01    # app output
docker stop lab01 && docker rm lab01
```

## Task 6 (stretch) — Try a volume

Run the container with a mounted volume and confirm you understand the difference between the image layer and runtime state:

```bash
docker run -d -p 5000:5000 -v lab01-data:/app/data --name lab01 devops-lab-01
docker volume ls     # lab01-data should appear
docker stop lab01 && docker rm lab01 && docker volume rm lab01-data
```

## What you learned

- Writing a minimal, cache-friendly Dockerfile
- Building images and running containers with port mapping
- Inspecting containers (`ps`, `logs`) and cleaning up
- Named volumes for runtime state
