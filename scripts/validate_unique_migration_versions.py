#!/usr/bin/env python3
"""Reject duplicate or malformed Supabase migration version prefixes."""
from __future__ import annotations

from datetime import datetime
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase/migrations"
VERSION_PREFIX = re.compile(r"^(\d{14})_")


def main() -> int:
    by_version: dict[str, list[str]] = {}
    malformed: list[str] = []
    invalid_timestamps: list[tuple[str, str]] = []

    for path in sorted(MIGRATIONS.glob("*.sql")):
        relative = path.relative_to(ROOT).as_posix()
        match = VERSION_PREFIX.match(path.name)
        if not match:
            malformed.append(relative)
            continue
        version = match.group(1)
        try:
            datetime.strptime(version, "%Y%m%d%H%M%S")
        except ValueError:
            invalid_timestamps.append((relative, version))
        by_version.setdefault(version, []).append(relative)

    duplicates = {
        version: paths for version, paths in by_version.items() if len(paths) > 1
    }
    if malformed or invalid_timestamps or duplicates:
        if malformed:
            print("Migration files without a 14-digit version prefix:", file=sys.stderr)
            for path in malformed:
                print(f"- {path}", file=sys.stderr)
        if invalid_timestamps:
            print("Migration files with invalid calendar timestamps:", file=sys.stderr)
            for path, version in invalid_timestamps:
                print(f"- {path}: {version}", file=sys.stderr)
        if duplicates:
            print("Duplicate Supabase migration version prefixes:", file=sys.stderr)
            for version, paths in sorted(duplicates.items()):
                print(f"- {version}: " + ", ".join(paths), file=sys.stderr)
        return 1

    print(f"Validated {sum(map(len, by_version.values()))} unique Supabase migration versions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
