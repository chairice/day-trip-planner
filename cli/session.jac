"""CLI session: server address and the signed-in user's token.

The token is the same one the web and mobile apps get from `/user/login`;
it is stored in ~/.daytrip/session.json and attached to every bridged
walker call so the CLI acts on the same user graph.
"""

import json;
import os;
import sys;
import urllib.error;
import urllib.request;
import from pathlib { Path }

glob SESSION_FILE: Path = Path.home() / ".daytrip" / "session.json",
     DEFAULT_SERVER: str = "http://localhost:8000",
     PROVIDER_APP: str = "web";

def warn(text: str) {
    print(text, file=sys.stderr);
}

def server_url -> str {
    return (os.environ.get("DAYTRIP_SERVER", "") or DEFAULT_SERVER).rstrip("/");
}

def load_session -> dict[str, str] {
    try {
        return json.loads(SESSION_FILE.read_text());
    } except Exception {
        return {};
    }
}

def save_session(data: dict[str, str]) {
    SESSION_FILE.parent.mkdir(parents=True, exist_ok=True);
    SESSION_FILE.write_text(json.dumps(data));
    os.chmod(SESSION_FILE, 0o600);
}

def clear_session {
    if SESSION_FILE.exists() {
        SESSION_FILE.unlink();
    }
}

class ServerError(Exception) {}

"""Signed-in check before calling walkers."""
def connect -> bool {
    if not load_session().get("token", "") {
        warn("daytrip: not signed in. Run: jac run cli -- login <username>");
        return False;
    }
    return True;
}

"""Run a walker on the server as the signed-in user; returns its reports."""
def call(name: str, args: dict[str, any] | None = None) -> list[any] {
    token = load_session().get("token", "");
    req = urllib.request.Request(
        server_url() + "/api/trips/walker/" + name,
        data=json.dumps(args or {}).encode(),
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + token},
        method="POST"
    );
    try {
        with urllib.request.urlopen(req, timeout=180) as resp {
            body = json.loads(resp.read().decode() or "{}");
        }
    } except urllib.error.HTTPError as e {
        if e.code in [401, 403] {
            raise ServerError("session expired — run `login` again");
        }
        raise ServerError(f"HTTP {e.code}: {e.read().decode()[:200]}");
    } except urllib.error.URLError as e {
        raise ServerError(f"server not reachable at {server_url()} — start it with `jac run`");
    }
    data = body.get("data") or {};
    return data.get("reports") or [];
}

def post_json(path: str, body: dict[str, any]) -> dict[str, any] {
    req = urllib.request.Request(
        server_url() + path,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    );
    try {
        with urllib.request.urlopen(req, timeout=15) as resp {
            return json.loads(resp.read().decode() or "{}");
        }
    } except urllib.error.HTTPError as e {
        detail = e.read().decode();
        try {
            return {"ok": False, "error": json.loads(detail)};
        } except Exception {
            return {"ok": False, "error": detail or str(e)};
        }
    }
}

"""Find the session token anywhere in a login response."""
def find_token(data: any) -> str {
    if isinstance(data, dict) {
        for key in ["token", "access_token"] {
            if isinstance(data.get(key), str) and data[key] {
                return data[key];
            }
        }
        for v in data.values() {
            found = find_token(v);
            if found {
                return found;
            }
        }
    }
    return "";
}

def login(username: str, password: str) -> str {
    res = post_json(
        "/user/login",
        {
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": password}
        }
    );
    token = find_token(res);
    if token {
        save_session(
            {"server": server_url(), "username": username, "token": token}
        );
    }
    return token;
}

def register(username: str, password: str) -> dict[str, any] {
    return post_json(
        "/user/register",
        {
            "identities": [{"type": "username", "value": username}],
            "credential": {"type": "password", "password": password}
        }
    );
}
