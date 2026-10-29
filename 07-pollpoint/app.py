"""PollPoint: live classroom polls with a QR code to join.

The trainer creates a poll and puts the "present" page on the projector.
Students scan the QR code with their phones, vote, and the bars move live.

Stack: Flask + SQLite + gunicorn. Data lives in DB_PATH (a Docker volume).
"""
import os
import socket
import sqlite3
import uuid

from flask import Flask, abort, jsonify, make_response, redirect, render_template, request

try:  # QR codes need the "segno" package (installed by requirements.txt)
    import segno
except ImportError:  # the app still works without it, just without the QR image
    segno = None

DB_PATH = os.getenv("DB_PATH", "data/pollpoint.db")
APP_VERSION = os.getenv("APP_VERSION", "dev")
PUBLIC_URL = os.getenv("PUBLIC_URL", "").rstrip("/")  # e.g. http://192.168.1.20:8000

app = Flask(__name__)


# ---------- database ----------
def db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    folder = os.path.dirname(DB_PATH)
    if folder:
        os.makedirs(folder, exist_ok=True)
    with db() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS polls (
                id TEXT PRIMARY KEY,
                question TEXT NOT NULL,
                created TEXT DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE IF NOT EXISTS options (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                poll_id TEXT NOT NULL,
                label TEXT NOT NULL,
                votes INTEGER NOT NULL DEFAULT 0
            );
            """
        )


def get_poll(poll_id):
    with db() as conn:
        poll = conn.execute("SELECT * FROM polls WHERE id = ?", (poll_id,)).fetchone()
        if not poll:
            abort(404)
        options = conn.execute(
            "SELECT * FROM options WHERE poll_id = ? ORDER BY id", (poll_id,)
        ).fetchall()
    return poll, options


def results(options):
    total = sum(o["votes"] for o in options)
    return total, [
        {
            "id": o["id"],
            "label": o["label"],
            "votes": o["votes"],
            "percent": round(100 * o["votes"] / total) if total else 0,
        }
        for o in options
    ]


# ---------- pages ----------
@app.context_processor
def footer_info():
    # Shown on every page: proves which container answered (try scaling!)
    return {"version": APP_VERSION, "container": socket.gethostname()}


@app.get("/")
def home():
    with db() as conn:
        polls = conn.execute(
            """SELECT p.id, p.question, COALESCE(SUM(o.votes), 0) AS total
               FROM polls p LEFT JOIN options o ON o.poll_id = p.id
               GROUP BY p.id ORDER BY p.created DESC"""
        ).fetchall()
    return render_template("home.html", polls=polls)


@app.post("/polls")
def create_poll():
    question = request.form.get("question", "").strip()[:140]
    labels = [l.strip()[:60] for l in request.form.getlist("option") if l.strip()]
    if not question or len(labels) < 2:
        return redirect("/?error=1")
    poll_id = uuid.uuid4().hex[:6]
    with db() as conn:
        conn.execute("INSERT INTO polls (id, question) VALUES (?, ?)", (poll_id, question))
        conn.executemany(
            "INSERT INTO options (poll_id, label) VALUES (?, ?)",
            [(poll_id, label) for label in labels[:6]],
        )
    return redirect(f"/p/{poll_id}/present")


@app.get("/p/<poll_id>/present")
def present(poll_id):
    poll, options = get_poll(poll_id)
    base = PUBLIC_URL or request.host_url.rstrip("/")
    vote_url = f"{base}/p/{poll_id}"
    qr_svg = None
    if segno:
        qr_svg = segno.make(vote_url, error="m").svg_inline(
            scale=8, border=2, dark="#0b1020", light="#ffffff"
        )
    on_localhost = "localhost" in base or "127.0.0.1" in base
    return render_template(
        "present.html", poll=poll, vote_url=vote_url, qr_svg=qr_svg, on_localhost=on_localhost
    )


@app.get("/p/<poll_id>")
def vote_page(poll_id):
    poll, options = get_poll(poll_id)
    if request.cookies.get(f"voted_{poll_id}"):
        return render_template("voted.html", poll=poll)
    return render_template("vote.html", poll=poll, options=options)


@app.post("/p/<poll_id>/vote")
def vote(poll_id):
    get_poll(poll_id)
    if request.cookies.get(f"voted_{poll_id}"):  # one vote per phone
        return redirect(f"/p/{poll_id}")
    option_id = request.form.get("option", type=int)
    with db() as conn:
        conn.execute(
            "UPDATE options SET votes = votes + 1 WHERE id = ? AND poll_id = ?",
            (option_id, poll_id),
        )
    resp = make_response(redirect(f"/p/{poll_id}"))
    resp.set_cookie(f"voted_{poll_id}", "1", max_age=60 * 60 * 24, samesite="Lax")
    return resp


# ---------- API ----------
@app.get("/api/polls/<poll_id>")
def api_poll(poll_id):
    poll, options = get_poll(poll_id)
    total, rows = results(options)
    return jsonify({"id": poll["id"], "question": poll["question"], "total": total, "options": rows})


@app.get("/health")
def health():
    return {"status": "ok", "version": APP_VERSION}


init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
