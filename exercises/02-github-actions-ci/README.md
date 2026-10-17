# Exercise 02 — GitHub Actions CI

Add a continuous integration pipeline for the app from Exercise 01. Every push and pull request will automatically: lint the code, run the tests, and build the Docker image.

## Files

- `.github/workflows/ci.yml` — the pipeline definition
- `test_app.py` — a small pytest suite for the Flask app
- `requirements-dev.txt` — dev dependencies (pytest, flake8)
- `app.py`, `requirements.txt`, `Dockerfile` — the same app from Exercise 01, copied here so this exercise is self-contained

## Prerequisites

- Exercise 01 completed (you understand the app and its Dockerfile)
- The code pushed to a GitHub repository (pipelines run on GitHub, not locally)

## Task 1 — Read the workflow

Open `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -r requirements.txt -r requirements-dev.txt
      - run: flake8 app.py test_app.py --max-line-length=100
      - run: pytest -v

  docker-build:
    runs-on: ubuntu-latest
    needs: lint-and-test
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - run: docker build -t devops-lab-01:${{ github.sha }} .
```

Key ideas:

- **Triggers** (`on:`): the pipeline runs on pushes to `main` and on every pull request.
- **Jobs run in parallel** by default; `needs:` makes `docker-build` wait for `lint-and-test` — no point building a broken image.
- Each `run:` step executes in a fresh shell on the runner.

## Task 2 — Read the tests

`test_app.py` uses Flask's built-in test client — no server needed:

```python
def test_index(client):
    assert client.get("/").status_code == 200

def test_health(client):
    assert client.get("/health").get_json() == {"status": "ok"}
```

## Task 3 — Run it locally first

```bash
pip install -r requirements.txt -r requirements-dev.txt
flake8 app.py test_app.py --max-line-length=100   # expect no output = clean
pytest -v
```

Expected output:

```
test_app.py::test_index PASSED
test_app.py::test_health PASSED
2 passed in ...
```

## Task 4 — Push and watch it run

> **Important:** GitHub only runs workflows from the repository-root `.github/workflows/` directory. To activate this pipeline for real, copy the workflow there:
>
> ```bash
> mkdir -p .github/workflows
> cp exercises/02-github-actions-ci/.github/workflows/ci.yml .github/workflows/
> ```
>
> (In this lab the workflow lives inside the exercise folder so each exercise stays self-contained — the copy step above is part of the exercise.)

Commit everything and push to GitHub. Then open the **Actions** tab of your repository — you should see the "CI" workflow run with both jobs green ✅.

## Task 5 (stretch) — Break it on purpose

Change `app.py` so `/health` returns the wrong JSON, push, and watch the pipeline fail. Then fix it and watch it go green again. This is the whole point of CI: fast, automatic feedback.

## What you learned

- Structuring a GitHub Actions workflow (triggers, jobs, steps)
- Lint + test as a quality gate before building
- `needs:` for job dependencies
- Reading pipeline results in the Actions tab
