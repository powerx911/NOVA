#!/usr/bin/env python3
"""Validate PostgreSQL SQL syntax and lightweight migration invariants.

This is a zero-hosting-cost CI guard. It parses SQL with PostgreSQL's grammar;
it does not replace executing migrations against an isolated database.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

from pglast import parse_sql


ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
DB_TESTS = ROOT / "supabase" / "tests" / "database"
VERSIONED_MIGRATION = re.compile(r"^(\d{14})_[a-z0-9_]+\.sql$")
PGTAP_ASSERTION = re.compile(
    r"\bselect\s+extensions\.(?:ok|is|isnt|throws_ok|lives_ok|throws_like|matches)"
    r"\s*\(",
    re.IGNORECASE,
)


def main() -> int:
    failures: list[str] = []
    migration_files = sorted(MIGRATIONS.glob("*.sql"))
    test_files = sorted(DB_TESTS.glob("*.sql"))

    if not migration_files:
        failures.append(f"No migration SQL files found under {MIGRATIONS}")

    versions: dict[str, Path] = {}
    for path in migration_files:
        match = VERSIONED_MIGRATION.fullmatch(path.name)
        if not match:
            failures.append(f"{path.relative_to(ROOT)}: filename must start with a 14-digit version")
            continue
        version = match.group(1)
        if version in versions:
            failures.append(
                f"Duplicate migration version {version}: "
                f"{versions[version].name} and {path.name}"
            )
        versions[version] = path

    for path in [*migration_files, *test_files]:
        source = path.read_text(encoding="utf-8")
        try:
            statements = parse_sql(source)
        except Exception as exc:  # pglast exposes parser-specific exception types
            failures.append(f"{path.relative_to(ROOT)}: PostgreSQL SQL parse failed: {exc}")
            continue
        print(f"OK {path.relative_to(ROOT)} ({len(statements)} statements)")

        if path.parent == DB_TESTS and "extensions.plan" in source.lower():
            plans = re.findall(r"extensions\.plan\s*\(\s*(\d+)\s*\)", source, re.IGNORECASE)
            assertions = len(PGTAP_ASSERTION.findall(source))
            if len(plans) != 1:
                failures.append(
                    f"{path.relative_to(ROOT)}: expected exactly one extensions.plan(...) call"
                )
            elif int(plans[0]) != assertions:
                failures.append(
                    f"{path.relative_to(ROOT)}: pgTAP plan declares {plans[0]} tests "
                    f"but contains {assertions} assertion calls"
                )

    if failures:
        print("\nSQL validation failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(
        f"Validated {len(migration_files)} migration files and "
        f"{len(test_files)} database test files."
    )
    print("Note: grammar validation does not execute PL/pgSQL or apply migrations.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
