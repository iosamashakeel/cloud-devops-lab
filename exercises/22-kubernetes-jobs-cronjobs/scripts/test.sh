#!/usr/bin/env bash
# Verify the Jobs completed, the CronJob is scheduled, and the parallel
# Job really produced six completions.
set -euo pipefail

NS=jobs-lab
FAIL=0

check() {
  if [ "$1" = "0" ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    FAIL=1
  fi
}

# 1. The one-off Job completed successfully.
kubectl wait --for=condition=complete --timeout=120s job/daily-report -n "$NS" >/dev/null 2>&1
check "$?" "daily-report Job completed"

# 2. The report actually printed a revenue total.
kubectl logs -n "$NS" job/daily-report 2>/dev/null | grep -q "total revenue"
check "$?" "daily-report printed a revenue total"

# 3. The parallel Job completed with all 6 completions.
kubectl wait --for=condition=complete --timeout=120s job/batch-processor -n "$NS" >/dev/null 2>&1
check "$?" "batch-processor Job completed"

COMPLETIONS=$(kubectl get job batch-processor -n "$NS" \
  -o jsonpath='{.status.succeeded}')
[ "${COMPLETIONS:-0}" = "6" ]
check "$?" "batch-processor has 6 succeeded pods (got ${COMPLETIONS:-0})"

# 4. Each parallel pod processed its own slice (6 distinct indexes logged).
INDEXES=$(kubectl logs -n "$NS" -l job-name=batch-processor 2>/dev/null \
  | grep -o 'Pod index [0-9]' | sort -u | wc -l)
[ "$INDEXES" = "6" ]
check "$?" "all 6 pod indexes logged their slice (got $INDEXES)"

# 5. The CronJob exists with the expected schedule.
SCHEDULE=$(kubectl get cronjob hourly-cleanup -n "$NS" \
  -o jsonpath='{.spec.schedule}')
[ "$SCHEDULE" = "0 * * * *" ]
check "$?" "hourly-cleanup CronJob scheduled at '0 * * * *' (got '$SCHEDULE')"

# 6. A manually triggered CronJob run works.
kubectl create job --from=cronjob/hourly-cleanup test-cleanup -n "$NS" >/dev/null
kubectl wait --for=condition=complete --timeout=120s job/test-cleanup -n "$NS" >/dev/null 2>&1
check "$?" "manual CronJob run completed"
kubectl delete job test-cleanup -n "$NS" >/dev/null

if [ "$FAIL" = "0" ]; then
  echo "All checks passed."
else
  echo "Some checks failed." >&2
  exit 1
fi
