# syntax=docker/dockerfile:1
FROM python:3.12-slim

# No third-party dependencies: server.py uses only the standard library.
WORKDIR /app
COPY server.py .

# Run as a non-root user; the app listens on 8080, so it does not
# need privileges. This also keeps the Pod Security Standards from
# Exercise 24 happy.
RUN useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app
USER 10001

EXPOSE 8080
CMD ["python3", "server.py"]
