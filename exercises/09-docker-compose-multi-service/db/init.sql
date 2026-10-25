CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT ''
);

INSERT INTO notes (title, body) VALUES
    ('First note', 'This note was seeded by db/init.sql.'),
    ('Compose works', 'nginx, the API, Postgres and Redis are talking to each other.')
ON CONFLICT DO NOTHING;
