"""
Set the custom claim admin=true on a Firebase Auth user.

Usage:
    uv run --project annotator python -m annotator.set_admin --email hugo.boronat@moov.ai
    uv run --project annotator python -m annotator.set_admin --uid <firebase-uid>
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials

SERVICE_ACCOUNT = Path(__file__).parent / "service-account.json"


def main() -> None:
    parser = argparse.ArgumentParser(description="Grant admin role to a Firebase user")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--uid", help="Firebase UID")
    group.add_argument("--email", help="User email address")
    args = parser.parse_args()

    cred = credentials.Certificate(str(SERVICE_ACCOUNT))
    firebase_admin.initialize_app(cred)

    uid: str
    if args.uid:
        uid = args.uid
    else:
        user = auth.get_user_by_email(args.email)
        uid = user.uid

    auth.set_custom_user_claims(uid, {"admin": True})
    print(f"✓ admin=true set for {uid}", file=sys.stderr)


if __name__ == "__main__":
    main()
