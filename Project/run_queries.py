"""
============================================================
TPC-H Query Benchmark Runner
============================================================
Thesis: Workload-Driven Automated Index Recommendation
        Using Machine Learning: A Comprehensive TPC-H
        Benchmark Evaluation

What this script does:
  1. Connects to your local MySQL (tpch database)
  2. Reads all 5 SQL query files
  3. Runs each query 3 times -> records avg/min/max runtime
  4. Runs EXPLAIN on each query -> records query plan details
  5. Saves two CSV files:
       results/runtime_results.csv
       results/explain_results.csv

Requirements:
  pip install mysql-connector-python

Usage:
  python run_queries.py
============================================================
"""

import mysql.connector
import csv
import time
import re
import os
import argparse
from datetime import datetime

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────
DEFAULT_CONFIG = {
    "host":               "127.0.0.1",
    "port":               3306,
    "user":               "root",
    "password":           "sayem1288",
    "database":           "tpch",
    "connection_timeout": 30,
}

RUNS_PER_QUERY = 3

QUERY_FILES = [
    ("single_table_filters", "queries/single_table_filters.sql"),
    ("two_table_joins",       "queries/two_table_joins.sql"),
    ("three_table_joins",     "queries/three_table_joins.sql"),
    ("aggregation",           "queries/Aggregation.sql"),
    ("complex_queries",       "queries/complex_queries.sql"),
]

OUTPUT_DIR = "results"
RUNTIME_CSV = os.path.join(OUTPUT_DIR, "runtime_results.csv")
EXPLAIN_CSV = os.path.join(OUTPUT_DIR, "explain_results.csv")
ERROR_LOG   = os.path.join(OUTPUT_DIR, "errors.log")

# ─────────────────────────────────────────────
# PARSER
# ─────────────────────────────────────────────

def parse_queries(sql_text):
    """
    Split a .sql file into individual queries.
    Handles both:
      - Files with  -- Q001: label  comments  (aggregation/complex)
      - Plain SQL files with no query ID labels (filter/join)
    Returns list of (query_id, query_sql) tuples.
    """
    # Remove USE statement
    sql_text = re.sub(r'(?im)^\s*USE\s+\w+\s*;', '', sql_text)

    q_counter = [0]

    def next_id():
        q_counter[0] += 1
        return "Q{:03d}".format(q_counter[0])

    # Walk lines: strip comments, tag SQL lines with pending Q-ID
    annotated  = []
    pending_id = None

    for raw in sql_text.splitlines():
        s = raw.strip()

        # Detect -- Q001: label
        m = re.match(r'^--\s+(Q\d+)\s*:', s)
        if m:
            pending_id = m.group(1)
            continue

        # Skip all comments and blank lines
        if s.startswith('--') or s.startswith('/*') \
                or s.startswith('*') or s == '':
            continue

        annotated.append((pending_id, s))
        pending_id = None   # consume after attaching

    # Split on semicolons
    queries = []
    buf     = []
    buf_id  = None

    for qid, line in annotated:
        if buf_id is None:
            buf_id = qid
        buf.append(line)
        if line.endswith(';'):
            sql = ' '.join(buf).rstrip(';').strip()
            if sql:
                queries.append((buf_id, sql))
            buf    = []
            buf_id = None

    # Flush trailing query without semicolon
    if buf:
        sql = ' '.join(buf).rstrip(';').strip()
        if sql:
            queries.append((buf_id, sql))

    # Explicit-ID files: deduplicate by ID
    # Plain SQL files:   renumber sequentially, keep ALL queries
    has_explicit = any(qid is not None for qid, _ in queries)

    if has_explicit:
        seen = {}
        for qid, sql in queries:
            seen[qid] = sql
        return list(seen.items())
    else:
        return [("Q{:03d}".format(i), sql)
                for i, (_, sql) in enumerate(queries, 1)]


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

def run_query_timed(cursor, sql, runs=3):
    times = []
    for _ in range(runs):
        try:
            start = time.perf_counter()
            cursor.execute(sql)
            cursor.fetchall()
            times.append((time.perf_counter() - start) * 1000)
        except Exception as e:
            return None, None, None, False, str(e)
    avg = sum(times) / len(times)
    return round(avg, 4), round(min(times), 4), round(max(times), 4), True, ""


def run_explain(cursor, sql):
    try:
        cursor.execute("EXPLAIN " + sql)
        rows    = cursor.fetchall()
        columns = [d[0] for d in cursor.description]
        return [dict(zip(columns, r)) for r in rows], ""
    except Exception as e:
        return [], str(e)


def run_explain_analyze(cursor, sql):
    try:
        cursor.execute("EXPLAIN ANALYZE " + sql)
        rows = cursor.fetchall()
        return str(rows[0][0]) if rows else "", ""
    except Exception as e:
        return "", str(e)


def flush_query_cache(cursor):
    try:
        cursor.execute("RESET QUERY CACHE")
    except Exception:
        pass


# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────

def main(config):
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("=" * 60)
    print("  TPC-H Query Benchmark Runner")
    print("  Database : {}@{}".format(config['database'], config['host']))
    print("  Runs/query: {}".format(RUNS_PER_QUERY))
    print("  Started  : {}".format(datetime.now().strftime('%Y-%m-%d %H:%M:%S')))
    print("=" * 60)

    try:
        conn   = mysql.connector.connect(**config)
        cursor = conn.cursor()
        print("Connected to MySQL successfully\n")
    except Exception as e:
        print("Connection failed: {}".format(e))
        return

    runtime_file = open(RUNTIME_CSV, 'w', newline='', encoding='utf-8')
    explain_file = open(EXPLAIN_CSV, 'w', newline='', encoding='utf-8')
    error_file   = open(ERROR_LOG,   'w', encoding='utf-8')

    runtime_writer = csv.writer(runtime_file)
    explain_writer = csv.writer(explain_file)

    runtime_writer.writerow([
        "category", "query_id", "query_number",
        "avg_runtime_ms", "min_runtime_ms", "max_runtime_ms",
        "runs", "status", "error", "sql_preview"
    ])

    explain_writer.writerow([
        "category", "query_id", "query_number", "explain_row",
        "id", "select_type", "table", "partitions",
        "type", "possible_keys", "key", "key_len",
        "ref", "rows", "filtered", "Extra",
        "explain_analyze", "error"
    ])

    total_queries  = 0
    total_success  = 0
    total_errors   = 0
    global_q_num   = 0

    for category, filepath in QUERY_FILES:
        if not os.path.exists(filepath):
            print("File not found: {} -- skipping".format(filepath))
            error_file.write("FILE NOT FOUND: {}\n".format(filepath))
            continue

        with open(filepath, 'r', encoding='utf-8') as f:
            sql_text = f.read()

        queries = parse_queries(sql_text)
        print("  {} --> {} queries found".format(category.ljust(25), len(queries)))

        for q_idx, (query_id, sql) in enumerate(queries, 1):
            global_q_num  += 1
            total_queries += 1
            full_id        = "{}_{}".format(category, query_id)
            sql_preview    = sql[:120].replace('\n', ' ')

            flush_query_cache(cursor)
            avg_ms, min_ms, max_ms, ok, err = run_query_timed(cursor, sql, RUNS_PER_QUERY)

            if ok:
                total_success += 1
                print("   [{:>4}] {:<38} avg={:>10.2f} ms".format(
                    global_q_num, full_id, avg_ms))
            else:
                total_errors += 1
                print("   [{:>4}] {:<38} ERROR: {}".format(
                    global_q_num, full_id, err[:60]))
                error_file.write("[{}] {}\n  SQL: {}\n  ERR: {}\n\n".format(
                    datetime.now(), full_id, sql_preview, err))

            runtime_writer.writerow([
                category, query_id, global_q_num,
                avg_ms if ok else "", min_ms if ok else "", max_ms if ok else "",
                RUNS_PER_QUERY, "OK" if ok else "ERROR", err, sql_preview
            ])

            explain_rows, exp_err = run_explain(cursor, sql)
            if explain_rows:
                analyze_out, _ = run_explain_analyze(cursor, sql)
                for rn, er in enumerate(explain_rows, 1):
                    explain_writer.writerow([
                        category, query_id, global_q_num, rn,
                        er.get('id',''), er.get('select_type',''),
                        er.get('table',''), er.get('partitions',''),
                        er.get('type',''), er.get('possible_keys',''),
                        er.get('key',''), er.get('key_len',''),
                        er.get('ref',''), er.get('rows',''),
                        er.get('filtered',''), er.get('Extra',''),
                        analyze_out if rn == 1 else '', exp_err
                    ])
            else:
                explain_writer.writerow([
                    category, query_id, global_q_num, 1,
                    '','','','','','','','','','','','','', exp_err
                ])

        print()

    runtime_file.close()
    explain_file.close()
    error_file.close()
    cursor.close()
    conn.close()

    print("=" * 60)
    print("  BENCHMARK COMPLETE")
    print("=" * 60)
    print("  Total queries : {}".format(total_queries))
    print("  Successful    : {}".format(total_success))
    print("  Errors        : {}".format(total_errors))
    print("  Success rate  : {:.1f}%".format(total_success / total_queries * 100))
    print("\n  Output files:")
    print("    {}".format(RUNTIME_CSV))
    print("    {}".format(EXPLAIN_CSV))
    if total_errors > 0:
        print("    {} <-- check failed queries".format(ERROR_LOG))
    print("\n  Finished : {}".format(datetime.now().strftime('%Y-%m-%d %H:%M:%S')))
    print("=" * 60)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TPC-H Query Benchmark Runner")
    parser.add_argument("--host",     default=DEFAULT_CONFIG["host"])
    parser.add_argument("--port",     default=DEFAULT_CONFIG["port"], type=int)
    parser.add_argument("--user",     default=DEFAULT_CONFIG["user"])
    parser.add_argument("--password", default=DEFAULT_CONFIG["password"])
    parser.add_argument("--database", default=DEFAULT_CONFIG["database"])
    args = parser.parse_args()

    main({
        "host": args.host, "port": args.port,
        "user": args.user, "password": args.password,
        "database": args.database,
        "connection_timeout": DEFAULT_CONFIG["connection_timeout"],
    })
