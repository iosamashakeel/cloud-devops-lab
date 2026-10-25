# Exercise 09 — Docker Compose multi-service app

Run a small app the way real projects do: several containers that talk to
each other over one Compose network, with persistent data in volumes and
healthchecks so services start in the right order.

## What you build

- `web` — nginx, serves a static page and reverse-proxies `/api/` to the API
- `api` — a small Python (Flask) API with a health endpoint and a notes API
- `db` — Postgres, seeded with one table by `db/init.sql`
- `cache` — Redis, used by the API as a simple counter cache

The API does not need the cache or the database to answer `/health`, but
`/api/notes` does need Postgres. That split is deliberate: it shows you which
failure breaks what.

## Files

- `docker-compose.yml` — the four services, one network, two named volumes
- `web/nginx.conf` — static site + `/api/` proxy, with a healthcheck
- `web/index.html` — a tiny page that calls the API from the browser
- `api/app.py`, `api/requirements.txt`, `api/Dockerfile` — the Flask API
- `db/init.sql` — creates the `notes` table and inserts two starter rows
- `.env.example` — copy to `.env` and fill in before you start

## Prerequisites

- Docker and Docker Compose
- Ports 8080, 5432 and 6379 free on your machine (or change them in
  `docker-compose.yml`)

## Task 1 — Configure and start the stack

```bash
cp .env.example .env
docker compose up -d --build
docker compose ps
```

Every service should be `Up (healthy)` except `cache`, which has no
healthcheck in this exercise and just shows `Up`. If `api` is restarting,
read its logs first — do not just restart the whole stack:

```bash
docker compose logs api
```

## Task 2 — Walk through the app

Open <http://localhost:8080> in a browser. The page loads from nginx and
fetches notes from the API through the `/api/` proxy, so you see the two
starter notes from the database.

Check the same things from the terminal:

```bash
curl http://localhost:8080/api/health
curl http://localhost:8080/api/notes
curl http://localhost:8080/api/visits
```

`visits` counts hits in Redis. Hit it a few times and watch the number rise.
Restart the `cache` container and hit it again — the counter resets, because
Redis here has no volume. That is the point: cache data is disposable,
database data is not.

## Task 3 — Add a note, then prove the data survives a restart

```bash
curl -X POST http://localhost:8080/api/notes \
  -H 'Content-Type: application/json' \
  -d '{"title": "Buy milk", "body": "Oat milk, not whole"}'
curl http://localhost:8080/api/notes
```

Now restart everything and check the note is still there:

```bash
docker compose down
docker compose up -d
curl http://localhost:8080/api/notes
```

Your note survives because Postgres stores its data in the named volume
`pgdata`. Run `docker volume ls` and find it. Then, only when you are done
with the exercise, wipe it on purpose and watch the starter notes come back:

```bash
docker compose down -v
docker compose up -d
curl http://localhost:8080/api/notes
```

## Task 4 — Break one service and see what happens

Stop the database while the rest keeps running:

```bash
docker compose stop db
curl http://localhost:8080/api/health
curl http://localhost:8080/api/notes
```

`/health` still answers (the API process is fine), but `/api/notes` now
fails with a 500. Bring the database back with `docker compose start db`
and confirm the notes endpoint recovers without restarting the API.

## Task 5 — Change one thing and rebuild only that service

Edit `web/index.html` (change the heading), then rebuild just the web
service — there is no need to rebuild the API or the database:

```bash
docker compose up -d --build web
```

Refresh the page and confirm your heading changed.

## Cleanup

```bash
docker compose down -v
```

The `-v` flag removes the named volumes too, so the next run starts from
the seed data in `db/init.sql` again.

## What you learned

- How Compose services find each other by service name on a shared network
- `depends_on` with `condition: service_healthy`, and why plain `depends_on`
  is not enough when a database needs time to accept connections
- Named volumes for data you must keep, and why cache data can live without one
- Reverse-proxying an API behind nginx on one public port
- Debugging a multi-service stack service by service, from its logs
