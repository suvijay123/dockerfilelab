"""Campus Feedback Board: a small but real web app.

Flask web app + SQLite database + JSON API + health check.
Students containerize this in the capstone lab.
"""
import os
import socket
import sqlite3

from flask import Flask, jsonify, redirect, render_template, request

DB_PATH = os.getenv("DB_PATH", "data/feedback.db")
APP_VERSION = os.getenv("APP_VERSION", "dev")

app = Flask(__name__)


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    folder = os.path.dirname(DB_PATH)
    if folder:
        os.makedirs(folder, exist_ok=True)
    with get_db() as conn:
        conn.execute(
            """CREATE TABLE IF NOT EXISTS feedback (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   name TEXT NOT NULL,
                   message TEXT NOT NULL,
                   rating INTEGER NOT NULL,
                   created TEXT DEFAULT CURRENT_TIMESTAMP
               )"""
        )


@app.get("/")
def index():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM feedback ORDER BY id DESC").fetchall()
    avg = round(sum(r["rating"] for r in rows) / len(rows), 1) if rows else 0
    return render_template(
        "index.html",
        rows=rows,
        avg=avg,
        version=APP_VERSION,
        container=socket.gethostname(),
    )


@app.post("/feedback")
def add_feedback():
    name = request.form.get("name", "").strip() or "Anonymous"
    message = request.form.get("message", "").strip()
    rating = int(request.form.get("rating", 5))
    if message:
        with get_db() as conn:
            conn.execute(
                "INSERT INTO feedback (name, message, rating) VALUES (?, ?, ?)",
                (name[:40], message[:280], max(1, min(rating, 5))),
            )
    return redirect("/")


@app.get("/api/feedback")
def api_feedback():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM feedback ORDER BY id DESC").fetchall()
    return jsonify([dict(r) for r in rows])


@app.get("/health")
def health():
    return {"status": "ok", "version": APP_VERSION}


init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
