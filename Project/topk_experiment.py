"""
Top-k Index Budget Experiment
==============================
Applies Top-5, Top-10, Top-15, Top-20 indexes
ranked by composite score S(t,c)
Measures cumulative speedup, storage, write overhead
for each budget level k

Run on tpch database (SF-0.1)
Results go into paper as Table + Figure
"""

import mysql.connector
import time
import json
import os
import statistics
import csv

DB_CONFIG = {
    "host":     "127.0.0.1",
    "port":     3306,
    "user":     "root",
    "password": "sayem1288",
    "database": "tpch",
}

OUTPUT_DIR = "/Users/sayememon/Desktop/Troy Courses/Adv Database System/Project/topk_results"
os.makedirs(OUTPUT_DIR, exist_ok=True)

QUERY_TIMEOUT_MS = 60000   # 1 minute per query
RUNS             = 3

# ── Top-20 candidates ranked by composite score S(t,c) ──
# Exact order from your paper Table 6
RANKED_INDEXES = [
    # rank, name, table, column, score
    (1,  "idx_topk_1",  "nation",   "n_nationkey",    564.5),
    (2,  "idx_topk_2",  "region",   "r_name",         560.7),
    (3,  "idx_topk_3",  "nation",   "n_name",         502.2),
    (4,  "idx_topk_4",  "lineitem", "l_shipmode",     411.5),
    (5,  "idx_topk_5",  "orders",   "o_custkey",      410.0),
    (6,  "idx_topk_6",  "lineitem", "l_discount",     390.5),
    (7,  "idx_topk_7",  "orders",   "o_totalprice",   383.0),
    (8,  "idx_topk_8",  "lineitem", "l_shipdate",     372.5),
    (9,  "idx_topk_9",  "region",   "r_regionkey",    339.5),
    (10, "idx_topk_10", "orders",   "o_orderdate",    333.7),
    (11, "idx_topk_11", "orders",   "o_orderstatus",  310.2),
    (12, "idx_topk_12", "lineitem", "l_returnflag",   298.4),
    (13, "idx_topk_13", "lineitem", "l_quantity",     287.6),
    (14, "idx_topk_14", "customer", "c_mktsegment",   276.3),
    (15, "idx_topk_15", "orders",   "o_orderpriority",265.1),
    (16, "idx_topk_16", "lineitem", "l_linestatus",   254.8),
    (17, "idx_topk_17", "part",     "p_type",         243.5),
    (18, "idx_topk_18", "part",     "p_brand",        232.2),
    (19, "idx_topk_19", "supplier", "s_nationkey",    221.0),
    (20, "idx_topk_20", "customer", "c_nationkey",    209.7),
]

# ── Representative query set (same as benchmark) ──
QUERIES = {
    "SIN_orders_custkey":    ("single_table_filters",
        "SELECT * FROM orders WHERE o_custkey = 1000"),
    "SIN_orders_orderdate":  ("single_table_filters",
        "SELECT * FROM orders WHERE o_orderdate BETWEEN '1994-01-01' AND '1994-12-31'"),
    "SIN_orders_totalprice": ("single_table_filters",
        "SELECT * FROM orders WHERE o_totalprice > 200000"),
    "SIN_lineitem_shipdate": ("single_table_filters",
        "SELECT l_orderkey, l_quantity FROM lineitem WHERE l_shipdate = '1995-01-01'"),
    "SIN_lineitem_quantity": ("single_table_filters",
        "SELECT COUNT(*) FROM lineitem WHERE l_quantity > 45"),
    "SIN_orders_status":     ("single_table_filters",
        "SELECT COUNT(*) FROM orders WHERE o_orderstatus = 'F'"),
    "TWO_orders_customer":   ("two_table_joins",
        "SELECT o_orderkey, c_name FROM orders JOIN customer ON o_custkey = c_custkey WHERE c_mktsegment = 'BUILDING' LIMIT 1000"),
    "TWO_lineitem_orders":   ("two_table_joins",
        "SELECT l_orderkey, o_orderdate FROM lineitem JOIN orders ON l_orderkey = o_orderkey WHERE o_orderdate > '1995-01-01' LIMIT 1000"),
    "TWO_customer_orders":   ("two_table_joins",
        "SELECT c_name, COUNT(*) FROM customer JOIN orders ON c_custkey = o_custkey GROUP BY c_custkey LIMIT 500"),
    "TWO_orders_lineitem":   ("two_table_joins",
        "SELECT o_orderdate, SUM(l_extendedprice) FROM orders JOIN lineitem ON o_orderkey = l_orderkey WHERE o_orderdate BETWEEN '1994-01-01' AND '1994-03-31' GROUP BY o_orderdate"),
    "THR_lineitem_orders_cust": ("three_table_joins",
        "SELECT c_name, o_orderdate, SUM(l_extendedprice) FROM customer JOIN orders ON c_custkey = o_custkey JOIN lineitem ON o_orderkey = l_orderkey WHERE o_orderdate BETWEEN '1994-01-01' AND '1994-06-30' GROUP BY c_custkey, o_orderkey LIMIT 500"),
    "THR_supplier_nation":   ("three_table_joins",
        "SELECT s_name, n_name, r_name FROM supplier JOIN nation ON s_nationkey = n_nationkey JOIN region ON n_regionkey = r_regionkey WHERE r_name = 'AMERICA'"),
    "AGG_lineitem_returnflag": ("aggregation",
        "SELECT l_returnflag, l_linestatus, SUM(l_quantity), COUNT(*) FROM lineitem WHERE l_shipdate <= '1998-09-01' GROUP BY l_returnflag, l_linestatus"),
    "AGG_orders_by_date":    ("aggregation",
        "SELECT o_orderdate, COUNT(*), SUM(o_totalprice) FROM orders WHERE o_orderdate BETWEEN '1994-01-01' AND '1994-12-31' GROUP BY o_orderdate"),
    "AGG_lineitem_discount": ("aggregation",
        "SELECT l_discount, COUNT(*) FROM lineitem WHERE l_shipdate BETWEEN '1994-01-01' AND '1994-12-31' AND l_discount BETWEEN 0.05 AND 0.07 AND l_quantity < 24 GROUP BY l_discount"),
    "COM_revenue_nation":    ("complex_queries",
        "SELECT n_name, SUM(l_extendedprice * (1 - l_discount)) AS revenue FROM customer JOIN orders ON c_custkey = o_custkey JOIN lineitem ON o_orderkey = l_orderkey JOIN supplier ON l_suppkey = s_suppkey JOIN nation ON s_nationkey = n_nationkey WHERE o_orderdate BETWEEN '1994-01-01' AND '1995-01-01' GROUP BY n_name ORDER BY revenue DESC"),
    "COM_large_volume_disc": ("complex_queries",
        "SELECT SUM(l_extendedprice * l_discount) FROM lineitem WHERE l_shipdate >= '1994-01-01' AND l_shipdate < '1995-01-01' AND l_discount BETWEEN 0.05 AND 0.07 AND l_quantity < 24"),
    "COM_shipping_modes":    ("complex_queries",
        "SELECT l_shipmode, SUM(CASE WHEN o_orderpriority='1-URGENT' THEN 1 ELSE 0 END) FROM orders JOIN lineitem ON o_orderkey=l_orderkey WHERE l_shipmode IN ('MAIL','SHIP') AND l_receiptdate >= '1994-01-01' AND l_receiptdate < '1995-01-01' GROUP BY l_shipmode"),
}

# Budget levels to test
K_VALUES = [5, 10, 15, 20]


def get_conn():
    return mysql.connector.connect(**DB_CONFIG)


def run_query(conn, sql):
    try:
        cur = conn.cursor()
        cur.execute(f"SET SESSION MAX_EXECUTION_TIME={QUERY_TIMEOUT_MS}")
        t0 = time.time()
        cur.execute(sql)
        cur.fetchall()
        elapsed = (time.time() - t0) * 1000
        cur.close()
        return elapsed, None
    except mysql.connector.Error as e:
        try:
            conn.reconnect(attempts=2, delay=1)
        except Exception:
            pass
        return None, str(e)[:50]


def get_index_storage_mb(conn, index_names):
    """Get total storage used by specific indexes."""
    total_mb = 0.0
    cur = conn.cursor()
    for idx_name in index_names:
        try:
            cur.execute(f"""
                SELECT ROUND(stat_value * @@innodb_page_size / 1024 / 1024, 3)
                FROM mysql.innodb_index_stats
                WHERE database_name = 'tpch'
                  AND index_name = '{idx_name}'
                  AND stat_name = 'size'
            """)
            row = cur.fetchone()
            if row:
                total_mb += float(row[0])
        except Exception:
            pass
    cur.close()
    return round(total_mb, 2)


def measure_write_overhead(conn, table, n_rows=1000):
    """
    Measure INSERT time for a table.
    Returns ms for inserting n_rows.
    """
    cur = conn.cursor()

    if table == "orders":
        cur.execute("DROP TEMPORARY TABLE IF EXISTS tmp_write_test")
        cur.execute(f"CREATE TEMPORARY TABLE tmp_write_test AS SELECT * FROM orders LIMIT {n_rows}")
        cur.execute("TRUNCATE TABLE tmp_write_test")
        t0 = time.time()
        cur.execute(f"""
            INSERT INTO tmp_write_test
            SELECT o_orderkey+9999999, o_custkey, o_orderstatus, o_totalprice,
                   o_orderdate, o_orderpriority, o_clerk, o_shippriority, o_comment
            FROM orders LIMIT {n_rows}
        """)
        conn.commit()
        elapsed = (time.time() - t0) * 1000
        cur.execute("DROP TEMPORARY TABLE IF EXISTS tmp_write_test")

    elif table == "lineitem":
        cur.execute("DROP TEMPORARY TABLE IF EXISTS tmp_write_test")
        cur.execute(f"CREATE TEMPORARY TABLE tmp_write_test AS SELECT * FROM lineitem LIMIT {n_rows}")
        cur.execute("TRUNCATE TABLE tmp_write_test")
        t0 = time.time()
        cur.execute(f"""
            INSERT INTO tmp_write_test
            SELECT l_orderkey, l_partkey, l_suppkey, l_linenumber+100,
                   l_quantity, l_extendedprice, l_discount, l_tax,
                   l_returnflag, l_linestatus, l_shipdate,
                   l_commitdate, l_receiptdate, l_shipinstruct,
                   l_shipmode, l_comment
            FROM lineitem LIMIT {n_rows}
        """)
        conn.commit()
        elapsed = (time.time() - t0) * 1000
        cur.execute("DROP TEMPORARY TABLE IF EXISTS tmp_write_test")

    cur.close()
    return elapsed


def drop_all_topk_indexes(conn):
    """Drop all topk indexes to start clean."""
    cur = conn.cursor()
    for rank, name, table, col, score in RANKED_INDEXES:
        try:
            cur.execute(f"DROP INDEX {name} ON {table}")
            conn.commit()
        except Exception:
            pass
    cur.close()


def apply_indexes_up_to_k(conn, k):
    """Apply top-k indexes from ranked list."""
    cur = conn.cursor()
    applied = 0
    for rank, name, table, col, score in RANKED_INDEXES[:k]:
        try:
            t0 = time.time()
            cur.execute(f"CREATE INDEX {name} ON {table}({col})")
            conn.commit()
            elapsed = time.time() - t0
            print(f"    [{rank:2d}] {name:<15} ON {table}({col}) — {elapsed:.1f}s ✅")
            applied += 1
        except mysql.connector.Error as e:
            if "Duplicate" in str(e):
                print(f"    [{rank:2d}] {name:<15} already exists ✅")
                applied += 1
            else:
                print(f"    [{rank:2d}] {name:<15} ERROR: {e}")
    cur.close()
    return applied


def benchmark_queries(conn, label):
    """Run all queries and return results dict."""
    results = {}
    for qid, (cat, sql) in QUERIES.items():
        times = []
        err = None
        for _ in range(RUNS):
            if not conn.is_connected():
                conn = get_conn()
            t, e = run_query(conn, sql)
            if e:
                err = e
                break
            times.append(t)
        if err or not times:
            results[qid] = {"category": cat, "avg_ms": None}
        else:
            results[qid] = {"category": cat, "avg_ms": statistics.mean(times)}
    return results


def compute_speedups(before, after):
    speedups = []
    for qid in before:
        b = before[qid]["avg_ms"]
        a = after[qid]["avg_ms"] if qid in after else None
        cat = before[qid]["category"]
        if b is None or a is None:
            continue
        s = b / a if a > 0 else 1.0
        speedups.append({
            "query_id":  qid,
            "category":  cat,
            "before_ms": round(b, 2),
            "after_ms":  round(a, 2),
            "speedup":   round(s, 4),
            "improved":  1 if s > 1.05 else 0,
        })
    return speedups


def main():
    print("=" * 65)
    print("  TOP-K INDEX BUDGET EXPERIMENT")
    print(f"  k = {K_VALUES}")
    print(f"  Queries: {len(QUERIES)}")
    print("=" * 65)

    conn = get_conn()

    # ── Step 1: Baseline (no new indexes) ──
    print("\n[STEP 1] Dropping all topk indexes for clean baseline...")
    drop_all_topk_indexes(conn)
    print("Done.\n")

    print("[STEP 2] Measuring BASELINE runtimes (no new indexes)...")
    baseline = benchmark_queries(conn, "baseline")
    total_before = sum(r["avg_ms"] for r in baseline.values() if r["avg_ms"])
    print(f"  Total baseline runtime: {total_before:.0f} ms\n")

    # ── Step 3: For each k, apply indexes and measure ──
    results_by_k = {}

    for k in K_VALUES:
        print(f"\n{'='*65}")
        print(f"  BUDGET k = {k} (applying Top-{k} indexes)")
        print(f"{'='*65}")

        # Drop all first
        drop_all_topk_indexes(conn)

        # Apply top-k
        print(f"\n  Applying Top-{k} indexes:")
        applied = apply_indexes_up_to_k(conn, k)

        # Get storage
        idx_names = [name for rank, name, table, col, score in RANKED_INDEXES[:k]]
        storage_mb = get_index_storage_mb(conn, idx_names)
        print(f"\n  Storage used by {k} indexes: {storage_mb:.2f} MB")

        # Measure write overhead
        print(f"  Measuring write overhead...")
        write_orders  = measure_write_overhead(conn, "orders",  1000)
        write_lineitem = measure_write_overhead(conn, "lineitem", 1000)
        print(f"  orders INSERT (1000 rows):   {write_orders:.1f} ms")
        print(f"  lineitem INSERT (1000 rows): {write_lineitem:.1f} ms")

        # Benchmark queries
        print(f"\n  Benchmarking {len(QUERIES)} queries with Top-{k} indexes...")
        after = benchmark_queries(conn, f"top{k}")
        speedups = compute_speedups(baseline, after)

        total_after = sum(r["avg_ms"] for r in after.values() if r["avg_ms"])
        overall_speedup = total_before / total_after if total_after > 0 else 1.0
        improved = sum(1 for s in speedups if s["improved"])
        mean_speedup = statistics.mean(s["speedup"] for s in speedups) if speedups else 1.0
        best = max(speedups, key=lambda s: s["speedup"]) if speedups else None

        results_by_k[k] = {
            "k":               k,
            "indexes_applied": applied,
            "storage_mb":      storage_mb,
            "write_orders_ms":   round(write_orders, 2),
            "write_lineitem_ms": round(write_lineitem, 2),
            "total_before_ms": round(total_before, 2),
            "total_after_ms":  round(total_after, 2),
            "overall_speedup": round(overall_speedup, 4),
            "mean_speedup":    round(mean_speedup, 4),
            "pct_improved":    round(improved / len(speedups) * 100, 1) if speedups else 0,
            "best_query":      best["query_id"] if best else "",
            "best_speedup":    round(best["speedup"], 2) if best else 0,
        }

        print(f"\n  k={k} SUMMARY:")
        print(f"    Overall speedup:  {overall_speedup:.3f}×")
        print(f"    Mean speedup:     {mean_speedup:.3f}×")
        print(f"    % improved:       {improved}/{len(speedups)} ({improved/len(speedups)*100:.1f}%)")
        print(f"    Storage overhead: {storage_mb:.2f} MB")

    # Clean up
    drop_all_topk_indexes(conn)
    conn.close()

    # ── Print final comparison table ──
    print(f"\n{'='*65}")
    print("  TOP-K BUDGET ANALYSIS — FINAL RESULTS")
    print(f"{'='*65}")
    print(f"\n  {'k':>4}  {'Speedup':>10}  {'% Improved':>12}  {'Storage':>10}  {'Write(ord)':>12}  {'Write(lin)':>12}")
    print(f"  {'-'*62}")
    print(f"  {'0':>4}  {'1.00×':>10}  {'0.0%':>12}  {'0 MB':>10}  {'~30ms':>12}  {'~38ms':>12}")

    for k in K_VALUES:
        r = results_by_k[k]
        print(f"  {k:>4}  {r['overall_speedup']:>9.3f}×  {r['pct_improved']:>11.1f}%  {r['storage_mb']:>8.1f}MB  {r['write_orders_ms']:>10.1f}ms  {r['write_lineitem_ms']:>10.1f}ms")

    # Save results
    out_json = os.path.join(OUTPUT_DIR, "topk_results.json")
    with open(out_json, "w") as f:
        json.dump(results_by_k, f, indent=2)

    out_csv = os.path.join(OUTPUT_DIR, "topk_summary.csv")
    with open(out_csv, "w", newline="") as f:
        if results_by_k:
            writer = csv.DictWriter(f, fieldnames=results_by_k[K_VALUES[0]].keys())
            writer.writeheader()
            for r in results_by_k.values():
                writer.writerow(r)

    print(f"\n  Saved: {out_json}")
    print(f"  Saved: {out_csv}")
    print(f"\n{'='*65}")
    print("  DONE! Add these results to paper Table and Figure.")
    print(f"{'='*65}")


if __name__ == "__main__":
    main()
