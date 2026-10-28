# Sample app image for scanning practice. Deliberately small on purpose:
# a pinned, minimal base image keeps the vulnerability list short enough
# to read through by hand.
FROM python:3.12-slim

WORKDIR /app

# No dependencies beyond the standard library, so the scan focuses on
# OS packages from the base image.
COPY app.py .

EXPOSE 8000

CMD ["python3", "app.py"]
