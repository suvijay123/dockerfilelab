# ═══════════════════════════════════════════════════════════════
#  CAPSTONE SOLUTION · Campus Feedback Board
#  Copy this to ../Dockerfile ONLY after trying it yourself!
# ═══════════════════════════════════════════════════════════════

# 1. Small, official base image
FROM python:3.12-slim

# 2. App settings (override at run time with -e)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=1.0.0 \
    DB_PATH=/data/feedback.db

WORKDIR /app

# 3. Dependencies first, so this layer is cached
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Then the source code
COPY . .

# 5. Run as a normal user, not root; give it the data folder
RUN useradd --create-home appuser \
 && mkdir -p /data \
 && chown appuser:appuser /data
USER appuser

# 6. The database lives here, so it can survive container restarts
VOLUME /data

EXPOSE 5000

# 7. Docker checks the app is really alive, not just "running"
HEALTHCHECK --interval=30s --timeout=3s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# 8. Production web server (not Flask's debug server)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
