#!/usr/bin/env python3
"""Validate the production migration source manifest against the checked-out Git tree."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "supabase/ci/production_migration_manifest.json"


def git_blob(path: str) -> str:
    return subprocess.check_output(
        ["git", "rev-parse", f"HEAD:{path}"],
        cwd=ROOT,
        text=True,
        stderr=subprocess.STDOUT,
    ).strip()


def main() -> int:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = data.get("entries", [])
    expected = int(data.get("production_ledger_records", 0))
    if len(entries) != expected:
        raise SystemExit(f"Manifest has {len(entries)} records; expected {expected}.")

    versions = [entry.get("version") for entry in entries]
    if len(set(versions)) != len(versions):
        raise SystemExit("Duplicate production migration versions in manifest.")

    missing = []
    stale = []
    for entry in entries:
        sources = []
        if entry.get("canonical_source"):
            sources.append((entry["canonical_source"], entry.get("canonical_git_blob_sha")))
        sources.extend(
            (variant["path"], variant.get("git_blob_sha"))
            for variant in entry.get("additional_variants", [])
        )
        if not sources:
            missing.append(entry.get("version"))
            continue
        for path, expected_sha in sources:
            try:
                actual_sha = git_blob(path)
            except subprocess.CalledProcessError:
                missing.append(f"{entry.get('version')}:{path}")
                continue
            if expected_sha and actual_sha != expected_sha:
                stale.append(f"{entry.get('version')}:{path}")

    if missing or stale:
        if missing:
            print("Missing migration sources:", *missing, sep="\n- ", file=sys.stderr)
        if stale:
            print("Changed migration source blobs:", *stale, sep="\n- ", file=sys.stderr)
        return 1

    summary = data.get("matching_summary", {})
    if summary.get("records_missing_source") != 0:
        raise SystemExit("Manifest still contains production migrations without a source.")
    print(
        f"Validated {expected} production migration records; "
        f"{summary.get('records_recovered_only', 0)} are sourced from recovered history."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
