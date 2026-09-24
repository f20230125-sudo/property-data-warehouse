"""Build the property data warehouse from scratch.

Runs sql/01..06 against a fresh DuckDB file (warehouse.duckdb), then runs the
data-quality checks in sql/07 and exits non-zero if any of them fail.

Usage:  python build.py
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).parent
DB_PATH = ROOT / "warehouse.duckdb"
SQL_DIR = ROOT / "sql"

LOAD_SCRIPTS = [
    "01_schema.sql",
    "02_stage_sources.sql",
    "03_load_dim_date.sql",
    "04_load_dim_location_property_type.sql",
    "05_load_dim_agent_scd2.sql",
    "06_load_fact_listings.sql",
]
QUALITY_SCRIPT = "07_quality_checks.sql"

TABLES = [
    "stg.listings_raw",
    "stg.listings_rejected",
    "dim_date",
    "dim_location",
    "dim_property_type",
    "dim_agent",
    "fact_listings",
]


def read_sql(name: str) -> str:
    return (SQL_DIR / name).read_text(encoding="utf-8")


def main() -> int:
    os.chdir(ROOT)  # the SQL reads data/raw/*.csv by relative path
    for stale in (DB_PATH, DB_PATH.with_suffix(".duckdb.wal")):
        stale.unlink(missing_ok=True)

    con = duckdb.connect(str(DB_PATH))
    for script in LOAD_SCRIPTS:
        con.execute(read_sql(script))
        print(f"ok   {script}")

    print("\nRow counts")
    for table in TABLES:
        (count,) = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()
        print(f"  {table:<24}{count:>8,}")

    print("\nData quality checks")
    results = con.execute(read_sql(QUALITY_SCRIPT)).fetchall()
    failed = [(name, n) for name, n in results if n > 0]
    for name, n in results:
        print(f"  {'FAIL' if n else 'pass'}  {name}" + (f"  ({n} violations)" if n else ""))

    con.close()
    if failed:
        print(f"\n{len(failed)} check(s) failed.")
        return 1
    print(f"\nAll {len(results)} checks passed. Warehouse written to {DB_PATH.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
