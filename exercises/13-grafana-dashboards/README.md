# Exercise 13 — Dashboards with Grafana

Prometheus collects the numbers; Grafana turns them into something a human can
read at 3am. In this exercise you build on Exercise 06: same Prometheus +
node-exporter stack, plus Grafana with a provisioned Prometheus data source and
a real dashboard that loads automatically — no clicking through the UI to set it
up.

## Files

- `docker-compose.yml` — runs `prom/prometheus`, `prom/node-exporter` and `grafana/grafana`
- `prometheus/prometheus.yml` — scrape config (same as Exercise 06)
- `grafana/provisioning/datasources/prometheus.yml` — Grafana connects to Prometheus on its own
- `grafana/provisioning/dashboards/dashboard.yml` — tells Grafana where to find dashboard files
- `grafana/dashboards/host-overview.json` — a host overview dashboard: CPU, memory, disk, network

## Prerequisites

- Docker and Docker Compose
- Exercise 06 completed (or at least comfortable with `docker compose up` and PromQL basics)

## Task 1 — Start the stack

```bash
docker compose up -d
docker compose ps
```

All three containers should be `Up`. Open Grafana at <http://localhost:3000>
and sign in with `admin` / `admin` (you will be asked to change the password
on first login — pick something you will remember, this is a local lab).

## Task 2 — Check the data source provisioned itself

Go to **Connections → Data sources**. You should see a Prometheus data source
already listed, pointing at `http://prometheus:9090`. You did not add it by
hand — `grafana/provisioning/datasources/prometheus.yml` did that at startup.

Click **Save & test** on it. It should report "Successfully queried the
Prometheus API". If it fails, check that the Prometheus container is healthy
(`docker compose logs prometheus`) and that the two containers share a network
(Compose puts them on one by default).

## Task 3 — Open the provisioned dashboard

Go to **Dashboards**. The **Host Overview** dashboard should already be there,
loaded from `grafana/dashboards/host-overview.json` — again, no manual import.

It shows four panels:

- **CPU usage %** — `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
- **Memory used %** — `100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)`
- **Disk used % (root)** — `100 * (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})`
- **Network traffic** — `rate(node_network_receive_bytes_total[5m])` and transmit

Generate some load in another terminal and watch the CPU panel move:

```bash
stress -c 2 --timeout 60
```

No `stress` installed? This works too:

```bash
timeout 60 bash -c 'while true; do :; done' &
```

## Task 4 — Add your own panel

Dashboards you click together in the UI live only in Grafana's database. To
keep them in version control, export them back to a file:

1. On the Host Overview dashboard, click **Edit** on any panel, then **Add →
   New panel**.
2. Build a panel showing load average: `node_load1`, `node_load5`,
   `node_load15`. Title it "Load average", unit "short".
3. Save the dashboard, then go to **Dashboard settings → JSON Model → Copy
   to clipboard** and paste it over `grafana/dashboards/host-overview.json`
   (or save it as a new file and add it to the provisioning folder).
4. Restart Grafana (`docker compose restart grafana`) and confirm your panel
   is still there. That round-trip — UI edit, export to JSON, restart — is
   how dashboards survive in a real team: the JSON file is the source of
   truth, not the running instance.

## Task 5 — Make it survive a restart

Stop everything and bring it back:

```bash
docker compose down
docker compose up -d
```

Sign in again. The data source and the dashboard should both be back without
you touching anything. That is the point of provisioning: a fresh Grafana is
useful within seconds of starting.

## Stretch goals

- Add an alert in Grafana (Alerting → Alert rules) that fires when CPU usage
  stays above 80% for 5 minutes, and point it at a contact point of your
  choice.
- Add a second dashboard for Prometheus itself: scrape duration
  (`prometheus_target_interval_length_seconds`), samples ingested
  (`rate(prometheus_tsdb_head_samples_appended_total[5m])`), and targets up.
- Give Grafana a persistent volume so your admin password and UI edits survive
  `docker compose down -v` — and think about why that conflicts with
  treating the JSON files as the source of truth.

## Clean up

```bash
docker compose down
```

## What you practised

- Provisioning Grafana data sources and dashboards as code
- Reading host metrics on a dashboard instead of raw PromQL
- The export-to-JSON workflow that keeps dashboards in version control
- Why "configured by hand in the UI" is not a deployment strategy
