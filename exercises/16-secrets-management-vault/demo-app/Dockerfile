FROM python:3.12-slim

WORKDIR /app
COPY app.py .

# No dependencies: the app uses only the Python standard library.
EXPOSE 8080
CMD ["python", "app.py"]
