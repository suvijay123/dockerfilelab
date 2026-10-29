#!/bin/bash
# ==============================================================================
#  DOCKER DAY 1 WORKSHOP - GUIDED PRACTICE (Ubuntu / Linux)
#  Companion to: Docker_Day1_Final.pptx   (Vijay Inguva)
#
#  Order of this practice (Git comes BEFORE Dockerfiles, so learners know how
#  Dockerfiles and project files get onto their machine):
#     1  Containers vs VMs      (quick proof)                  deck slides 11-16
#     2  Docker fundamentals                                   deck slides 17-25
#     3  Container lifecycle + nginx lab                       deck slides 26-29
#     4  Git and GitHub         (get + version the lab files)  deck slides 38-43
#     5  Docker images          (Dockerfile, commit, labs)     deck slides 30-37
#     6  Image optimization + multi-stage                      deck slides 44-48
#     7  Wrap-up                                               deck slides 49-51
#
#  Usage:   ./docker_day1_practice.sh        start from the beginning
#           ./docker_day1_practice.sh 5      jump straight to section 5
#           ./docker_day1_practice.sh -l     list sections
# ==============================================================================

BOLD=$'\e[1m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; CYAN=$'\e[36m'; RED=$'\e[31m'; RESET=$'\e[0m'

ROOT="$HOME/docker-training"
LAB="$ROOT/docker-fun-lab"
GHURL=""
DHUSER=""

# ------------------------------------------------------------------ helpers
pause() { read -n1 -s -r -p "Press any key to continue..."; echo; }

section() {
    clear
    echo "${CYAN}============================================================${RESET}"
    echo "${BOLD}  $1${RESET}"
    echo "${CYAN}============================================================${RESET}"
    echo "  $2"
    echo
    pause
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
        read -n1 -s -r -p " [R] Repeat for practice   [N] Next step   [Q] Quit : " choice
        echo
        case "${choice,,}" in
            r) continue ;;
            q) finish ;;
            *) return 0 ;;
        esac
    done
}
p() { practice "$1" "$2" "$3" "$4"; }

# quietly remove containers (used for safe re-runs)
qrm() { docker rm -f "$@" >/dev/null 2>&1; }

finish() {
    echo
    echo "${CYAN}============================================================${RESET}"
    echo "  Practice finished. Your work folder: $ROOT"
    echo "  Re-run any part with:  $0 <section-number>"
    echo "${CYAN}============================================================${RESET}"
    exit 0
}

ask_dockerhub() {
    [ -n "$DHUSER" ] && return
    echo
    echo "  OPTIONAL: pushing to Docker Hub needs a free account (hub.docker.com)."
    read -r -e -p "Enter your Docker Hub username, or press Enter to skip: " DHUSER
}

ask_github() {
    [ -n "$GHURL" ] && return
    echo
    echo "  OPTIONAL: to push to GitHub, first create an EMPTY repository on github.com"
    echo "  (no README, no .gitignore). Example URL: https://github.com/YourName/docker-fun-lab.git"
    read -r -e -p "Paste your GitHub repo URL, or press Enter to skip: " GHURL
}

# ------------------------------------------------------------------ lab files
# The "docker-fun-lab" kit used by the Git, Images and Optimization sections.
# In a real class the instructor shares these as a GitHub repo and you
# 'git clone' it. Here this function writes the SAME files for you.
# It never overwrites an existing kit, so your own edits are safe.
ensure_lab() {
    [ -f "$ROOT/.lab_ready" ] && return
    mkdir -p "$LAB/00-hello-nginx" "$LAB/01-whale-says" "$LAB/02-whack-a-bug" "$LAB/03-scale-me" \
             "$LAB/04-time-machine" "$LAB/05-optimize-me/go-multistage"

    # ---- 00 hello-nginx : your first Dockerfile (Method 1)
    cat > "$LAB/00-hello-nginx/Dockerfile" <<'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
EOF
    cat > "$LAB/00-hello-nginx/index.html" <<'EOF'
<h1>Hello from MY first Docker image!</h1>
<p>Built from a Dockerfile in the Day 1 workshop.</p>
EOF

    # ---- 01 whale-says : run tools you never installed
    cat > "$LAB/01-whale-says/Dockerfile" <<'EOF'
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
        cowsay figlet fortune-mod fortunes-min lolcat \
    && rm -rf /var/lib/apt/lists/*
ENV PATH="/usr/games:${PATH}"
COPY run.sh /run.sh
RUN chmod +x /run.sh
ENTRYPOINT ["/run.sh"]
EOF
    cat > "$LAB/01-whale-says/run.sh" <<'EOF'
#!/bin/sh
MSG="${*:-Hello from Docker}"
figlet "$MSG" | lolcat -f
cowsay "$MSG" | lolcat -f
fortune | cowsay | lolcat -f
EOF

    # ---- 02 whack-a-bug : ship any app with one command
    cat > "$LAB/02-whack-a-bug/Dockerfile" <<'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
EOF
    cat > "$LAB/02-whack-a-bug/index.html" <<'EOF'
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Whack-a-Bug</title>
<style>
 body{font-family:sans-serif;text-align:center;background:#0f172a;color:#fff}
 #g{display:grid;grid-template-columns:repeat(3,110px);gap:12px;justify-content:center;margin:24px auto}
 .h{width:110px;height:110px;border-radius:50%;background:#334155;font-size:56px;line-height:110px;cursor:pointer;user-select:none}
 button{font-size:18px;padding:8px 24px}
</style></head>
<body>
<h1>Whack-a-Bug</h1>
<p>Score: <b id="s">0</b> &nbsp;|&nbsp; Time: <b id="t">30</b>s</p>
<div id="g"></div>
<button onclick="start()">Start</button>
<p>Served from a Docker container (nginx:alpine)</p>
<script>
var score=0,time=30,cur=-1,tick=null,spawn=null,holes=[];
var g=document.getElementById("g");
for(var i=0;i<9;i++){(function(i){
  var d=document.createElement("div");d.className="h";
  d.onclick=function(){if(i===cur){score++;cur=-1;draw();}};
  g.appendChild(d);holes.push(d);})(i);}
function draw(){
  holes.forEach(function(h,i){h.textContent=(i===cur)?"\uD83D\uDC1B":"";});
  document.getElementById("s").textContent=score;
  document.getElementById("t").textContent=time;
}
function start(){
  clearInterval(tick);clearInterval(spawn);score=0;time=30;cur=-1;draw();
  spawn=setInterval(function(){cur=Math.floor(Math.random()*9);draw();},700);
  tick=setInterval(function(){time--;draw();
    if(time<=0){clearInterval(tick);clearInterval(spawn);cur=-1;draw();alert("Final score: "+score);}},1000);
}
draw();
</script>
</body></html>
EOF

    # ---- 03 scale-me : one image, many copies
    cat > "$LAB/03-scale-me/Dockerfile" <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY app.py .
ENV PYTHONUNBUFFERED=1
EXPOSE 8000
CMD ["python", "app.py"]
EOF
    cat > "$LAB/03-scale-me/app.py" <<'EOF'
import hashlib
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

HOST = socket.gethostname()
COLOR = "#" + hashlib.md5(HOST.encode()).hexdigest()[:6]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = (
            "<body style='background:%s;font-family:sans-serif;color:#fff;"
            "text-align:center;padding-top:20vh;text-shadow:0 0 6px #000'>"
            "<h1>Scale Me</h1><h2>Served by container: %s</h2></body>" % (COLOR, HOST)
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
EOF

    # ---- 04 time-machine : "works on my machine", solved
    cat > "$LAB/04-time-machine/Dockerfile" <<'EOF'
ARG PY_VERSION=3.12
FROM python:${PY_VERSION}-slim
WORKDIR /app
COPY app.py .
CMD ["python", "app.py"]
EOF
    cat > "$LAB/04-time-machine/app.py" <<'EOF'
import sys

print("Running on Python", sys.version.split()[0])
if sys.version_info >= (3, 10):
    print("Modern Python: match/case and 'X | Y' type syntax are available")
else:
    print("Legacy Python: no match/case, no 'X | Y' type syntax")
EOF

    # ---- 05 optimize-me : fat vs slim
    cat > "$LAB/05-optimize-me/app.py" <<'EOF'
from flask import Flask
import os

app = Flask(__name__)


@app.route("/")
def home():
    return "Hello from " + os.environ.get("APP_NAME", "Docker") + " app"


@app.route("/health")
def health():
    return "OK"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF
    echo "flask" > "$LAB/05-optimize-me/requirements.txt"
    cat > "$LAB/05-optimize-me/Dockerfile.fat" <<'EOF'
FROM python:3.12
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
EOF
    cat > "$LAB/05-optimize-me/Dockerfile.slim" <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir \
    -r requirements.txt
COPY app.py .
CMD ["python", "app.py"]
EOF
    cat > "$LAB/05-optimize-me/Dockerfile.secure" <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN useradd -m appuser
USER appuser
ENV APP_NAME=DockerDemo
EXPOSE 5000
CMD ["python", "app.py"]
EOF
    cat > "$LAB/05-optimize-me/.dockerignore" <<'EOF'
.git
__pycache__
*.pyc
Dockerfile*
.dockerignore
README.md
go-multistage
EOF

    # ---- 05 multi-stage (Go) : the Dockerfile on slide 48
    cat > "$LAB/05-optimize-me/go-multistage/go.mod" <<'EOF'
module go-api

go 1.23
EOF
    cat > "$LAB/05-optimize-me/go-multistage/main.go" <<'EOF'
package main

import (
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Hello from a tiny Go container")
	})
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "OK")
	})
	http.ListenAndServe(":8080", nil)
}
EOF
    cat > "$LAB/05-optimize-me/go-multistage/Dockerfile" <<'EOF'
# Stage 1: builder (has the compiler)
FROM golang:1.23-alpine AS builder
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /out/server .

# Stage 2: final image (only the result)
FROM alpine:3.20
COPY --from=builder /out/server /app/server
CMD ["/app/server"]
EOF
    touch "$ROOT/.lab_ready"
}

# Visible, typeable step used in the Git section.
get_lab_files() {
    if [ -f "$ROOT/.lab_ready" ]; then
        echo "  Lab files already exist in: $LAB"
    else
        ensure_lab
        echo "  Lab files written to: $LAB"
    fi
}

# ==============================================================================
#  SECTION 1 - CONTAINERS VS VIRTUAL MACHINES  (deck slides 11-16)
# ==============================================================================
sec1() {
    cd "$ROOT" || exit 1
    section "1. CONTAINERS VS VIRTUAL MACHINES  (deck slides 11-16)" \
            "Prove on YOUR machine that containers share the host kernel and start in about a second"
    note "Slide 13: there is no guest OS inside a container. Every container is an isolated process on ONE shared kernel."

    p "Show the kernel version of your own Ubuntu machine" "uname -r" \
      "uname -r prints the version of the Linux kernel your host computer is running. We note this number so we can compare it with a container next." \
      "A version such as 5.15.0-91-generic. Remember it."
    p "Show the kernel version INSIDE a container" "docker run --rm alpine uname -r" \
      "docker run creates and starts a container from the image 'alpine' (a tiny Linux, downloaded automatically the first time). It runs 'uname -r' inside and then --rm deletes the container as soon as it finishes." \
      "The SAME kernel number as the previous step. A container has no kernel of its own; it borrows the host's. A VM would show its own kernel."
    p "Run a different Linux distribution (Ubuntu) and check its kernel" "docker run --rm ubuntu sh -c 'cat /etc/os-release | head -2; uname -r'" \
      "Starts an Ubuntu container and runs two commands inside it with sh -c: first prints the OS name, then the kernel version." \
      "The OS name says Ubuntu (the container's own files and libraries), but the kernel number is still the host's. That is exactly what 'shared kernel' means."
    p "Measure how fast a container starts" "time docker run --rm alpine echo started" \
      "'time' measures how long the command takes. The command creates a container, prints 'started' and removes it." \
      "'real' is around 1 second (or less). Booting a full VM would take minutes."
    ask "Does a container have its own operating system kernel?  (Answer: no, it uses the host's.)"
}

# ==============================================================================
#  SECTION 2 - DOCKER FUNDAMENTALS  (deck slides 17-25)
# ==============================================================================
sec2() {
    cd "$ROOT" || exit 1
    section "2. DOCKER FUNDAMENTALS  (deck slides 17-25)" \
            "The Docker platform: CLI, daemon (Engine), images, containers, registry, volume, network"
    note "Slide 20-21: you type a command in the CLI -> the CLI calls the REST API -> the daemon (dockerd) does the work."

    p "Check that Docker is installed" "docker --version" \
      "Prints the version of the Docker command-line tool (the CLI)." \
      "A line like 'Docker version 27.x.x'. If you get 'command not found', Docker is not installed."
    p "Show Client AND Server details" "docker version" \
      "Prints two separate blocks. 'Client' is the CLI you type into. 'Server' is the Docker Engine (daemon) that does the real work." \
      "Both a Client and a Server block. If the Server block is missing, the CLI cannot reach the daemon (slide 21: the CLI is only a messenger)."
    p "Check the Docker Engine service" "systemctl status docker --no-pager" \
      "systemctl asks Ubuntu's service manager whether the 'docker' service (dockerd) is running. --no-pager prints everything at once instead of opening a scrolling viewer." \
      "'Active: active (running)' in green. If it says inactive, start it with: sudo systemctl start docker"
    p "Show full Engine details" "docker info" \
      "Prints a summary of the Engine: number of containers and images, storage driver, runtime, kernel version, and more." \
      "Look at 'Containers', 'Images', 'Storage Driver' and 'Server Version'."
    note "Slide 22 question: what happens to running containers if the daemon goes down? It depends on a setting called live-restore."
    p "Check whether live-restore is enabled" "docker info --format '{{.LiveRestoreEnabled}}'" \
      "--format picks out just ONE field from docker info. LiveRestoreEnabled tells you whether containers keep running while the daemon is stopped." \
      "'false' (the default) means all containers stop when dockerd stops. 'true' means they keep running."
    p "List running containers" "docker ps" \
      "Shows only containers that are running right now." \
      "An empty list with just the column headers (CONTAINER ID, IMAGE, ...). That is normal at the start."
    p "Run your first container" "docker run hello-world" \
      "Starts a container from the 'hello-world' image. Docker notices the image is not on your machine, downloads it from Docker Hub (the registry), creates the container and runs it." \
      "'Unable to find image locally' then 'Pulling...' then a 'Hello from Docker!' message. That message describes the exact architecture of slide 21."
    p "List ALL containers, including stopped ones" "docker ps -a" \
      "-a means 'all'. Without it, docker ps hides containers that have finished." \
      "The hello-world container with STATUS 'Exited (0)'. It finished its job but still exists."
    p "List the images stored on this machine" "docker images" \
      "Shows every image downloaded or built locally. Images are the read-only templates containers are created from." \
      "hello-world listed with its TAG (latest) and a tiny SIZE."
    p "Search the registry (Docker Hub) from the command line" "docker search nginx --limit 5" \
      "Searches Docker Hub for images matching 'nginx'. --limit 5 shows only the first 5 results." \
      "A table with NAME, DESCRIPTION, STARS and OFFICIAL. The official image is simply called 'nginx'."

    note "Slide 24 terms: a Volume is storage that outlives a container; a Network lets containers talk to each other."
    p "Create a volume" "docker volume create data" \
      "Creates a named storage area managed by Docker, named 'data'." \
      "The command echoes the name: data"
    p "List volumes" "docker volume ls" \
      "Shows all Docker volumes." \
      "Your 'data' volume with DRIVER 'local'."
    p "List networks" "docker network ls" \
      "Shows the virtual networks Docker created." \
      "Three defaults: bridge, host, none."
    p "Remove the practice volume" "docker volume rm data" \
      "Deletes the volume we just made." \
      "The name 'data' is echoed back."
    p "See the list of Docker commands" "docker --help" \
      "Prints every top-level Docker command with a one-line description." \
      "Commands you will use today: run, ps, build, images, pull, push, exec, logs, rm."
    note "Slide 25: Podman is a near drop-in replacement. Most commands are identical (alias docker=podman)."
}

# ==============================================================================
#  SECTION 3 - CONTAINER LIFECYCLE  (deck slides 26-29)
# ==============================================================================
sec3() {
    cd "$ROOT" || exit 1
    qrm web web2
    section "3. THE CONTAINER LIFECYCLE  (deck slides 26-29)" \
            "Created -> Running -> Paused -> Stopped -> Removed, then the hands-on nginx lab from slide 29"
    note "Lifecycle: Created, Running, Paused, Stopped [Exited], Removed.   docker run = docker create + docker start."

    part "PART A: create and start as two separate steps"
    p "CREATE a container without starting it" "docker create --name web -p 8080:80 nginx:alpine" \
      "docker create builds the container but does not run it. --name web gives it a readable name. -p 8080:80 maps port 8080 on YOUR machine to port 80 inside the container. nginx:alpine is a small web-server image (downloaded if needed)." \
      "It prints a long container ID. The container now exists but nothing is running."
    p "Check its status" "docker ps -a" \
      "Lists all containers including ones that are not running." \
      "Container 'web' with STATUS 'Created'."
    p "START the container" "docker start web" \
      "Starts the existing container named 'web'." \
      "It prints the name: web"
    p "Check its status again" "docker ps" \
      "Lists running containers." \
      "'web' with STATUS 'Up ...' and PORTS 0.0.0.0:8080->80/tcp."
    p "Call the web server" "curl http://localhost:8080" \
      "curl sends an HTTP request to port 8080 on your machine, which Docker forwards into the container's port 80." \
      "HTML text: 'Welcome to nginx!'. You can also open http://localhost:8080 in a browser."
    p "Force remove it so the lab starts clean" "docker rm -f web" \
      "rm removes a container. -f (force) stops it first if it is running." \
      "The name 'web' is echoed back."

    part "PART B: the hands-on lab from slide 29"
    note "After EACH step: run docker ps -a to see the STATUS (Up, Exited, Paused) and try http://localhost:8080."
    p "Run nginx in the background" "docker run -d -p 8080:80 --name web nginx:alpine" \
      "docker run = create + start in one command. -d runs it in the background (detached) so you get your terminal back. -p maps the ports. --name web names it." \
      "A container ID is printed and your prompt returns immediately."
    p "List running containers" "docker ps" \
      "Shows what is running now." \
      "'web' with STATUS 'Up a few seconds'."
    p "Confirm the web page works" "curl http://localhost:8080" \
      "Sends a request to the running container." \
      "The nginx welcome page HTML."
    p "STOP the container" "docker stop web" \
      "Gracefully asks the main process to shut down (waits up to 10 seconds, then forces it)." \
      "The name 'web' is echoed back."
    p "A stopped container is NOT deleted" "docker ps -a" \
      "Lists all containers, including stopped ones." \
      "'web' with STATUS 'Exited (0) ...'. It still exists with all its files."
    p "The page no longer answers" "curl -m 3 http://localhost:8080" \
      "-m 3 tells curl to give up after 3 seconds." \
      "An error such as 'Failed to connect' or 'Connection refused'. Nothing is running to answer."
    p "START the same container again" "docker start web" \
      "Starts the stopped container. It is the SAME container: same ID, same files." \
      "The name 'web' is echoed back."
    p "PAUSE the container" "docker pause web" \
      "Freezes every process in the container in memory. Nothing is lost, but nothing runs." \
      "The name 'web' is echoed back."
    p "Try the page while it is paused" "curl -m 3 http://localhost:8080" \
      "The request reaches the container but nobody can reply because the process is frozen." \
      "curl HANGS for 3 seconds and then reports a timeout. (A browser page would just keep loading.) docker ps now shows 'Up ... (Paused)'."
    p "UNPAUSE the container" "docker unpause web" \
      "Un-freezes the processes. They carry on exactly where they stopped." \
      "The name 'web' is echoed back."
    p "The page works again" "curl http://localhost:8080" \
      "Same request as before." \
      "The nginx welcome page is back immediately."
    p "RESTART the container" "docker restart web" \
      "Stop + start in one step." \
      "The name 'web' is echoed back."
    p "View the container's logs" "docker logs web" \
      "Prints everything the container's main process has written to its output." \
      "nginx start-up lines and one access-log line for each curl request you made."
    p "Resource usage snapshot" "docker stats --no-stream" \
      "docker stats shows live CPU and memory use. --no-stream prints one snapshot instead of updating forever." \
      "A table with CPU %, MEM USAGE and NET I/O for 'web'. Memory is only a few MB."
    p "Read only the container's state" "docker inspect --format '{{.State.Status}}' web" \
      "docker inspect prints every detail about a container as JSON. --format picks one field out of it." \
      "The word 'running'."
    p "Run ONE command inside the container" "docker exec web cat /etc/os-release" \
      "docker exec runs a command inside an already-running container. Here it prints the operating-system information file." \
      "'Alpine Linux' details: the OS inside the container, not your Ubuntu."
    note "The next step opens a shell INSIDE the container. Your prompt will change. Try: ls   then   cat /etc/os-release   then type  exit  to come back."
    p "Open an interactive shell inside the container" "docker exec -it web sh" \
      "-i keeps your keyboard connected, -t gives you a proper terminal, sh is the shell program to start. You are now 'inside' the container." \
      "The prompt changes (for example to '/ #'). Type exit to return to your normal terminal."
    note "Common mistake: docker rm on a RUNNING container fails. Watch the error message."
    p "Try to remove a running container" "docker rm web" \
      "Plain rm refuses to delete a container that is still running." \
      "An error: 'cannot remove a running container ... stop the container before attempting removal or force remove'."
    p "Force remove it" "docker rm -f web" \
      "-f stops the container and removes it in one go." \
      "The name 'web' is echoed back."
    p "Confirm it is gone" "docker ps -a" \
      "Lists all containers." \
      "'web' no longer appears."

    part "PART C: handy extras"
    p "A temporary container that deletes itself" "docker run --rm alpine echo Hello from a temporary container" \
      "Runs one command in a throw-away container. --rm removes the container the moment it exits." \
      "The text prints, and docker ps -a shows no leftover container."
    p "Remove ALL stopped containers at once" "docker container prune -f" \
      "prune deletes every stopped container. -f skips the 'are you sure?' question." \
      "'Deleted Containers:' followed by IDs (for example the old hello-world one) and the space reclaimed."
    note "Common errors: 'port is already allocated' -> use another port, e.g. -p 8090:80.   'Cannot connect to the Docker daemon' -> start Docker."
}

# ==============================================================================
#  SECTION 4 - GIT AND GITHUB  (deck slides 38-43)
#  Comes BEFORE Dockerfiles: this is how project files reach your machine.
# ==============================================================================
sec4() {
    cd "$ROOT" || exit 1
    section "4. GIT AND GITHUB  (deck slides 38-43)" \
            "How Dockerfiles and project files get onto your machine, and how teams version, review and share them"
    echo "  ${BOLD}Why Git before Dockerfiles?${RESET}"
    echo "  Every Dockerfile lives inside a project. In real life you get that project"
    echo "  with 'git clone <url>' and share your changes with 'git push'."
    echo "  In this section you will:"
    echo "    1. clone a public repo to see how files arrive on your machine,"
    echo "    2. get the workshop lab files (these hold ALL the Dockerfiles used later),"
    echo "    3. put them under Git: add, commit, branch, merge, undo, push."
    echo
    pause
    note "Slide 39: working directory -> (git add) staging -> (git commit) local repo -> (git push) GitHub."

    part "PART A: get files onto your machine with git clone (slide 40)"
    p "Check Git is installed" "git --version" \
      "Prints the installed Git version." \
      "A line like 'git version 2.34.1'. If missing: sudo apt install git"
    p "See your global Git settings" "git config --global --list" \
      "Shows settings that apply to every repo on this machine, such as your name and email." \
      "user.name and user.email if you set them before; it may be empty on a fresh machine, and that is fine."
    note "Slide 40 uses --global. In this practice we use repo-level settings instead, so your machine's Git config stays untouched."
    p "CLONE a public repository from GitHub" "git clone https://github.com/docker/welcome-to-docker.git" \
      "git clone downloads a complete copy of a repository (all files plus the full history) into a new folder named after the repo, and links it to GitHub automatically. This is exactly how you get anyone's Dockerfile." \
      "'Cloning into welcome-to-docker...' and progress lines ending with 'done'."
    p "Enter the cloned folder" "cd welcome-to-docker" \
      "cd changes your current folder." \
      "No output. Your prompt (if it shows the folder) changes."
    p "List its files" "ls -la" \
      "Lists all files, including hidden ones, with details." \
      "The project files that were just copied from GitHub (look for a Dockerfile among them) and a hidden .git folder, which holds the history."
    p "View the last 3 commits" "git log --oneline -3" \
      "git log shows the history of saved snapshots (commits). --oneline shows one short line each; -3 limits it to 3." \
      "Three lines, each with a short commit ID and a message."
    p "Go back to the training folder" "cd $ROOT" \
      "Returns to your practice folder using its full path." \
      "No output."

    part "PART B: get the workshop lab files (they contain all the Dockerfiles)"
    note "In a real class your instructor shares a GitHub link and you run 'git clone'. Here the next step writes the SAME lab files into your folder for you."
    p "Create the lab files in ~/docker-training/docker-fun-lab" "get_lab_files" \
      "This step is built into the script. It writes the lab folders: 00-hello-nginx, 01-whale-says, 02-whack-a-bug, 03-scale-me, 04-time-machine and 05-optimize-me, each with its own Dockerfile and app code." \
      "A message saying where the files were written."
    p "Look at the lab folders" "ls docker-fun-lab" \
      "Lists the folders inside the lab. Each one is a small project used in a later section." \
      "Folders 00-hello-nginx to 05-optimize-me."
    p "Look inside one project" "ls docker-fun-lab/03-scale-me" \
      "Shows the files of one lab project." \
      "A Dockerfile and app.py. You will build an image from these in the Images section."

    part "PART C: put the lab under Git (slide 40)"
    p "Enter the lab folder" "cd docker-fun-lab" \
      "Moves into the project folder we want to track." \
      "No output."
    p "Create a repository here" "git init" \
      "git init turns the current folder into a Git repository by creating a hidden .git folder. Use it for a folder you already have; use git clone for one that already exists on GitHub." \
      "'Initialized empty Git repository in .../docker-fun-lab/.git/'."
    p "Set your name for this repo" "git config user.name Demo" \
      "Every commit is stamped with a name. Without --global, this applies only to this repo." \
      "No output."
    p "Set your email for this repo" "git config user.email demo@example.com" \
      "Every commit is also stamped with an email. In real life use the same email as your GitHub account." \
      "No output."
    p "Create a README file" "echo '# Docker Fun Lab' > README.md" \
      "echo prints text, and > writes it into a new file called README.md." \
      "No output. The file now exists."

    part "PART D: daily workflow - add, commit, push, pull (slide 41)"
    p "Ask Git what it sees" "git status" \
      "Shows which files are new, changed or saved." \
      "'Untracked files' listed in red: Git sees them but is not tracking them yet."
    p "STAGE one folder only" "git add 01-whale-says" \
      "git add moves changes into the staging area, which is a draft of your next commit (slide 39: packing the box)." \
      "No output."
    p "Check the status again" "git status" \
      "Same command as before." \
      "01-whale-says is now listed under 'Changes to be committed' in green. The rest is still red."
    p "STAGE everything" "git add ." \
      "The dot means 'the current folder and everything inside it'." \
      "No output."
    p "COMMIT: save a snapshot on your laptop" 'git commit -m "Add docker fun lab"' \
      "git commit seals the staged files into a permanent snapshot in your local history. -m gives it a message. Good messages say what the change DOES." \
      "'[main or master (root-commit) abc1234] Add docker fun lab' and a count of files created."
    p "Check the status after committing" "git status" \
      "Same command again." \
      "'nothing to commit, working tree clean' means everything is saved."
    p "View the history" "git log --oneline" \
      "Lists commits, newest first." \
      "One line: a short ID and 'Add docker fun lab'."
    p "Edit a file (add one line)" "echo '# tweak' >> 03-scale-me/app.py" \
      "echo with >> appends a line to the END of an existing file. > would replace the whole file." \
      "No output."
    p "See that Git noticed" "git status" \
      "Compares your folder with the last commit." \
      "'modified: 03-scale-me/app.py' in red."
    p "See exactly which lines changed" "git diff" \
      "Shows the difference between your working files and the last commit. Lines starting with + were added; lines starting with - were removed." \
      "A green '+# tweak' line."
    p "Stage and commit in one go" 'git add . && git commit -m "Tweak scale-me app"' \
      "&& runs the second command only if the first succeeds." \
      "A second commit is created, 1 file changed."
    p "Rename the branch to main" "git branch -M main" \
      "A branch is a line of history. -M renames the current branch; 'main' is the modern default name (older Git calls it master)." \
      "No output."

    ask_github
    if [ -n "$GHURL" ]; then
        note "GitHub does NOT accept your password for push. Use 'gh auth login', a Personal Access Token, or an SSH URL."
        p "Link your local repo to GitHub" "git remote add origin $GHURL" \
          "A remote is a shared copy of your repo on another server. 'origin' is the conventional name for the main one." \
          "No output."
        p "Verify the link" "git remote -v" \
          "Lists your remotes and their URLs (-v = verbose)." \
          "Two lines (fetch and push) showing your GitHub URL."
        p "First PUSH to GitHub" "git push -u origin main" \
          "git push uploads your commits to GitHub. -u remembers 'origin main' as the default, so later you only need 'git push'." \
          "Upload progress ending with 'Branch main set up to track ...'. Refresh your repo page on github.com to see the files."
        p "PULL teammates' changes" "git pull" \
          "git pull downloads new commits from GitHub and merges them into your branch (fetch + merge)." \
          "'Already up to date.' because nobody else has pushed."
        ask "I committed but my teammate can't see my change. Why?  (Commits are local until you push.)"
    else
        note "GitHub skipped. The remote steps would be: git remote add origin <url>, git push -u origin main, git pull."
    fi

    part "PART E: branches and merging (slide 42)"
    p "List branches" "git branch" \
      "Lists local branches. The * marks the one you are on." \
      "'* main'"
    p "Create a feature branch AND move to it" "git switch -c feature/login" \
      "git switch moves between branches. -c creates the new branch first. Work on a branch keeps 'main' always working." \
      "'Switched to a new branch feature/login'."
    p "Do some work on the branch" "echo 'login page' > login.txt" \
      "Creates a new file holding the text 'login page'." \
      "No output."
    p "Stage and commit it" 'git add . && git commit -m "Add login page"' \
      "Saves the new file as a commit on the feature branch only." \
      "A commit on feature/login with 1 file changed."
    p "Go back to main" "git switch main" \
      "Switches back to the main branch." \
      "'Switched to branch main'."
    p "Check the files on main" "ls" \
      "Lists the current folder." \
      "login.txt is NOT here. It exists only on the feature branch."
    p "MERGE the feature into main" "git merge feature/login" \
      "git merge brings the commits of feature/login into the branch you are on (main)." \
      "'Fast-forward' and 'login.txt | 1 +'. The feature is now part of main."
    p "Check the files again" "ls" \
      "Lists the current folder." \
      "login.txt has arrived on main."
    p "Draw the history" "git log --oneline --graph" \
      "--graph draws the branch structure as ASCII art." \
      "Three commits in a line, newest on top."
    if [ -n "$GHURL" ]; then
        p "Push main to GitHub" "git push" \
          "Uploads the new commits. No arguments are needed because of -u earlier." \
          "Upload progress. GitHub now shows login.txt."
    fi
    p "Delete the merged branch" "git branch -d feature/login" \
      "-d deletes a branch that has already been merged. The commits stay in main." \
      "'Deleted branch feature/login'."
    note "On GitHub the flow is: push branch -> open Pull Request -> team reviews -> Merge -> everyone runs git pull."

    part "PART F: undo mistakes safely (slide 42)"
    p "Make a mistake in a file" "echo 'oops' >> README.md" \
      "Appends an unwanted line to README.md." \
      "No output."
    p "See the mistake" "git status" \
      "Shows what changed." \
      "'modified: README.md' in red."
    p "RESTORE: throw away the unsaved edit" "git restore README.md" \
      "git restore puts the file back to how it was at the last commit. Careful: the discarded edit cannot be recovered." \
      "No output."
    p "Confirm it is clean" "git status" \
      "Same check." \
      "'nothing to commit, working tree clean'."
    p "Mistake again, this time also staged" "echo 'oops' >> README.md && git add README.md" \
      "Makes the same bad edit and stages it." \
      "No output."
    p "UNSTAGE it but keep the edit" "git restore --staged README.md" \
      "--staged removes the file from the staging area only. Your edit stays in the file." \
      "No output. git status shows it as modified (red) again."
    p "Now discard the edit too" "git restore README.md" \
      "Puts the file back to the last commit." \
      "No output."
    p "AMEND the last commit message" 'git commit --amend -m "Add login feature"' \
      "--amend rewrites the most recent commit, here just to improve its message." \
      "The commit is shown again with the new message."
    note "WARNING: --amend rewrites history. Never amend a commit that is already pushed and shared."

    if [ -n "$GHURL" ]; then
        part "PART G: simulate 'another machine' with a fresh clone"
        p "Push the amended history" "git push --force-with-lease" \
          "We amended an already-pushed commit, so GitHub must be told to accept the rewritten history. --force-with-lease is the safer form of force-push. (This is the exact case the warning above is about; only do it on your OWN practice repo.)" \
          "Upload progress with a forced update '+'."
        p "Go back to the training folder" "cd $ROOT" \
          "Leaves the lab repo." \
          "No output."
        p "Clone YOUR OWN repo from GitHub into a new folder" "git clone $GHURL docker-fun-lab-clone" \
          "This is what a teammate (or a server) would do: download your project from GitHub." \
          "'Cloning into docker-fun-lab-clone...'."
        p "The same Dockerfiles arrived" "ls docker-fun-lab-clone" \
          "Lists the cloned folder." \
          "The same 00-hello-nginx ... 05-optimize-me folders. Git carried your files to a 'new machine'."
    fi
    p "Return to the training folder" "cd $ROOT" \
      "Leaves the repo. The next section builds images from these files." \
      "No output."
}

# ==============================================================================
#  SECTION 5 - DOCKER IMAGES  (deck slides 30-37)
# ==============================================================================
sec5() {
    cd "$ROOT" || exit 1
    ensure_lab
    qrm web myapp-web layer-demo temp game app1 app2 app3
    section "5. DOCKER IMAGES  (deck slides 30-37)" \
            "What an image is, Method 1 (Dockerfile), Method 2 (docker commit), and the 4 fun labs"
    note "An image is a read-only stack of layers. A container = that image + one thin writable layer on top."
    note "All Dockerfiles used here come from the lab files you got in the Git section: $LAB"

    part "PART A: what is inside an image (slide 31)"
    p "PULL an image" "docker pull python:3.12-slim" \
      "pull downloads an image from the registry. 'python' is the repository, '3.12-slim' is the tag (a version label)." \
      "Several lines of 'Pull complete': each line is one LAYER being downloaded."
    p "PULL another image" "docker pull nginx:alpine" \
      "Downloads the small nginx web-server image." \
      "Fewer layers and a faster download."
    p "LIST local images" "docker images" \
      "Shows every image stored on this machine." \
      "python:3.12-slim and nginx:alpine with their SIZE."
    p "See the layers of an image" "docker history python:3.12-slim" \
      "Shows the layers an image is built from, newest first, and the instruction that created each one." \
      "A table of layers with CREATED BY, such as ADD, ENV, RUN and CMD."
    p "Count the read-only layers" "docker image inspect python:3.12-slim --format '{{len .RootFS.Layers}}'" \
      "Reads image details and prints just the number of layers." \
      "A single number (typically between 4 and 10)."
    p "Start a container and keep it alive" "docker run -d --name layer-demo alpine sleep 300" \
      "Starts Alpine in the background running 'sleep 300' (wait 5 minutes) so the container stays up for the next steps." \
      "A container ID."
    p "Write a file inside the container" "docker exec layer-demo sh -c 'echo hi > /hello.txt'" \
      "Runs a command inside the container that creates /hello.txt. The file goes into the container's thin WRITABLE layer, not into the image." \
      "No output."
    p "See what the writable layer holds" "docker diff layer-demo" \
      "docker diff lists files added (A), changed (C) or deleted (D) compared with the image." \
      "'A /hello.txt' (plus a few 'C' lines)."
    p "Remove the container" "docker rm -f layer-demo" \
      "Deleting the container deletes its writable layer along with it." \
      "The name 'layer-demo' is echoed back."
    p "Start a NEW container from the same image and look for the file" "docker run --rm alpine ls /hello.txt" \
      "Runs ls on the file in a brand-new container made from the same image." \
      "'No such file or directory'. The image was never changed, so the file is gone."

    part "PART B: Method 1 - write a Dockerfile, build the image (slides 32-34)"
    p "Enter the first lab project" "cd docker-fun-lab/00-hello-nginx" \
      "Moves into the folder holding a Dockerfile and a web page." \
      "No output."
    p "List the files" "ls" \
      "Shows what is in the folder." \
      "Dockerfile and index.html. The build 'context' is this folder."
    p "Read the Dockerfile" "cat Dockerfile" \
      "A Dockerfile is a recipe. FROM picks the ready-made base image. COPY copies a file from your folder into the image. EXPOSE documents which port the app listens on." \
      "Three lines: FROM nginx:alpine, COPY index.html ..., EXPOSE 80."
    p "BUILD the image" "docker build -t myapp:1.0 ." \
      "docker build reads the Dockerfile and creates an image. -t gives it a name:tag (myapp:1.0). The final dot means 'use this folder as the build context'." \
      "Steps like '[1/2] FROM nginx:alpine' and '[2/2] COPY ...' and finally 'naming to docker.io/library/myapp:1.0'."
    p "List your new image" "docker images myapp" \
      "Shows images whose name is 'myapp'." \
      "myapp with TAG 1.0."
    p "RUN a container from your image" "docker run -d -p 8080:80 --name myapp-web myapp:1.0" \
      "Starts a container from YOUR image, in the background, with port 8080 forwarded to port 80." \
      "A container ID."
    p "See your own page" "curl http://localhost:8080" \
      "Requests the page from your container." \
      "'Hello from MY first Docker image!'  (also visible in a browser at localhost:8080)."
    p "Stop and remove the container" "docker rm -f myapp-web" \
      "Cleans up the container so port 8080 is free again." \
      "The name 'myapp-web' is echoed back."
    note "Slide 32 image lifecycle: Build -> Tag -> Push -> Pull -> Run. We have done Build and Run. Now Tag."
    p "TAG: add a second label to the SAME image" "docker tag myapp:1.0 myapp:1.0.0" \
      "A tag is just a version label. This adds the label 1.0.0 to the image that already has 1.0. Nothing is copied." \
      "No output."
    p "Compare the image IDs" "docker images myapp" \
      "Lists the tags of myapp." \
      "Two rows (1.0 and 1.0.0) with the SAME IMAGE ID. They point at one image."
    p "Remove only one tag" "docker rmi myapp:1.0.0" \
      "rmi removes an image name. Because another tag still points to the image, only the label is removed, not the image." \
      "'Untagged: myapp:1.0.0'. The image itself is NOT deleted."
    p "Back to the training folder" "cd $ROOT" \
      "Leaves the lab project." \
      "No output."

    ask_dockerhub
    if [ -n "$DHUSER" ]; then
        part "Registry round trip: push and pull (slide 32)"
        note "The tag MUST contain your Docker Hub username, otherwise the push is denied."
        p "TAG with your registry name" "docker tag myapp:1.0 $DHUSER/myapp:1.0" \
          "Adds the label <your-username>/myapp:1.0, which tells Docker where the image belongs on Docker Hub." \
          "No output."
        p "Log in to Docker Hub" "docker login" \
          "Asks for your Docker Hub username and password (or access token). Needed once." \
          "'Login Succeeded'."
        p "PUSH: image -> registry" "docker push $DHUSER/myapp:1.0" \
          "Uploads the image layers to Docker Hub." \
          "Layer upload lines ending with a digest. Check hub.docker.com to see your repository."
        p "Delete the local copies to simulate another machine" "docker rmi $DHUSER/myapp:1.0 myapp:1.0" \
          "Removes the image from this machine so the next step must download it." \
          "'Untagged' and 'Deleted' lines."
        p "PULL: registry -> this machine" "docker pull $DHUSER/myapp:1.0" \
          "Downloads your image from Docker Hub." \
          "'Pull complete' lines then 'Downloaded newer image'."
        p "RUN: image -> running container" "docker run -d -p 8080:80 --name myapp-web $DHUSER/myapp:1.0" \
          "Runs the image that came from the registry. Nobody rebuilt anything." \
          "A container ID."
        p "Same page, no rebuild" "curl http://localhost:8080" \
          "Requests the page." \
          "'Hello from MY first Docker image!'  Built once, runs anywhere."
        p "Clean up" "docker rm -f myapp-web" \
          "Removes the container." \
          "The name is echoed back."
    fi

    part "PART C: Method 2 - docker commit (slides 35-36)"
    note "docker commit = a snapshot of a container you changed BY HAND. Good for experiments, NOT for production: nothing records how it was built."
    echo
    echo "  ${BOLD}${RED}READ THIS BEFORE THE NEXT STEP${RESET}"
    echo "  The next command opens a shell INSIDE a new Ubuntu container."
    echo "  Your prompt will change to something like:  ${BOLD}root@7d2efdeba352:/#${RESET}"
    echo "  Type these THREE lines there, one at a time, pressing Enter after each:"
    echo
    echo "     ${GREEN}1)  apt-get update && apt-get install -y figlet${RESET}"
    echo "     ${GREEN}2)  echo \"Made with docker commit\" > /notes.txt${RESET}"
    echo "     ${GREEN}3)  exit${RESET}"
    echo
    echo "  (Line 1 installs a tool, line 2 creates a file, line 3 leaves the container.)"
    echo "  If you forget, don't worry: the script detects it and applies them for you."
    pause
    p "1. Start a container from plain Ubuntu and go inside" "docker run -it --name temp ubuntu bash" \
      "-i keeps your keyboard connected and -t gives a terminal. --name temp names the container. 'ubuntu' is the image, 'bash' is the program to run inside. Now type the 3 lines from the box above." \
      "The prompt changes to root@<id>:/#. After you type exit you return to your normal prompt."
    if ! docker diff temp 2>/dev/null | grep -q "notes.txt" || ! docker diff temp 2>/dev/null | grep -q "figlet"; then
        note "I did not detect figlet and notes.txt inside the container. Applying the two changes for you now..."
        docker start temp >/dev/null 2>&1
        docker exec temp bash -c 'apt-get update -qq && apt-get install -y -qq figlet >/dev/null 2>&1 && echo "Made with docker commit" > /notes.txt'
        docker stop temp >/dev/null 2>&1
        echo "  Done."
    fi
    p "2. See what you changed" "docker diff temp" \
      "docker diff lists every file that differs from the original Ubuntu image. A = added, C = changed, D = deleted." \
      "'A /notes.txt' and many 'A /usr/...' lines from the figlet install."
    p "3. COMMIT: freeze the container into a new image" 'docker commit -m "Add figlet and notes" temp my-ubuntu:custom' \
      "docker commit turns container 'temp' into a new image named my-ubuntu:custom. -m adds a message. The original container is untouched." \
      "A sha256 image ID is printed."
    p "4. Check the new image" "docker images my-ubuntu" \
      "Lists images named my-ubuntu." \
      "my-ubuntu:custom, noticeably larger than plain ubuntu because it includes figlet."
    p "5. Run a NEW container from it: figlet is already installed" "docker run --rm my-ubuntu:custom figlet Hello" \
      "Starts a fresh container from your committed image and runs figlet. You did not install anything this time." \
      "'Hello' drawn in big ASCII letters."
    p "6. The file is there too" "docker run --rm my-ubuntu:custom cat /notes.txt" \
      "Prints /notes.txt from a fresh container." \
      "'Made with docker commit'."
    p "Why Dockerfiles win: look at the history" "docker history my-ubuntu:custom" \
      "Shows the layers of the committed image." \
      "The top layer is just 'Add figlet and notes'. Nothing records WHICH commands installed figlet, so nobody can rebuild it reliably."
    p "Clean up" "docker rm temp && docker rmi my-ubuntu:custom" \
      "Removes the container, then the image." \
      "The name 'temp' and 'Untagged'/'Deleted' lines."

    part "PART D: Docker Fun Lab - four demos (slide 37)"
    note "Each demo is a folder from your lab files with its own Dockerfile."
    p "Enter the lab folder" "cd docker-fun-lab" \
      "Moves into the folder with the four demos." \
      "No output."

    echo; echo "  ${BOLD}Demo 1 - The whale says: run tools you never installed${RESET}"
    p "Enter demo 1" "cd 01-whale-says" \
      "Moves into the demo folder." \
      "No output."
    p "Read its Dockerfile" "cat Dockerfile" \
      "Shows the recipe: a Debian base plus four fun tools installed with apt." \
      "A RUN line installing cowsay, figlet, fortune and lolcat."
    p "Build the image" "docker build -t whale-says ." \
      "Builds an image named whale-says from this folder's Dockerfile. The first build downloads packages, so it takes a minute." \
      "'naming to docker.io/library/whale-says'."
    p "Run it" "docker run --rm -t whale-says \"Hi\"" \
      "Starts a container and passes the word Hi to the program inside. -t gives a terminal so colours show; --rm deletes the container afterwards." \
      "'Hi' in big colourful letters, a cow saying Hi, and a random fortune. None of these tools are installed on YOUR machine."
    ask "How long would installing cowsay, figlet, fortune and lolcat take on Windows?"

    echo; echo "  ${BOLD}Demo 2 - Whack-a-bug: ship any app with one command${RESET}"
    p "Enter demo 2" "cd ../02-whack-a-bug" \
      "'..' means the parent folder, so this goes up one level and into the next demo." \
      "No output."
    p "Build the image" "docker build -t whack-a-bug ." \
      "Builds an nginx image with a small game page copied in." \
      "'naming to docker.io/library/whack-a-bug'."
    p "Run the game" "docker run -d -p 8080:80 --name game whack-a-bug" \
      "Starts the container in the background on port 8080." \
      "A container ID. Open http://localhost:8080 in your browser and click Start."
    ask "Did anyone install a web server?  (No. The image carries it.)"
    p "Stop the game" "docker rm -f game" \
      "Removes the container." \
      "The name 'game' is echoed back."

    echo; echo "  ${BOLD}Demo 3 - Scale me: one image, many copies${RESET}"
    p "Enter demo 3" "cd ../03-scale-me" \
      "Moves into the next demo." \
      "No output."
    p "Build the image" "docker build -t scale-me ." \
      "Builds a small Python web app image." \
      "'naming to docker.io/library/scale-me'."
    p "Start copy 1" "docker run -d -p 8001:8000 --name app1 scale-me" \
      "Starts a container; your port 8001 maps to port 8000 inside." \
      "A container ID."
    p "Start copy 2" "docker run -d -p 8002:8000 --name app2 scale-me" \
      "Same image, new container, different outside port." \
      "A container ID."
    p "Start copy 3" "docker run -d -p 8003:8000 --name app3 scale-me" \
      "A third container from the same image." \
      "A container ID."
    p "Check all three" "docker ps" \
      "Lists running containers." \
      "app1, app2 and app3, all from the image 'scale-me'. Open localhost:8001, 8002 and 8003: three colours."
    p "Ask each copy who it is" "curl -s localhost:8001 | grep -o 'container: [a-z0-9]*'" \
      "curl -s fetches quietly; grep -o prints only the matching part, the container's hostname." \
      "A line like 'container: 3f9a1c2b7d4e'. Try ports 8002 and 8003 and compare."
    p "Kill one copy" "docker rm -f app2" \
      "Removes app2 while the others keep running." \
      "The name 'app2' is echoed back."
    p "The others still work" "curl -s -o /dev/null -w '%{http_code}\n' localhost:8001" \
      "Sends a request and prints only the HTTP status code (-o /dev/null throws away the page)." \
      "200"
    ask "It's a Big Billion Days sale: how do you handle 10x traffic?  (Start more copies of the same image.)"
    p "Clean up the copies" "docker rm -f app1 app3" \
      "Removes the remaining containers." \
      "app1 and app3 are echoed back."

    echo; echo "  ${BOLD}Demo 4 - Time machine: 'works on my machine', solved${RESET}"
    p "Enter demo 4" "cd ../04-time-machine" \
      "Moves into the last demo." \
      "No output."
    p "Build with Python 3.8" "docker build -t pytime:old --build-arg PY_VERSION=3.8 ." \
      "--build-arg sets a variable the Dockerfile reads (ARG PY_VERSION) to choose which Python base image to use." \
      "'naming to docker.io/library/pytime:old'."
    p "Run the OLD environment" "docker run --rm -t pytime:old" \
      "Runs the same app.py inside the Python 3.8 world." \
      "'Running on Python 3.8.x' and 'Legacy Python: no match/case...'."
    p "Build with Python 3.13" "docker build -t pytime:new --build-arg PY_VERSION=3.13 ." \
      "Same code, different base image." \
      "'naming to docker.io/library/pytime:new'."
    p "Run the NEW environment" "docker run --rm -t pytime:new" \
      "Runs the same app.py inside Python 3.13." \
      "'Running on Python 3.13.x' and 'Modern Python...'. The code did not change, only the environment did."
    ask "Your laptop has 3.13, the server has 3.8. What happens on deploy day?  (With Docker, the image carries its own Python, so nothing breaks.)"

    part "PART E: Git + Docker - tag images with the commit ID (slide 43)"
    p "Return to the lab root" "cd $LAB" \
      "Goes to the lab folder, which is your Git repository." \
      "No output."
    if [ -d "$LAB/.git" ]; then
        note "Tagging every image with the Git commit ID means each image can be traced to the exact code that built it. Rollback = redeploy the previous tag."
        p "Show the current short commit ID" "git rev-parse --short HEAD" \
          "Prints the short ID of the latest commit." \
          "A 7-character ID such as 4a7b3d2."
        p "Build an image tagged with that ID" 'docker build -t scale-me:$(git rev-parse --short HEAD) 03-scale-me' \
          "\$(...) is replaced by the command's output, so the tag becomes the commit ID. The last word, 03-scale-me, is the build folder." \
          "'naming to docker.io/library/scale-me:<commit-id>'."
        p "See the commit-ID tag" "docker images scale-me" \
          "Lists the tags of scale-me." \
          "A tag equal to your commit ID next to 'latest'."
    else
        note "Skipping the commit-ID tag demo: the lab is not a Git repo yet. Run section 4 first, then repeat this part."
    fi
    p "Back to the training folder" "cd $ROOT" \
      "Leaves the lab." \
      "No output."
}

# ==============================================================================
#  SECTION 6 - IMAGE OPTIMIZATION  (deck slides 44-48)
# ==============================================================================
sec6() {
    cd "$ROOT" || exit 1
    ensure_lab
    qrm opt-slim go-api
    section "6. IMAGE OPTIMIZATION  (deck slides 44-48)" \
            "Why ship 1 GB when 150 MB does the same job? Slim base, layer cache, --no-cache-dir, multi-stage builds"
    note "Slide 45: smaller base image, smart layer order, only needed dependencies, multi-stage builds."
    ask "Your image is 1 GB and you deploy to 50 servers. How much data moves on every release?  (50 GB)"

    p "Enter the optimize lab" "cd docker-fun-lab/05-optimize-me" \
      "Moves into a small Flask web app that we will package two different ways." \
      "No output."
    p "List the files" "ls -a" \
      "-a also shows hidden files such as .dockerignore." \
      "app.py, requirements.txt, three Dockerfiles (fat, slim, secure) and .dockerignore."
    p "BEFORE: read the fat Dockerfile" "cat Dockerfile.fat" \
      "The 'wasteful' version: full python image, and 'COPY . .' copies everything BEFORE pip install." \
      "FROM python:3.12 (large) and COPY . . on line 3."
    p "AFTER: read the slim Dockerfile" "cat Dockerfile.slim" \
      "The 'optimized' version: slim base, requirements.txt copied first, pip install --no-cache-dir, and the code copied last." \
      "FROM python:3.12-slim, COPY requirements.txt first, then COPY app.py."
    p "Read the .dockerignore" "cat .dockerignore" \
      "Lists files Docker must NOT send into the build, so images stay small and builds stay fast." \
      "Entries like .git, __pycache__ and *.pyc."

    part "Build both and compare"
    p "BUILD the fat image" "docker build -f Dockerfile.fat -t optimize:fat ." \
      "-f chooses which Dockerfile to use (the default name is just 'Dockerfile')." \
      "A long build; it downloads the large python:3.12 image."
    p "BUILD the slim image" "docker build -f Dockerfile.slim -t optimize:slim ." \
      "Same app, different Dockerfile." \
      "A shorter build."
    p "COMPARE the sizes" "docker images optimize" \
      "Lists both images side by side." \
      "optimize:fat is around 1 GB and optimize:slim around 150 MB. The app is identical; only the Dockerfile changed."
    p "Compare the base images themselves" "docker images python" \
      "Lists the Python base images stored locally." \
      "python:3.12 is several times bigger than python:3.12-slim."
    p "See the layers of the slim image" "docker history optimize:slim" \
      "Shows each layer and its size." \
      "The pip install layer is small because --no-cache-dir left no download files."

    part "Layer caching: edit the code and rebuild"
    p "Build slim again with no changes" "docker build -f Dockerfile.slim -t optimize:slim ." \
      "Docker reuses every layer whose inputs did not change." \
      "Every step says CACHED, and it finishes almost instantly."
    p "Make a small change in the code" "echo '# small change' >> app.py" \
      "Appends a comment line to app.py." \
      "No output."
    p "Rebuild FAT" "docker build -f Dockerfile.fat -t optimize:fat ." \
      "'COPY . .' includes app.py, so its layer changed and every later step, including pip install, runs again." \
      "'RUN pip install ...' is re-executed (not CACHED)."
    p "Rebuild SLIM" "docker build -f Dockerfile.slim -t optimize:slim ." \
      "Only the final COPY app.py layer changed. The expensive pip install layer comes earlier, so it is reused." \
      "'RUN pip install' says CACHED; only COPY app.py is rebuilt. Much faster."

    part "Bonus: run as a non-root user (slide 45 notes)"
    p "Build the secure variant" "docker build -f Dockerfile.secure -t optimize:secure ." \
      "This Dockerfile adds a normal user (useradd) and switches to it with USER." \
      "'naming to docker.io/library/optimize:secure'."
    p "Which user runs the app?" "docker run --rm optimize:secure whoami" \
      "Prints the user name the container's process runs as." \
      "'appuser' (not root). If the app is ever hacked, the attacker has fewer rights."
    p "Run the app" "docker run -d --name opt-slim -p 5000:5000 -e APP_NAME=MyDemo optimize:secure" \
      "-e sets an environment variable inside the container; the app reads APP_NAME for its greeting." \
      "A container ID."
    p "Test the app" "curl http://localhost:5000" \
      "Calls the Flask app." \
      "'Hello from MyDemo app'."
    p "Test the health endpoint" "curl http://localhost:5000/health" \
      "A /health URL is a common way for tools to check an app is alive." \
      "'OK'."
    p "Remove the container" "docker rm -f opt-slim" \
      "Cleans up." \
      "The name is echoed back."
    p "See how much disk Docker uses" "docker system df" \
      "Summarizes disk used by images, containers, volumes and build cache." \
      "A table with TOTAL, ACTIVE, SIZE and RECLAIMABLE."

    part "Multi-stage builds (slides 47-48)"
    note "Two FROM lines in one Dockerfile: stage 1 builds with the compiler; stage 2 receives ONLY the compiled program."
    p "Enter the Go project" "cd go-multistage" \
      "Moves into a tiny Go web server project." \
      "No output."
    p "Read the multi-stage Dockerfile" "cat Dockerfile" \
      "Stage 1 'AS builder' has the Go compiler and builds the program. Stage 2 starts from tiny Alpine and copies only the finished program with COPY --from=builder." \
      "Two FROM lines and one COPY --from=builder."
    p "BUILD it" "docker build -t go-api ." \
      "Runs both stages. The compiler stage is thrown away afterwards." \
      "Steps labelled 'builder' and then the final stage; ends with 'naming to docker.io/library/go-api'."
    p "Check the final size" "docker images go-api" \
      "Lists the go-api image." \
      "A very small SIZE (roughly 15 MB)."
    p "Compare with the compiler image" "docker images golang" \
      "The golang image is what a single-stage build would have shipped." \
      "golang:1.23-alpine is many times larger than go-api."
    p "Run the tiny image" "docker run -d --name go-api -p 8085:8080 go-api" \
      "Starts the Go server; your port 8085 maps to 8080 inside." \
      "A container ID."
    p "Test it" "curl http://localhost:8085" \
      "Calls the Go program." \
      "'Hello from a tiny Go container'."
    p "Clean up" "docker rm -f go-api" \
      "Removes the container." \
      "The name is echoed back."
    p "Remove unused dangling images" "docker image prune -f" \
      "Deletes untagged leftover images (for example old build layers). -f skips the confirmation." \
      "'Total reclaimed space: ...'."
    p "Back to the training folder" "cd $ROOT" \
      "Leaves the project." \
      "No output."
}

# ==============================================================================
#  SECTION 7 - WRAP-UP  (deck slides 49-51)
# ==============================================================================
sec7() {
    cd "$ROOT" || exit 1
    section "7. WRAP-UP  (deck slides 49-51)" \
            "Key takeaways, knowledge check, and cleaning up everything you created today"
    echo "  ${BOLD}If you remember only five things:${RESET}"
    echo "   1. Containers ship the environment with the code. That ends 'it works on my machine'."
    echo "   2. Containers share the host kernel; VMs don't."
    echo "   3. Image = template.  Container = running instance."
    echo "   4. Dockerfiles beat docker commit for real work."
    echo "   5. Small images are faster and safer."
    echo

    echo "${BOLD}  KNOWLEDGE CHECK${RESET}  (think first, then press a key to see the answer)"
    local -a Q A
    Q[1]="Q1. What is the difference between an image and a container?"
    A[1]="    An image is a read-only template; a container is a running instance of it."
    Q[2]="Q2. Why can a laptop run more containers than VMs?"
    A[2]="    Containers have no guest OS; they share the host kernel, so they use far less memory and disk."
    Q[3]="Q3. What does docker ps -a show that docker ps doesn't?"
    A[3]="    Stopped (exited) containers as well as running ones."
    Q[4]="Q4. Why is a Dockerfile better than docker commit?"
    A[4]="    It is written down, version-controlled, reviewable and rebuilds identically."
    Q[5]="Q5. What does COPY --from=builder do?"
    A[5]="    It copies only the named file from the builder stage, leaving compilers and source behind."
    local i
    for i in 1 2 3 4 5; do
        echo; echo "  ${YELLOW}${Q[$i]}${RESET}"
        read -n1 -s -r -p "  [press a key for the answer] "; echo
        echo "  ${GREEN}${A[$i]}${RESET}"
    done
    echo
    p "Q3 live: running containers only" "docker ps" \
      "Shows only running containers." \
      "Probably an empty list."
    p "Q3 live: ALL containers" "docker ps -a" \
      "Adds stopped containers to the list." \
      "Any containers that are left over from the labs."
    p "Final check: images" "docker images" \
      "Lists everything you built and downloaded today." \
      "myapp, whale-says, whack-a-bug, scale-me, pytime, optimize, go-api and the base images."
    p "Disk used by Docker" "docker system df" \
      "Summarizes Docker's disk usage." \
      "A table showing images as the biggest user of space."

    echo
    local ans
    read -r -p "  Clean up EVERYTHING created today (containers and practice images)? [y/N] " ans
    if [[ "${ans,,}" == "y" ]]; then
        qrm web web2 myapp-web layer-demo temp game app1 app2 app3 opt-slim go-api
        docker rmi whale-says whack-a-bug scale-me pytime:old pytime:new myapp:1.0 myapp:1.0.0 \
                   my-ubuntu:custom optimize:fat optimize:slim optimize:secure go-api >/dev/null 2>&1
        docker images --format '{{.Repository}}:{{.Tag}}' | grep '^scale-me:' | xargs -r docker rmi >/dev/null 2>&1
        [ -n "$DHUSER" ] && docker rmi "$DHUSER/myapp:1.0" >/dev/null 2>&1
        docker container prune -f >/dev/null 2>&1
        docker image prune -f >/dev/null 2>&1
        echo "  Cleaned up. Your lab files stay in $ROOT"
    fi
    echo
    echo "  ${CYAN}\"You learn it by breaking it.\"${RESET}  Day 1 complete. Any questions?"
}

# ==============================================================================
#  MAIN
# ==============================================================================
list_sections() {
    cat <<'EOF'
  1  Containers vs VMs        (quick proof: shared kernel, fast start)
  2  Docker fundamentals      (CLI, daemon, hello-world, volume, network)
  3  Container lifecycle      (create/start/pause/stop/rm + nginx lab)
  4  Git and GitHub           (clone, get the lab files, commit, branch, push)
  5  Docker images            (layers, Dockerfile, tag/push/pull, commit, 4 fun labs)
  6  Image optimization      (fat vs slim, cache, multi-stage)
  7  Wrap-up                  (takeaways, knowledge check, cleanup)
EOF
}

case "${1:-}" in
    -l|--list) list_sections; exit 0 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
esac

START="${1:-1}"
if ! [[ "$START" =~ ^[1-7]$ ]]; then
    echo "Section must be a number from 1 to 7. Use -l to list sections."
    exit 1
fi

clear
echo "${CYAN}============================================================${RESET}"
echo "${BOLD}  DOCKER DAY 1 WORKSHOP - GUIDED PRACTICE (Ubuntu)${RESET}"
echo "  Follows: Docker_Day1_Final.pptx"
echo "${CYAN}============================================================${RESET}"
cat <<'EOF'

  How this works:
   1. The script shows a STEP, what the command DOES, what to LOOK FOR,
      and the command to TYPE.
   2. Type the command exactly and press Enter.
   3. If you only press Enter, the script types it for you.
   4. After the output you can choose:
        R = Repeat the same command for practice
        N = Go to the Next step
        Q = Quit

  Sections:
EOF
list_sections
cat <<'EOF'

  Note: Git comes BEFORE Dockerfiles so you know how project files reach
  your machine. All lab files are stored in ~/docker-training/docker-fun-lab.
  Requirements: Docker Engine running, Git, curl, internet.
EOF
echo
pause

for tool in docker git curl; do
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

mkdir -p "$ROOT"
cd "$ROOT" || exit 1

for n in 1 2 3 4 5 6 7; do
    [ "$n" -ge "$START" ] && "sec$n"
done

finish
