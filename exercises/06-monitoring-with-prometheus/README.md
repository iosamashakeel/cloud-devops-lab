# Exercise 06 — Monitoring with Prometheus

Set up real monitoring for a machine. In this exercise you run Prometheus and
the node-exporter with Docker Compose, collect host metrics, explore them with
PromQL, and wire up two alert rules that actually fire.

## Files

- `docker-compose.yml` — runs `prom/prometheus` and `prom/node-exporter`
- `prometheus/prometheus.yml` — scrape configuration (Prometheus itself + node-exporter)
- `prometheus/rules/example.rules.yml` — two working alert rules

## Prerequisites

- Docker and Docker Compose (you built these images yourself in Exercise 01 — now you pull public ones)
- A Linux or macOS machine; the node-exporter mounts `/proc` and `/sys` read-only

## Task 1 — Start the stack

```bash
docker compose up -d
docker compose ps
```

Both containers should be `Up`. Open the Prometheus UI at <http://localhost:9090>.

Under **Status → Targets**, both targets (`prometheus` and `node`) should show
as healthy (`up == 1`).

## Task 2 — Explore metrics with PromQL

In the UI, run a few queries under **Graph**:

```
up
node_cpu_seconds_total
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
node_memory_MemAvailable_bytes
```

The third query is host CPU usage as a percentage — the same expression the
`HighCpuLoad` alert is built on. Switch to the **Graph** tab to see it over time.

Try generating some load in another terminal (`stress -c 4` or a simple
`while true; do :; done` loop) and watch the graph react.

## Task 3 — Make an alert fire

Stop the node-exporter while keeping Prometheus running:

```bash
docker compose stop node-exporter
```

Wait about a minute, then open **Alerts** in the Prometheus UI. The
`InstanceDown` alert moves from inactive → pending → firing. Bring the exporter
back with `docker compose start node-exporter` and watch the alert resolve.

## Task 4 — Check your config before shipping

Prometheus ships a config checker. Run it against your own `prometheus.yml`:

```bash
docker run --rm -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  prom/prometheus:v2.55.1 --config.check --config.file=/etc/prometheus/prometheus.yml
```

It should print `SUCCESS`. Break something on purpose (a bad port, a stray
character), run the check again, and see how the error reads.

## Cleanup

```bash
docker compose down
docker volume rm 06-monitoring-with-prometheus_prometheus-data
```

## What you learned

- How Prometheus scrapes metrics from exporters on a fixed interval
- Writing basic PromQL: instant vectors, `rate()`, aggregation with `by`
- Alert rules: `expr`, `for`, labels, annotations
- Validating a Prometheus config before it goes live
