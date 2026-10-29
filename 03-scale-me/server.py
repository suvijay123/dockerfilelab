"""A tiny web server (Python standard library only, no installs).

Every container picks a color from its own unique ID, so when you run
several copies side by side, each one looks different.
"""
import hashlib
import socket
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

# ┌─────────────────────────────────────────────────────────────┐
# │  CHANGE THE COLOR HERE                                      │
# │  Use any CSS color: "crimson", "teal", "#ff5fa2", "gold"... │
# │  Leave it empty ("") for an automatic color per container.  │
# └─────────────────────────────────────────────────────────────┘
COLOR = ""

CONTAINER_ID = socket.gethostname()
STARTED = time.time()
HUE = int(hashlib.md5(CONTAINER_ID.encode()).hexdigest(), 16) % 360

if COLOR:
    BG = COLOR
    CARD = f"color-mix(in srgb, {COLOR} 65%, black)"
else:
    BG = f"hsl({HUE} 70% 45%)"
    CARD = f"hsl({HUE} 70% 30%)"

visits = 0

PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Container {cid}</title>
<style>
 body {{ margin:0; min-height:100vh; display:grid; place-items:center;
        background:{bg}; color:#fff; font-family:system-ui,sans-serif; }}
 .card {{ text-align:center; padding:48px 40px; border:4px solid #fff; border-radius:24px;
         background:{card}; box-shadow:12px 12px 0 #0b0f1a; }}
 h1 {{ margin:0 0 8px; font-size:clamp(2rem,6vw,3.5rem); }}
 code {{ font-size:clamp(1.4rem,4vw,2.2rem); background:#0b0f1a; padding:6px 16px; border-radius:10px; }}
 p {{ font-size:1.2rem; opacity:.9; }}
</style></head>
<body><div class="card">
 <h1>Hi! I'm a container</h1>
 <p>My ID</p>
 <code>{cid}</code>
 <p>I've served <b>{visits}</b> visits &middot; alive for <b>{uptime}s</b></p>
 <p>Refresh me &middot; then open another port</p>
</div></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        global visits
        if self.path != "/":
            self.send_response(404)
            self.end_headers()
            return
        visits += 1
        body = PAGE.format(
            cid=CONTAINER_ID, bg=BG, card=CARD, visits=visits, uptime=int(time.time() - STARTED)
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"[{CONTAINER_ID}] visit #{visits} from {self.client_address[0]}")


if __name__ == "__main__":
    print(f"Container {CONTAINER_ID} ready on port 8000")
    HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
