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

SUBTITLE = "Offline learning activities"
PROMO = ("Four playful, fully offline learning activities: phonics, story building, "
         "coding puzzles, and matching fun. No ads, no logins, no data collection.")
KEYWORDS = ("kids,learning,phonics,abc,coding,puzzle,story,educational,"
            "preschool,brain,games,offline")
DESCRIPTION = """AI4Kids is a bright, friendly app where children play and learn through four hands-on activities. Everything runs fully offline, with no login, no ads, and no data collection, so families can use it safely at home, in class, or on the go.

FOUR WAYS TO PLAY & LEARN

• Phonics Playground (ages 4–6) — Tap the picture that begins with the shown letter and build early reading skills with letters and sounds.

• Story Builder (ages 7–9) — Pick a hero, a magical place, and a special object, then read a short story created from those choices, page by page.

• Code Puzzles (ages 10–12) — Plan a sequence of steps to guide a robot to the star. A gentle, screen-free-feeling introduction to coding and logical thinking.

• Brain Games (all ages) — Flip cards to find matching pairs and grow focus, attention, and concentration.

WHY PARENTS LOVE IT

• Completely offline — works anywhere, no internet needed
• No accounts, no sign-ups, no ads, no in-app purchases
• No data collected — a built-in Parents' Corner explains everything
• Big, colourful, easy-to-tap controls for iPhone and iPad
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

# --- Made for Kids age band ---
s, infos = call("GET", f"/v1/apps/{AID}/appInfos")
info_id = infos["data"][0]["id"]
s, age = call("GET", f"/v1/appInfos/{info_id}/ageRatingDeclaration")
if s < 300:
    age_id = age["data"]["id"]
    s, b = call("PATCH", f"/v1/ageRatingDeclarations/{age_id}",
        {"data": {"type": "ageRatingDeclarations", "id": age_id,
                  "attributes": {"kidsAgeBand": "SIX_TO_EIGHT"}}})
    print("kids age band SIX_TO_EIGHT:", s, "" if s < 300 else json.dumps(b)[:400])
