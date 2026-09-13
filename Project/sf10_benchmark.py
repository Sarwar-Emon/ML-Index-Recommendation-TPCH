"""
SF-10 Scalability Benchmark for Paper
======================================
Runs representative queries on TPC-H SF-10
Uses query timeout to skip queries that take too long
Reports results suitable for paper comparison table
"""

import mysql.connector
import csv
import time
import os
import json
import statistics

# ── CONFIG ──────────────────────────────────────────
DB_CONFIG = {
    "host":     "127.0.0.1",
    "port":     3306,
    "user":     "root",
    "password": "sayem1288",
    "database": "tpch_sf10",
    "connection_timeout": 300,
}

OUTPUT_DIR = "sf10_results"
os.makedirs(OUTPUT_DIR, exist_ok=True)

QUERY_TIMEOUT_SEC = 120   # skip queries taking more than 2 min
RUNS_PER_QUERY    = 3     # same as SF-1 paper

# ── REPRESENTATIVE QUERIES ───────────────────────────
# One from each category type — same structure as SF-1 queries
# These match the categories in your paper

QUERIES = {
    # ── Single-Table Filters (use indexed columns)
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

    # ── Two-Table Joins
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

    # ── Three-Table Joins
    "THR_lineitem_orders_customer": ("three_table_joins",
        "SELECT c_name, o_orderdate, SUM(l_extendedprice) FROM customer JOIN orders ON c_custkey = o_custkey JOIN lineitem ON o_orderkey = l_orderkey WHERE o_orderdate BETWEEN '1994-01-01' AND '1994-06-30' GROUP BY c_custkey, o_orderkey LIMIT 500"),
    "THR_supplier_nation_region":   ("three_table_joins",
        "SELECT s_name, n_name, r_name FROM supplier JOIN nation ON s_nationkey = n_nationkey JOIN region ON n_regionkey = r_regionkey WHERE r_name = 'AMERICA'"),
    "THR_part_partsupp_supplier":   ("three_table_joins",
        "SELECT p_name, s_name, ps_supplycost FROM part JOIN partsupp ON p_partkey = ps_partkey JOIN supplier ON ps_suppkey = s_suppkey WHERE ps_supplycost < 100 LIMIT 500"),
    "THR_orders_lineitem_part":     ("three_table_joins",
        "SELECT p_brand, SUM(l_quantity) FROM orders JOIN lineitem ON o_orderkey = l_orderkey JOIN part ON l_partkey = p_partkey WHERE o_orderdate > '1995-01-01' GROUP BY p_brand LIMIT 100"),
    "THR_customer_nation_region":   ("three_table_joins",
        "SELECT c_name, n_name, r_name FROM customer JOIN nation ON c_nationkey = n_nationkey JOIN region ON n_regionkey = r_regionkey WHERE r_name = 'EUROPE' LIMIT 500"),

    # ── Aggregation Queries
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

    # ── Complex Queries
    "COM_revenue_by_nation":   ("complex_queries",
        "SELECT n_name, SUM(l_extendedprice * (1 - l_discount)) AS revenue FROM customer JOIN orders ON c_custkey = o_custkey JOIN lineitem ON o_orderkey = l_orderkey JOIN supplier ON l_suppkey = s_suppkey JOIN nation ON s_nationkey = n_nationkey WHERE o_orderdate BETWEEN '1994-01-01' AND '1995-01-01' GROUP BY n_name ORDER BY revenue DESC"),
    "COM_top_suppliers":       ("complex_queries",
        "SELECT s_name, COUNT(*) as cnt FROM supplier JOIN lineitem ON s_suppkey = l_suppkey JOIN orders ON l_orderkey = o_orderkey WHERE o_orderstatus = 'F' AND l_receiptdate > l_commitdate GROUP BY s_suppkey ORDER BY cnt DESC LIMIT 100"),
    "COM_market_share":        ("complex_queries",
        "SELECT o_orderdate, SUM(CASE WHEN n_name='BRAZIL' THEN l_extendedprice*(1-l_discount) ELSE 0 END) / SUM(l_extendedprice*(1-l_discount)) AS mkt_share FROM customer JOIN orders ON c_custkey=o_custkey JOIN lineitem ON o_orderkey=l_orderkey JOIN supplier ON l_suppkey=s_suppkey JOIN nation n1 ON c_nationkey=n1.n_nationkey JOIN nation n2 ON s_nationkey=n2.n_nationkey JOIN region ON n1.n_regionkey=r_regionkey WHERE r_name='AMERICA' AND o_orderdate BETWEEN '1995-01-01' AND '1996-12-31' AND p_type='ECONOMY ANODIZED STEEL' GROUP BY o_orderdate"),
    "COM_large_volume_disc":   ("complex_queries",
        "SELECT SUM(l_extendedprice * l_discount) AS revenue FROM lineitem WHERE l_shipdate >= '1994-01-01' AND l_shipdate < '1995-01-01' AND l_discount BETWEEN 0.05 AND 0.07 AND l_quantity < 24"),
    "COM_shipping_modes":      ("complex_queries",
        "SELECT l_shipmode, SUM(CASE WHEN o_orderpriority='1-URGENT' OR o_orderpriority='2-HIGH' THEN 1 ELSE 0 END) AS high_line_count FROM orders JOIN lineitem ON o_orderkey=l_orderkey WHERE l_shipmode IN ('MAIL','SHIP') AND l_commitdate < l_receiptdate AND l_shipdate < l_commitdate AND l_receiptdate >= '1994-01-01' AND l_receiptdate < '1995-01-01' GROUP BY l_shipmode"),
}

# ── RUN BENCHMARK ────────────────────────────────────

def run_with_timeout(cursor, sql, timeout_sec):
    """Run query with timeout, return (runtime_ms, rows, error)"""
    try:
        cursor.execute(f"SET SESSION MAX_EXECUTION_TIME={timeout_sec * 1000}")
        start = time.time()
        cursor.execute(sql)
        cursor.fetchall()
        elapsed = (time.time() - start) * 1000
        return elapsed, None
    except mysql.connector.Error as e:
        return None, str(e)

def main():
    print("=" * 60)
    print("  TPC-H SF-10 Scalability Benchmark")
    print(f"  Queries: {len(QUERIES)}")
    print(f"  Runs/query: {RUNS_PER_QUERY}")
    print(f"  Timeout: {QUERY_TIMEOUT_SEC}s per run")
    print("=" * 60)

    results = []
    errors  = []

    conn   = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()
    print(f"\nConnected to tpch_sf10 ✅\n")

    total = len(QUERIES)
    for idx, (qid, (category, sql)) in enumerate(QUERIES.items(), 1):
        print(f"[{idx:3d}/{total}] {qid:<40}", end="", flush=True)

        runtimes = []
        error    = None

        for run in range(RUNS_PER_QUERY):
            # Reconnect if connection lost
            if not conn.is_connected():
                conn = mysql.connector.connect(**DB_CONFIG)
                cursor = conn.cursor()

            elapsed, err = run_with_timeout(cursor, sql, QUERY_TIMEOUT_SEC)

            if err:
                error = err
                break
            runtimes.append(elapsed)

        if error or not runtimes:
            print(f"  TIMEOUT/ERROR")
            errors.append({"query_id": qid, "category": category, "error": error or "timeout"})
        else:
            avg = statistics.mean(runtimes)
            print(f"  {avg:8.1f} ms")
            results.append({
                "query_id":       qid,
                "category":       category,
                "avg_runtime_ms": round(avg, 4),
                "min_runtime_ms": round(min(runtimes), 4),
                "max_runtime_ms": round(max(runtimes), 4),
                "runs":           len(runtimes),
                "status":         "OK",
                "sql":            sql[:80],
            })

    cursor.close()
    conn.close()

    # ── Save results
    out_csv = os.path.join(OUTPUT_DIR, "sf10_runtime_results.csv")
    if results:
        with open(out_csv, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=results[0].keys())
            writer.writeheader()
            writer.writerows(results)

    err_csv = os.path.join(OUTPUT_DIR, "sf10_errors.csv")
    if errors:
        with open(err_csv, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["query_id","category","error"])
            writer.writeheader()
            writer.writerows(errors)

    # ── Summary by category
    print("\n" + "=" * 60)
    print("  RESULTS SUMMARY BY CATEGORY")
    print("=" * 60)

    categories = {}
    for r in results:
        cat = r["category"]
        if cat not in categories:
            categories[cat] = []
        categories[cat].append(r["avg_runtime_ms"])

    total_before = 0
    cat_summary  = {}
    for cat, times in sorted(categories.items()):
        avg = statistics.mean(times)
        total_before += sum(times)
        cat_summary[cat] = {"count": len(times), "avg_ms": round(avg,1)}
        print(f"  {cat:<30} {len(times):3d} queries  avg={avg:8.1f}ms")

    print(f"\n  Total successful: {len(results)}/{total}")
    print(f"  Total errors:     {len(errors)}/{total}")
    print(f"  Total runtime:    {total_before/1000:.1f} sec")

    # ── Save summary JSON
    summary = {
        "scale_factor": 10,
        "database": "tpch_sf10",
        "total_queries": total,
        "successful": len(results),
        "errors": len(errors),
        "categories": cat_summary,
        "total_runtime_ms": round(total_before, 2),
    }
    with open(os.path.join(OUTPUT_DIR, "sf10_summary.json"), "w") as f:
        json.dump(summary, f, indent=2)

    print(f"\n  Results saved to: {OUTPUT_DIR}/")
    print("=" * 60)

if __name__ == "__main__":
    main()
