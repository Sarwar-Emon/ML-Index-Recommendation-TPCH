"""
Full SF-10 Benchmark — All 911 Queries
=======================================
Reads queries from 5 category SQL files
Runs complete workload on tpch_sf10
"""

import mysql.connector
import csv
import time
import os
import json
import statistics

# ── CONFIG ──────────────────────────────────────────
DB_CONFIG = {
    "host":               "127.0.0.1",
    "port":               3306,
    "user":               "root",
    "password":           "sayem1288",
    "database":           "tpch_sf10",
    "connection_timeout": 600,
}

PROJECT_DIR = "/Users/sayememon/Desktop/Troy Courses/Adv Database System/Project"
QUERIES_DIR = os.path.join(PROJECT_DIR, "queries")
OUTPUT_DIR  = os.path.join(PROJECT_DIR, "sf10_full_results")
os.makedirs(OUTPUT_DIR, exist_ok=True)

QUERY_TIMEOUT_MS = 180000   # 3 minutes per query
RUNS_PER_QUERY   = 3

# ── Query file mapping ───────────────────────────────
QUERY_FILES = {
    "aggregation":          "Aggregation.sql",
    "complex_queries":      "complex_queries.sql",
    "single_table_filters": "single_table_filters.sql",
    "three_table_joins":    "three_table_joins.sql",
    "two_table_joins":      "two_table_joins.sql",
}

# ── Helpers ──────────────────────────────────────────

def get_conn():
    conn = mysql.connector.connect(**DB_CONFIG)
    cur  = conn.cursor()
    cur.execute("SET SESSION MAX_EXECUTION_TIME=0")
    cur.execute("SET SESSION wait_timeout=28800")
    cur.execute("SET SESSION net_read_timeout=3600")
    cur.execute("SET SESSION net_write_timeout=3600")
    cur.close()
    return conn


def run_query(conn, sql):
    try:
        cur = conn.cursor()
        cur.execute(f"SET SESSION MAX_EXECUTION_TIME={QUERY_TIMEOUT_MS}")
        t0  = time.time()
        cur.execute(sql)
        cur.fetchall()
        elapsed = (time.time() - t0) * 1000
        cur.close()
        return elapsed, None
    except mysql.connector.Error as e:
        try:
            conn.reconnect(attempts=3, delay=2)
        except Exception:
            pass
        return None, str(e)[:80]


def parse_sql_file(filepath, category):
    """
    Parse SQL file into individual queries.
    Handles both semicolon-separated and
    newline-separated query formats.
    """
    queries = []
    with open(filepath, encoding="utf-8", errors="ignore") as f:
        content = f.read()

    # Split by semicolon
    raw = content.split(";")

    qnum = 1
    for raw_sql in raw:
        sql = raw_sql.strip()
        # Skip empty, comments only
        lines = [l.strip() for l in sql.split("\n")
                 if l.strip() and not l.strip().startswith("--")]
        if not lines:
            continue
        clean = " ".join(lines)
        # Must start with SELECT
        if not clean.upper().startswith("SELECT"):
            continue
        cat_prefix = {
            "aggregation":          "AGG",
            "complex_queries":      "COM",
            "single_table_filters": "SIN",
            "three_table_joins":    "THR",
            "two_table_joins":      "TWO",
        }
        prefix = cat_prefix.get(category, "Q")
        qid = f"{prefix}_Q{qnum:03d}"
        queries.append((qid, category, clean))
        qnum += 1

    return queries


def load_all_queries():
    all_queries = []
    for category, filename in QUERY_FILES.items():
        filepath = os.path.join(QUERIES_DIR, filename)
        if not os.path.exists(filepath):
            print(f"  WARNING: {filename} not found — skipping")
            continue
        qs = parse_sql_file(filepath, category)
        print(f"  {filename:<35} → {len(qs):4d} queries")
        all_queries.extend(qs)
    return all_queries


# ── MAIN ──────────────────────────────────────────────

def main():
    print("=" * 65)
    print("  TPC-H SF-10 FULL BENCHMARK — All 911 Queries")
    print(f"  Timeout: {QUERY_TIMEOUT_MS//1000}s, Runs: {RUNS_PER_QUERY}")
    print("=" * 65)

    print("\nLoading queries:")
    queries = load_all_queries()
    total   = len(queries)
    print(f"\n  Total loaded: {total} queries\n")

    if not queries:
        print("ERROR: No queries found!")
        return

    conn    = get_conn()
    print("Connected to tpch_sf10 ✅\n")

    results = []
    errors  = []
    skipped = 0

    for idx, (qid, category, sql) in enumerate(queries, 1):
        print(f"[{idx:4d}/{total}] {qid:<15} {category:<25}", end="", flush=True)

        if not conn.is_connected():
            try:
                conn = get_conn()
            except Exception as e:
                print(f"  RECONNECT FAILED: {e}")
                continue

        runtimes = []
        error    = None

        for _ in range(RUNS_PER_QUERY):
            if not conn.is_connected():
                try:
                    conn = get_conn()
                except Exception:
                    error = "reconnect_failed"
                    break

            ms, err = run_query(conn, sql)

            if err:
                if "execution time exceeded" in err.lower() or "timeout" in err.lower():
                    error = "TIMEOUT"
                else:
                    error = err
                break
            runtimes.append(ms)

        if error or not runtimes:
            status = error or "no_result"
            print(f"  SKIP ({status[:25]})")
            skipped += 1
            errors.append({
                "query_id": qid,
                "category": category,
                "error":    status,
                "sql":      sql[:100],
            })
        else:
            avg = statistics.mean(runtimes)
            mn  = min(runtimes)
            mx  = max(runtimes)
            print(f"  {avg:10.1f} ms")

            results.append({
                "query_id":       qid,
                "category":       category,
                "avg_runtime_ms": round(avg, 4),
                "min_runtime_ms": round(mn, 4),
                "max_runtime_ms": round(mx, 4),
                "runs":           len(runtimes),
                "status":         "OK",
                "sql_preview":    sql[:80],
            })

    conn.close()

    # ── Save ─────────────────────────────────────────
    out_csv = os.path.join(OUTPUT_DIR, "sf10_full_runtime_results.csv")
    if results:
        with open(out_csv, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=results[0].keys())
            writer.writeheader()
            writer.writerows(results)

    err_csv = os.path.join(OUTPUT_DIR, "sf10_full_errors.csv")
    if errors:
        with open(err_csv, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["query_id","category","error","sql"])
            writer.writeheader()
            writer.writerows(errors)

    # ── Summary ───────────────────────────────────────
    print("\n" + "=" * 65)
    print("  RESULTS SUMMARY BY CATEGORY")
    print("=" * 65)

    cats = {}
    for r in results:
        c = r["category"]
        if c not in cats:
            cats[c] = []
        cats[c].append(r["avg_runtime_ms"])

    total_time = sum(r["avg_runtime_ms"] for r in results)

    print(f"\n  {'Category':<28} {'Success':>8} {'Avg (ms)':>12} {'Max (ms)':>12}")
    print(f"  {'-'*62}")
    for cat, times in sorted(cats.items()):
        print(f"  {cat:<28} {len(times):>8} {statistics.mean(times):>12.1f} {max(times):>12.1f}")

    print(f"\n  Total successful: {len(results)} / {total}")
    print(f"  Skipped/timeout:  {skipped} / {total}")
    print(f"  Success rate:     {len(results)/total*100:.1f}%")
    print(f"  Total runtime:    {total_time/1000:.1f}s ({total_time/60000:.1f} min)")

    if results:
        best = max(results, key=lambda r: r["avg_runtime_ms"])
        fastest = min(results, key=lambda r: r["avg_runtime_ms"])
        print(f"\n  Slowest query:  {best['query_id']} = {best['avg_runtime_ms']:.0f} ms")
        print(f"  Fastest query:  {fastest['query_id']} = {fastest['avg_runtime_ms']:.2f} ms")
        print(f"  Overall avg:    {statistics.mean(r['avg_runtime_ms'] for r in results):.1f} ms")

    # Save JSON
    summary = {
        "scale_factor":     10,
        "total_queries":    total,
        "successful":       len(results),
        "skipped":          skipped,
        "success_rate_pct": round(len(results)/total*100, 1),
        "total_runtime_ms": round(total_time, 2),
        "categories": {
            cat: {
                "count":  len(times),
                "avg_ms": round(statistics.mean(times), 1),
                "max_ms": round(max(times), 1),
                "min_ms": round(min(times), 1),
            }
            for cat, times in cats.items()
        }
    }
    with open(os.path.join(OUTPUT_DIR, "sf10_full_summary.json"), "w") as f:
        json.dump(summary, f, indent=2)

    print(f"\n  Results saved to: {OUTPUT_DIR}/")
    print("=" * 65)


if __name__ == "__main__":
    main()
