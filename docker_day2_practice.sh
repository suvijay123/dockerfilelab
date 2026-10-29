#!/bin/bash
# ==============================================================================
#  DOCKER DAY 2 WORKSHOP - GUIDED PRACTICE (Ubuntu / Linux)
#  Companion to: Docker-Workshop-Day2.pptx   (Vijay Inguva)
#
#  One growing story: store -> connect -> expose -> scale -> share -> automate.
#
#   1  Volumes                       deck slides  7-10
#   2  Bind mounts                   deck slides 11-13
#   3  Networking                    deck slides 14-16
#   4  Port mapping                  deck slide  17
#   5  Service discovery             deck slide  18
#   6  Docker Compose                deck slides 19-23
#   7  Multi-container application   deck slides  5, 21, 24-26   (the E-Commerce app)
#   8  Scaling                       deck slide  27
#   9  Docker Swarm basics           deck slides 28-30
#  10  Docker Hub / registries       deck slides 31-34
#  11  Troubleshooting + wrap-up     deck slides 42-51
#
#  (Jenkins CI/CD, webhooks and automated deployment, deck slides 35-41,
#   are covered in the physical lab and are not part of this script.)
#
#  Usage:   ./docker_day2_practice.sh        intro, then a menu to pick a module
#           ./docker_day2_practice.sh 7      jump straight to module 7
#           ./docker_day2_practice.sh -m     open the module menu directly
#           ./docker_day2_practice.sh -l     list modules
#  At any step press [M] to open the menu and switch to another module.
# ==============================================================================

BOLD=$'\e[1m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; CYAN=$'\e[36m'; RED=$'\e[31m'; RESET=$'\e[0m'

ROOT="$HOME/docker-training-day2"
APP="$ROOT/docker-day2-app"          # the E-Commerce app (sections 7, 8, 10)
C1="$ROOT/compose-first"             # first compose file (section 6)
TROUBLE="$ROOT/trouble-compose"      # broken compose project (section 12)
DHUSER="${DHUSER:-}"                 # optional Docker Hub username
SELF="$(readlink -f "$0")"           # absolute path of this script (used to switch modules)
LAST_SECTION=11

# ------------------------------------------------------------------ helpers
pause() { read -n1 -s -r -p "Press any key to continue..."; echo; }

section() {
    clear
    echo "${CYAN}============================================================${RESET}"
    echo "${BOLD}  $1${RESET}"
    echo "${CYAN}============================================================${RESET}"
    echo "  $2"
    echo
    local k
    read -n1 -s -r -p "Press any key to start this module   [M] Menu : " k; echo
    [[ "${k,,}" == "m" ]] && jump_menu
}

note() { echo; echo "  ${YELLOW}[NOTE]${RESET} $1"; }
ask()  { echo; echo "  ${RED}[ASK THE ROOM]${RESET} $1"; }
part() { echo; echo "  ${BOLD}${CYAN}>>> $1${RESET}"; }

# field LABEL TEXT : prints a wrapped, aligned "LABEL : text" block
field() {
    printf '  %s%-9s:%s ' "$BOLD" "$1" "$RESET"
    echo "$2" | fold -s -w 64 | sed '2,$s/^/             /'
}

# practice TITLE COMMAND [WHAT-IT-DOES] [WHAT-TO-LOOK-FOR]
practice() {
    local desc="$1" expected="$2" what="$3" look="$4" usercmd choice
    while true; do
        echo
        echo "------------------------------------------------------------"
        field "STEP" "$desc"
        [ -n "$what" ] && field "WHAT" "$what"
        [ -n "$look" ] && field "LOOK FOR" "$look"
        echo "  ${BOLD}TYPE     :${RESET} ${GREEN}$expected${RESET}"
        echo "------------------------------------------------------------"
        while true; do
            read -r -e -p ">> " usercmd
            if [ -z "$usercmd" ]; then
                usercmd="$expected"
                echo "  [auto-typed] $usercmd"
                break
            elif [ "$usercmd" == "$expected" ]; then
                break
            else
                echo
                echo "  Not an exact match. Try again, or press Enter and I will type it for you."
            fi
        done
        echo
        echo "  [OUTPUT]"
        echo
        eval "$usercmd"
        echo
        read -n1 -s -r -p " [R] Repeat   [N] Next step   [M] Menu (switch module)   [Q] Quit : " choice
        echo
        case "${choice,,}" in
            r) continue ;;
            m) jump_menu ;;
            q) finish ;;
            *) return 0 ;;
        esac
    done
}
p() { practice "$1" "$2" "$3" "$4"; }

# quiet helpers used for safe re-runs
qrm()   { docker rm -f "$@" >/dev/null 2>&1; }
qvol()  { docker volume rm "$@" >/dev/null 2>&1; }
qnet()  { docker network rm "$@" >/dev/null 2>&1; }
# stop a compose project quietly (keeps its volumes)
qdown() { [ -f "$1/compose.yaml" ] && ( cd "$1" && docker compose down --remove-orphans >/dev/null 2>&1 ); return 0; }

finish() {
    echo
    echo "${CYAN}============================================================${RESET}"
    echo "  Practice finished. Your work folder: $ROOT"
    echo "  Re-run any module with:  $SELF <module-number>   (or $SELF -m for the menu)"
    echo "${CYAN}============================================================${RESET}"
    exit 0
}

ask_dockerhub() {
    [ -n "$DHUSER" ] && return
    echo
    echo "  OPTIONAL: pushing to Docker Hub needs a free account (hub.docker.com)."
    read -r -e -p "Enter your Docker Hub username, or press Enter to skip: " DHUSER
}

# If a lab volume name already exists (an earlier run), offer to delete it.
fresh_vol() {
    local v ans
    for v in "$@"; do
        if docker volume inspect "$v" >/dev/null 2>&1; then
            echo
            echo "  ${YELLOW}[HEADS UP]${RESET} A Docker volume named '$v' already exists on this machine."
            read -r -p "  This lab needs a clean one. Delete it now? [y/N] " ans
            if [[ "${ans,,}" == "y" ]]; then
                docker volume rm "$v" >/dev/null 2>&1 || echo "  (could not delete it: a container still uses it)"
            else
                echo "  Keeping it. Your results may differ from the instructions."
            fi
        fi
    done
}

# ---- built-in "wait" steps (typed like commands, they poll until something is ready)
wait_mysql() {      # wait_mysql CONTAINER
    local c="${1:-db}" i=0
    printf "  Waiting for MySQL inside '%s' " "$c"
    until docker exec "$c" mysqladmin ping -h 127.0.0.1 -uroot -pdemo123 --silent >/dev/null 2>&1; do
        i=$((i+1))
        if [ $i -gt 90 ]; then echo; echo "  Not ready after 3 minutes. Look at: docker logs $c"; return 1; fi
        printf "."; sleep 2
    done
    echo; echo "  MySQL is ready."
}

wait_shop() {       # waits until the shop's backend reports the database as ready
    local i=0
    printf "  Waiting for the shop's database "
    until curl -s localhost:8080/api/checkout 2>/dev/null | grep -q ready; do
        i=$((i+1))
        if [ $i -gt 90 ]; then echo; echo "  Not ready after 3 minutes. Look at: docker compose logs database"; return 1; fi
        printf "."; sleep 2
    done
    echo; echo "  The database is accepting connections."
}

ensure_registry() { # starts the local registry (registry:2) on port 5000 if it is not running
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx registry; then
        echo "  The local registry is already running on port 5000."
    else
        docker rm -fv registry >/dev/null 2>&1
        docker run -d --name registry -p 5000:5000 registry:2 >/dev/null && echo "  Local registry started on port 5000."
    fi
}

swarm_state() { docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null; }

# ---- module menu: pick a module by number, from the start or from any step
choose_section() {
    local pick
    while true; do
        echo
        echo "${CYAN}============================================================${RESET}"
        echo "${BOLD}  CHOOSE A MODULE${RESET}"
        echo "${CYAN}============================================================${RESET}"
        list_sections
        echo "   0  Quit"
        echo
        read -r -e -p "  Module number [1-$LAST_SECTION, Enter = 1]: " pick
        pick="${pick:-1}"
        case "${pick,,}" in 0|q) finish ;; esac
        if [[ "$pick" =~ ^([1-9]|1[01])$ ]]; then
            CHOICE="$pick"
            return 0
        fi
        echo "  ${RED}Please enter a number from 1 to $LAST_SECTION.${RESET}"
    done
}

# Restart this script at the chosen module (clean state: no half-finished loops, cd's or variables).
jump_menu() {
    choose_section
    export DHUSER
    DAY2_SKIP_INTRO=1 exec bash "$SELF" "$CHOICE"
}

# ------------------------------------------------------------------ lab files
# ---- the E-Commerce app of slides 5, 25, 26 (frontend, backend, payment, database)
write_app_files() {
    mkdir -p "$APP/frontend" "$APP/backend" "$APP/payment"

    cat > "$APP/compose.yaml" <<'EOF'
services:
  frontend:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./frontend/index.html:/usr/share/nginx/html/index.html:ro
      - ./frontend/default.conf:/etc/nginx/conf.d/default.conf:ro
    networks: [app-net]
    depends_on: [backend]
    restart: unless-stopped

  backend:
    build: ./backend
    environment:
      DB_HOST: database
      DB_PORT: "3306"
      PAYMENT_URL: http://payment:9000
    networks: [app-net]
    depends_on: [database, payment]
    restart: unless-stopped

  payment:
    build: ./payment
    networks: [app-net]
    restart: unless-stopped

  database:
    image: mysql:8.4
    environment:
      MYSQL_ROOT_PASSWORD: demo123
      MYSQL_DATABASE: shop
    volumes:
      - db_data:/var/lib/mysql
    networks: [app-net]
    restart: unless-stopped

networks:
  app-net:

volumes:
  db_data:
EOF

    # nginx: serves the page and forwards /api/ to the backend BY NAME (Docker DNS, re-checked every 5 s)
    cat > "$APP/frontend/default.conf" <<'EOF'
server {
    listen 80;
    server_name _;
    resolver 127.0.0.11 valid=5s;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    location /api/ {
        set $upstream http://backend:8000;
        rewrite ^/api/(.*)$ /$1 break;
        proxy_pass $upstream;
    }
}
EOF

    cat > "$APP/frontend/index.html" <<'EOF'
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Day 2 Shop</title>
<style>
 body{font-family:sans-serif;background:#0b1426;color:#f1f5fb;text-align:center;padding-top:8vh}
 button{font-size:18px;padding:8px 22px;margin:6px;border-radius:8px;border:0;background:#2496ed;color:#fff;cursor:pointer}
 pre{background:#13203a;display:inline-block;text-align:left;padding:16px;border-radius:10px;min-width:420px}
</style></head>
<body>
<h1>Day 2 Shop</h1>
<p>Frontend (nginx) &rarr; Backend API &rarr; Payment + Database. Every box is a container.</p>
<button onclick="call('/api/products')">Load products</button>
<button onclick="call('/api/checkout')">Checkout</button>
<button onclick="call('/api/whoami')">Who served me?</button>
<br><pre id="out">Press a button...</pre>
<script>
function call(path){
  fetch(path).then(function(r){return r.text();})
             .then(function(t){document.getElementById("out").textContent=t;})
             .catch(function(e){document.getElementById("out").textContent="Error: "+e;});
}
</script>
</body></html>
EOF

    echo "v1" > "$APP/backend/VERSION"
    cat > "$APP/backend/Dockerfile" <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY . .
ENV PYTHONUNBUFFERED=1
EXPOSE 8000
CMD ["python", "app.py"]
EOF
    cat > "$APP/backend/app.py" <<'EOF'
import json
import os
import socket
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = socket.gethostname()
BASE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(BASE, "VERSION")) as f:
    VERSION = f.read().strip()

DB_HOST = os.environ.get("DB_HOST", "database")
DB_PORT = int(os.environ.get("DB_PORT", "3306"))
PAYMENT_URL = os.environ.get("PAYMENT_URL", "http://payment:9000")

PRODUCTS = [
    {"id": 1, "name": "Laptop", "price_inr": 55000},
    {"id": 2, "name": "Headphones", "price_inr": 2500},
    {"id": 3, "name": "Backpack", "price_inr": 1800},
]


def database_state():
    # depends_on only controls START ORDER, so we really test the connection
    try:
        socket.create_connection((DB_HOST, DB_PORT), timeout=2).close()
        return "ready"
    except OSError:
        return "waiting"


def call_payment():
    try:
        with urllib.request.urlopen(PAYMENT_URL + "/pay", timeout=2) as r:
            return json.loads(r.read().decode())
    except Exception as exc:
        return {"status": "unreachable", "error": str(exc)}


class Handler(BaseHTTPRequestHandler):
    def reply(self, text, ctype="application/json", code=200):
        data = text.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/whoami":
            self.reply("backend container: " + HOST + "\n", "text/plain")
        elif path == "/health":
            self.reply("OK\n", "text/plain")
        elif path == "/products":
            self.reply(json.dumps({"served_by": HOST, "products": PRODUCTS}) + "\n")
        elif path == "/checkout":
            self.reply(json.dumps({"served_by": HOST,
                                   "database": database_state(),
                                   "payment": call_payment()}) + "\n")
        else:
            self.reply(json.dumps({"service": "backend", "version": VERSION,
                                   "served_by": HOST}) + "\n")

    def log_message(self, fmt, *args):
        print("%s - %s" % (HOST, fmt % args), flush=True)


ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
EOF

    cat > "$APP/payment/Dockerfile" <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY app.py .
ENV PYTHONUNBUFFERED=1
EXPOSE 9000
CMD ["python", "app.py"]
EOF
    cat > "$APP/payment/app.py" <<'EOF'
import json
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = socket.gethostname()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = (json.dumps({"status": "approved", "served_by": HOST}) + "\n").encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print("payment - " + fmt % args, flush=True)


ThreadingHTTPServer(("0.0.0.0", 9000), Handler).serve_forever()
EOF
}

# Writes the project only if it is missing (sections 8 and 10 use it too).
ensure_app() { [ -f "$APP/compose.yaml" ] || write_app_files; }

# Visible, typeable step used in section 7: always rewrites the project so every run starts the same.
get_app_files() {
    write_app_files
    echo "  Project written to: $APP"
}

# ---- section 6: the first compose file of slide 20 (and a broken copy)
write_compose_first() {
    mkdir -p "$C1"
    cat > "$C1/compose.yaml" <<'EOF'
services:

  frontend:
    image: nginx:alpine
    ports:
      - "8080:80"

  backend:
    image: nginx:alpine

  database:
    image: mysql:8.4
    environment:
      MYSQL_ROOT_PASSWORD: demo123
EOF
    echo "  Written: $C1/compose.yaml"
}

write_compose_broken() {
    mkdir -p "$C1"
    cat > "$C1/compose-broken.yaml" <<'EOF'
services:
  frontend:
    image: nginx:alpine
  backend:
      image: nginx:alpine
    ports: ["8081:80"]
EOF
    echo "  Written: $C1/compose-broken.yaml  (it has an indentation mistake on purpose)"
}

# ---- section 12: a compose project that fails (scenario 4, slide 42-43)
write_trouble_compose() {
    mkdir -p "$TROUBLE"
    cat > "$TROUBLE/compose.yaml" <<'EOF'
services:
  web:
    image: nginx:alpine
    ports:
      - "8086:80"
  database:
    image: mysql:8.4
EOF
    echo "  Written: $TROUBLE/compose.yaml  (something is missing on purpose)"
}

fix_trouble_compose() {
    cat > "$TROUBLE/compose.yaml" <<'EOF'
services:
  web:
    image: nginx:alpine
    ports:
      - "8086:80"
  database:
    image: mysql:8.4
    environment:
      MYSQL_ROOT_PASSWORD: demo123
EOF
    echo "  Fixed: MYSQL_ROOT_PASSWORD added to the database service."
}

# ==============================================================================
#  SECTION 1 - VOLUMES  (deck slides 7-10)
# ==============================================================================
sec1() {
    cd "$ROOT" || exit 1
    qrm nodata db db-nopass
    fresh_vol mydata mydata2 dbdata
    section "1. VOLUMES  (deck slides 7-10)" \
            "\"I deleted my database container... and my data.\"  Containers are disposable; data must not be."
    note "Deck slides use 'nginx' and 'mysql'. Here we use nginx:alpine (same server, much smaller) and mysql:8.4 (a pinned version instead of :latest)."
    note "Slide 7: a container's filesystem is a temporary writable layer. When the container is removed, that layer goes with it."

    part "PART A: feel the problem first (no volume)"
    p "Start a container and save 'order data' in its own filesystem" 'docker run -d --name nodata alpine sh -c "echo order-1001 > /orders.txt; sleep 300"' \
      "Starts Alpine in the background. The command inside writes a file called /orders.txt, then sleeps 5 minutes so the container stays alive." \
      "A container ID."
    p "Read the order back" "docker exec nodata cat /orders.txt" \
      "Runs cat inside the running container." \
      "order-1001. The data is there, for now."
    p "Replace the container (like an upgrade would)" "docker rm -f nodata" \
      "Deletes the container. Its writable layer, with our file, is deleted too." \
      "The name 'nodata' is echoed back."
    p "Start a brand-new container and look for the order" "docker run --rm alpine cat /orders.txt" \
      "A fresh container from the same image. It has no memory of the old one." \
      "An error: No such file or directory. The data is lost."
    ask "What happens to your Swiggy orders if the database container is replaced during an upgrade?"

    part "PART B: managing volumes (slide 8)"
    p "Create a named volume" "docker volume create mydata" \
      "A volume is storage created and managed by Docker, outside any single container." \
      "The name is echoed back: mydata"
    p "List volumes" "docker volume ls" \
      "Shows all Docker volumes on this machine." \
      "'mydata' with DRIVER 'local'."
    p "Inspect the volume" "docker volume inspect mydata" \
      "Prints the volume's details as JSON." \
      "'Driver': 'local' and a 'Mountpoint' under Docker's data folder (usually /var/lib/docker/volumes/mydata/_data)."

    part "PART C: prove persistence (slide 10)"
    p "Write a file into the volume from a throw-away container" 'docker run --rm -v mydata:/data alpine sh -c "echo hello > /data/note.txt"' \
      "-v mydata:/data means VOLUME_NAME:PATH_INSIDE_CONTAINER. The container writes note.txt into /data, which is really the volume. --rm deletes the container afterwards." \
      "No output. The container is already gone."
    p "Read the file from a DIFFERENT, brand-new container" "docker run --rm -v mydata:/data alpine cat /data/note.txt" \
      "Another new container mounts the same volume." \
      "hello. Two containers, both deleted, same data. That is the proof."
    note "Common mistake (slide 10): a different volume name in the two commands. Docker silently creates a NEW empty volume. Try it:"
    p "Typo in the volume name" "docker run --rm -v mydata2:/data alpine cat /data/note.txt" \
      "'mydata2' does not exist, so Docker creates it empty and the file is not there." \
      "An error: No such file or directory. Persistence did not fail, we mounted the wrong volume."
    p "Spot the accidental volume" "docker volume ls" \
      "Lists volumes again." \
      "Both 'mydata' and 'mydata2'. Always check names with docker volume ls."
    p "Remove the accidental volume" "docker volume rm mydata2" \
      "Deletes a volume that no container is using." \
      "The name is echoed back."

    part "PART D: a database on a volume (slide 9)"
    note "A MySQL data folder must start EMPTY. 'mydata' already holds note.txt, so the database uses a fresh volume called dbdata."
    p "Start MySQL WITHOUT the password variable" "docker run -d --name db-nopass mysql:8.4" \
      "MySQL refuses to start without MYSQL_ROOT_PASSWORD (or a similar setting). The first run downloads the image, so it can take a few minutes." \
      "A container ID. The container will exit within seconds."
    p "Check its status (wait 5 seconds, press R if it still says Up)" "docker ps -a --filter name=db-nopass" \
      "Shows the container even if it has stopped." \
      "STATUS 'Exited (1)'."
    p "Read the error" "docker logs db-nopass 2>&1 | tail -5" \
      "docker logs prints what the container wrote. 2>&1 merges error output; tail -5 keeps the last 5 lines." \
      "A message saying the database is uninitialized and a password option is not specified."
    p "Remove the failed container" "docker rm -f db-nopass" \
      "Cleans up." \
      "The name is echoed back."
    p "Start MySQL properly, with a password and a volume" "docker run -d --name db -e MYSQL_ROOT_PASSWORD=demo123 -v dbdata:/var/lib/mysql mysql:8.4" \
      "-e sets an environment variable (demo password only, never commit real secrets). -v dbdata:/var/lib/mysql stores MySQL's data folder on the volume." \
      "A container ID. MySQL needs 20-30 seconds to initialise."
    p "Wait until MySQL is ready" "wait_mysql db" \
      "A built-in helper of this script. It asks MySQL 'are you alive?' every 2 seconds until it answers." \
      "Dots, then 'MySQL is ready.'"
    p "Create a database table and save an order" "docker exec db mysql -uroot -pdemo123 -e 'CREATE DATABASE shop; CREATE TABLE shop.orders (id INT PRIMARY KEY, item VARCHAR(40)); INSERT INTO shop.orders VALUES (1001, \"laptop\");' 2>/dev/null" \
      "docker exec runs the mysql client inside the container. The text after -e is the SQL. 2>/dev/null hides MySQL's warning about typing a password on the command line." \
      "No output. The order is saved."
    p "Read the order back" "docker exec db mysql -uroot -pdemo123 -e 'SELECT * FROM shop.orders' 2>/dev/null" \
      "Runs a SELECT inside the database container." \
      "A table with id 1001 and item laptop."
    p "Find 'Mounts' in docker inspect" "docker inspect db --format '{{range .Mounts}}{{.Type}}: {{.Name}} -> {{.Destination}}{{end}}'" \
      "docker inspect shows everything about a container. --format picks out just the mounts." \
      "volume: dbdata -> /var/lib/mysql"
    p "DELETE the database container" "docker rm -f db" \
      "Removes the container completely." \
      "The name 'db' is echoed back."
    p "Is the volume still there?" "docker volume ls" \
      "Volumes survive docker rm. That is the whole point (slide 8: common mistake)." \
      "'dbdata' is still listed."
    p "Start a NEW database container on the SAME volume" "docker run -d --name db -e MYSQL_ROOT_PASSWORD=demo123 -v dbdata:/var/lib/mysql mysql:8.4" \
      "A brand-new container, mounting the old data folder." \
      "A container ID. It starts faster because the data already exists."
    p "Wait until MySQL is ready" "wait_mysql db" \
      "Same helper as before." \
      "'MySQL is ready.'"
    p "Is our order still there?" "docker exec db mysql -uroot -pdemo123 -e 'SELECT * FROM shop.orders' 2>/dev/null" \
      "Reads the table again, in a different container." \
      "id 1001, laptop. The container was replaced; the data survived."
    p "Try to delete the volume while a container uses it" "docker volume rm dbdata" \
      "Docker protects volumes that are in use." \
      "An error: volume is in use. Fix: remove the container using it first (docker ps -a)."
    p "Remove the container, then the volume" "docker rm -f db && docker volume rm dbdata" \
      "Now nothing uses the volume, so it can be deleted, and the data with it." \
      "The names 'db' and 'dbdata' are echoed back."
    p "Remove the practice volume from Part C" "docker volume rm mydata" \
      "Cleans up the last lab volume." \
      "The name is echoed back."
    note "docker volume prune deletes EVERY unused volume on this machine. We do not run it here because it could remove volumes from your other projects. Use it with care."
    ask "Why do we mount /var/lib/mysql specifically?  (It is the folder where MySQL keeps its data files.)"
}

# ==============================================================================
#  SECTION 2 - BIND MOUNTS  (deck slides 11-13)
# ==============================================================================
sec2() {
    cd "$ROOT" || exit 1
    qrm web web-ro
    section "2. BIND MOUNTS  (deck slides 11-13)" \
            "Use YOUR folder inside the container: edit a file on your laptop, see it live"
    note "Volume = Docker owns the location.  Bind mount = YOU own the location. Rule of thumb: data the app owns -> volume; files you edit -> bind mount."
    note "If port 8080 is busy on your machine, use -p 8081:80 and curl localhost:8081 instead."

    p "Create a folder on your machine" "mkdir -p docker-data" \
      "This is the HOST folder that the container will see." \
      "No output."
    p "Create a web page in it" 'echo "Hello from Docker Day 2" > docker-data/index.html' \
      "Writes one line into docker-data/index.html." \
      "No output."
    p "Run nginx with your folder bind-mounted" 'docker run -d --name web -v $(pwd)/docker-data:/usr/share/nginx/html -p 8080:80 nginx:alpine' \
      "-v HOST_PATH:CONTAINER_PATH. \$(pwd) is replaced by your current folder, so the host path is absolute (a bind mount needs an absolute path). nginx serves files from /usr/share/nginx/html, which is now YOUR docker-data folder." \
      "A container ID."
    p "Call the web server" "curl http://localhost:8080" \
      "nginx reads index.html from the bind-mounted folder." \
      "Hello from Docker Day 2"
    p "Now change the file on the HOST" 'echo "Updated! No restart needed." > docker-data/index.html' \
      "We edit the file on your machine. We do NOT touch the container." \
      "No output."
    p "Call the web server again" "curl http://localhost:8080" \
      "Same request, no restart in between." \
      "The new text, immediately. That is why bind mounts are great for development."
    p "Prove the container sees the same file" "docker exec web cat /usr/share/nginx/html/index.html" \
      "Reads the file from INSIDE the container." \
      "The same 'Updated!' text. Host file and container file are one and the same."
    p "Ask Docker what kind of mount this is" "docker inspect web --format '{{range .Mounts}}{{.Type}}: {{.Source}} -> {{.Destination}}{{end}}'" \
      "Shows the mount type and both paths." \
      "bind: /home/.../docker-data -> /usr/share/nginx/html   (Section 1 showed 'volume:')"

    part "Read-only bind mount (slide 26 uses :ro)"
    p "Run a second container with the folder mounted read-only" 'docker run -d --name web-ro -v $(pwd)/docker-data:/usr/share/nginx/html:ro -p 8081:80 nginx:alpine' \
      ":ro at the end makes the mount read-only inside the container. Good for configuration files the container must not change." \
      "A container ID."
    p "Try to write from inside the container" "docker exec web-ro sh -c 'echo hack > /usr/share/nginx/html/x.txt'" \
      "The container tries to create a file in the read-only folder." \
      "An error: Read-only file system."

    part "Common mistake: a bare name is a VOLUME, not a folder (slide 11)"
    p "Use the folder name WITHOUT an absolute path" "docker run --rm -v docker-data:/data alpine ls -la /data" \
      "Without a / or \$(pwd) in front, Docker reads 'docker-data' as the name of a VOLUME and creates a new empty one. Your real folder is NOT used." \
      "An empty listing (just . and ..), not your index.html."
    p "See the accidental volume" "docker volume ls" \
      "Lists volumes." \
      "A volume called 'docker-data' that you never meant to create."
    p "Remove it" "docker volume rm docker-data" \
      "Cleans up." \
      "The name is echoed back."

    p "Clean up the containers" "docker rm -f web web-ro" \
      "Removes both web servers." \
      "Both names are echoed back."
    ask "When would you use a bind mount in production?  (Rarely: config files or host sockets. Databases and app data belong on volumes.)"
}

# ==============================================================================
#  SECTION 3 - NETWORKING  (deck slides 14-16)
# ==============================================================================
sec3() {
    cd "$ROOT" || exit 1
    qrm old-backend backend
    qnet app-network
    section "3. NETWORKING  (deck slides 14-16)" \
            "\"How does the frontend find the backend?\"  Containers are isolated until they share a network"
    note "Slide 14: the default bridge exists out of the box but has NO name-based discovery. A user-defined bridge gives isolation plus DNS by name. Use that."

    p "List the networks Docker created for you" "docker network ls" \
      "Shows the virtual networks on this machine." \
      "Three defaults: bridge, host, none."

    part "PART A: the default bridge cannot resolve names"
    p "Start a backend on the DEFAULT network" "docker run -d --name old-backend nginx:alpine" \
      "No --network option, so it joins the default bridge." \
      "A container ID."
    p "Call it BY NAME from another container" "docker run --rm curlimages/curl http://old-backend" \
      "A small curl container plays the frontend and tries to reach 'old-backend'." \
      "curl: (6) Could not resolve host: old-backend. The default bridge has no DNS for names."
    p "Find its IP address" "docker inspect old-backend --format '{{.NetworkSettings.IPAddress}}'" \
      "Prints the container's IP on the default bridge." \
      "An address like 172.17.0.2"
    p "Call it by IP instead" 'docker run --rm curlimages/curl -s http://$(docker inspect old-backend --format "{{.NetworkSettings.IPAddress}}")' \
      "Works, but it is fragile: IPs change when a container is recreated (slide 18). Never hard-code them." \
      "The nginx welcome page HTML."

    part "PART B: a user-defined network (slides 14-16)"
    p "Create your own network" "docker network create app-network" \
      "Creates a user-defined bridge network called app-network." \
      "A long network ID."
    p "Start the backend on it" "docker run -d --name backend --network app-network nginx:alpine" \
      "--network app-network attaches the container to our network at start." \
      "A container ID. Notice: no -p. The backend publishes nothing to the host."
    p "Inspect the network (slide 15: your #1 troubleshooting command)" "docker network inspect app-network" \
      "Shows the network's configuration as JSON." \
      "Driver, Subnet and a 'Containers' section that lists backend and its IP."
    p "Just the attached containers" "docker network inspect app-network --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}   {{end}}'" \
      "The same command, trimmed to names and IPs with --format." \
      "backend 172.xx.0.2/16"
    p "Frontend calls backend BY NAME" "docker run --rm --network app-network curlimages/curl http://backend" \
      "The curl container joins the same network and uses the container name as the host name." \
      "The nginx welcome page HTML. Docker's DNS turned 'backend' into an IP."
    p "Common mistake: forget --network on the client" "docker run --rm curlimages/curl http://backend" \
      "The client lands on the default bridge, a different network from the backend." \
      "curl: (6) Could not resolve host: backend"
    p "Fix a container that is on the wrong network, while it is running" "docker network connect app-network old-backend" \
      "docker network connect attaches a running container to another network (slide 15: troubleshooting)." \
      "No output."
    p "Now the old container is reachable by name too" "docker run --rm --network app-network curlimages/curl -s http://old-backend" \
      "Same client, same network, different target." \
      "The nginx welcome page HTML."
    p "Check that nothing is published to the host" "docker ps --filter name=backend" \
      "The PORTS column tells what is published to your machine." \
      "'80/tcp' only. No 0.0.0.0:...->80. Containers on a shared network do not need -p to talk to each other."
    note "Other network drivers: host (shares the host's network), none (no network), overlay (multi-host, used by Swarm)."
    p "Clean up" "docker rm -f old-backend backend && docker network rm app-network" \
      "Removes both containers, then the network." \
      "The names are echoed back."
    ask "Why use a user-defined bridge instead of the default bridge?  (Name-based discovery and better isolation.)"
}

# ==============================================================================
#  SECTION 4 - PORT MAPPING  (deck slide 17)
# ==============================================================================
sec4() {
    cd "$ROOT" || exit 1
    qrm web web2 web-bad web-local
    section "4. PORT MAPPING  (deck slide 17)" \
            "Letting the outside world in: two doors. The network door (container to container) and the front door (published ports)"
    note "Container-to-container = Docker network.  External-to-container = published ports.  Syntax: -p HOST_PORT:CONTAINER_PORT"

    p "Publish port 8080 of your machine to port 80 of the container" "docker run -d --name web -p 8080:80 nginx:alpine && docker port web" \
      "-p 8080:80 sends traffic arriving at your machine's port 8080 to port 80 inside the container, where nginx listens. docker port prints the mapping." \
      "80/tcp -> 0.0.0.0:8080   (a second line with [::]:8080 is normal)"
    p "Open the front door" "curl http://localhost:8080" \
      "Your request enters on host port 8080 and Docker forwards it to the container." \
      "The nginx welcome page HTML."
    p "See the mapping in the PORTS column" "docker ps --filter name=web" \
      "docker ps shows published ports in the PORTS column." \
      "0.0.0.0:8080->80/tcp"

    part "Common mistake 1: swapping the numbers"
    p "Map host 8082 to container port 8080 (but nginx listens on 80)" "docker run -d --name web-bad -p 8082:8080 nginx:alpine" \
      "The mapping is valid, but nothing listens on port 8080 inside the container." \
      "A container ID. It looks fine..."
    p "Try to use it" "curl -m 3 http://localhost:8082" \
      "-m 3 gives up after 3 seconds." \
      "An error such as 'Empty reply from server' or 'Connection reset'. The container is running, but the app is not reachable."
    p "Diagnose: what does Docker say the mapping is?" "docker port web-bad" \
      "The first thing to check when 'the container runs but the browser cannot open the app' (slide 42, scenario 1)." \
      "8080/tcp -> 0.0.0.0:8082. The container side is 8080; nginx listens on 80. The numbers are wrong."
    p "Fix: recreate it with the right container port" "docker rm -f web-bad && docker run -d --name web-bad -p 8082:80 nginx:alpine" \
      "Host port 8082 now goes to container port 80." \
      "The name, then a new container ID."
    p "Test again" "curl -s http://localhost:8082 | head -4" \
      "Quiet curl, first 4 lines only." \
      "The nginx welcome page (<!DOCTYPE html> ...)."

    part "Common mistake 2: host port already in use"
    p "Start another container on the SAME host port" "docker run -d --name web2 -p 8080:80 nginx:alpine" \
      "Port 8080 on your machine is already taken by 'web'." \
      "An error: ... port is already allocated (Bind for 0.0.0.0:8080 failed)."
    p "Fix: use another host port" "docker rm -f web2 && docker run -d --name web2 -p 8081:80 nginx:alpine" \
      "Removes the half-created container and starts it on 8081." \
      "The name, then a new container ID."

    part "Publish only what outsiders must reach"
    p "Bind a port to localhost only" "docker run -d --name web-local -p 127.0.0.1:8083:80 nginx:alpine && docker port web-local" \
      "Adding 127.0.0.1 in front makes the port reachable only from this machine, not from other computers on your network." \
      "80/tcp -> 127.0.0.1:8083"
    p "Clean up" "docker rm -f web web2 web-bad web-local" \
      "Removes all four containers." \
      "The names are echoed back."
    ask "Explain -p 8080:80 in one sentence.  (Host port 8080 forwards to container port 80.)"
}

# ==============================================================================
#  SECTION 5 - SERVICE DISCOVERY  (deck slide 18)
# ==============================================================================
sec5() {
    cd "$ROOT" || exit 1
    qrm backend backend-v2
    qnet app-network
    section "5. SERVICE DISCOVERY  (deck slide 18)" \
            "Names, not IP addresses. Docker runs a small DNS server for every user-defined network"
    note "Slide 18 rule: use names, not IPs. It is like phone contacts: you dial 'Mom', not the number. DNS is the contact list."

    p "Create a network" "docker network create app-network" \
      "Our user-defined network again." \
      "A network ID."
    p "Start the backend on it" "docker run -d --name backend --network app-network nginx:alpine" \
      "A container named 'backend' on app-network." \
      "A container ID."
    p "Which DNS server does the container use?" "docker exec -it backend cat /etc/resolv.conf" \
      "resolv.conf lists the DNS servers a machine uses. -it gives us a terminal." \
      "nameserver 127.0.0.11. That is Docker's embedded DNS server for user-defined networks."
    p "Ask that DNS server for 'backend'" "docker run --rm --network app-network alpine nslookup backend" \
      "nslookup asks DNS to translate a name into an IP address." \
      "Server 127.0.0.11, and 'Name: backend' with an address like 172.18.0.2."
    p "Compare with the real IP" "docker network inspect app-network --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}   {{end}}'" \
      "Shows the IP address Docker really gave the container." \
      "The same address that nslookup returned."

    part "IPs change, names keep working (slide 18)"
    p "Recreate the backend (like a redeploy)" "docker rm -f backend && docker run -d --name backend --network app-network nginx:alpine" \
      "A brand-new container with the same name." \
      "The name, then a new container ID."
    p "Look at its IP now" "docker network inspect app-network --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}   {{end}}'" \
      "Same command as before." \
      "The IP is often DIFFERENT from last time. A client that stored the old IP would now be broken."
    p "Call it by NAME again" "docker run --rm --network app-network curlimages/curl -s http://backend" \
      "The client never knew any IP; Docker DNS finds the current one." \
      "The nginx welcome page HTML. It still works."

    part "Extra: a second name for the same container"
    p "Start a container with a network alias" "docker run -d --name backend-v2 --network app-network --network-alias api nginx:alpine" \
      "--network-alias gives the container one more DNS name on this network." \
      "A container ID."
    p "Call it through the alias" "docker run --rm --network app-network curlimages/curl -s http://api" \
      "'api' resolves to backend-v2." \
      "The nginx welcome page HTML."
    note "Docker Compose (next section) does all this for you: every service name becomes a DNS name on the project's network."
    note "Common mistake: testing name resolution on the DEFAULT bridge. It does not work there. Both containers must be on the SAME user-defined network."
    p "Clean up" "docker rm -f backend backend-v2 && docker network rm app-network" \
      "Removes the containers and the network." \
      "The names are echoed back."
    ask "How does Docker DNS work?  (An embedded DNS server at 127.0.0.11 maps container and service names to their current IPs on user-defined networks.)"
}

# ==============================================================================
#  SECTION 6 - DOCKER COMPOSE  (deck slides 19-23)
# ==============================================================================
sec6() {
    cd "$ROOT" || exit 1
    qrm web
    [ -f "$C1/compose.yaml" ] && ( cd "$C1" && docker compose down >/dev/null 2>&1 )
    section "6. DOCKER COMPOSE  (deck slides 19-23)" \
            "Too many commands, too many chances to mistype. Describe the whole app in ONE file, start it with ONE command"
    note "Slide 19: Compose reads a YAML file and creates the networks, volumes and containers it defines, on a SINGLE Docker host. It is not Swarm."
    echo
    echo "  ${BOLD}Without Compose you would type all of this, in the right order:${RESET}"
    echo "     docker network create ...   docker volume create ..."
    echo "     docker run ... db           docker run ... backend       docker run ... frontend"
    echo

    p "Check Compose is installed" "docker compose version" \
      "Prints the Compose version. Note the SPACE: 'docker compose' is the modern plugin. The old 'docker-compose' with a hyphen is the legacy standalone tool." \
      "A line like 'Docker Compose version v2.x.x'."

    part "PART A: your first compose.yaml (slide 20)"
    p "Create the project folder and file" "write_compose_first" \
      "A built-in step of this script. It writes the compose.yaml from slide 20: three services (frontend, backend, database)." \
      "A message saying where the file was written."
    p "Go into the project folder" "cd compose-first" \
      "Compose commands must run in the folder that holds compose.yaml (slide 22: common mistake)." \
      "No output."
    p "Read the file" "cat compose.yaml" \
      "services: is the top-level block. Each entry under it becomes one container. image: says what to run, ports: is the same as -p, environment: sets variables. YAML uses spaces, never tabs." \
      "Three services. There is NO network defined; Compose will create one."
    p "Validate it and print the final configuration" "docker compose config" \
      "Checks the file and prints the fully resolved version." \
      "The YAML, plus a 'name: compose-first' line and a default network. An error message would point at the line with the problem."
    note "Common mistake: tabs or wrong indentation cause a parse error. Let us create one on purpose."
    p "Create a broken copy of the file" "write_compose_broken" \
      "A built-in step that writes compose-broken.yaml with an indentation mistake." \
      "A message saying where the file was written."
    p "Validate the broken file" "docker compose -f compose-broken.yaml config" \
      "-f chooses which file to use instead of compose.yaml." \
      "An error like 'yaml: line 5: did not find expected key'. docker compose config points you at the line."

    part "PART B: start, inspect, stop (slides 22-23)"
    p "Download the images first" "docker compose pull" \
      "Fetches nginx:alpine and mysql:8.4 so the next step is not slowed down by downloads." \
      "Pull progress, then 'Pulled' for each image."
    p "Run in the FOREGROUND for 20 seconds" "timeout -s INT 20 docker compose up" \
      "docker compose up shows the logs of all services in your terminal. Normally you stop it with Ctrl+C. Here 'timeout -s INT 20' sends Ctrl+C for you after 20 seconds, so this script survives." \
      "Colourful log lines prefixed by service name (frontend-1, database-1 ...), then 'Stopping'. up (without -d) is for a quick foreground test."
    p "The containers were stopped, not deleted" "docker compose ps -a" \
      "-a includes stopped containers." \
      "Three containers with STATUS Exited."
    p "Clean up the test run" "docker compose down" \
      "Removes the containers and the network." \
      "'Container ... Removed' and 'Network compose-first_default Removed'."
    p "Start everything in the BACKGROUND (the normal way)" "docker compose up -d" \
      "-d means detached: Compose starts the services and gives your terminal back." \
      "Network created, then three containers 'Started'."
    p "List this project's containers" "docker compose ps" \
      "Shows only the containers of THIS compose project." \
      "frontend, backend and database with their state; frontend shows 0.0.0.0:8080->80/tcp."
    p "Show recent logs of all services" "docker compose logs --tail 3" \
      "docker compose logs prints the services' output. --tail 3 limits it to the last 3 lines per service." \
      "A few lines per service. This is the first command to run when something fails."
    p "Follow the logs live for 6 seconds" "timeout -s INT 6 docker compose logs -f --tail 1" \
      "-f follows new log lines as they appear (normally you stop it with Ctrl+C)." \
      "The last line of each service, then the command ends by itself."
    p "The frontend reaches the backend by SERVICE NAME" "docker compose exec frontend wget -qO- http://backend | head -5" \
      "docker compose exec runs a command inside a service's container. wget -qO- downloads a page quietly to the screen. The name 'backend' is the service name from the YAML." \
      "The first lines of the nginx welcome page. Free bonus (slide 20): Compose created a network and every service name is a DNS name."
    p "See the network Compose created for you" "docker network ls --filter name=compose-first" \
      "Compose names things PROJECT_NAME + _ + something. The project name is the folder name." \
      "compose-first_default"
    p "Open the front door from your machine" "curl -s http://localhost:8080 | head -4" \
      "Only the frontend published a port, so only it is reachable from outside." \
      "The nginx welcome page."

    part "Lifecycle commands (slide 23)"
    p "STOP the services (containers are kept)" "docker compose stop" \
      "Stops the containers but does not delete them." \
      "'Container ... Stopped' for each service."
    p "Check the state" "docker compose ps -a" \
      "Lists all containers of the project." \
      "STATUS 'Exited' for all three."
    p "START them again" "docker compose start" \
      "Starts the stopped containers. Same containers, same data." \
      "'Container ... Started'."
    p "RESTART the services" "docker compose restart" \
      "Stop + start in one step." \
      "'Container ... Restarted'."
    p "DOWN: stop AND remove containers and the network" "docker compose down" \
      "The clean shutdown / reset. Containers and the network are deleted. (Section 7 shows what happens to volumes.)" \
      "'Container ... Removed' and 'Network ... Removed'."
    p "Confirm nothing is left" "docker compose ps -a" \
      "Lists containers of the project." \
      "An empty list."
    p "Go back to the training folder" "cd $ROOT" \
      "Leaves the compose project." \
      "No output."
    ask "What is Docker Compose and what problem does it solve?  (One file describes the whole multi-container app; one command starts it.)"
}

# ==============================================================================
#  SECTION 7 - MULTI-CONTAINER APPLICATIONS  (deck slides 5, 21, 24-26)
# ==============================================================================
sec7() {
    cd "$ROOT" || exit 1
    qrm web backend db
    qdown "$APP"
    section "7. THE E-COMMERCE APP: MANY CONTAINERS, ONE COMMAND  (deck slides 5, 21, 24-26)" \
            "Frontend + Backend API + Payment service + Database, on one network, with a volume for the data"
    note "Slides 5 and 25. Frontend = shop window, backend = shop staff, payment = cash counter, database = ledger. Only the frontend is published to the host."
    echo
    echo "      USER --8080--> [ FRONTEND nginx ] --> [ BACKEND API ] --> [ PAYMENT ]"
    echo "                                                  |"
    echo "                                           [ DATABASE mysql ] --- (volume db_data)"
    echo "                      \\_____________ one Docker network: app-net ____________/"
    echo

    part "PART A: the project (slide 26)"
    p "Write the project files" "get_app_files" \
      "A built-in step. It writes the whole docker-day2-app project: compose.yaml, frontend/, backend/ and payment/. It rewrites everything, so every run starts the same." \
      "A message saying where the project was written."
    p "Go into the project" "cd docker-day2-app" \
      "All compose commands run from this folder." \
      "No output."
    p "Look at the structure" "find . -type f | sort" \
      "Lists every file in the project." \
      "compose.yaml, frontend/default.conf, frontend/index.html, backend/ (Dockerfile, app.py, VERSION) and payment/ (Dockerfile, app.py)."
    p "Read the compose file (slide 21: the keys you use every day)" "cat compose.yaml" \
      "build: builds an image from a Dockerfile. environment: passes variables. volumes: attaches a named volume or bind mount. networks: attaches a service to a network. depends_on: start order. restart: policy after a crash or reboot." \
      "Four services, one network (app-net) and one volume (db_data). Only the frontend has ports:."
    p "Read how the frontend finds the backend" "cat frontend/default.conf" \
      "nginx forwards /api/ to http://backend:8000. It uses the NAME 'backend' and Docker's DNS server (127.0.0.11), and asks again every 5 seconds. Section 8 relies on this." \
      "'resolver 127.0.0.11' and 'http://backend:8000'."
    p "Validate the file" "docker compose config --quiet && echo compose file is valid" \
      "--quiet prints nothing unless there is an error; the echo runs only if validation succeeded." \
      "compose file is valid"
    p "List the services" "docker compose config --services" \
      "Prints the service names defined in the file." \
      "frontend, backend, payment, database (in some order)."

    part "PART B: build and run (slides 22-23, 26)"
    p "Build the images" "docker compose build" \
      "Builds the images of services that have build: (backend and payment). frontend and database use ready-made images." \
      "Build steps for backend and payment, ending with 'Built'."
    p "Start the whole application" "docker compose up -d" \
      "Creates the network and the volume, then starts one container per service. Four containers with one command." \
      "Network, Volume and four Containers 'Started'."
    p "Check the services" "docker compose ps" \
      "Lists the project's containers and their ports." \
      "4 services running. ONLY the frontend shows 0.0.0.0:8080->80/tcp. Backend, payment and database stay private."
    p "Look at the container names" "docker ps --filter name=docker-day2-app --format '{{.Names}}'" \
      "Compose names containers project-service-number." \
      "docker-day2-app-frontend-1, ...-backend-1, ...-payment-1, ...-database-1"
    p "Ask the app to check out RIGHT NOW (probably too early)" "curl -s http://localhost:8080/api/checkout" \
      "The backend calls the payment service and tests the database, both BY NAME. depends_on only controls START ORDER; it does not wait until MySQL is ready (slide 21)." \
      "Usually 'database': 'waiting' while MySQL initialises (about 20-30 s). payment 'approved'. If it already says 'ready', your machine is fast; that is luck, not a guarantee."
    p "Wait until the database really is ready" "wait_shop" \
      "A built-in helper. It repeats the checkout call every 2 seconds until the database answers." \
      "Dots, then 'The database is accepting connections.'"
    p "Check out again" "curl -s http://localhost:8080/api/checkout" \
      "Same request, a bit later." \
      "'database': 'ready' and payment 'approved'. The three services found each other by NAME."
    p "The shop window" "curl -s http://localhost:8080 | head -5" \
      "nginx serves frontend/index.html (bind-mounted read-only from your project folder). Open http://localhost:8080 in a browser and click the buttons." \
      "The start of the HTML page."
    p "The product list, through the proxy" "curl -s http://localhost:8080/api/products" \
      "nginx forwards /api/products to the backend container." \
      "JSON with Laptop, Headphones and Backpack."
    p "What Compose created automatically: network and volume" "docker network ls --filter name=docker-day2-app; docker volume ls --filter name=db_data" \
      "Two commands in one line (the semicolon runs them one after the other)." \
      "A network docker-day2-app_app-net and a volume docker-day2-app_db_data."
    p "Service discovery inside the project" "docker compose exec backend getent hosts database payment" \
      "getent hosts asks the container's DNS for names. We ask from inside the backend." \
      "Two lines: an IP address next to 'database' and one next to 'payment'."
    p "Read the backend's logs" "docker compose logs backend --tail 5" \
      "The backend prints one log line per request it served." \
      "Lines showing GET /checkout, GET /products ... with the container's host name."

    part "PART C: change the code and rebuild (slide 23: up --build)"
    p "Bump the backend's version" "echo v2 > backend/VERSION" \
      "A developer changes the backend. Here we edit the VERSION file that is copied into the image." \
      "No output."
    p "Rebuild and restart only what changed" "docker compose up -d --build" \
      "--build rebuilds images before starting. Compose then recreates ONLY the services whose image or configuration changed." \
      "backend is rebuilt and recreated; frontend, payment and database are left as they are."
    p "Confirm the new version is live" "curl -s http://localhost:8080/api/" \
      "The backend's root page reports its version." \
      "'version': 'v2'."

    part "PART D: stop vs down, and your data (slide 24)"
    p "Save an order in the database" "docker compose exec database mysql -uroot -pdemo123 shop -e 'CREATE TABLE orders (id INT PRIMARY KEY, item VARCHAR(40)); INSERT INTO orders VALUES (1001, \"laptop\");' 2>/dev/null" \
      "docker compose exec runs the mysql client inside the database service. The database 'shop' already exists because of MYSQL_DATABASE in compose.yaml." \
      "No output. The order is stored on the db_data volume."
    p "STOP the application (pause)" "docker compose stop" \
      "Containers stop but stay (as Exited). The network stays too." \
      "'Container ... Stopped' for all four."
    p "Containers and network are still there" "docker compose ps -a; docker network ls --filter name=docker-day2-app" \
      "Two commands. stop keeps everything so you can resume." \
      "STATUS 'Exited' for each service, and the network is still listed."
    p "RESUME with start" "docker compose start" \
      "Starts the same containers again." \
      "'Container ... Started'."
    p "Wait until the database is ready" "wait_shop" \
      "The database needs a few seconds to come back." \
      "'The database is accepting connections.'"
    p "DOWN: demolish the environment" "docker compose down" \
      "Stops AND removes the containers and the network. Named volumes are KEPT by default." \
      "Containers and network 'Removed'. No mention of the volume."
    p "What is left?" "docker network ls --filter name=docker-day2-app; docker volume ls --filter name=db_data" \
      "Checks the network and the volume." \
      "The network is gone. The volume docker-day2-app_db_data is still there."
    p "Start the application again from scratch" "docker compose up -d" \
      "New containers, same volume." \
      "Network and four containers created and started."
    p "Wait until the database is ready" "wait_shop" \
      "Same helper." \
      "'The database is accepting connections.'"
    p "Is the order still there?" "docker compose exec database mysql -uroot -pdemo123 shop -e 'SELECT * FROM orders' 2>/dev/null" \
      "Reads the table in the brand-new database container." \
      "id 1001, laptop. The environment was demolished, the data survived."
    note "DANGER (slide 24): 'docker compose down -v' ALSO deletes the named volumes. On a real database that is data loss. The next step does it on purpose, on this lab only."
    p "down -v: demolish AND delete the data" "docker compose down -v" \
      "-v removes the volumes declared in the file." \
      "'Volume docker-day2-app_db_data Removed'."
    p "Confirm the data is gone" "docker volume ls --filter name=db_data" \
      "Checks for the volume." \
      "An empty list."
    p "Go back to the training folder" "cd $ROOT" \
      "Leaves the project." \
      "No output."
    ask "What does Compose create for you automatically?  (A project network, the declared volumes and one container per service, named project-service-N.)"
    ask "stop vs down in Compose?  (stop keeps containers and network; down removes both; named volumes survive unless you add -v.)"
}

# ==============================================================================
#  SECTION 8 - SCALING  (deck slide 27)
# ==============================================================================
sec8() {
    cd "$ROOT" || exit 1
    ensure_app
    qrm web backend db
    section "8. SCALING  (deck slide 27)" \
            "Traffic grows, one backend is not enough. Run more copies of a service"
    note "Slide 27 (honest note): replicas alone are not production load balancing. Here the name 'backend' resolves to ALL replicas and nginx re-asks Docker DNS every 5 seconds. Real health checks and fair balancing need a proper load balancer or Swarm."

    p "Go into the project" "cd docker-day2-app" \
      "The E-Commerce app from section 7." \
      "No output."
    p "Start the application" "docker compose up -d" \
      "Four containers, one backend." \
      "Everything 'Started' or 'Running'."
    p "Ask 6 times: who served me?" "for i in 1 2 3 4 5 6; do curl -s http://localhost:8080/api/whoami; done" \
      "Each request goes through nginx to the backend, which answers with its own container ID (its host name)." \
      "Six identical lines: there is only one backend."

    part "Scale the backend to 3 copies"
    p "Start 3 backend replicas" "docker compose up -d --scale backend=3" \
      "--scale backend=3 makes Compose run three containers of the backend service. It reuses the existing one and adds two." \
      "Two new containers created, docker-day2-app-backend-2 and -3."
    p "List the containers" "docker compose ps" \
      "Shows all containers of the project." \
      "Three backend containers (backend-1, -2, -3). Why no port conflict? The backend publishes no host port."
    p "Ask again: who served me?  (if you see one name only, wait 5 seconds and press R)" "for i in 1 2 3 4 5 6; do curl -s http://localhost:8080/api/whoami; done" \
      "nginx re-resolves the name 'backend' every 5 seconds and now gets three IP addresses." \
      "Different container IDs across the six lines. The spread is not perfectly even: this is DNS-based, not a real load balancer."
    p "Count the distribution over 12 requests" 'for i in $(seq 1 12); do curl -s http://localhost:8080/api/whoami; done | sort | uniq -c' \
      "sort groups equal lines, uniq -c counts them." \
      "Up to three lines, each with a count. All three replicas received traffic."

    part "Kill a replica: Compose does NOT heal by itself"
    p "Remove one replica by force" "docker rm -f docker-day2-app-backend-2" \
      "Simulates a crash of one copy." \
      "The name is echoed back."
    p "The app keeps working" "for i in 1 2 3 4 5 6; do curl -s -m 5 http://localhost:8080/api/whoami; done" \
      "Requests are served by the remaining replicas. (For up to 5 seconds nginx may still try the dead address, then retries another.)" \
      "Mostly two different container IDs; a rare error line in the first seconds is possible."
    p "How many backends are there now?" "docker compose ps" \
      "Lists the containers." \
      "Only two backends. Nobody replaced the missing one; Compose does not watch for that. Swarm does (next section)."
    p "Restore three replicas by command" "docker compose up -d --scale backend=3" \
      "Compose compares what you ask with what runs and creates the missing container." \
      "One new backend container created."

    part "The limit of scaling: a fixed host port (slide 27: common mistake)"
    p "Try to scale the FRONTEND, which publishes 8080" "docker compose up -d --scale frontend=2" \
      "Two containers cannot both own host port 8080." \
      "An error: ... port is already allocated (Bind for 0.0.0.0:8080 failed). Rule: scale internal services, put a proxy in front."
    p "Go back to one frontend" "docker compose up -d --scale frontend=1 --scale backend=1" \
      "Removes the container that could not start and brings the backend back to one copy." \
      "Extra containers removed; frontend and backend running once."
    p "Check the result" "docker compose ps" \
      "Lists the containers." \
      "One of each service again."
    p "Stop the application (keep the data volume)" "docker compose down" \
      "Frees port 8080 for the next section." \
      "Containers and network removed."
    p "Go back to the training folder" "cd $ROOT" \
      "Leaves the project." \
      "No output."
    ask "How would you scale a Compose service, and what limits does it have?  (--scale N; fixed host ports conflict; no health checks or smart balancing; one host only.)"
}

# ==============================================================================
#  SECTION 9 - DOCKER SWARM BASICS  (deck slides 28-30)
# ==============================================================================
sec9() {
    cd "$ROOT" || exit 1
    qrm web web2
    qdown "$APP"
    section "9. DOCKER SWARM BASICS  (deck slides 28-30)" \
            "One host is not enough: a cluster of Docker hosts that keeps your desired state"
    note "Slide 28: a swarm has Managers (schedule and keep the state) and Workers (run the tasks). A Service is the desired state (image + replicas); a Task is one container of a service. Compose = one host; Swarm = a cluster."
    note "We build a ONE-node swarm on your machine. That is enough to see services, replicas and self-healing. The last step makes your machine leave the swarm again."
    if [ "$(swarm_state)" = "active" ]; then
        note "This machine is ALREADY part of a swarm, so 'docker swarm init' will complain. That is fine; carry on with the next steps."
    fi

    p "Is this machine in a swarm?" "docker info --format '{{.Swarm.LocalNodeState}}'" \
      "Reads just the swarm state from docker info." \
      "'inactive'."
    p "Turn this machine into a swarm manager" "docker swarm init" \
      "Creates a swarm and makes this host its manager. It prints a join token that workers on other machines would use." \
      "'Swarm initialized: current node (...) is now a manager.' If you get 'could not choose an IP address to advertise', run: docker swarm init --advertise-addr 127.0.0.1"
    p "List the nodes" "docker node ls" \
      "Shows the machines in the swarm. Works only on a manager." \
      "One node, STATUS Ready, MANAGER STATUS 'Leader'."

    part "Declare a service: desired state (slide 29)"
    p "Create a service with 3 replicas" "docker service create --name web --publish 8080:80 --replicas 3 nginx:alpine" \
      "You do not run containers; you DECLARE what you want: 3 replicas of nginx, reachable on port 8080. Swarm makes it true." \
      "A progress display that ends with 'Service ... converged'."
    p "List the services" "docker service ls" \
      "Shows each service and how many replicas run." \
      "web with REPLICAS 3/3."
    p "Where are the tasks running?" "docker service ps web" \
      "Lists the tasks (containers) of the service and the node each one runs on." \
      "web.1, web.2, web.3, all Running (all on the same node in a one-node swarm)."
    p "Use it" "curl -s http://localhost:8080 | head -4" \
      "The routing mesh answers on the published port on every node and load-balances across the tasks." \
      "The nginx welcome page."
    p "Scale up to 5 replicas" "docker service scale web=5" \
      "Changes the desired state from 3 to 5. Swarm starts two more tasks." \
      "'web scaled to 5' and 'converged'."
    p "Check" "docker service ls" \
      "Same list as before." \
      "web with REPLICAS 5/5."

    part "Desired state in action (slide 30)"
    note "A container that dies stays dead unless you restart it. A service is different: Swarm keeps working until reality matches what you declared."
    p "Kill one task's container, then look again" 'docker rm -f $(docker ps -q --filter name=web.1) && sleep 5 && docker service ps web' \
      "We delete the container behind task web.1 (like a crash). Swarm notices that only 4 of 5 run and starts a replacement." \
      "web.1 appears twice: the old one as Shutdown/Failed and a new one Running. Replicas are back to 5."
    p "Check the replica count" "docker service ls" \
      "Same list." \
      "web with REPLICAS 5/5 again. Nobody typed a start command."
    p "Read the service definition" "docker service inspect web --pretty" \
      "--pretty prints the service's desired state in a readable form." \
      "Mode Replicated, Replicas 5, the image and the published port 8080."
    p "Read the service logs" "docker service logs web --tail 2" \
      "Collects logs from all tasks of the service." \
      "A couple of nginx log lines, each prefixed with the task name."
    note "Compare with Compose: Compose runs on one host and does not replace a container you removed. Swarm schedules across hosts and heals. The idea of desired state is also the foundation of Kubernetes."

    part "Clean up"
    p "Remove the service" "docker service rm web" \
      "Deletes the service and all its tasks." \
      "The name 'web' is echoed back."
    p "Leave the swarm" "docker swarm leave --force" \
      "--force is needed because this node is the last manager. Your machine goes back to normal Docker mode." \
      "'Node left the swarm.'"
    p "Confirm" "docker info --format '{{.Swarm.LocalNodeState}}'" \
      "Reads the swarm state again." \
      "'inactive'."
    ask "What happens if a container in a service dies?  (Swarm starts a replacement task.)  Manager vs worker?  (Manager schedules and keeps state; worker runs tasks.)"
}

# ==============================================================================
#  SECTION 10 - DOCKER HUB / REGISTRIES  (deck slides 31-34)
# ==============================================================================
sec10() {
    cd "$ROOT" || exit 1
    ensure_app
    qrm from-registry registry
    docker rm -fv registry >/dev/null 2>&1
    section "10. DOCKER HUB AND REGISTRIES  (deck slides 31-34)" \
            "\"Another machine needs my image.\"  Build once, push once, pull anywhere"
    note "Slide 31: Developer -> docker build -> image -> docker tag -> docker push -> REGISTRY -> docker pull -> server -> docker run. Code goes to a Git host; images go to a registry."
    note "To practise WITHOUT an account we run our own private registry (the official 'registry' image) on port 5000. The commands are identical for Docker Hub; only the name prefix differs. Docker Hub comes at the end, optionally."
    note "Slide 32: registry = the library (server), repository = one book title (an image name), tag = the edition (a version label). Image name anatomy:  [registry-host/]user-or-org/repository:tag"

    part "PART A: an image to ship"
    p "Build the shop's backend image" "docker build -t shop-backend:v1 docker-day2-app/backend" \
      "Builds an image from the backend folder of the E-Commerce app and names it shop-backend with tag v1." \
      "'naming to docker.io/library/shop-backend:v1'."
    p "Look at the name parts" "docker images shop-backend" \
      "The REPOSITORY column is the image name, TAG is the version label." \
      "REPOSITORY shop-backend, TAG v1."

    part "PART B: our own registry (slides 31, 33, 34)"
    p "Start a private registry" "docker run -d --name registry -p 5000:5000 registry:2" \
      "The official registry image. It stores images and answers push and pull requests on port 5000." \
      "A container ID."
    p "Ask it what it contains" "curl -s http://localhost:5000/v2/_catalog" \
      "Every registry has an HTTP API. _catalog lists the repositories." \
      "{\"repositories\":[]}  It is empty."
    p "Common mistake: push without a registry or user name in the tag" "docker push shop-backend:v1" \
      "With no registry host in the name, Docker tries Docker Hub's official-images area, where you have no rights." \
      "'denied: requested access to the resource is denied' (or 'push access denied ... authorization failed'). Slide 34: the tag has no namespace."
    p "TAG the image with the registry host" "docker tag shop-backend:v1 localhost:5000/shop-backend:v1" \
      "Adds a second name to the same image. The host prefix localhost:5000 tells Docker WHERE the image belongs. For a private registry the host MUST be part of the name (slide 33)." \
      "No output."
    p "Check the two names" "docker images shop-backend; docker images localhost:5000/shop-backend" \
      "Two commands. Both names point to the same image." \
      "The same IMAGE ID under both names."
    p "PUSH: image -> registry" "docker push localhost:5000/shop-backend:v1" \
      "Uploads the image layers to the registry. localhost:5000 is allowed over plain HTTP; real remote registries use HTTPS and docker login." \
      "Layer lines 'Pushed', then 'v1: digest: sha256:... size: ...'."
    p "The registry now has it" "curl -s http://localhost:5000/v2/_catalog" \
      "Lists the repositories again." \
      "{\"repositories\":[\"shop-backend\"]}"
    p "Add a second, explicit version tag" "docker tag shop-backend:v1 localhost:5000/shop-backend:v2 && docker push localhost:5000/shop-backend:v2" \
      "Pushing a second tag of the same image. Layers that the registry already has are skipped, so this push is fast." \
      "'Layer already exists' lines and 'v2: digest: ...'."
    p "List the tags in the repository" "curl -s http://localhost:5000/v2/shop-backend/tags/list" \
      "Asks the registry for all tags of the repository." \
      "{\"name\":\"shop-backend\",\"tags\":[\"v1\",\"v2\"]}"
    note "Slide 32 (avoid in production): relying on :latest. Use explicit tags such as v1, v2 or a CI build number (the Jenkins physical lab)."

    part "Simulate ANOTHER MACHINE: pull and run"
    p "Delete every local copy of the image" "docker rmi localhost:5000/shop-backend:v1 localhost:5000/shop-backend:v2 shop-backend:v1" \
      "Removes the image from this machine, so the next step must download it, just as a new server would." \
      "'Untagged' and 'Deleted' lines."
    p "PULL: registry -> this machine" "docker pull localhost:5000/shop-backend:v1" \
      "Downloads the image from our registry." \
      "'Pull complete' lines and 'Downloaded newer image'."
    p "RUN: image -> running container" "docker run -d --name from-registry -p 8010:8000 localhost:5000/shop-backend:v1" \
      "Starts a container from the pulled image. Nobody rebuilt anything." \
      "A container ID."
    p "Use it" "curl -s http://localhost:8010/whoami" \
      "Calls the backend's /whoami page." \
      "'backend container: <id>'. Built once, runs anywhere."
    p "Clean up the container" "docker rm -f from-registry" \
      "Removes the test container. The registry keeps running for the next section." \
      "The name is echoed back."

    ask_dockerhub
    if [ -n "$DHUSER" ]; then
        part "PART C: the same flow with Docker Hub"
        note "The tag MUST contain your Docker Hub username, otherwise the push is denied. Use an access token instead of your password if you have one."
        p "Pull the image back from our registry for re-tagging" "docker pull localhost:5000/shop-backend:v1" \
          "Makes sure the image is on this machine." \
          "'Image is up to date' or a download."
        p "TAG with your Docker Hub name" "docker tag localhost:5000/shop-backend:v1 $DHUSER/shop-backend:v1" \
          "Adds the label <your-username>/shop-backend:v1." \
          "No output."
        p "Log in to Docker Hub" "docker login" \
          "Asks for your username and password (or access token). Needed once." \
          "'Login Succeeded'."
        p "PUSH to Docker Hub" "docker push $DHUSER/shop-backend:v1" \
          "Uploads the image to hub.docker.com." \
          "Layer upload lines ending with a digest. Check hub.docker.com to see your repository."
        p "Delete the local copy, then pull it back from Docker Hub" "docker rmi $DHUSER/shop-backend:v1 && docker pull $DHUSER/shop-backend:v1" \
          "Proves the image now lives on the registry." \
          "'Untagged' lines, then 'Pull complete' and 'Downloaded newer image'."
    fi

    part "Different registries, same idea (slide 33)"
    echo "  Docker Hub (public default)      Amazon ECR        Azure Container Registry"
    echo "  Google Artifact Registry         GitLab Registry   Harbor (self-hosted, open source)"
    echo "  The login URL and the naming differ per vendor. The push/pull workflow is identical:"
    echo "      docker login <registry-host>  ->  docker tag ...  ->  docker push ...  ->  docker pull ..."
    echo "  Private registry names always start with the host, e.g. registry.example.com/team/app:v1"
    ask "Registry vs repository?  (A registry is the server; a repository is one image name inside it, holding many tags.)"
    ask "How would you troubleshoot a failed docker push?  (Logged in? Tag has the namespace/host? Registry reachable? Credentials valid?)"
    p "Go back to the training folder" "cd $ROOT" \
      "Nothing to do here." \
      "No output."
}

# ==============================================================================
#  SECTION 11 - TROUBLESHOOTING AND WRAP-UP  (deck slides 42-51)
# ==============================================================================
sec11() {
    cd "$ROOT" || exit 1
    qrm t1 t2-backend
    qnet shop-net
    fresh_vol shop-data shop_data
    section "11. TROUBLESHOOTING AND WRAP-UP  (deck slides 42-51)" \
            "5 scenarios: diagnose before you peek. Then the knowledge check and the clean-up"
    note "Slide 42: troubleshooting is a method. Observe, hypothesise, verify. For each scenario we break something on purpose; say your guess out loud BEFORE you press Enter."

    part "SCENARIO 1: the container is running, but the browser cannot open the app"
    p "Start the broken app" "docker run -d --name t1 -p 8085:8080 nginx:alpine" \
      "Looks innocent." \
      "A container ID."
    ask "The container is Up. Why can't we open it?  Think: ports, logs, what the app listens on."
    p "Try the app" "curl -m 3 http://localhost:8085" \
      "-m 3 gives up after 3 seconds." \
      "An error: Empty reply from server / Connection reset."
    p "Check the real mapping" "docker port t1" \
      "Slide 42 toolbox: docker ps, docker port, docker logs, docker inspect." \
      "8080/tcp -> 0.0.0.0:8085. The container side says 8080."
    p "Check what the app listens on" "docker exec t1 grep listen /etc/nginx/conf.d/default.conf" \
      "Reads nginx's own configuration inside the container." \
      "'listen 80;'. nginx listens on port 80, not 8080."
    p "Fix it" "docker rm -f t1 && docker run -d --name t1 -p 8085:80 nginx:alpine && sleep 1 && curl -s http://localhost:8085 | head -4" \
      "Recreate with the right container port, wait a second, test." \
      "The nginx welcome page. Cause (slide 43): port mapping wrong, -p 80:8080 vs 8080:80."

    part "SCENARIO 2: the frontend cannot reach the backend"
    p "Set up: a backend on a network, a client NOT on it" "docker network create shop-net && docker run -d --name t2-backend --network shop-net nginx:alpine" \
      "The backend lives on shop-net." \
      "A network ID and a container ID."
    p "The frontend calls the backend" "docker run --rm curlimages/curl -s -m 5 http://t2-backend" \
      "A client container without any --network option." \
      "curl: (6) Could not resolve host: t2-backend"
    ask "Which command shows who is on the network?  (docker network ls, docker network inspect)"
    p "Diagnose: who is on shop-net?" "docker network inspect shop-net --format '{{range .Containers}}{{.Name}} {{end}}'" \
      "Lists the containers attached to the network." \
      "Only t2-backend. The client was never attached."
    p "Fix: put the client on the same network" "docker run --rm --network shop-net curlimages/curl -s http://t2-backend | head -4" \
      "Same client, now on shop-net." \
      "The nginx welcome page. Cause (slide 43): not on the same network, wrong name or wrong port."

    part "SCENARIO 3: the database data disappeared"
    p "Yesterday: the app saved data on a volume" 'docker run --rm -v shop-data:/data alpine sh -c "echo order-1 > /data/orders.txt"' \
      "Writes an order into the volume shop-data." \
      "No output."
    p "Today: the app reads... and finds nothing" "docker run --rm -v shop_data:/data alpine cat /data/orders.txt" \
      "Someone typed shop_data (underscore) instead of shop-data (hyphen)." \
      "An error: No such file or directory."
    ask "Where is the data?  Which commands help?  (docker volume ls, docker volume inspect, docker inspect <container> and its Mounts)"
    p "Diagnose" "docker volume ls --filter name=shop" \
      "Lists volumes whose name contains 'shop'." \
      "TWO volumes: shop-data and shop_data. The second one is the accidental empty copy."
    p "Fix: use the right volume name" "docker run --rm -v shop-data:/data alpine cat /data/orders.txt" \
      "Reads from the volume that holds the data." \
      "order-1. Cause (slide 43): a different or anonymous volume was created (a typo in the name)."
    p "Clean up the two volumes" "docker volume rm shop-data shop_data" \
      "Deletes both practice volumes." \
      "Both names are echoed back."

    part "SCENARIO 4: the Compose application fails"
    p "Write a compose project with a hidden mistake" "write_trouble_compose" \
      "A built-in step. It writes a web service and a database service." \
      "A message saying where the file was written."
    p "Go into it" "cd trouble-compose" \
      "Compose commands run from the folder with the file." \
      "No output."
    p "Start it" "docker compose up -d" \
      "Looks like it works..." \
      "Containers created and started."
    p "Check the state (wait 5 seconds, press R if the database still says Up)" "docker compose ps -a" \
      "-a shows containers that have stopped." \
      "web is running, but the database is Exited (1)."
    ask "Which command tells you why?  (docker compose logs <service>)"
    p "Read the failing service's logs" "docker compose logs database 2>&1 | tail -6" \
      "Slide 43: read the logs of the failing service." \
      "A message saying the password option is not specified (MYSQL_ROOT_PASSWORD)."
    p "Fix the file" "fix_trouble_compose" \
      "A built-in step. It adds the missing environment variable." \
      "A message saying what was fixed."
    p "Validate and restart" "docker compose config --quiet && docker compose up -d" \
      "Checks the file, then recreates what changed." \
      "The database container is recreated and stays Up. Cause (slide 43): YAML indentation, a missing env var, or a port conflict."
    p "Clean up" "docker compose down -v && cd $ROOT" \
      "Removes the containers and volumes of this practice project, then leaves the folder." \
      "Containers, network and volume removed."

    part "SCENARIO 5: docker push fails (the same error a CI pipeline hits)"
    p "Get a tiny image to practise with" "docker pull alpine" \
      "Makes sure we have an image to tag." \
      "'Image is up to date' or a short download."
    p "Tag it for a registry host that does not exist" "docker tag alpine localhost:5001/team/app:v1" \
      "Pretend the pipeline has the wrong registry URL (nothing listens on port 5001)." \
      "No output."
    p "Push" "docker push localhost:5001/team/app:v1" \
      "The same command a CI pipeline would run." \
      "An error such as 'connection refused'. The name was fine; the registry host was wrong."
    ask "Your checklist for a failed push?  (Logged in or expired credentialsId? Tag has the right namespace? Registry URL right? Network access? Docker permission for the Jenkins user?)"
    p "Make sure the real local registry is running" "ensure_registry" \
      "A built-in step." \
      "'Local registry started' or 'already running'."
    p "Fix: the right host and port" "docker tag alpine localhost:5000/team/app:v1 && docker push localhost:5000/team/app:v1" \
      "Same image, correct registry." \
      "'Pushed' lines and a digest."

    part "Cheat sheet: which Docker tool do I use?  (slide 47)"
    echo "   Need persistent data?            -> VOLUME / BIND MOUNT"
    echo "   Containers must communicate?     -> DOCKER NETWORK"
    echo "   External access?                 -> PORT MAPPING (-p)"
    echo "   Find services by name?           -> DOCKER DNS / SERVICE NAME"
    echo "   Multiple containers?             -> DOCKER COMPOSE"
    echo "   Need replicas?                   -> SCALING (--scale)"
    echo "   Cluster orchestration?           -> DOCKER SWARM"
    echo "   Share images?                    -> REGISTRY (Docker Hub, ECR, ACR, Harbor ...)"
    echo "   Need automation?                 -> JENKINS + WEBHOOK + CI/CD  (physical lab)"
    echo
    pause

    echo "${BOLD}  YOUR TURN: 10 QUESTIONS${RESET}  (think first, then press a key to see the answer)"
    local -a Q A
    Q[1]="Q1.  docker run -d -p 8080:80 nginx : what does 8080:80 mean?"
    A[1]="     Host port 8080 forwards to container port 80."
    Q[2]="Q2.  Two containers share a user-defined network. Must the backend publish its port to the host?"
    A[2]="     No. Publishing is only for access from outside Docker."
    Q[3]="Q3.  A database container is deleted. How do we keep its data?"
    A[3]="     Store it on a named volume (or a bind mount)."
    Q[4]="Q4.  A container keeps restarting. Which commands do you use?"
    A[4]="     docker ps -a, docker logs, docker inspect."
    Q[5]="Q5.  Registry vs repository?"
    A[5]="     A registry is the server; a repository is one image name inside it, holding many tags."
    Q[6]="Q6.  Which command sends an image to Docker Hub?"
    A[6]="     docker push username/name:tag (after docker login)."
    Q[7]="Q7.  You need three backend replicas. Which mechanism?"
    A[7]="     docker compose up -d --scale backend=3 (or Swarm --replicas 3)."
    Q[8]="Q8.  What replaces hard-coded container IPs?"
    A[8]="     Service / container names, resolved by Docker DNS."
    Q[9]="Q9.  stop vs down in Compose?"
    A[9]="     stop keeps the containers; down removes the containers and the network (volumes stay unless -v)."
    Q[10]="Q10. Why use explicit image tags (v1, v2, build numbers) instead of :latest?"
    A[10]="     Traceability and safe rollbacks; :latest is ambiguous."
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        echo; echo "  ${YELLOW}${Q[$i]}${RESET}"
        read -n1 -s -r -p "  [press a key for the answer] "; echo
        echo "  ${GREEN}${A[$i]}${RESET}"
    done

    echo
    echo "  ${BOLD}If you remember only this:${RESET}"
    echo "   CODE -> GIT -> WEBHOOK -> JENKINS -> BUILD + TEST -> DOCKER BUILD -> IMAGE -> REGISTRY -> DEPLOY"
    echo "   Store data. Connect services. Expose applications. Scale workloads. Share images. Automate deployment."
    echo "   Every feature exists because of a problem. If you remember the problems, you will remember the tools."
    echo

    p "What is still running?" "docker ps -a" \
      "Lists all containers, including stopped ones." \
      "Possibly the registry and leftovers of the labs."
    p "Disk used by Docker" "docker system df" \
      "Summarizes disk used by images, containers, volumes and build cache." \
      "A table with TOTAL, ACTIVE, SIZE and RECLAIMABLE."

    echo
    local ans
    read -r -p "  Clean up EVERYTHING created today (containers, volumes, networks, images, registry)? [y/N] " ans
    if [[ "${ans,,}" == "y" ]]; then
        cleanup_day2
        echo "  Cleaned up. Your lab files stay in $ROOT"
    fi
    echo
    echo "  ${CYAN}\"Each tool exists because of a problem.\"${RESET}  Day 2 complete. Any questions?"
}

# Removes only the things THIS practice creates.
cleanup_day2() {
    qrm web web2 web-ro web-bad web-local old-backend backend backend-v2 db db-nopass nodata \
        t1 t2-backend from-registry
    docker rm -fv registry >/dev/null 2>&1
    [ -f "$APP/compose.yaml" ]     && ( cd "$APP" && docker compose down -v --rmi local --remove-orphans >/dev/null 2>&1 )
    [ -f "$C1/compose.yaml" ]      && ( cd "$C1" && docker compose down -v >/dev/null 2>&1 )
    [ -f "$TROUBLE/compose.yaml" ] && ( cd "$TROUBLE" && docker compose down -v >/dev/null 2>&1 )
    if [ "$(swarm_state)" = "active" ]; then
        local a
        read -r -p "  This machine is in a swarm. Remove the 'web' service and leave the swarm? [y/N] " a
        if [[ "${a,,}" == "y" ]]; then
            docker service rm web >/dev/null 2>&1
            docker swarm leave --force >/dev/null 2>&1
        fi
    fi
    qvol mydata mydata2 dbdata docker-data shop-data shop_data
    qnet app-network shop-net
    # images built or tagged today
    docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
        | grep -E '^(shop-backend:|localhost:5000/|localhost:5001/)' \
        | xargs -r docker rmi >/dev/null 2>&1
    [ -n "$DHUSER" ] && docker rmi "$DHUSER/shop-backend:v1" >/dev/null 2>&1
    docker container prune -f >/dev/null 2>&1
    docker image prune -f >/dev/null 2>&1
}

# ==============================================================================
#  MAIN
# ==============================================================================
list_sections() {
    cat <<'EOF'
   1  Volumes                    (lost data, named volumes, MySQL on a volume, persistence proof)
   2  Bind mounts                (edit on the host, see it live; read-only; volume vs bind mount)
   3  Networking                 (default bridge vs user-defined network, inspect, connect)
   4  Port mapping               (-p HOST:CONTAINER, swapped numbers, port already in use)
   5  Service discovery          (Docker DNS, names not IPs, aliases)
   6  Docker Compose             (first compose.yaml, up/down/stop/start/logs)
   7  Multi-container app        (E-Commerce: frontend, backend, payment, database, volume)
   8  Scaling                    (--scale, spreading requests, limits of Compose scaling)
   9  Docker Swarm basics        (init, services, replicas, self-healing)
  10  Docker Hub / registries    (tag, push, pull with your own registry; optional Docker Hub)
  11  Troubleshooting + wrap-up  (5 scenarios, knowledge check, clean-up)
EOF
}

show_intro() {
    clear
    echo "${CYAN}============================================================${RESET}"
    echo "${BOLD}  DOCKER DAY 2 WORKSHOP - GUIDED PRACTICE (Ubuntu)${RESET}"
    echo "  Follows: Docker-Workshop-Day2.pptx"
    echo "${CYAN}============================================================${RESET}"
    cat <<'EOF'

  How this works:
   1. Pick a module from the menu (or press Enter to start at module 1).
   2. The script shows a STEP, what the command DOES, what to LOOK FOR,
      and the command to TYPE.
   3. Type the command exactly and press Enter.
      If you only press Enter, the script types it for you.
   4. After the output you can choose:
        R = Repeat the same command for practice
        N = Go to the Next step
        M = Menu: switch directly to any other module
        Q = Quit
   Modules run in order; after one ends the next one starts.

  One story all day: the E-Commerce app grows from a sketch into a
  shareable system. Each module solves the problem the previous one left.
  (Jenkins CI/CD and webhooks: covered in the physical lab.)

  Requirements: Docker Engine with the Compose plugin, Git, curl, internet,
  about 2 GB of free RAM (MySQL is hungry).
  Ports used: 5000, 5001 (on purpose, nothing listens), 8010, 8080-8083, 8085, 8086.
  Work folder: ~/docker-training-day2
  The script removes containers and volumes that carry the lab's own names
  (web, db, backend, mydata, dbdata ...). Do not use those names for real work.
EOF
    echo
    pause
}

check_prereqs() {
    local tool
    for tool in docker git curl timeout stat readlink; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "'$tool' is not installed. Install it first, for example: sudo apt install $tool"
            exit 1
        fi
    done
    if ! docker info >/dev/null 2>&1; then
        echo "Cannot talk to Docker. Possible fixes:"
        echo "  Start the engine : sudo systemctl start docker"
        echo "  Permission denied: sudo usermod -aG docker \$USER   then log out and log in again"
        exit 1
    fi
    if ! docker compose version >/dev/null 2>&1; then
        echo "The Docker Compose plugin is missing. Install it, for example: sudo apt install docker-compose-plugin"
        exit 1
    fi
}

START=""
case "${1:-}" in
    -l|--list) list_sections; exit 0 ;;
    -h|--help) sed -n '2,/^# =====/p' "$SELF" | sed '$d'; exit 0 ;;
    -m|--menu) ;;                                   # menu, no intro
    "")        [ -z "${DAY2_SKIP_INTRO:-}" ] && show_intro ;;
    *)
        if [[ "$1" =~ ^([1-9]|1[01])$ ]]; then
            START="$1"
        else
            echo "Module must be a number from 1 to $LAST_SECTION. Use -l to list modules, -m for the menu."
            exit 1
        fi ;;
esac

check_prereqs
mkdir -p "$ROOT"
cd "$ROOT" || exit 1

if [ -z "$START" ]; then
    choose_section
    START="$CHOICE"
fi

for n in $(seq "$START" "$LAST_SECTION"); do
    "sec$n"
done

finish
