"""
MySQL to PostgreSQL SQL Converter
===================================
Fixes MySQL-specific functions so queries
work on PostgreSQL too
"""

import os
import re

PROJECT_DIR = "/Users/sayememon/Desktop/Troy Courses/Adv Database System/Project"
QUERIES_DIR = os.path.join(PROJECT_DIR, "queries")
PG_DIR      = os.path.join(PROJECT_DIR, "queries_pg")
os.makedirs(PG_DIR, exist_ok=True)

QUERY_FILES = [
    "Aggregation.sql",
    "complex_queries.sql",
    "single_table_filters.sql",
    "three_table_joins.sql",
    "two_table_joins.sql",
]

def convert_mysql_to_pg(sql):
    """Convert MySQL-specific syntax to PostgreSQL."""

    # YEAR(col) → EXTRACT(YEAR FROM col)
    sql = re.sub(
        r'\bYEAR\s*\(\s*(\w+)\s*\)',
        r'EXTRACT(YEAR FROM \1)',
        sql, flags=re.IGNORECASE
    )

    # MONTH(col) → EXTRACT(MONTH FROM col)
    sql = re.sub(
        r'\bMONTH\s*\(\s*(\w+)\s*\)',
        r'EXTRACT(MONTH FROM \1)',
        sql, flags=re.IGNORECASE
    )

    # DAY(col) → EXTRACT(DAY FROM col)
    sql = re.sub(
        r'\bDAY\s*\(\s*(\w+)\s*\)',
        r'EXTRACT(DAY FROM \1)',
        sql, flags=re.IGNORECASE
    )

    # DATE_FORMAT(col, '%Y-%m') → TO_CHAR(col, 'YYYY-MM')
    sql = re.sub(
        r"DATE_FORMAT\s*\(\s*(\w+)\s*,\s*'%Y-%m'\s*\)",
        r"TO_CHAR(\1, 'YYYY-MM')",
        sql, flags=re.IGNORECASE
    )

    # DATE_FORMAT(col, '%Y') → TO_CHAR(col, 'YYYY')
    sql = re.sub(
        r"DATE_FORMAT\s*\(\s*(\w+)\s*,\s*'%Y'\s*\)",
        r"TO_CHAR(\1, 'YYYY')",
        sql, flags=re.IGNORECASE
    )

    # DATE_FORMAT(col, '%Y-%m-%d') → TO_CHAR(col, 'YYYY-MM-DD')
    sql = re.sub(
        r"DATE_FORMAT\s*\(\s*(\w+)\s*,\s*'%Y-%m-%d'\s*\)",
        r"TO_CHAR(\1, 'YYYY-MM-DD')",
        sql, flags=re.IGNORECASE
    )

    # IFNULL(a, b) → COALESCE(a, b)
    sql = re.sub(
        r'\bIFNULL\s*\(',
        r'COALESCE(',
        sql, flags=re.IGNORECASE
    )

    # ISNULL(a) → (a IS NULL)
    sql = re.sub(
        r'\bISNULL\s*\(\s*(\w+)\s*\)',
        r'(\1 IS NULL)',
        sql, flags=re.IGNORECASE
    )

    # IF(cond, a, b) → CASE WHEN cond THEN a ELSE b END
    # Simple cases only
    sql = re.sub(
        r'\bIF\s*\(([^,]+),\s*([^,]+),\s*([^)]+)\)',
        r'CASE WHEN \1 THEN \2 ELSE \3 END',
        sql, flags=re.IGNORECASE
    )

    # GROUP_CONCAT → STRING_AGG
    sql = re.sub(
        r'\bGROUP_CONCAT\s*\(',
        r'STRING_AGG(',
        sql, flags=re.IGNORECASE
    )

    # LIMIT x, y → LIMIT y OFFSET x
    sql = re.sub(
        r'\bLIMIT\s+(\d+)\s*,\s*(\d+)',
        r'LIMIT \2 OFFSET \1',
        sql, flags=re.IGNORECASE
    )

    # DATE_ADD(date, INTERVAL x DAY) → date + INTERVAL 'x day'
    sql = re.sub(
        r"DATE_ADD\s*\(\s*(\w+)\s*,\s*INTERVAL\s+(\d+)\s+DAY\s*\)",
        r"\1 + INTERVAL '\2 day'",
        sql, flags=re.IGNORECASE
    )

    # DATE_SUB(date, INTERVAL x DAY) → date - INTERVAL 'x day'
    sql = re.sub(
        r"DATE_SUB\s*\(\s*(\w+)\s*,\s*INTERVAL\s+(\d+)\s+DAY\s*\)",
        r"\1 - INTERVAL '\2 day'",
        sql, flags=re.IGNORECASE
    )

    # DATEDIFF(a, b) → (a - b) (PostgreSQL date subtraction gives days)
    sql = re.sub(
        r'\bDATEDIFF\s*\(\s*(\w+)\s*,\s*(\w+)\s*\)',
        r'(\1 - \2)',
        sql, flags=re.IGNORECASE
    )

    # NOW() is same in PostgreSQL ✅
    # CURDATE() → CURRENT_DATE
    sql = re.sub(r'\bCURDATE\s*\(\s*\)', 'CURRENT_DATE', sql, flags=re.IGNORECASE)

    # STR_TO_DATE → TO_DATE (approximate)
    sql = re.sub(
        r"STR_TO_DATE\s*\(\s*'([^']+)'\s*,\s*'[^']+'\s*\)",
        r"'\1'::date",
        sql, flags=re.IGNORECASE
    )

    # CONCAT with || operator (PostgreSQL supports both)
    # MySQL CONCAT already works in PostgreSQL ✅

    # Backtick identifiers → double quotes
    sql = re.sub(r'`(\w+)`', r'"\1"', sql)

    return sql


def convert_file(filename):
    filepath    = os.path.join(QUERIES_DIR, filename)
    pg_filepath = os.path.join(PG_DIR, filename.replace(".sql", "_pg.sql"))

    if not os.path.exists(filepath):
        print(f"  WARNING: {filename} not found")
        return 0, 0

    with open(filepath, encoding="utf-8", errors="ignore") as f:
        content = f.read()

    # Split into individual queries
    raw = content.split(";")
    converted = 0
    unchanged = 0
    output_parts = []

    for raw_sql in raw:
        sql = raw_sql.strip()
        lines = [l.strip() for l in sql.split("\n")
                 if l.strip() and not l.strip().startswith("--")]
        if not lines:
            continue
        clean = " ".join(lines)
        if not clean.upper().startswith("SELECT"):
            continue

        pg_sql = convert_mysql_to_pg(clean)
        output_parts.append(pg_sql)

        if pg_sql != clean:
            converted += 1
        else:
            unchanged += 1

    # Write converted file
    with open(pg_filepath, "w") as f:
        f.write(";\n\n".join(output_parts) + ";")

    return converted, unchanged


def main():
    print("=" * 60)
    print("  MySQL → PostgreSQL SQL Converter")
    print("=" * 60)
    print(f"\n  Output folder: {PG_DIR}\n")

    total_converted = 0
    total_unchanged = 0

    for filename in QUERY_FILES:
        converted, unchanged = convert_file(filename)
        total_converted += converted
        total_unchanged += unchanged
        print(f"  {filename:<35} {converted:4d} converted, {unchanged:4d} unchanged")

    print(f"\n  Total converted: {total_converted}")
    print(f"  Total unchanged: {total_unchanged}")
    print(f"  Total queries:   {total_converted + total_unchanged}")
    print(f"\n  Converted files saved to: {PG_DIR}/")
    print("\n  Now re-run pg_ml_benchmark.py with QUERIES_DIR pointing to:")
    print(f"  {PG_DIR}")
    print("=" * 60)


if __name__ == "__main__":
    main()
