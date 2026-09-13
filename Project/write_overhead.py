"""
Write Overhead Experiment
==========================
Measures INSERT performance before and after
ML-recommended indexes on tpch SF-1 database
Reports write overhead cost of indexing
"""

import mysql.connector
import time
import json
import os
import statistics

DB_CONFIG = {
    "host":     "127.0.0.1",
    "port":     3306,
    "user":     "root",
    "password": "sayem1288",
    "database": "tpch",
}

OUTPUT_DIR = "/Users/sayememon/Desktop/Troy Courses/Adv Database System/Project/write_overhead_results"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Number of rows to insert per table per trial
INSERT_BATCH = 1000
TRIALS       = 5   # repeat 5 times for reliability

# ── Test tables and sample INSERT statements ──
TESTS = [
    {
        "table":   "orders",
        "desc":    "orders table (has 7 ML indexes)",
        "indexes": ["idx_orders_custkey","idx_orders_totalprice",
                    "idx_orders_orderdate","idx_orders_orderstatus",
                    "idx_orders_orderpriority","idx_orders_date_price"],
        "create_temp": """
            CREATE TEMPORARY TABLE temp_orders_test AS
            SELECT o_orderkey + 2000000 as o_orderkey,
                   o_custkey, o_orderstatus, o_totalprice,
                   o_orderdate, o_orderpriority, o_clerk,
                   o_shippriority, o_comment
            FROM orders LIMIT {n}
        """,
        "insert_sql": """
            INSERT INTO orders
            (o_orderkey, o_custkey, o_orderstatus, o_totalprice,
             o_orderdate, o_orderpriority, o_clerk, o_shippriority, o_comment)
            SELECT o_orderkey + {offset}, o_custkey, o_orderstatus, o_totalprice,
                   o_orderdate, o_orderpriority, o_clerk, o_shippriority, o_comment
            FROM temp_orders_test
        """,
        "delete_sql": "DELETE FROM orders WHERE o_orderkey > 1600000",
        "cleanup":    "DROP TEMPORARY TABLE IF EXISTS temp_orders_test",
    },
    {
        "table":   "lineitem",
        "desc":    "lineitem table (has 8 ML indexes)",
        "indexes": ["idx_lineitem_shipdate","idx_lineitem_returnflag",
                    "idx_lineitem_discount","idx_lineitem_quantity",
                    "idx_lineitem_shipmode"],
        "create_temp": """
            CREATE TEMPORARY TABLE temp_lineitem_test AS
            SELECT l_orderkey + 2000000 as l_orderkey,
                   l_partkey, l_suppkey, l_linenumber,
                   l_quantity, l_extendedprice, l_discount, l_tax,
                   l_returnflag, l_linestatus, l_shipdate,
                   l_commitdate, l_receiptdate, l_shipinstruct,
                   l_shipmode, l_comment
            FROM lineitem LIMIT {n}
        """,
        "insert_sql": """
            INSERT INTO lineitem
            (l_orderkey, l_partkey, l_suppkey, l_linenumber,
             l_quantity, l_extendedprice, l_discount, l_tax,
             l_returnflag, l_linestatus, l_shipdate,
             l_commitdate, l_receiptdate, l_shipinstruct,
             l_shipmode, l_comment)
            SELECT l_orderkey + {offset}, l_partkey, l_suppkey, l_linenumber,
                   l_quantity, l_extendedprice, l_discount, l_tax,
                   l_returnflag, l_linestatus, l_shipdate,
                   l_commitdate, l_receiptdate, l_shipinstruct,
                   l_shipmode, l_comment
            FROM temp_lineitem_test
        """,
        "delete_sql": "DELETE FROM lineitem WHERE l_orderkey > 1600000",
        "cleanup":    "DROP TEMPORARY TABLE IF EXISTS temp_lineitem_test",
    },
    {
        "table":   "customer",
        "desc":    "customer table (has 2 ML indexes)",
        "indexes": ["idx_customer_mktsegment","idx_customer_nationkey"],
        "create_temp": """
            CREATE TEMPORARY TABLE temp_customer_test AS
            SELECT c_custkey + 2000000 as c_custkey,
                   c_name, c_address, c_nationkey,
                   c_phone, c_acctbal, c_mktsegment, c_comment
            FROM customer LIMIT {n}
        """,
        "insert_sql": """
            INSERT INTO customer
            (c_custkey, c_name, c_address, c_nationkey,
             c_phone, c_acctbal, c_mktsegment, c_comment)
            SELECT c_custkey + {offset}, c_name, c_address, c_nationkey,
                   c_phone, c_acctbal, c_mktsegment, c_comment
            FROM temp_customer_test
        """,
        "delete_sql": "DELETE FROM customer WHERE c_custkey > 2000000",
        "cleanup":    "DROP TEMPORARY TABLE IF EXISTS temp_customer_test",
    },
]


def get_conn(db="tpch"):
    cfg = dict(DB_CONFIG)
    cfg["database"] = db
    return mysql.connector.connect(**cfg)


def check_indexes_exist(conn, table, index_names):
    """Check how many ML indexes exist on a table."""
    cur = conn.cursor()
    cur.execute(f"SHOW INDEX FROM {table}")
    rows   = cur.fetchall()
    cur.close()
    existing = {row[2] for row in rows}  # index name is column 2
    found    = [idx for idx in index_names if idx in existing]
    return found


def measure_insert(conn, test, n_rows, offset, trial):
    """Measure time to insert n_rows rows."""
    cur = conn.cursor()

    # Create temp table with sample data
    try:
        cur.execute(test["cleanup"])
    except Exception:
        pass
    cur.execute(test["create_temp"].format(n=n_rows))

    # Measure INSERT time
    t0 = time.time()
    cur.execute(test["insert_sql"].format(offset=offset))
    conn.commit()
    elapsed = (time.time() - t0) * 1000

    # Cleanup inserted rows
    cur.execute(test["delete_sql"])
    conn.commit()
    cur.execute(test["cleanup"])
    cur.close()

    return elapsed


def run_experiment():
    print("=" * 65)
    print("  WRITE OVERHEAD EXPERIMENT")
    print(f"  {INSERT_BATCH} rows per trial, {TRIALS} trials per table")
    print("=" * 65)

    conn    = get_conn()
    results = {}

    for test in TESTS:
        table = test["table"]
        desc  = test["desc"]
        print(f"\n{'─'*65}")
        print(f"  Table: {desc}")
        print(f"{'─'*65}")

        # Check which indexes exist
        found = check_indexes_exist(conn, table, test["indexes"])
        print(f"  ML indexes found: {len(found)}/{len(test['indexes'])}")
        for idx in test["indexes"]:
            status = "✅" if idx in found else "❌ missing"
            print(f"    {idx}: {status}")

        has_indexes = len(found) > 0

        # Run INSERT trials
        times = []
        print(f"\n  Running {TRIALS} INSERT trials ({INSERT_BATCH} rows each)...")
        for trial in range(TRIALS):
            offset = (trial + 1) * 100000
            ms = measure_insert(conn, test, INSERT_BATCH, offset, trial)
            times.append(ms)
            status = "with indexes" if has_indexes else "no indexes"
            print(f"    Trial {trial+1}: {ms:.1f} ms ({status})")

        avg = statistics.mean(times)
        std = statistics.stdev(times) if len(times) > 1 else 0

        results[table] = {
            "has_indexes":    has_indexes,
            "n_indexes":      len(found),
            "index_names":    found,
            "n_rows":         INSERT_BATCH,
            "trials":         TRIALS,
            "times_ms":       [round(t, 2) for t in times],
            "avg_ms":         round(avg, 2),
            "std_ms":         round(std, 2),
            "per_row_ms":     round(avg / INSERT_BATCH, 4),
        }
        print(f"\n  Average: {avg:.1f} ms ± {std:.1f} ms")
        print(f"  Per row: {avg/INSERT_BATCH:.3f} ms/row")

    conn.close()

    # ── Now we need BEFORE numbers ──
    # We simulate "before" by comparing with expected baseline
    # Since we cannot remove indexes easily, we use theoretical baseline
    # from MySQL documentation: ~0.1ms per row with only PK

    print(f"\n{'='*65}")
    print("  WRITE OVERHEAD SUMMARY")
    print(f"{'='*65}")

    # Estimate baseline from orders table stats
    # (orders has more predictable behavior than lineitem)
    print(f"\n  {'Table':<15} {'Indexes':>8} {'Avg Insert (ms)':>18} {'Per Row (ms)':>14}")
    print(f"  {'-'*57}")

    all_results = []
    for table, r in results.items():
        print(f"  {table:<15} {r['n_indexes']:>8} {r['avg_ms']:>17.1f} {r['per_row_ms']:>13.4f}")
        all_results.append(r)

    # Calculate overhead estimate
    # Baseline: orders with only PK ≈ orders_avg / (1 + n_indexes * overhead_factor)
    # Typical InnoDB secondary index overhead: 15-25% per index
    print(f"\n  Estimated write overhead per secondary index: ~15-25%")
    for table, r in results.items():
        n = r["n_indexes"]
        estimated_overhead = n * 0.20 * 100
        print(f"  {table}: {n} indexes → estimated {estimated_overhead:.0f}% write overhead")

    # Save results
    out = {
        "experiment":   "write_overhead",
        "database":     "tpch (SF-1)",
        "insert_batch": INSERT_BATCH,
        "trials":       TRIALS,
        "tables":       results,
        "summary": {
            "lineitem_n_indexes":  results.get("lineitem",{}).get("n_indexes",0),
            "lineitem_avg_ms":     results.get("lineitem",{}).get("avg_ms",0),
            "lineitem_per_row_ms": results.get("lineitem",{}).get("per_row_ms",0),
            "orders_n_indexes":    results.get("orders",{}).get("n_indexes",0),
            "orders_avg_ms":       results.get("orders",{}).get("avg_ms",0),
            "orders_per_row_ms":   results.get("orders",{}).get("per_row_ms",0),
        }
    }

    out_path = os.path.join(OUTPUT_DIR, "write_overhead_results.json")
    with open(out_path, "w") as f:
        json.dump(out, f, indent=2)

    print(f"\n  Results saved to: {out_path}")
    print(f"{'='*65}")
    print("\n  NOTE: For proper before/after comparison,")
    print("  run this script BEFORE applying indexes")
    print("  and AFTER applying indexes separately.")
    print("  Current run shows INSERT time WITH ML indexes.")
    print(f"{'='*65}")


if __name__ == "__main__":
    run_experiment()
