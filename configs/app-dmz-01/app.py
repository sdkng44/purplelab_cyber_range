from flask import Flask, request, jsonify, make_response, render_template_string, Response
import logging
import os
import re
import socket
import subprocess
import json
from pathlib import Path
from werkzeug.exceptions import NotFound, MethodNotAllowed

APP = Flask(__name__)

LOG_DIR = Path("/var/log/purple-web")
LOG_DIR.mkdir(parents=True, exist_ok=True)

ACCESS_LOG = LOG_DIR / "access.log"
AUTH_LOG = LOG_DIR / "auth.log"
ERROR_LOG = LOG_DIR / "error.log"
APP_JSON_LOG = LOG_DIR / "app.json"

VALID_USER = os.getenv("WEBAPP_USER", "webanalyst")
VALID_PASS = os.getenv("WEBAPP_PASS", "WebAnalyst123!")

INTERNAL_HOSTS = {
    "app-int.corp.lab",
    "10.10.50.20",
    "localhost",
    "127.0.0.1",
}

POOL_GROUP = os.getenv("PURPLE_POOL_GROUP", "s13-flow")
SUPPORT_PATH = os.getenv("PURPLE_SUPPORT_PATH", "/support/diagnostics")
CALDERA_URL = os.getenv("CALDERA_URL", "http://192.168.56.10:8888")

APPDMZ_S13_GROUP = os.getenv("APPDMZ_S13_GROUP", "s13-flow")
APPDMZ_S13_PAW = os.getenv("APPDMZ_S13_PAW", "app-dmz-01-s13")

POOL_NODE_IP_PREFIX = os.getenv("POOL_NODE_IP_PREFIX", "10.10.50.")
POOL_NODE_RANGE_START = int(os.getenv("POOL_NODE_RANGE_START", "101"))
POOL_NODE_RANGE_END = int(os.getenv("POOL_NODE_RANGE_END", "199"))
POOL_NODE_SSH_PORT = int(os.getenv("POOL_NODE_SSH_PORT", "22"))

POOL_NODE_NAME_RE = re.compile(r"^pool-node-[0-9]+$")
APP_TITLE = os.getenv("PURPLE_APP_TITLE", "Purple Corporation Portal")

def build_logger(name: str, path: Path, level: int = logging.INFO, fmt: str = "%(asctime)s %(message)s") -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(level)
    logger.propagate = False
    if not logger.handlers:
        handler = logging.FileHandler(path)
        formatter = logging.Formatter(fmt)
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    return logger


access_logger = build_logger("purple_access", ACCESS_LOG, logging.INFO)
auth_logger = build_logger("purple_auth", AUTH_LOG, logging.INFO)
error_logger = build_logger("purple_error", ERROR_LOG, logging.ERROR)
app_logger = build_logger("purple_app_json", APP_JSON_LOG, logging.INFO, "%(message)s")


def log_app_event(event_type: str, **kwargs):
    payload = {"event": event_type}
    payload.update(kwargs)
    app_logger.info(json.dumps(payload, ensure_ascii=False))


def client_ip() -> str:
    return request.headers.get("X-Forwarded-For", request.remote_addr)


def user_agent() -> str:
    return request.headers.get("User-Agent", "-")


def request_host() -> str:
    return request.host.lower()

def request_host_name() -> str:
    return request.host.split(":", 1)[0].lower()

def is_internal_request() -> bool:
    host = request_host_name()
    return host in INTERNAL_HOSTS


BASE_HTML = """
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>{{ title }}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
      body {
        margin: 0;
        font-family: Arial, sans-serif;
        background: #f4f6f8;
        color: #1f2937;
      }
      .topbar {
        background: #1f3a5f;
        color: white;
        padding: 14px 24px;
      }
      .topbar h1 {
        margin: 0;
        font-size: 22px;
      }
      .topbar small {
        color: #d7e3f3;
      }
      .nav {
        background: #294d78;
        padding: 10px 24px;
      }
      .nav a {
        color: white;
        margin-right: 18px;
        text-decoration: none;
        font-size: 14px;
      }
      .container {
        max-width: 1100px;
        margin: 24px auto;
        padding: 0 20px;
      }
      .grid {
        display: grid;
        grid-template-columns: 2fr 1fr;
        gap: 20px;
      }
      .card {
        background: white;
        border-radius: 8px;
        padding: 20px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      }
      .hero {
        background: linear-gradient(135deg, #1f3a5f, #365f93);
        color: white;
      }
      .hero h2 {
        margin-top: 0;
      }
      .hero p {
        color: #e7eef8;
      }
      .pill {
        display: inline-block;
        background: #e8eef7;
        color: #234;
        padding: 6px 10px;
        border-radius: 999px;
        font-size: 12px;
        margin-right: 6px;
      }
      .notice {
        padding: 10px 12px;
        margin-bottom: 10px;
        border-left: 4px solid #365f93;
        background: #f7faff;
      }
      .footer {
        color: #64748b;
        font-size: 13px;
        text-align: center;
        padding: 25px;
      }
      table {
        width: 100%;
        border-collapse: collapse;
      }
      th, td {
        text-align: left;
        padding: 10px;
        border-bottom: 1px solid #e5e7eb;
      }
      input[type=text], input[type=password] {
        width: 100%;
        padding: 10px;
        margin: 6px 0 14px 0;
        border: 1px solid #cbd5e1;
        border-radius: 6px;
      }
      button {
        background: #1f3a5f;
        color: white;
        border: 0;
        padding: 10px 14px;
        border-radius: 6px;
        cursor: pointer;
      }
      .search-box {
        display: flex;
        gap: 8px;
      }
      .search-box input {
        flex: 1;
      }
      code {
        background: #eef2f7;
        padding: 2px 5px;
        border-radius: 4px;
      }
      @media (max-width: 900px) {
        .grid {
          grid-template-columns: 1fr;
        }
      }
    </style>
  </head>
  <body>
    <div class="topbar">
      <h1>{{ title }}</h1>
      <small>Corporate intranet services portal</small>
    </div>
    <div class="nav">
      <a href="/">Home</a>
      <a href="/login">Login</a>
      <a href="/announcements">Announcements</a>
      <a href="/departments">Departments</a>
      <a href="/search?q=printer">Search</a>
    </div>
    <div class="container">
      {{ body|safe }}
    </div>
    <div class="footer">
      Purple Corporation Portal · Internal Services · Status OK
    </div>
  </body>
</html>
"""


@APP.after_request
def log_request(response):
    access_logger.info(
        'src_ip="%s" host="%s" method="%s" path="%s" status=%s user_agent="%s"',
        client_ip(),
        request.host,
        request.method,
        request.full_path.rstrip("?"),
        response.status_code,
        user_agent(),
    )
    return response


@APP.get("/favicon.ico")
def favicon():
    return ("", 204)


@APP.errorhandler(NotFound)
def handle_not_found(exc):
    return make_response(jsonify({"status": "error", "message": "not found"}), 404)


@APP.errorhandler(MethodNotAllowed)
def handle_method_not_allowed(exc):
    return make_response(jsonify({"status": "error", "message": "method not allowed"}), 405)


@APP.errorhandler(Exception)
def handle_error(exc):
    error_logger.exception('unhandled_exception path="%s" error="%s"', request.path, str(exc))
    return make_response(jsonify({"status": "error", "message": "internal server error"}), 500)


@APP.get("/")
def index():
    if request.accept_mimetypes.best == "application/json":
        return jsonify({
            "application": "purple-web",
            "status": "ok",
            "login": "/login",
            "search": "/search?q=test",
            "announcements": "/announcements",
            "departments": "/departments",
        }), 200

    body = """
    <div class="grid">
      <div class="card hero">
        <h2>Welcome to the Purple Corporation Portal</h2>
        <p>Access internal resources, department notices, and service shortcuts from a single place.</p>
        <span class="pill">HR</span>
        <span class="pill">Operations</span>
        <span class="pill">Field Services</span>
        <span class="pill">IT Support</span>
      </div>

      <div class="card">
        <h3>Quick Search</h3>
        <form class="search-box" method="GET" action="/search">
          <input type="text" name="q" placeholder="Search docs, teams, services">
          <button type="submit">Search</button>
        </form>
        <p><small>Examples: printer, directory, proxy, files, onboarding</small></p>
      </div>

      <div class="card">
        <h3>Announcements</h3>
        <div class="notice"><strong>Operations:</strong> Weekly maintenance window on Thursday 22:00 UTC.</div>
        <div class="notice"><strong>HR:</strong> Q3 travel approval workflow updated.</div>
        <div class="notice"><strong>IT:</strong> Proxy and print services remain available during patching.</div>
      </div>

      <div class="card">
        <h3>Service Directory</h3>
        <table>
          <tr><th>Service</th><th>Status</th></tr>
          <tr><td>Employee Login</td><td>Available</td></tr>
          <tr><td>Document Search</td><td>Available</td></tr>
          <tr><td>Print Services</td><td>Available</td></tr>
          <tr><td>Directory Services</td><td>Available</td></tr>
          <tr><td>Proxy Access</td><td>Available</td></tr>
        </table>
      </div>
    </div>
    """
    return render_template_string(BASE_HTML, title=APP_TITLE, body=body), 200


@APP.get("/login")
def login_form():
    body = """
    <div class="card" style="max-width: 480px; margin: 0 auto;">
      <h2>Employee Login</h2>
      <form method="POST" action="/login">
        <label>Username</label>
        <input type="text" name="username" placeholder="username">
        <label>Password</label>
        <input type="password" name="password" placeholder="password">
        <button type="submit">Sign in</button>
      </form>
      <p><small>Authorized personnel only. All access is monitored.</small></p>
    </div>
    """
    return render_template_string(BASE_HTML, title=f"{APP_TITLE} · Login", body=body), 200


@APP.post("/login")
def login():
    username = request.form.get("username", "")
    password = request.form.get("password", "")
    src_ip = client_ip()

    if username == VALID_USER and password == VALID_PASS:
        auth_logger.info(
            'event="login_success" src_ip="%s" username="%s" user_agent="%s"',
            src_ip,
            username,
            user_agent(),
        )
        return jsonify({"status": "ok", "message": "login successful"}), 200

    auth_logger.info(
        'event="login_failed" src_ip="%s" username="%s" user_agent="%s"',
        src_ip,
        username,
        user_agent(),
    )
    return jsonify({"status": "fail", "message": "invalid credentials"}), 401


@APP.get("/announcements")
def announcements():
    data = [
        {"title": "Field Services Coordination", "owner": "Operations", "priority": "medium"},
        {"title": "Directory Service Maintenance", "owner": "IT", "priority": "low"},
        {"title": "Printer Queue Review", "owner": "Facilities", "priority": "low"},
        {"title": "Proxy Usage Reminder", "owner": "Security", "priority": "medium"},
    ]
    log_app_event("announcements_view", src_ip=client_ip(), path="/announcements", user_agent=user_agent())
    return jsonify({"status": "ok", "items": data}), 200


@APP.get("/departments")
def departments():
    departments_data = [
        {"name": "Operations", "code": "OPS"},
        {"name": "Field Services", "code": "FS"},
        {"name": "Information Technology", "code": "IT"},
        {"name": "Human Resources", "code": "HR"},
    ]
    log_app_event("departments_view", src_ip=client_ip(), path="/departments", user_agent=user_agent())
    return jsonify({"status": "ok", "departments": departments_data}), 200


@APP.get("/search")
def search():
    q = request.args.get("q", "").strip().lower()

    log_app_event(
        "search_request",
        src_ip=client_ip(),
        path="/search",
        query=q,
        user_agent=user_agent()
    )

    results = []

    if q:
        if "printer" in q or "print" in q:
            results.append({
                "title": "Printer Services",
                "summary": "Corporate print services and queue visibility",
                "path": "print.corp.lab",
            })
        if "directory" in q or "ldap" in q:
            results.append({
                "title": "Directory Services",
                "summary": "Internal identity and directory lookup services",
                "path": "ldap.corp.lab",
            })
        if "proxy" in q:
            results.append({
                "title": "Proxy Access",
                "summary": "HTTP proxy service for internal workloads",
                "path": "proxy.corp.lab:3128",
            })
        if "file" in q or "share" in q:
            results.append({
                "title": "Shared Files",
                "summary": "Internal file distribution and SMB resources",
                "path": "files.corp.lab",
            })
        if "field" in q or "operations" in q:
            results.append({
                "title": "Field Operations Coordination",
                "summary": "Internal coordination records for field access planning",
                "path": "/announcements",
            })

    return jsonify({
        "status": "ok",
        "query": q,
        "results": results
    }), 200


@APP.get("/robots.txt")
def robots():
    body = "User-agent: *\nDisallow: /support/\nAllow: /\n"
    return make_response(body, 200, {"Content-Type": "text/plain"})


@APP.get("/api/info")
def api_info():
    if not is_internal_request():
        return jsonify({"status": "error", "message": "not found"}), 404
    payload = {
        "application": "purple-web",
        "status": "ok",
        "service": "purple-pool-agent-gateway",
        "node": "core-pool",
        "bootstrap_hint": SUPPORT_PATH,
    }
    log_app_event("api_info_view", src_ip=client_ip(), host=request.host, path="/api/info")
    return jsonify(payload), 200

@APP.get("/support/diagnostics")
def support_diagnostics_info():
    if not is_internal_request():
        return jsonify({"status": "error", "message": "not found"}), 404

    payload = {
        "status": "ok",
        "module": "ops-gateway",
        "scope": "core-pool",
        "action": "refresh",
        "parameter": "target",
        "notes": "internal diagnostic interface",
    }
    log_app_event(
        "support_diagnostics_view",
        src_ip=client_ip(),
        host=request.host,
        path=request.path,
    )
    return jsonify(payload), 200


@APP.post("/support/diagnostics")
def support_diagnostics_run():
    if not is_internal_request():
        return jsonify({"status": "error", "message": "not found"}), 404

    module = request.form.get("module", "")
    scope = request.form.get("scope", "")
    action = request.form.get("action", "")
    target = request.form.get("target", "127.0.0.1")

    log_app_event(
        "support_diagnostics_request",
        src_ip=client_ip(),
        host=request.host,
        path=request.path,
        module=module,
        scope=scope,
        action=action,
        target=target,
    )

    if module == "ops-gateway" and scope == "core-pool" and action == "refresh":
        # Deliberately vulnerable for lab use: unsafely passes user-controlled
        # target into a shell-based diagnostic command.
        cmd = f"getent hosts {target}"

        try:
            result = subprocess.run(
                ["bash", "-lc", cmd],
                capture_output=True,
                text=True,
                timeout=45,
            )

            output = (result.stdout or "") + (result.stderr or "")
            log_app_event(
                "support_diagnostics_execution",
                src_ip=client_ip(),
                module=module,
                scope=scope,
                action=action,
                target=target,
                returncode=result.returncode,
                output=output.strip(),
            )

            return Response(output if output else "diagnostic completed\n", mimetype="text/plain", status=200)

        except Exception as exc:
            log_app_event(
                "support_diagnostics_exception",
                src_ip=client_ip(),
                error=str(exc),
            )
            return Response("diagnostic failed\n", mimetype="text/plain", status=200)

    return jsonify({
        "status": "ok",
        "message": "diagnostic completed",
        "module": module,
        "scope": scope,
        "action": action,
    }), 200


if __name__ == "__main__":
    APP.run(host="0.0.0.0", port=8080)
