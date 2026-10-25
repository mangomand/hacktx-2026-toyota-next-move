FROM python:3.12-slim

WORKDIR /app
COPY perception/server.py /app/perception/server.py

ENV PYTHONUNBUFFERED=1
EXPOSE 8787
CMD ["python3", "/app/perception/server.py"]
