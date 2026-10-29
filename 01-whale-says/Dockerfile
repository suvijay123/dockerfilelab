# ═══════════════════════════════════════════════════════════════
#  DEMO 1 · "THE WHALE SAYS"
#  Why industry uses Docker:  NO SETUP. ZERO INSTALLS.
#
#  Your laptop does not have cowsay, figlet, fortune or lolcat.
#  This container does. Run it, enjoy the rainbow, delete it,
#  and your laptop is exactly as clean as before.
# ═══════════════════════════════════════════════════════════════

# Start from a tiny Linux (works the same on Windows, Mac and Linux)
FROM debian:bookworm-slim

# Install the fun tools INSIDE the image (not on your laptop!)
RUN apt-get update \
 && apt-get install -y --no-install-recommends cowsay figlet fortune-mod fortunes-min lolcat \
 && rm -rf /var/lib/apt/lists/*

# Debian puts these "games" in /usr/games, so add it to the PATH
ENV PATH="/usr/games:${PATH}"

WORKDIR /app
COPY whale.cow say.sh ./
RUN chmod +x say.sh

# Run our script every time the container starts
ENTRYPOINT ["/app/say.sh"]

# ── Try it ─────────────────────────────────────────────────────
#  docker build -t whale-says .
#  docker run --rm -t whale-says                      (random quote)
#  docker run --rm -t whale-says "Docker is awesome"  (your message)
#
#  Then check:  cowsay   (on your laptop → "command not found"!)
