"""
Full SF-10 Benchmark — All 911 Queries
=======================================
Runs the complete workload on tpch_sf10
with per-query timeout and reconnect logic
Saves results to sf10_full_results/
"""

import mysql.connector
import csv
import time
import os
import json
import statistics
import subprocess

# ── CONFIG ──────────────────────────────────────────
DB_CONFIG = {
    "host":               "127.0.0.1",
    "port":               3306,
    "user":               "root",
    "password":           "sayem1288",
    "database":           "tpch_sf10",
    "connection_timeout": 600,
    "allow_local_infile": True,
}

PROJECT_DIR  = "/Users/sayememon/Desktop/Troy Courses/Adv Database System/Project"
QUERIES_DIR  = os.path.join(PROJECT_DIR, "queries")
OUTPUT_DIR   = os.path.join(PROJECT_DIR, "sf10_full_results")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Per-query timeout: 3 minutes
# Queries that take longer are skipped and logged
QUERY_TIMEOUT_MS = 180000
RUNS_PER_QUERY   = 3

# ── Helpers ──────────────────────────────────────────

def get_conn():
    """Get a fresh MySQL connection with timeouts set."""
    conn = mysql.connector.connect(**DB_CONFIG)
    cur  = conn.cursor()
    cur.execute("SET SESSION MAX_EXECUTION_TIME=0")
    cur.execute("SET SESSION wait_timeout=28800")
    cur.execute("SET SESSION net_read_timeout=3600")
    cur.execute("SET SESSION net_write_timeout=3600")
    cur.close()
    return conn


def run_query(conn, sql, timeout_ms=QUERY_TIMEOUT_MS):
    """Run a single query with timeout. Returns (ms, error)."""
    try:
        cur = conn.cursor()
        cur.execute(f"SET SESSION MAX_EXECUTION_TIME={timeout_ms}")
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


def load_queries_from_dir(queries_dir):
    """
    Load all SQL queries from the queries/ folder.
    Returns list of (query_id, category, sql) tuples.
    Supports both individual .sql files and combined files.
    """
    queries = []

    # Try to read from individual category folders first
    category_map = {
        "single_table_filters": "single_table_filters",
        "two_table_joins":      "two_table_joins",
        "three_table_joins":    "three_table_joins",
        "aggregation":          "aggregation",
        "complex_queries":      "complex_queries",
    }

    if os.path.exists(queries_dir):
        for folder, category in category_map.items():
            folder_path = os.path.join(queries_dir, folder)
            if os.path.isdir(folder_path):
                for fname in sorted(os.listdir(folder_path)):
                    if fname.endswith(".sql"):
                        qid = fname.replace(".sql", "")
                        with open(os.path.join(folder_path, fname)) as f:
                            sql = f.read().strip()
                        if sql:
                            queries.append((qid, category, sql))
            # Also check flat .sql files with category prefix
            else:
                for fname in sorted(os.listdir(queries_dir)):
                    prefix = folder[:3].upper()
                    if fname.startswith(prefix) and fname.endswith(".sql"):
                        qid = fname.replace(".sql", "")
                        with open(os.path.join(queries_dir, fname)) as f:
                            sql = f.read().strip()
                        if sql:
                            queries.append((qid, category, sql))

    # Fallback: read from All_query.sql if queries/ folder is empty
    if not queries:
        all_sql = os.path.join(PROJECT_DIR, "All_query.sql")
        if os.path.exists(all_sql):
            print(f"  Loading from All_query.sql...")
            with open(all_sql) as f:
                content = f.read()
            # Parse individual queries separated by semicolons
            raw = [q.strip() for q in content.split(";") if q.strip()]
            for i, sql in enumerate(raw, 1):
                # Guess category from SQL content
                sql_upper = sql.upper()
                if "GROUP BY" in sql_upper and "JOIN" not in sql_upper:
                    cat = "aggregation"
                elif sql_upper.count("JOIN") >= 2:
                    cat = "three_table_joins" if sql_upper.count("JOIN") >= 2 else "two_table_joins"
                elif "JOIN" in sql_upper:
                    cat = "two_table_joins"
                elif "WHERE" in sql_upper and "JOIN" not in sql_upper:
                    cat = "single_table_filters"
                else:
                    cat = "complex_queries"
                queries.append((f"Q{i:03d}", cat, sql))

    return queries


def run_explain(conn, sql):
    """Run EXPLAIN and collect 30 structural features."""
    features = {
        "has_full_scan": 0,
        "full_scan_table_count": 0,
        "max_join_type_score": 0,
        "index_coverage_ratio": 0.0,
        "num_indexes_used": 0,
        "has_no_index": 0,
        "has_filesort": 0,
        "has_temp_table": 0,
        "num_tables": 0,
        "total_rows_examined": 0,
        "max_rows_examined": 0,
    }
    type_scores = {"system":0,"const":0,"eq_ref":1,"ref":3,"range":5,
                   "index":7,"ALL":11}
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(f"EXPLAIN {sql}")
        rows = cur.fetchall()
        cur.close()
        if not rows:
            return features

        features["num_tables"] = len(rows)
        scores, rows_list, idx_used = [], [], 0

        for row in rows:
            t = str(row.get("type","ALL"))
            s = type_scores.get(t, 11)
            scores.append(s)
            if t == "ALL":
                features["has_full_scan"] = 1
                features["full_scan_table_count"] += 1

            r = int(row.get("rows") or 0)
            rows_list.append(r)

            k = row.get("key")
            if k and k != "NULL":
                idx_used += 1
            else:
                features["has_no_index"] = 1

            extra = str(row.get("Extra",""))
            if "filesort" in extra:
                features["has_filesort"] = 1
            if "temporary" in extra:
                features["has_temp_table"] = 1

        features["max_join_type_score"]  = max(scores) if scores else 0
        features["num_indexes_used"]     = idx_used
        features["index_coverage_ratio"] = (idx_used / len(rows)) if rows else 0.0
        features["total_rows_examined"]  = sum(rows_list)
        features["max_rows_examined"]    = max(rows_list) if rows_list else 0

    except Exception:
        pass
    return features


# ── MAIN ──────────────────────────────────────────────

def main():
    print("=" * 65)
    print("  TPC-H SF-10 FULL BENCHMARK — All 911 Queries")
    print(f"  Timeout: {QUERY_TIMEOUT_MS//1000}s per run, {RUNS_PER_QUERY} runs each")
    print("=" * 65)

    # Load queries
    print(f"\nLoading queries from: {QUERIES_DIR}")
    queries = load_queries_from_dir(QUERIES_DIR)

    if not queries:
        print("ERROR: No queries found!")
        print(f"Please check that {QUERIES_DIR} exists and contains .sql files")
        return

    print(f"Loaded {len(queries)} queries\n")

    # Connect
    conn = get_conn()
    print("Connected to tpch_sf10 ✅\n")

    results  = []
    errors   = []
    total    = len(queries)
    skipped  = 0

    for idx, (qid, category, sql) in enumerate(queries, 1):
        print(f"[{idx:4d}/{total}] {qid:<25} {category:<25}", end="", flush=True)

        # Reconnect if needed
        if not conn.is_connected():
            try:
                conn = get_conn()
            except Exception as e:
                print(f"  RECONNECT FAILED: {e}")
                continue

        # Run EXPLAIN for features
        features = run_explain(conn, sql)

        # Run benchmark
        runtimes = []
        error    = None

        for run_num in range(RUNS_PER_QUERY):
            if not conn.is_connected():
                try:
                    conn = get_conn()
                except Exception:
                    error = "reconnect_failed"
                    break

            ms, err = run_query(conn, sql, QUERY_TIMEOUT_MS)

            if err:
                if "execution time exceeded" in err.lower() or "timeout" in err.lower():
                    error = "TIMEOUT"
                else:
                    error = err
                break

            runtimes.append(ms)

        if error or not runtimes:
            status = error or "no_result"
            print(f"  SKIP ({status[:30]})")
            skipped += 1
            errors.append({
                "query_id":  qid,
                "category":  category,
                "error":     status,
                "sql":       sql[:100],
            })
        else:
            avg = statistics.mean(runtimes)
            mn  = min(runtimes)
            mx  = max(runtimes)
            print(f"  {avg:10.1f} ms  (min={mn:.0f} max={mx:.0f})")

            row = {
                "query_id":       qid,
                "category":       category,
                "avg_runtime_ms": round(avg, 4),
                "min_runtime_ms": round(mn, 4),
                "max_runtime_ms": round(mx, 4),
                "runs":           len(runtimes),
                "status":         "OK",
                **features,
                "sql_preview":    sql[:80],
            }
            results.append(row)

    conn.close()

    # ── Save results ──────────────────────────────────
    out_csv = os.path.join(OUTPUT_DIR, "sf10_full_runtime_results.csv")
    if results:
        with open(out_csv, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=results[0].keys())
            writer.writeheader()
            writer.writerows(results)
        print(f"\nSaved: {out_csv}")

    err_csv = os.path.join(OUTPUT_DIR, "sf10_full_errors.csv")
    if errors:
        with open(err_csv, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["query_id","category","error","sql"])
            writer.writeheader()
            writer.writerows(errors)
        print(f"Saved: {err_csv}")

    # ── Summary ───────────────────────────────────────
    print("\n" + "=" * 65)
    print("  SF-10 FULL BENCHMARK SUMMARY")
    print("=" * 65)

    cats = {}
    for r in results:
        c = r["category"]
        if c not in cats:
            cats[c] = []
        cats[c].append(r["avg_runtime_ms"])

    total_time = sum(r["avg_runtime_ms"] for r in results)

    print(f"\n  {'Category':<30} {'Queries':>8} {'Avg (ms)':>12}")
    print(f"  {'-'*52}")
    for cat, times in sorted(cats.items()):
        print(f"  {cat:<30} {len(times):>8} {statistics.mean(times):>12.1f}")

    print(f"\n  Total successful: {len(results)}/{total}")
    print(f"  Skipped/timeout:  {skipped}/{total}")
    print(f"  Success rate:     {len(results)/total*100:.1f}%")
    print(f"  Total runtime:    {total_time/1000:.1f}s ({total_time/60000:.1f}min)")

    # Save JSON summary
    summary = {
        "scale_factor":    10,
        "total_queries":   total,
        "successful":      len(results),
        "skipped":         skipped,
        "success_rate_pct": round(len(results)/total*100, 1),
        "total_runtime_ms": round(total_time, 2),
        "categories": {
            cat: {
                "count":   len(times),
                "avg_ms":  round(statistics.mean(times), 1),
                "min_ms":  round(min(times), 1),
                "max_ms":  round(max(times), 1),
            }
            for cat, times in cats.items()
        }
    }
    with open(os.path.join(OUTPUT_DIR, "sf10_full_summary.json"), "w") as f:
        json.dump(summary, f, indent=2)

    print(f"\nAll results saved to: {OUTPUT_DIR}/")
    print("=" * 65)


if __name__ == "__main__":
    main()
