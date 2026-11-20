#!/usr/bin/env python3
"""Parse recovered untracked SQL events without replaying historical one-off DDL."""
from pathlib import Path
import sys

from pglast import parse_sql

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "supabase/recovered-history/untracked"


def main() -> int:
    files = sorted(ARCHIVE.glob("*.sql"))
    if len(files) != 13:
        print(f"Expected 13 archived untracked SQL events; found {len(files)}.", file=sys.stderr)
        return 1
    failed = []
    for path in files:
        try:
            parse_sql(path.read_text(encoding="utf-8"))
            print(f"OK {path.relative_to(ROOT)}")
        except Exception as exc:
            failed.append(f"{path.relative_to(ROOT)}: {exc}")
    if failed:
        print("Recovered SQL syntax validation failed:", file=sys.stderr)
        for item in failed:
            print(f"- {item}", file=sys.stderr)
        return 1
    print(f"Validated {len(files)} recovered untracked SQL events (syntax only; not executed).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
