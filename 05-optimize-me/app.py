"""A tiny Flask app used to compare a FAT image with a SLIM image."""
import socket

from flask import Flask

app = Flask(__name__)


@app.get("/")
def hello():
    return {"message": "Same app, smaller box!", "container": socket.gethostname()}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
