# ═══════════════════════════════════════════════════════════════
#  DEMO 2 · "WHACK-A-BUG" (a browser game)
#  Why industry uses Docker:  SHIP ANY APP WITH ONE COMMAND.
#
#  A whole web server + game, packaged in 3 lines.
#  Anyone in the world can run it with `docker run` — no web
#  server setup, no config, no "which version do I install?".
# ═══════════════════════════════════════════════════════════════

# A production-grade web server, ready-made
FROM nginx:alpine

# Drop our game into the folder nginx serves
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

# ── Try it ─────────────────────────────────────────────────────
#  docker build -t whack-a-bug .
#  docker run -d -p 8080:80 --name game whack-a-bug
#  Open http://localhost:8080 and squash some bugs!
#
#  Stop it:   docker rm -f game
