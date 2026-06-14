#!/usr/bin/env python3
"""Register the bundle ID and create the App Store Connect app record (API-first).

Load .env first:  set -a; source .env; set +a
Then:             python3 scripts/asc_create_app.py
Prints the numeric app id on success.
"""
import json, os, subprocess, sys, urllib.error, urllib.request

BASE = "https://api.appstoreconnect.apple.com"
JWT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", ".agents", "skills", "app-store-submission", "scripts", "asc_jwt.swift")

BUNDLE = os.environ["ASC_BUNDLE_ID"]
SKU = os.environ.get("ASC_SKU", "AI4KIDS001")
NAME_CANDIDATES = [n for n in [
    os.environ.get("ASC_APP_NAME"), "AI4Kids", "AI4Kids Academy",
    "AI4Kids Learn and Play", "AI4Kids Kids Learning"] if n]


def token():
    out = subprocess.run(["swift", JWT], capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit("JWT error: " + out.stderr.strip())
    return out.stdout.strip()


TOK = token()


def call(method, path, body=None):
    req = urllib.request.Request(
        BASE + path, data=(json.dumps(body).encode() if body else None), method=method,
        headers={"Authorization": f"Bearer {TOK}", "Content-Type": "application/json"})
    try:
        r = urllib.request.urlopen(req)
        b = r.read().decode()
        return r.status, (json.loads(b) if b.strip().startswith(("{", "[")) else b)
    except urllib.error.HTTPError as e:
        b = e.read().decode()
        return e.code, (json.loads(b) if b.strip().startswith(("{", "[")) else b)


def ensure_bundle_id():
    s, d = call("GET", f"/v1/bundleIds?filter[identifier]={BUNDLE}&limit=1")
    if isinstance(d, dict) and d.get("data"):
        print("bundleId exists:", d["data"][0]["id"])
        return d["data"][0]["id"]
    body = {"data": {"type": "bundleIds", "attributes": {
        "identifier": BUNDLE, "name": "AI4Kids", "platform": "IOS"}}}
    s, d = call("POST", "/v1/bundleIds", body)
    if s >= 300:
        sys.exit(f"bundleId create failed {s}: {json.dumps(d)[:500]}")
    print("bundleId created:", d["data"]["id"])
    return d["data"]["id"]


def existing_app():
    s, d = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE}&limit=1")
    if isinstance(d, dict) and d.get("data"):
        return d["data"][0]["id"]
    return None


def create_app():
    for name in NAME_CANDIDATES:
        body = {"data": {"type": "apps", "attributes": {
            "name": name, "bundleId": BUNDLE, "primaryLocale": "en-US", "sku": SKU}}}
        s, d = call("POST", "/v1/apps", body)
        if s < 300:
            print(f"app created: name={name!r} id={d['data']['id']}")
            return d["data"]["id"]
        # Name collision → try next candidate; other errors → report and stop.
        txt = json.dumps(d)
        if "name" in txt.lower() and ("taken" in txt.lower() or "another app" in txt.lower() or "duplicate" in txt.lower()):
            print(f"  name {name!r} unavailable, trying next…")
            continue
        sys.exit(f"app create failed {s} for {name!r}: {txt[:700]}")
    sys.exit("all candidate names unavailable")


aid = existing_app()
if aid:
    print("app already exists:", aid)
else:
    ensure_bundle_id()
    aid = create_app()
print("APP_ID=" + aid)
