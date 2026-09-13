"""
Smart SF-10 Before/After Benchmark
====================================
Uses ONLY high-selectivity and composite indexes
Excludes low-selectivity single-column indexes
that hurt aggregation performance at SF-10
"""

import mysql.connector
import csv
import time
import os
import json
import statistics

DB_CONFIG = {
    "host":     "127.0.0.1",
    "port":     3306,
    "user":     "root",
    "password": "sayem1288",
    "database": "tpch_sf10",
    "connection_timeout": 600,
}

OUTPUT_DIR = "/Users/sayememon/Desktop/Troy Courses/Adv Database System/Project/sf10_results"
os.makedirs(OUTPUT_DIR, exist_ok=True)

QUERY_TIMEOUT_MS = 180000
RUNS = 3

# ── SMART INDEX LIST ──────────────────────────────────
# Only HIGH-SELECTIVITY and COMPOSITE indexes
# Removed: l_returnflag (3 vals), l_discount (11 vals),
#          l_shipmode (7 vals), l_quantity (50 vals)
# Added:   composite indexes for aggregation queries

SMART_INDEXES = [
    # High-selectivity single-column (safe to add)
    ("idx_sf10_nationkey",    "nation",    "n_nationkey",                   None),
    ("idx_sf10_r_name",       "region",    "r_name",                        None),
    ("idx_sf10_n_name",       "nation",    "n_name",                        None),
    ("idx_sf10_o_custkey",    "orders",    "o_custkey",                     None),
    ("idx_sf10_o_totalprice", "orders",    "o_totalprice",                  None),
    ("idx_sf10_l_shipdate",   "lineitem",  "l_shipdate",                    None),
    ("idx_sf10_r_regionkey",  "region",    "r_regionkey",                   None),
    ("idx_sf10_o_orderdate",  "orders",    "o_orderdate",                   None),
    ("idx_sf10_o_orderstatus","orders",    "o_orderstatus",                 None),
    ("idx_sf10_c_mktsegment", "customer",  "c_mktsegment",                  None),
    ("idx_sf10_o_priority",   "orders",    "o_orderpriority",               None),
    ("idx_sf10_l_linestatus", "lineitem",  "l_linestatus",                  None),
    ("idx_sf10_p_type",       "part",      "p_type",                        None),
    ("idx_sf10_p_brand",      "part",      "p_brand",                       None),
    ("idx_sf10_s_nationkey",  "supplier",  "s_nationkey",                   None),
    ("idx_sf10_c_nationkey",  "customer",  "c_nationkey",                   None),

    # Composite indexes for aggregation queries
    # Covers: l_shipdate filter + l_returnflag + l_shipmode GROUP BY
    ("idx_sf10_composite",    "lineitem",
     "l_shipdate, l_returnflag, l_shipmode",                               "COMPOSITE"),
    # Covers: l_discount filter + l_quantity condition
    ("idx_sf10_disc_qty",     "lineitem",
     "l_discount, l_quantity",                                             "COMPOSITE"),
]

# ── Queries ────────────────────────────────────────────
QUERIES = {
    "SIN_orders_custkey":    ("single_table_filters",
        "SELECT * FROM orders WHERE o_custkey = 1000"),
    "SIN_orders_orderdate":  ("single_table_filters",
        "SELECT * FROM orders WHERE o_orderdate BETWEEN '1994-01-01' AND '1994-12-31'"),
    "SIN_orders_totalprice": ("single_table_filters",
        "SELECT * FROM orders WHERE o_totalprice > 200000"),
    "SIN_supplier_nation":   ("single_table_filters",
        "SELECT * FROM supplier WHERE s_nationkey = 5"),
    "SIN_part_type":         ("single_table_filters",
        "SELECT * FROM part WHERE p_type = 'ECONOMY ANODIZED STEEL'"),
    "SIN_customer_market":   ("single_table_filters",
        "SELECT * FROM customer WHERE c_mktsegment = 'BUILDING'"),
    "SIN_lineitem_shipdate": ("single_table_filters",
        "SELECT l_orderkey, l_quantity FROM lineitem WHERE l_shipdate = '1995-01-01'"),
    "SIN_lineitem_quantity": ("single_table_filters",
        "SELECT COUNT(*) FROM lineitem WHERE l_quantity > 45"),
    "SIN_orders_status":     ("single_table_filters",
        "SELECT COUNT(*) FROM orders WHERE o_orderstatus = 'F'"),
    "SIN_part_brand":        ("single_table_filters",
        "SELECT COUNT(*) FROM part WHERE p_brand = 'Brand#13'"),
    "TWO_orders_customer":   ("two_table_joins",
        "SELECT o_orderkey, c_name FROM orders JOIN customer ON o_custkey = c_custkey WHERE c_mktsegment = 'BUILDING' LIMIT 1000"),
    "TWO_lineitem_orders":   ("two_table_joins",
        "SELECT l_orderkey, o_orderdate FROM lineitem JOIN orders ON l_orderkey = o_orderkey WHERE o_orderdate > '1995-01-01' LIMIT 1000"),
    "TWO_supplier_nation":   ("two_table_joins",
        "SELECT s_name, n_name FROM supplier JOIN nation ON s_nationkey = n_nationkey WHERE n_name = 'UNITED STATES'"),
    "TWO_part_partsupp":     ("two_table_joins",
        "SELECT p_name, ps_availqty FROM part JOIN partsupp ON p_partkey = ps_partkey WHERE ps_availqty > 9000 LIMIT 1000"),
    "TWO_customer_orders":   ("two_table_joins",
        "SELECT c_name, COUNT(*) as order_count FROM customer JOIN orders ON c_custkey = o_custkey GROUP BY c_custkey LIMIT 500"),
    "TWO_orders_lineitem_agg":("two_table_joins",
        "SELECT o_orderdate, SUM(l_extendedprice) FROM orders JOIN lineitem ON o_orderkey = l_orderkey WHERE o_orderdate BETWEEN '1994-01-01' AND '1994-03-31' GROUP BY o_orderdate"),
    "TWO_nation_supplier":   ("two_table_joins",
        "SELECT n_name, COUNT(*) FROM nation JOIN supplier ON n_nationkey = s_nationkey GROUP BY n_name"),
    "TWO_part_supplier":     ("two_table_joins",
        "SELECT p_brand, AVG(ps_supplycost) FROM part JOIN partsupp ON p_partkey = ps_partkey GROUP BY p_brand LIMIT 100"),
    "THR_lineitem_orders_customer": ("three_table_joins",
        "SELECT c_name, o_orderdate, SUM(l_extendedprice) FROM customer JOIN orders ON c_custkey = o_custkey JOIN lineitem ON o_orderkey = l_orderkey WHERE o_orderdate BETWEEN '1994-01-01' AND '1994-06-30' GROUP BY c_custkey, o_orderkey LIMIT 500"),
    "THR_supplier_nation_region":   ("three_table_joins",
        "SELECT s_name, n_name, r_name FROM supplier JOIN nation ON s_nationkey = n_nationkey JOIN region ON n_regionkey = r_regionkey WHERE r_name = 'AMERICA'"),
    "THR_part_partsupp_supplier":   ("three_table_joins",
        "SELECT p_name, s_name, ps_supplycost FROM part JOIN partsupp ON p_partkey = ps_partkey JOIN supplier ON ps_suppkey = s_suppkey WHERE ps_supplycost < 100 LIMIT 500"),
    "THR_customer_nation_region":   ("three_table_joins",
        "SELECT c_name, n_name, r_name FROM customer JOIN nation ON c_nationkey = n_nationkey JOIN region ON n_regionkey = r_regionkey WHERE r_name = 'EUROPE' LIMIT 500"),
    "AGG_lineitem_returnflag": ("aggregation",
        "SELECT l_returnflag, l_linestatus, SUM(l_quantity), SUM(l_extendedprice), COUNT(*) FROM lineitem WHERE l_shipdate <= '1998-09-01' GROUP BY l_returnflag, l_linestatus"),
    "AGG_orders_by_date":      ("aggregation",
        "SELECT o_orderdate, COUNT(*), SUM(o_totalprice) FROM orders WHERE o_orderdate BETWEEN '1994-01-01' AND '1994-12-31' GROUP BY o_orderdate ORDER BY o_orderdate"),
    "AGG_lineitem_shipmode":   ("aggregation",
        "SELECT l_shipmode, COUNT(*), AVG(l_discount) FROM lineitem WHERE l_shipdate BETWEEN '1994-01-01' AND '1995-01-01' GROUP BY l_shipmode"),
    "AGG_customer_segment":    ("aggregation",
        "SELECT c_mktsegment, COUNT(*), AVG(c_acctbal) FROM customer GROUP BY c_mktsegment"),
    "AGG_supplier_nation":     ("aggregation",
        "SELECT n_name, COUNT(*), AVG(s_acctbal) FROM supplier JOIN nation ON s_nationkey = n_nationkey GROUP BY n_name ORDER BY COUNT(*) DESC"),
    "AGG_lineitem_discount":   ("aggregation",
        "SELECT l_discount, COUNT(*), SUM(l_extendedprice * l_discount) FROM lineitem WHERE l_shipdate BETWEEN '1994-01-01' AND '1994-12-31' AND l_discount BETWEEN 0.05 AND 0.07 AND l_quantity < 24 GROUP BY l_discount"),
    "AGG_part_container":      ("aggregation",
        "SELECT p_container, COUNT(*), AVG(p_retailprice) FROM part GROUP BY p_container"),
    "AGG_orders_priority":     ("aggregation",
        "SELECT o_orderpriority, COUNT(*) FROM orders WHERE o_orderdate BETWEEN '1993-07-01' AND '1993-10-01' GROUP BY o_orderpriority"),
    "COM_revenue_by_nation":   ("complex_queries",
        "SELECT n_name, SUM(l_extendedprice * (1 - l_discount)) AS revenue FROM customer JOIN orders ON c_custkey = o_custkey JOIN lineitem ON o_orderkey = l_orderkey JOIN supplier ON l_suppkey = s_suppkey JOIN nation ON s_nationkey = n_nationkey WHERE o_orderdate BETWEEN '1994-01-01' AND '1995-01-01' GROUP BY n_name ORDER BY revenue DESC"),
    "COM_large_volume_disc":   ("complex_queries",
        "SELECT SUM(l_extendedprice * l_discount) AS revenue FROM lineitem WHERE l_shipdate >= '1994-01-01' AND l_shipdate < '1995-01-01' AND l_discount BETWEEN 0.05 AND 0.07 AND l_quantity < 24"),
    "COM_shipping_modes":      ("complex_queries",
        "SELECT l_shipmode, SUM(CASE WHEN o_orderpriority='1-URGENT' OR o_orderpriority='2-HIGH' THEN 1 ELSE 0 END) AS high_line_count FROM orders JOIN lineitem ON o_orderkey=l_orderkey WHERE l_shipmode IN ('MAIL','SHIP') AND l_commitdate < l_receiptdate AND l_shipdate < l_commitdate AND l_receiptdate >= '1994-01-01' AND l_receiptdate < '1995-01-01' GROUP BY l_shipmode"),
}


def get_conn():
    conn = mysql.connector.connect(**DB_CONFIG)
    cur  = conn.cursor()
    cur.execute("SET SESSION MAX_EXECUTION_TIME=0")
    cur.execute("SET SESSION wait_timeout=28800")
    cur.close()
    return conn


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
            conn.reconnect(attempts=3, delay=2)
        except Exception:
            pass
        return None, str(e)[:60]


def benchmark_all(label):
    print(f"\n{'='*60}")
    print(f"  Running: {label}")
    print(f"{'='*60}")
    conn    = get_conn()
    results = {}
    for qid, (cat, sql) in QUERIES.items():
        print(f"  {qid:<40}", end="", flush=True)
        times = []
        err   = None
        for _ in range(RUNS):
            if not conn.is_connected():
                conn = get_conn()
            t, e = run_query(conn, sql)
            if e:
                err = e
                break
            times.append(t)
        if err or not times:
            print(f"  SKIP ({err or 'timeout'})")
            results[qid] = {"category": cat, "avg_ms": None}
        else:
            avg = statistics.mean(times)
            print(f"  {avg:10.1f} ms")
            results[qid] = {"category": cat, "avg_ms": avg}
    conn.close()
    return results


def apply_smart_indexes():
    print(f"\n{'='*60}")
    print("  Applying SMART indexes (high-selectivity + composite)")
    print(f"{'='*60}")
    conn = get_conn()
    cur  = conn.cursor()
    applied = 0
    for idx_name, table, columns, idx_type in SMART_INDEXES:
        label = f"{'COMPOSITE ' if idx_type else ''}{table}({columns})"
        print(f"  {idx_name:<35}", end="", flush=True)
        try:
            start = time.time()
            cur.execute(f"CREATE INDEX {idx_name} ON {table}({columns})")
            conn.commit()
            elapsed = time.time() - start
            print(f"  {elapsed:.1f}s ✅")
            applied += 1
        except mysql.connector.Error as e:
            if "Duplicate" in str(e) or "already exists" in str(e).lower():
                print(f"  already exists ✅")
                applied += 1
            else:
                print(f"  ERROR: {e}")
    cur.close()
    conn.close()
    print(f"\n  Applied {applied}/{len(SMART_INDEXES)} indexes")
    print(f"  NOTE: Low-selectivity single-column indexes EXCLUDED")
    print(f"  (l_returnflag, l_discount, l_shipmode, l_quantity)")
    print(f"  Replaced by composite indexes for better aggregation!")


def main():
    print("=" * 60)
    print("  TPC-H SF-10 Smart Before/After Benchmark")
    print("  (High-selectivity + Composite Indexes Only)")
    print("=" * 60)

    before = benchmark_all("BEFORE indexes")
    apply_smart_indexes()
    after  = benchmark_all("AFTER smart indexes")

    # Compute speedups
    speedups = []
    for qid in before:
        if qid not in after:
            continue
        b = before[qid]["avg_ms"]
        a = after[qid]["avg_ms"]
        cat = before[qid]["category"]
        if b is None or a is None:
            continue
        s = b / a if a > 0 else 1.0
        speedups.append({"query_id": qid, "category": cat,
                         "before_ms": round(b,2), "after_ms": round(a,2),
                         "speedup": round(s,4), "improved": 1 if s > 1.05 else 0})

    # Category summary
    print(f"\n{'='*60}")
    print("  SF-10 SMART INDEX RESULTS")
    print(f"{'='*60}")
    print(f"  {'Category':<25} {'Before':>10} {'After':>10} {'Speedup':>10}")
    print(f"  {'-'*57}")

    cats = {}
    for r in speedups:
        c = r["category"]
        if c not in cats:
            cats[c] = {"before":[],"after":[],"speedup":[]}
        cats[c]["before"].append(r["before_ms"])
        cats[c]["after"].append(r["after_ms"])
        cats[c]["speedup"].append(r["speedup"])

    total_before = sum(r["before_ms"] for r in speedups)
    total_after  = sum(r["after_ms"]  for r in speedups)
    overall      = total_before / total_after if total_after > 0 else 1.0

    cat_summary = {}
    for cat, vals in sorted(cats.items()):
        avg_b = statistics.mean(vals["before"])
        avg_a = statistics.mean(vals["after"])
        avg_s = statistics.mean(vals["speedup"])
        pct   = sum(1 for s in vals["speedup"] if s > 1.05) / len(vals["speedup"]) * 100
        print(f"  {cat:<25} {avg_b:>9.0f}ms {avg_a:>9.0f}ms {avg_s:>9.2f}x")
        cat_summary[cat] = {"avg_before_ms": round(avg_b,1),
                             "avg_after_ms":  round(avg_a,1),
                             "avg_speedup":   round(avg_s,4),
                             "pct_improved":  round(pct,1)}

    print(f"  {'-'*57}")
    print(f"  {'OVERALL':<25} {total_before:>9.0f}ms {total_after:>9.0f}ms {overall:>9.2f}x")

    improved = sum(1 for r in speedups if r["improved"])
    best     = max(speedups, key=lambda r: r["speedup"])
    mean_s   = statistics.mean(r["speedup"] for r in speedups)

    print(f"\n  Queries improved (>5%): {improved}/{len(speedups)} ({improved/len(speedups)*100:.1f}%)")
    print(f"  Best speedup: {best['query_id']} = {best['speedup']:.1f}x")
    print(f"  Mean speedup: {mean_s:.2f}x")
    print(f"  Overall:      {overall:.2f}x")

    # Save
    csv_path = os.path.join(OUTPUT_DIR, "sf10_smart_before_after.csv")
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=speedups[0].keys())
        writer.writeheader()
        writer.writerows(speedups)

    summary = {
        "scale_factor":    10,
        "index_strategy":  "smart_selective_composite",
        "n_queries":       len(speedups),
        "overall_speedup": round(overall, 4),
        "mean_speedup":    round(mean_s, 4),
        "best_speedup":    round(best["speedup"], 4),
        "best_query":      best["query_id"],
        "pct_improved":    round(improved/len(speedups)*100, 1),
        "categories":      cat_summary,
    }
    with open(os.path.join(OUTPUT_DIR, "sf10_smart_summary.json"), "w") as f:
        json.dump(summary, f, indent=2)

    print(f"\n  Saved: {csv_path}")
    print("=" * 60)


if __name__ == "__main__":
    main()
