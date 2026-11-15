#!/usr/bin/env python3
"""
تجهيز حساب Apple لتطبيق «البيان» عبر App Store Connect API:
  1) يسجّل معرّف التطبيق (Bundle ID) إن لم يكن مسجّلًا.
  2) يتحقق أن سجل التطبيق موجود في App Store Connect، وإلا يتوقف برسالة واضحة.
المتغيرات: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER, BUNDLE_ID
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt  # PyJWT

API = "https://api.appstoreconnect.apple.com/v1"


def token() -> str:
    key = open(os.environ["ASC_KEY_PATH"]).read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER"], "iat": now, "exp": now + 1000,
         "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def call(method: str, path: str, body=None):
    req = urllib.request.Request(
        API + path, method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        print(f"❌ {method} {path} → {e.code}\n{e.read().decode()[:800]}")
        sys.exit(1)


def main() -> None:
    bid = os.environ["BUNDLE_ID"]
    q = urllib.parse.quote(bid)
    found = call("GET", f"/bundleIds?filter[identifier]={q}")["data"]
    found = [b for b in found if b["attributes"]["identifier"] == bid]
    if found:
        print(f"✅ معرّف التطبيق مسجّل: {bid}")
    else:
        call("POST", "/bundleIds", {"data": {"type": "bundleIds", "attributes": {
            "identifier": bid, "name": "Albayan", "platform": "IOS"}}})
        print(f"✅ سُجّل معرّف التطبيق الآن: {bid}")

    apps = call("GET", f"/apps?filter[bundleId]={q}")["data"]
    if not apps:
        print("❌ APP_RECORD_MISSING — سجل التطبيق غير موجود في App Store Connect.")
        print("   أنشئه مرة واحدة من: https://appstoreconnect.apple.com/apps")
        print(f"   (+) تطبيق جديد ← iOS ← Bundle ID: {bid} ← اللغة: العربية")
        sys.exit(2)
    print(f"✅ سجل التطبيق موجود: {apps[0]['attributes']['name']}")


if __name__ == "__main__":
    main()
