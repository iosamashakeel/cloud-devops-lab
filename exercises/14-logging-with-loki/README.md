# Exercise 14 — Centralised Logging with Loki

Metrics tell you *something is wrong*. Logs tell you *what*. In this
exercise you add the third piece of the observability stack from
Exercises 06 and 13: Grafana Loki collects logs from every container,
Promtail ships them, and Grafana queries them with LogQL — the same
tool you already use for dashboards.

A small demo app produces realistic log lines (requests, warnings,
background jobs) so there is something real to search through.

## Files

- `docker-compose.yml` — runs Loki, Promtail, Grafana and the demo app
- `loki/loki-config.yml` — Loki in single-binary mode, local filesystem storage
- `promtail/promtail-config.yml` — scrapes container logs via the Docker socket
- `demo-app/app.py` — a tiny Python web app that logs every request
- `demo-app/Dockerfile` — builds the demo app
- `grafana/provisioning/datasources/loki.yml` — Grafana connects to Loki on its own

## Prerequisites

- Docker and Docker Compose
- Exercises 06 and 13 completed (or at least comfortable with
  `docker compose up` and the Grafana UI)

## Task 1 — Start the stack

```bash
docker compose up -d --build
docker compose ps
```

All four containers should be `Up`. Loki needs a few seconds before it
accepts logs; if Promtail logs connection errors at first, wait and
check again — it retries on its own.

```bash
docker compose logs promtail | tail -20
```

## Task 2 — Generate some logs

Hit the demo app a few times, then check Grafana at
<http://localhost:3000> (admin / admin):

```bash
curl http://localhost:8080/
curl http://localhost:8080/products
curl http://localhost:8080/checkout
```

The app also logs a background message every few seconds on its own,
so the log stream never goes quiet.

## Task 3 — Your first LogQL query

Go to **Explore** in Grafana, pick the **Loki** data source, and run:

```logql
{container="lab-demo-app"}
```

You should see the app's log lines. Now try to answer real questions:

```logql
# Only warnings — the slow responses
{container="lab-demo-app"} |= "slow"

# Requests to the checkout page
{container="lab-demo-app"} |= "GET /checkout"

# Everything except the background noise
{container="lab-demo-app"} != "cache miss"
```

LogQL reads like PromQL on purpose: `{label="value"}` selects the
stream, `|=` filters lines containing a string, `!=` excludes them.

## Task 4 — Count errors over time

A log line is only useful once you can count it. These queries return
numbers you can graph:

```logql
# Requests per minute
rate({container="lab-demo-app"} |= "GET" [1m])

# Warnings per minute
rate({container="lab-demo-app"} |= "slow" [1m])
```

Switch the query type to **Range** and you get a graph instead of a
list — the same panels you built in Exercise 13, fed by logs instead
of metrics.

## Task 5 — Find the slow endpoint

Generate load against one endpoint and watch which lines show up:

```bash
for i in $(seq 1 50); do curl -s http://localhost:8080/checkout > /dev/null; done
```

Then query `{container="lab-demo-app"} |= "slow"` again and check the
timestamps. In a real incident this is the workflow: an alert fires on
a metric (Exercise 06), you open the dashboard (Exercise 13), then you
drop into the logs for the same time window to find the cause.

## Stretch goals

- Add a second demo container that logs JSON lines, and use a
  `json` parser stage in Promtail to extract a `level` label.
- Add a Grafana alert that fires when the rate of `slow` lines
  exceeds 5 per minute for 2 minutes.
- Point Promtail at a host log file as well (for example
  `/var/log/syslog`) with a `static_configs` job — logs that do not
  come from Docker.
- Give Loki a named volume instead of the default anonymous one, and
  confirm logs survive `docker compose down` and `up`.

## Clean up

```bash
docker compose down
```

## What you practised

- Running Loki + Promtail + Grafana as one stack
- LogQL: stream selectors, line filters, and rate queries
- The metrics → dashboard → logs workflow for debugging an incident
- Shipping container logs centrally instead of `docker logs` per container
