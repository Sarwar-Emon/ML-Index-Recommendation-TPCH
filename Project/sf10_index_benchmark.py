"""
SF-10 Before/After Index Benchmark
====================================
Applies ML-recommended indexes to tpch_sf10
then measures speedup for paper comparison table
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

OUTPUT_DIR = "sf10_results"
os.makedirs(OUTPUT_DIR, exist_ok=True)

QUERY_TIMEOUT_MS = 120000  # 2 minutes
RUNS             = 3

# ── INDEXES to apply (same as SF-1 ML recommendations)
INDEXES = [
    ("idx_sf10_nationkey",    "nation",    "n_nationkey"),
    ("idx_sf10_r_name",       "region",    "r_name"),
    ("idx_sf10_n_name",       "nation",    "n_name"),
    ("idx_sf10_l_shipmode",   "lineitem",  "l_shipmode"),
    ("idx_sf10_o_custkey",    "orders",    "o_custkey"),
    ("idx_sf10_l_discount",   "lineitem",  "l_discount"),
    ("idx_sf10_o_totalprice", "orders",    "o_totalprice"),
    ("idx_sf10_l_shipdate",   "lineitem",  "l_shipdate"),
    ("idx_sf10_r_regionkey",  "region",    "r_regionkey"),
    ("idx_sf10_o_orderdate",  "orders",    "o_orderdate"),
    ("idx_sf10_o_orderstatus","orders",    "o_orderstatus"),
    ("idx_sf10_l_returnflag", "lineitem",  "l_returnflag"),
    ("idx_sf10_l_quantity",   "lineitem",  "l_quantity"),
    ("idx_sf10_c_mktsegment", "customer",  "c_mktsegment"),
    ("idx_sf10_o_priority",   "orders",    "o_orderpriority"),
    ("idx_sf10_l_linestatus", "lineitem",  "l_linestatus"),
    ("idx_sf10_p_type",       "part",      "p_type"),
    ("idx_sf10_p_brand",      "part",      "p_brand"),
    ("idx_sf10_s_nationkey",  "supplier",  "s_nationkey"),
    ("idx_sf10_c_nationkey",  "customer",  "c_nationkey"),
]

# ── Same queries as sf10_benchmark.py
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
        "SELECT l_shipmode, COUNT(*), AVG(l_discount) FROM lineitem GROUP BY l_shipmode"),
    "AGG_customer_segment":    ("aggregation",
        "SELECT c_mktsegment, COUNT(*), AVG(c_acctbal) FROM customer GROUP BY c_mktsegment"),
    "AGG_supplier_nation":     ("aggregation",
        "SELECT n_name, COUNT(*), AVG(s_acctbal) FROM supplier JOIN nation ON s_nationkey = n_nationkey GROUP BY n_name ORDER BY COUNT(*) DESC"),
    "AGG_lineitem_discount":   ("aggregation",
        "SELECT l_discount, COUNT(*), SUM(l_extendedprice * l_discount) FROM lineitem WHERE l_shipdate BETWEEN '1994-01-01' AND '1994-12-31' GROUP BY l_discount"),
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
    return mysql.connector.connect(**DB_CONFIG)


def run_query(conn, sql, timeout_ms=QUERY_TIMEOUT_MS):
    try:
        cur = conn.cursor()
        cur.execute(f"SET SESSION MAX_EXECUTION_TIME={timeout_ms}")
        start = time.time()
        cur.execute(sql)
        cur.fetchall()
        elapsed = (time.time() - start) * 1000
        cur.close()
        return elapsed, None
    except mysql.connector.Error as e:
        return None, str(e)


def benchmark_all(label):
    print(f"\n{'='*60}")
    print(f"  Running queries: {label}")
    print(f"{'='*60}")

    results = {}
    conn = get_conn()

    for qid, (cat, sql) in QUERIES.items():
        print(f"  {qid:<40}", end="", flush=True)
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
            print(f"  SKIP ({err or 'timeout'})")
            results[qid] = {"category": cat, "avg_ms": None, "error": err}
        else:
            avg = statistics.mean(times)
            print(f"  {avg:9.1f} ms")
            results[qid] = {"category": cat, "avg_ms": avg, "error": None}

    conn.close()
    return results


def apply_indexes():
    print(f"\n{'='*60}")
    print("  Applying ML-recommended indexes to tpch_sf10")
    print(f"{'='*60}")
    conn = get_conn()
    cur  = conn.cursor()

    applied = 0
    for idx_name, table, column in INDEXES:
        try:
            print(f"  CREATE INDEX {idx_name} ON {table}({column})...", end="", flush=True)
            start = time.time()
            cur.execute(f"CREATE INDEX {idx_name} ON {table}({column})")
            conn.commit()
            elapsed = time.time() - start
            print(f"  {elapsed:.1f}s ✅")
            applied += 1
        except mysql.connector.Error as e:
            if "Duplicate" in str(e):
                print(f"  already exists ✅")
                applied += 1
            else:
                print(f"  ERROR: {e}")

    cur.close()
    conn.close()
    print(f"\n  Applied {applied}/{len(INDEXES)} indexes")


def compute_speedups(before, after):
    results = []
    for qid in before:
        if qid not in after:
            continue
        b = before[qid]["avg_ms"]
        a = after[qid]["avg_ms"]
        cat = before[qid]["category"]
        if b is None or a is None:
            continue
        speedup = b / a if a > 0 else 1.0
        results.append({
            "query_id":    qid,
            "category":    cat,
            "before_ms":   round(b, 2),
            "after_ms":    round(a, 2),
            "speedup":     round(speedup, 4),
            "improved":    1 if speedup > 1.05 else 0,
        })
    return results


def main():
    print("=" * 60)
    print("  TPC-H SF-10 Before/After Index Benchmark")
    print("=" * 60)

    # Step 1: benchmark BEFORE indexes
    before = benchmark_all("BEFORE indexes")

    # Step 2: apply indexes
    apply_indexes()

    # Step 3: benchmark AFTER indexes
    after = benchmark_all("AFTER indexes")

    # Step 4: compute speedups
    speedups = compute_speedups(before, after)

    # Save CSV
    csv_path = os.path.join(OUTPUT_DIR, "sf10_before_after.csv")
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=speedups[0].keys())
        writer.writeheader()
        writer.writerows(speedups)

    # Summary by category
    print(f"\n{'='*60}")
    print("  SF-10 BEFORE vs AFTER SUMMARY")
    print(f"{'='*60}")
    print(f"  {'Category':<25} {'Before':>10} {'After':>10} {'Speedup':>10}")
    print(f"  {'-'*55}")

    cats = {}
    for r in speedups:
        c = r["category"]
        if c not in cats:
            cats[c] = {"before":[], "after":[], "speedup":[]}
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
        improved = sum(1 for s in vals["speedup"] if s > 1.05)
        pct = improved / len(vals["speedup"]) * 100
        print(f"  {cat:<25} {avg_b:>9.0f}ms {avg_a:>9.0f}ms {avg_s:>9.2f}x")
        cat_summary[cat] = {
            "avg_before_ms": round(avg_b,1),
            "avg_after_ms":  round(avg_a,1),
            "avg_speedup":   round(avg_s,4),
            "pct_improved":  round(pct,1),
            "n_queries":     len(vals["speedup"]),
        }

    print(f"  {'-'*55}")
    print(f"  {'OVERALL':<25} {total_before:>9.0f}ms {total_after:>9.0f}ms {overall:>9.2f}x")

    improved_total = sum(1 for r in speedups if r["improved"])
    best = max(speedups, key=lambda r: r["speedup"])

    print(f"\n  Queries improved (>5%): {improved_total}/{len(speedups)} "
          f"({improved_total/len(speedups)*100:.1f}%)")
    print(f"  Best individual speedup: {best['query_id']} = {best['speedup']:.1f}x "
          f"({best['before_ms']:.0f}ms → {best['after_ms']:.0f}ms)")
    print(f"  Mean per-query speedup:  "
          f"{statistics.mean(r['speedup'] for r in speedups):.2f}x")

    # Save summary JSON
    summary = {
        "scale_factor":   10,
        "n_queries":      len(speedups),
        "overall_speedup": round(overall, 4),
        "mean_speedup":   round(statistics.mean(r["speedup"] for r in speedups), 4),
        "best_speedup":   round(best["speedup"], 4),
        "best_query":     best["query_id"],
        "pct_improved":   round(improved_total/len(speedups)*100, 1),
        "total_before_ms": round(total_before, 2),
        "total_after_ms":  round(total_after, 2),
        "categories":     cat_summary,
    }
    with open(os.path.join(OUTPUT_DIR, "sf10_summary_full.json"), "w") as f:
        json.dump(summary, f, indent=2)

    print(f"\n  Saved: {csv_path}")
    print(f"  Saved: {OUTPUT_DIR}/sf10_summary_full.json")
    print("=" * 60)


if __name__ == "__main__":
    main()
