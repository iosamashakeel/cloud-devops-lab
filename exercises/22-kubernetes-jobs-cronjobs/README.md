# Exercise 22 — Kubernetes Jobs and CronJobs

Deployments and StatefulSets run forever. A lot of real work does not:
nightly reports, database migrations, backups, image processing, data
imports. For work that runs once and finishes, Kubernetes has the Job.
For work that runs on a schedule, it has the CronJob.

## What you will learn

- How a Job differs from a Deployment: run to completion, then stop
- Retries with `backoffLimit` and what `restartPolicy: Never` really means
- Running a Job in parallel with indexed completions (`completionMode: Indexed`)
- Scheduling recurring work with a CronJob, including history limits and
  concurrency rules
- Cleaning finished Jobs up automatically with `ttlSecondsAfterFinished`

## Prerequisites

- A local cluster: `kind` (used here) or minikube
- `kubectl` configured against the cluster
- Exercise 04 (Kubernetes basics) completed

## Why Jobs matter

A Deployment's job is to keep N pods alive forever. If the container exits,
the Deployment restarts it, forever. A Job's job is the opposite: run the
command, and when the pod exits with code 0, the work is done. If it exits
non-zero, the Job retries it up to `backoffLimit` times, with growing delays
between attempts. That makes Jobs the right tool for migrations (run once
before a deploy), batch processing (split the work across pods), and
anything scheduled (backups every night at 02:00).

## Steps

### 1. Create the cluster

```bash
./scripts/setup.sh
```

This creates a kind cluster (`jobs-lab`) and applies the manifests. The
one-off Job and the parallel Job run immediately; the CronJob just sits
there waiting for its schedule.

### 2. Watch the one-off Job finish

```bash
kubectl get jobs -n jobs-lab --watch
kubectl get pods -n jobs-lab
```

The `daily-report` Job runs a small Python script (from the `report-script`
ConfigMap) that pretends to process a day of orders and prints a summary.
When the pod exits with code 0, the Job shows `1/1` completions and the pod
moves to `Completed` — it is not restarted.

Read the output:

```bash
kubectl logs -n jobs-lab job/daily-report
```

### 3. Watch the parallel Job split the work

```bash
kubectl get pods -n jobs-lab -l job-name=batch-processor
kubectl logs -n jobs-lab -l job-name=batch-processor
```

The `batch-processor` Job has `completions: 6` and `parallelism: 3`, so
three pods run at a time until six have finished. It uses indexed
completion mode, so each pod knows its own index through the
`JOB_COMPLETION_INDEX` environment variable and processes only its own
slice of the work (here: items 0–9, 10–19, and so on). Try changing
`parallelism` to 6 and re-applying: all six pods start at once.

### 4. Check the CronJob

```bash
kubectl get cronjobs -n jobs-lab
```

The `hourly-cleanup` CronJob is scheduled for the top of every hour
(`0 * * * *`). It has not run yet, and that is fine — you can trigger it
manually without waiting:

```bash
kubectl create job --from=cronjob/hourly-cleanup manual-cleanup -n jobs-lab
kubectl logs -n jobs-lab job/manual-cleanup
kubectl delete job manual-cleanup -n jobs-lab
```

`kubectl create job --from=cronjob/...` is the standard way to test a
CronJob's template before trusting the schedule.

### 5. Run the checks

```bash
./scripts/test.sh
```

This verifies both Jobs completed, the CronJob exists with the right
schedule, and the parallel Job really produced six completions.

## Tasks

1. Make the `daily-report` Job fail on purpose: change the ConfigMap
   script to exit with code 1, re-apply, and delete/recreate the Job.
   Watch `kubectl get pods -n jobs-lab` — how many restarts happen
   before the Job gives up? (Answer: `backoffLimit: 3`, so 3 retries
   after the first failure, with growing delays: 10s, 20s, 40s...)
2. Set `ttlSecondsAfterFinished: 60` on the parallel Job and watch it
   disappear a minute after finishing. Why is this useful? (Finished
   Jobs pile up; the TTL keeps `kubectl get jobs` readable.)
3. Change the CronJob schedule to `*/2 * * * *` and watch a Job appear
   every two minutes. Then set `concurrencyPolicy: Forbid` vs `Replace`
   and think about which one you want for a backup job. (Forbid: never
   run two backups at once. Replace: a late run kills the previous one.)
4. Give the CronJob `successfulJobsHistoryLimit: 1` and
   `failedJobsHistoryLimit: 3`. Run it manually a few times and check
   `kubectl get jobs -n jobs-lab` — only the last successful Job is kept.
5. Look at the parallel Job's `activeDeadlineSeconds`. What happens if a
   single pod hangs forever? (The whole Job is killed after the deadline,
   even if other pods already finished.)

## Cleanup

```bash
kind delete cluster --name jobs-lab
```

## Key takeaways

- Use a Job for work that finishes; use a Deployment for work that runs
  forever. Picking the wrong one is the most common beginner mistake.
- `backoffLimit` controls retries; `restartPolicy: Never` means a failed
  pod is replaced by a new pod, not restarted in place.
- Indexed completions give each pod its own slice of the work through
  `JOB_COMPLETION_INDEX` — the standard pattern for batch processing.
- CronJobs are just Jobs with a schedule; always test them with
  `kubectl create job --from=cronjob/...` instead of waiting for the clock.
- Set `ttlSecondsAfterFinished` and history limits, or finished Jobs and
  their pods accumulate forever.
