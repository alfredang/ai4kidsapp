#!/usr/bin/env python3
"""Set AI4Kids version + app-info metadata and primary category (App Store Connect API).
Load .env first:  set -a; source .env; set +a
"""
import json, os, subprocess, sys, urllib.error, urllib.request

BASE = "https://api.appstoreconnect.apple.com"
JWT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", ".agents", "skills", "app-store-submission", "scripts", "asc_jwt.swift")
TOK = subprocess.run(["swift", JWT], capture_output=True, text=True).stdout.strip()
AID = os.environ["ASC_APP_ID"]

SUBTITLE = "Fun AI learning for kids"
PROMO = ("Four playful, fully offline learning activities for kids — phonics, story "
         "building, coding puzzles, and brain games. No ads, no logins, totally kid-safe.")
KEYWORDS = ("kids,learning,phonics,abc,coding,puzzle,story,memory,educational,"
            "preschool,brain,games,toddler")
DESCRIPTION = """AI4Kids is a bright, friendly iPad app that lets children play and learn through four hands-on activities — inspired by the AI Kids Academy programme. Everything runs fully offline, with no login, no ads, and no data collection, so kids can explore safely on their own.

FOUR WAYS TO PLAY & LEARN

• Phonics Playground (ages 4–6) — Tap the picture that begins with the shown letter and build early reading skills with letters and sounds.

• Story Builder (ages 7–9) — Pick a hero, a magical place, and a special object, then watch your very own illustrated story come to life, page by page.

• Code Puzzles (ages 10–12) — Plan a sequence of steps to guide a robot to the star. A gentle, screen-free-feeling introduction to coding and logical thinking.

• Brain Games (all ages) — Flip cards to find matching pairs and grow memory, focus, and concentration.

WHY PARENTS LOVE IT

• Completely offline — works anywhere, no internet needed
• No accounts, no sign-ups, no ads, no in-app purchases
• No data collected — a built-in Parents' Corner explains everything
• Designed for iPad with big, colourful, easy-to-tap controls
• Earn stars and celebrate every win

AI4Kids turns screen time into playful learning time. Download it and let the adventures begin!"""

def call(method, path, body=None):
    req = urllib.request.Request(BASE + path,
        data=(json.dumps(body).encode() if body else None), method=method,
        headers={"Authorization": f"Bearer {TOK}", "Content-Type": "application/json"})
    try:
        r = urllib.request.urlopen(req); b = r.read().decode()
        return r.status, (json.loads(b) if b.strip().startswith(("{", "[")) else b)
    except urllib.error.HTTPError as e:
        b = e.read().decode()
        return e.code, (json.loads(b) if b.strip().startswith(("{", "[")) else b)

# --- version (copyright) + version localization (description, keywords, urls, promo) ---
s, vers = call("GET", f"/v1/apps/{AID}/appStoreVersions?limit=1")
vid = vers["data"][0]["id"]
if os.environ.get("ASC_COPYRIGHT"):
    call("PATCH", f"/v1/appStoreVersions/{vid}", {"data": {"type": "appStoreVersions",
        "id": vid, "attributes": {"copyright": os.environ["ASC_COPYRIGHT"]}}})
s, vlocs = call("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")
vlid = vlocs["data"][0]["id"]
attrs = {"description": DESCRIPTION, "keywords": KEYWORDS, "promotionalText": PROMO}
if os.environ.get("ASC_SUPPORT_URL"): attrs["supportUrl"] = os.environ["ASC_SUPPORT_URL"]
if os.environ.get("ASC_MARKETING_URL"): attrs["marketingUrl"] = os.environ["ASC_MARKETING_URL"]
s, b = call("PATCH", f"/v1/appStoreVersionLocalizations/{vlid}",
    {"data": {"type": "appStoreVersionLocalizations", "id": vlid, "attributes": attrs}})
print("version localization:", s, "" if s < 300 else json.dumps(b)[:400])

# --- app info localization (subtitle, privacyPolicyUrl) ---
s, infos = call("GET", f"/v1/apps/{AID}/appInfos")
info_id = infos["data"][0]["id"]
s, ilocs = call("GET", f"/v1/appInfos/{info_id}/appInfoLocalizations")
ilid = ilocs["data"][0]["id"]
iattrs = {"subtitle": SUBTITLE}
if os.environ.get("ASC_PRIVACY_POLICY_URL"): iattrs["privacyPolicyUrl"] = os.environ["ASC_PRIVACY_POLICY_URL"]
s, b = call("PATCH", f"/v1/appInfoLocalizations/{ilid}",
    {"data": {"type": "appInfoLocalizations", "id": ilid, "attributes": iattrs}})
print("app info localization:", s, "" if s < 300 else json.dumps(b)[:400])

# --- primary category: Education ---
s, b = call("PATCH", f"/v1/appInfos/{info_id}",
    {"data": {"type": "appInfos", "id": info_id, "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": "EDUCATION"}}}}})
print("primary category EDUCATION:", s, "" if s < 300 else json.dumps(b)[:400])
