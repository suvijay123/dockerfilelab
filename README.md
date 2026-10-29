# Docker fun lab: demos and labs for Docker Day 1

Each demo is a short, beginner-friendly Dockerfile with an output students can **see**.
Each one answers one question: *why do companies actually use this?*

| # | Demo | What students see | Why industry uses Docker |
|---|------|-------------------|--------------------------|
| 1 | `01-whale-says` | Rainbow ASCII banner + a whale saying a quote | **No setup.** Run tools you never installed. Delete them, laptop stays clean. |
| 2 | `02-whack-a-bug` | A playable browser game | **Ship any app with one command.** Web server + app packaged together. |
| 3 | `03-scale-me` | 3 browser tabs, 3 different colored containers | **Scale in seconds.** One image → many copies. Kill one, the rest keep running. |
| 4 | `04-time-machine` | Same code: 2/5 features on old Python, 5/5 on new | **"Works on my machine" — solved.** Pin exact versions so everyone gets the same result. |
| 5 | `05-optimize-me` | Same app as a ~1 GB image and a ~150 MB image; a 15 MB Go API | **Smaller images ship faster and safer.** Slim bases, layer order, multi-stage builds. |
| 6 | `06-capstone-feedback` | A feedback web app whose data survives deleting the container | **Real apps in containers.** Students write the Dockerfile; answer in `solution/`. |
| 7 | `07-pollpoint` | Live class poll: QR code on the projector, votes from phones, bars move live | **A real app, shipped.** Alternative capstone; guide in its README. |

Demos 5 and 6 are run step by step in the Day 1 lab handout (Labs 8.1, 8.2 and 9.1–9.3).

---

## Demo 1 · The whale says (no setup)

```bash
cd 01-whale-says
docker build -t whale-says .
docker run --rm -t whale-says
docker run --rm -t whale-says "Our workshop rocks"
cowsay hi        # on your laptop → command not found!
```
**Ask the room:** "How long would it take you to install these 4 tools on Windows?"

## Demo 2 · Whack-a-bug (ship an app)

```bash
cd ../02-whack-a-bug
docker build -t whack-a-bug .
docker run -d -p 8080:80 --name game whack-a-bug
```
Open **http://localhost:8080** and run a class high-score battle.
**Ask the room:** "Did anyone install or configure a web server?"

## Demo 3 · Scale me (scaling + resilience)

```bash
cd ../03-scale-me
docker build -t scale-me .
docker run -d -p 8001:8000 --name app1 scale-me
docker run -d -p 8002:8000 --name app2 scale-me
docker run -d -p 8003:8000 --name app3 scale-me
```
Open **localhost:8001**, **:8002** and **:8003**. Three colors, three containers, one image.
Then `docker rm -f app2` and refresh. Two still work.
**Ask the room:** "It's a Big Billion Days sale. How do you handle 10x traffic?"

## Demo 4 · Python time machine ("works on my machine")

```bash
cd ../04-time-machine
docker build --build-arg PY_VERSION=3.8  -t pytime:old .
docker build --build-arg PY_VERSION=3.13 -t pytime:new .
docker run --rm -t pytime:old
docker run --rm -t pytime:new
```
**Ask the room:** "Your laptop has 3.13, the server has 3.8. What happens on deploy day?"

---

## Before the workshop

- Build all images once at home. The first build downloads base images (needs internet).
- On venue Wi-Fi, have students pull the base images early:
  `docker pull debian:bookworm-slim nginx:alpine python:3.12-slim python:3.8-slim python:3.13-slim`
- `-t` in `docker run` gives colored output. On Windows, use Windows Terminal or PowerShell 7.

## Clean up everything

```bash
docker rm -f game app1 app2 app3
docker rmi whale-says whack-a-bug scale-me pytime:old pytime:new
```
