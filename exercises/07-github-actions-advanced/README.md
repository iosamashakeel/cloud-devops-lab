# Exercise 07 — GitHub Actions Advanced

Exercise 02 gave you a single straight-line pipeline. Real pipelines are
smarter: they test several versions at once, skip work that hasn't changed,
reuse shared jobs, and only deploy from `main` after a human approval.
This exercise builds that pipeline around a tiny Python app.

## Files

- `workflows/ci-advanced.yml` — the main workflow: matrix builds, pip
  caching, path filters, concurrency, and a gated deploy job
- `workflows/reusable-test.yml` — a reusable workflow the main workflow
  calls instead of duplicating the test steps
- `app.py` — a small greeting app (the thing being tested)
- `test_app.py` — tests, runnable with plain `unittest`
- `requirements.txt` — no third-party dependencies; the stdlib is enough here

## Prerequisites

- A GitHub repo you can push to (a throwaway fork is fine)
- Python 3.10+ locally if you want to run the tests before pushing

## Task 1 — Run the tests locally first

```bash
python3 -m unittest test_app.py -v
```

All three tests should pass. If they don't, fix the code before you
touch CI — a pipeline that fails locally will fail in CI too, slower.

## Task 2 — Install the workflows

Copy both workflow files into your repo's `.github/workflows/` directory:

```bash
mkdir -p .github/workflows
cp workflows/ci-advanced.yml .github/workflows/ci-advanced.yml
cp workflows/reusable-test.yml .github/workflows/reusable-test.yml
cp app.py test_app.py requirements.txt .
git add .github/workflows app.py test_app.py requirements.txt
git commit -m "add advanced CI pipeline"
git push
```

Open the Actions tab and watch the run. Notice the matrix: three jobs,
one per Python version, running in parallel.

## Task 3 — Read the run, not just the green tick

Open one matrix job and answer these questions from its log:

1. Did the pip cache hit or miss on the first run? On a second run?
2. Which job ran the lint step, and which ones skipped it (see the
   `if:` condition on that step)?
3. What does the `concurrency` block do when you push twice in a row?

Then push a second commit that only touches `README.md` and watch what
happens: the `paths` filter means the test workflow should not run at
all for a docs-only change.

## Task 4 — Try the gated deploy

The deploy job has two gates:

1. `needs: test` — it never runs if tests fail.
2. `if: github.ref == 'refs/heads/main'` — it never runs on a branch.
3. `environment: production` — GitHub pauses the job until someone
   approves it, if you configure required reviewers on that environment
   (Settings → Environments → production → Required reviewers).

Create the `production` environment, add yourself as a required
reviewer, merge a branch to `main`, and approve the deploy when it
pauses. A deploy that anyone can trigger from any branch is not a
deploy pipeline — it is a footgun.

## Task 5 — Extend it yourself

1. Add Python 3.13 to the matrix and watch a fourth job appear.
2. Add a job that builds a Docker image only when the test job passes,
   using `needs: test` (see exercise 01 for the Dockerfile pattern).
3. Add `workflow_dispatch` inputs so you can trigger the pipeline
   manually with a chosen Python version.

## What you practiced

- Matrix builds: one workflow, several runtimes, no copy-paste
- Caching: `actions/setup-python` with `cache: pip` cuts install time
- Reusable workflows: shared jobs called with `uses:`, not duplicated
- Path filters and concurrency: skip pointless runs, cancel stale ones
- Gated deploys: branch checks plus environment approvals
