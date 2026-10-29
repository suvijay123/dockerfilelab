# Capstone: containerize PollPoint

PollPoint is a live classroom poll. The trainer puts a question on the projector
with a QR code; everyone votes from their phone and the bars move live.

It's a real web app: a Flask web server, a SQLite database, a JSON API,
a health check, one-vote-per-phone cookies and live updates. Your job is to
put it in a container, keep its votes safe, and ship it.

```
07-pollpoint/
├── app.py              # the web app
├── templates/          # the pages (projector, phone, home)
├── requirements.txt    # flask, gunicorn, segno (QR codes)
├── .dockerignore
└── solution/Dockerfile # don't peek for 20 minutes!
```

## Step 1: Write the Dockerfile (20 min)

Create `Dockerfile` in this folder and fill the blanks. Every line uses
something you learned today.

```dockerfile
FROM ____________                 # a small Python base image
ENV APP_VERSION=1.0.0 DB_PATH=/data/pollpoint.db
WORKDIR /app
COPY ____________ .               # dependencies first (build cache)
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --create-home appuser && mkdir -p /data && chown appuser /data
USER ____________                 # never run as root
EXPOSE ____                       # look at app.py
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "4", "app:app"]
```

```bash
docker build -t pollpoint:1.0.0 .
```

## Step 2: Run it with a volume (10 min)

Find your laptop's IP address, so phones on the same Wi-Fi can reach you:

- Windows: `ipconfig` → "IPv4 Address"
- macOS: `ipconfig getifaddr en0`
- Linux: `hostname -I`

```bash
docker volume create pollpoint-data
docker run -d -p 8000:8000 --name pollpoint \
  -v pollpoint-data:/data \
  -e PUBLIC_URL=http://YOUR-IP:8000 \
  pollpoint:1.0.0
```

Open http://localhost:8000, create a poll and click **Create poll and present**.

## Step 3: Vote from real phones (10 min)

Put the present page on screen. Your neighbours scan the QR code and vote;
watch the bars move every two seconds. Try voting twice from the same phone.

If phones can't connect: they must be on the same Wi-Fi as your laptop, and
your firewall must allow port 8000. College Wi-Fi often blocks this; a phone
hotspot always works.

## Step 4: Prove the votes survive (5 min)

```bash
docker rm -f pollpoint
docker run -d -p 8000:8000 --name pollpoint \
  -v pollpoint-data:/data -e PUBLIC_URL=http://YOUR-IP:8000 pollpoint:1.0.0
docker ps                          # STATUS: (healthy) after ~30 s
curl http://localhost:8000/health
```

Your polls and votes are still there: they live in the volume, not the container.

## Step 5: Ship it (10 min)

```bash
git switch -c feature/pollpoint
git add Dockerfile
git commit -m "Containerize PollPoint"
git push -u origin feature/pollpoint      # then open a pull request

docker tag pollpoint:1.0.0 <you>/pollpoint:1.0.0
docker push <you>/pollpoint:1.0.0
```

## Bonus challenges

1. **Version 1.1.0:** run with `-e APP_VERSION=1.1.0` and look at the footer.
2. **Scale it:** start a second container on port 8001 with the *same* volume.
   Both show the same votes; the footer shows which container answered.
3. **Read the API:** open http://localhost:8000/api/polls/POLL-ID in a browser.
4. **Shrink it:** compare `docker images pollpoint` with `python:3.12`.

## Clean up

```bash
docker rm -f pollpoint
docker volume rm pollpoint-data
```
