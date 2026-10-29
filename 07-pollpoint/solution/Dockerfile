# ═══════════════════════════════════════════════════════════════
#  SOLUTION · PollPoint (live classroom polls)
#  Try writing ../Dockerfile yourself first!
# ═══════════════════════════════════════════════════════════════

# Small official Python base image
FROM python:3.12-slim

# Settings you can override with -e at run time
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=1.0.0 \
    DB_PATH=/data/pollpoint.db

WORKDIR /app

# Dependencies first, so code changes reuse this cached layer
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Then the app code (filtered by .dockerignore)
COPY . .

# Run as a normal user and give it the data folder
RUN useradd --create-home appuser \
 && mkdir -p /data \
 && chown appuser:appuser /data
USER appuser

# Votes are stored here, so they survive container restarts
VOLUME /data

EXPOSE 8000

# Docker checks the app is really answering
HEALTHCHECK --interval=30s --timeout=3s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Production server: 2 workers x 4 threads handles a whole classroom voting at once
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "4", "app:app"]
