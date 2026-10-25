import os

import psycopg
import redis
from flask import Flask, jsonify, request

app = Flask(__name__)

DATABASE_URL = os.environ["DATABASE_URL"]
REDIS_URL = os.environ.get("REDIS_URL", "redis://cache:6379/0")


def db_connection():
    return psycopg.connect(DATABASE_URL)


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


@app.get("/notes")
def list_notes():
    with db_connection() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, title, body FROM notes ORDER BY id")
        rows = cur.fetchall()
    return jsonify([
        {"id": row[0], "title": row[1], "body": row[2]} for row in rows
    ])


@app.post("/notes")
def create_note():
    data = request.get_json(force=True)
    title = data["title"]
    body = data.get("body", "")
    with db_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO notes (title, body) VALUES (%s, %s) RETURNING id",
            (title, body),
        )
        note_id = cur.fetchone()[0]
    return jsonify({"id": note_id, "title": title, "body": body}), 201


@app.get("/visits")
def visits():
    client = redis.Redis.from_url(REDIS_URL, decode_responses=True)
    count = client.incr("visits")
    return jsonify({"visits": count})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
