# ═══════════════════════════════════════════════════════════════
#  DEMO 4 · "PYTHON TIME MACHINE"
#  Why industry uses Docker:  "IT WORKS ON MY MACHINE" — SOLVED.
#
#  The SAME code behaves differently on different Python versions.
#  Docker pins the exact version, so everyone (you, your team,
#  the server) gets identical results. And you can run several
#  versions side by side without them fighting each other.
# ═══════════════════════════════════════════════════════════════

# Pick the Python version at build time (default: 3.13)
ARG PY_VERSION=3.13
FROM python:${PY_VERSION}-slim

WORKDIR /app
COPY check.py .

CMD ["python", "check.py"]

# ── Try it ─────────────────────────────────────────────────────
#  Build an OLD and a NEW version from the same Dockerfile:
#  docker build --build-arg PY_VERSION=3.8  -t pytime:old .
#  docker build --build-arg PY_VERSION=3.13 -t pytime:new .
#
#  Run both, one after the other:
#  docker run --rm -t pytime:old
#  docker run --rm -t pytime:new
#
#  Same code. Different results. Now imagine that bug in production.
