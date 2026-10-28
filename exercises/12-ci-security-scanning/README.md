# Exercise 12: CI Security Scanning

Add automated security scanning to a CI pipeline so vulnerabilities are caught
before code ships, not after. You will wire up container image scanning,
infrastructure-as-code scanning, and dependency scanning in one workflow, then
fix the findings it reports.

## Learning goals

- Run a container image scan locally with Trivy and read its output.
- Scan Terraform code with Checkov (or tfsec) and fix a real misconfiguration.
- Add Trivy, Checkov, and dependency scanning to a GitHub Actions workflow.
- Decide when a finding should fail the build and when it should only warn.

## Prerequisites

- Exercises 08 (AWS basics) and 10 (Terraform modules) completed, or at least
  comfortable reading Terraform and Dockerfiles.
- Docker installed locally. Trivy installed (`brew install trivy` or see
  https://aquasecurity.github.io/trivy/latest/getting-started/installation/).
- A GitHub repo you can push a workflow to (this repo works fine).

## Part 1: Scan a container image locally

1. Build the sample image in `app/`:

   ```bash
   cd app
   docker build -t scan-demo:1.0 .
   ```

2. Scan it:

   ```bash
   trivy image scan-demo:1.0
   ```

3. Read the output. Note the difference between:
   - **OS package vulnerabilities** (from the base image) and
   - **application dependencies** (from the app itself, if any).
4. Try the `--severity HIGH,CRITICAL` flag to filter noise, and `--exit-code 1`
   to make the scan fail on findings — this is what CI will use.

**Task:** Write down the three highest-severity findings. For each one, decide:
is it fixable by upgrading the base image, or is it a false positive you would
suppress with a documented reason?

## Part 2: Scan Terraform code

1. From the exercise root, run Checkov against the sample config:

   ```bash
   checkov -d terraform/ --framework terraform_plan
   ```

   No Checkov? `pip install checkov` gets you there. tfsec works too:
   `tfsec terraform/`.

2. The sample config in `terraform/` contains a deliberately open security
   group. Find the failing check, fix it (restrict the ingress CIDR, or add a
   comment explaining why it is open if you genuinely need it), and re-run
   until the check passes.

**Task:** Fix the finding without just suppressing it. If you do suppress a
check, use an inline `# checkov:skip=` comment with a reason, never a blanket
ignore.

## Part 3: Wire it into CI

1. Copy `workflows/security-scan.yml` to `.github/workflows/security-scan.yml`
   in your repo.
2. Push and open the Actions tab. The workflow runs on every push and pull
   request and:
   - scans the container image with Trivy and fails on HIGH/CRITICAL,
   - scans the Terraform code with Checkov,
   - runs Trivy's repo scan for misconfigurations and secrets.
3. Open a pull request that reintroduces the open security group from Part 2
   and watch the Checkov step fail. That red build is the whole point: the
   pipeline now catches what a reviewer might miss.

## Part 4: Make it practical

Not every finding should break the build on day one, or teams start ignoring
the pipeline. Decide for your workflow:

- Which severities fail the build (suggested: HIGH and CRITICAL only)?
- Which checks run on every PR vs. nightly?
- Where do results go — GitHub Security tab via SARIF upload, or just the log?

The workflow in this exercise uploads SARIF to the Security tab, so findings
are tracked instead of buried in logs.

## Stretch goals

- Add Dependabot or Renovate to the repo and merge one automated dependency
  update.
- Add a `.trivyignore` file for one accepted finding, with a comment stating
  why it is accepted and when it expires.
- Run the same scans as a pre-commit hook so problems are caught before push.

## Cleanup

The sample image and Terraform config are local-only examples. `docker rmi
scan-demo:1.0` removes the image; nothing in this exercise creates cloud
resources.
