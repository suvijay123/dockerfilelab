# ═══════════════════════════════════════════════════════════════
#  DEMO 3 · "SCALE ME"
#  Why industry uses Docker:  SCALE IN SECONDS.
#
#  Build ONE image, start as many copies as you want.
#  Each copy gets its own ID and its own color, so you can SEE
#  them. This is how Netflix, Swiggy & co. handle traffic spikes.
# ═══════════════════════════════════════════════════════════════

FROM python:3.12-slim

WORKDIR /app
COPY server.py .

# Show Python output in `docker logs` immediately
ENV PYTHONUNBUFFERED=1

EXPOSE 8000
CMD ["python", "server.py"]

# ── Try it ─────────────────────────────────────────────────────
#  docker build -t scale-me .
#
#  Start 3 copies of the SAME app (takes ~1 second):
#  docker run -d -p 8001:8000 --name app1 scale-me
#  docker run -d -p 8002:8000 --name app2 scale-me
#  docker run -d -p 8003:8000 --name app3 scale-me
#
#  Open localhost:8001, :8002, :8003 → three different colors!
#
#  Crash one on purpose:  docker rm -f app2
#  The other two keep serving users. That's resilience.
#
# ── Change the code, ship a new version ────────────────────────
#  1. Open server.py and change:   COLOR = ""
#     to any color you like, e.g.  COLOR = "crimson"
#  2. Rebuild the image as version 2:
#     docker build -t scale-me:v2 .
#  3. Run it on port 8004, next to the old ones:
#     docker run -d -p 8004:8000 --name app4 scale-me:v2
#  4. Open http://localhost:8004 → your new color!
#     (8001 and 8003 still show the old version — that's how
#      companies roll out updates without downtime.)
#
#  Clean up:  docker rm -f app1 app3 app4
