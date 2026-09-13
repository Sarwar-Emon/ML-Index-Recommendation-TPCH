"""
Write Overhead — Proper Before/After
======================================
Creates temp tables with and without
secondary indexes to get clean baseline
"""

import mysql.connector
import time
import json
import os
import statistics

DB_CONFIG = {
    "host": "127.0.0.1", "port": 3306,
    "user": "root", "password": "sayem1288",
    "database": "tpch",
}

OUTPUT_DIR = "/Users/sayememon/Desktop/Troy Courses/Adv Database System/Project/write_overhead_results"
os.makedirs(OUTPUT_DIR, exist_ok=True)

BATCH  = 5000   # rows per trial
TRIALS = 5      # trials for reliability
WARMUP = 2      # warmup runs (discarded)


def get_conn():
    return mysql.connector.connect(**DB_CONFIG)


def measure_orders_insert(conn, with_indexes, trials=TRIALS, warmup=WARMUP):
    """
    Measure INSERT speed on orders-like table
    with and without secondary indexes.
    """
    cur = conn.cursor()

    # Drop test tables
    cur.execute("DROP TABLE IF EXISTS test_orders_indexed")
    cur.execute("DROP TABLE IF EXISTS test_orders_bare")

    # Create bare table (PK only)
    cur.execute("""
        CREATE TABLE test_orders_bare (
          o_orderkey   INTEGER PRIMARY KEY,
          o_custkey    INTEGER,
          o_orderstatus CHAR(1),
          o_totalprice  DECIMAL(15,2),
          o_orderdate   DATE,
          o_orderpriority CHAR(15),
          o_clerk       CHAR(15),
          o_shippriority INTEGER,
          o_comment     VARCHAR(79)
        ) ENGINE=InnoDB
    """)

    # Create indexed table (PK + 6 secondary indexes = same as tpch orders)
    cur.execute("""
        CREATE TABLE test_orders_indexed (
          o_orderkey   INTEGER PRIMARY KEY,
          o_custkey    INTEGER,
          o_orderstatus CHAR(1),
          o_totalprice  DECIMAL(15,2),
          o_orderdate   DATE,
          o_orderpriority CHAR(15),
          o_clerk       CHAR(15),
          o_shippriority INTEGER,
          o_comment     VARCHAR(79),
          INDEX idx_custkey (o_custkey),
          INDEX idx_totalprice (o_totalprice),
          INDEX idx_orderdate (o_orderdate),
          INDEX idx_orderstatus (o_orderstatus),
          INDEX idx_orderpriority (o_orderpriority),
          INDEX idx_date_price (o_orderdate, o_totalprice)
        ) ENGINE=InnoDB
    """)
    conn.commit()

    target = "test_orders_indexed" if with_indexes else "test_orders_bare"
    label  = "WITH 6 secondary indexes" if with_indexes else "PK only (baseline)"
    print(f"\n  Measuring INSERT into {target} ({label})")

    all_times = []

    for trial in range(TRIALS + WARMUP):
        # Clear table
        cur.execute(f"TRUNCATE TABLE {target}")
        conn.commit()

        # Insert BATCH rows from real orders table
        t0 = time.time()
        cur.execute(f"""
            INSERT INTO {target}
            SELECT o_orderkey + {trial * 100000},
                   o_custkey, o_orderstatus, o_totalprice,
                   o_orderdate, o_orderpriority, o_clerk,
                   o_shippriority, o_comment
            FROM orders LIMIT {BATCH}
        """)
        conn.commit()
        elapsed = (time.time() - t0) * 1000

        if trial < WARMUP:
            print(f"    Warmup {trial+1}: {elapsed:.1f} ms (discarded)")
        else:
            all_times.append(elapsed)
            print(f"    Trial {trial-WARMUP+1}: {elapsed:.1f} ms")

    # Cleanup
    cur.execute("DROP TABLE IF EXISTS test_orders_indexed")
    cur.execute("DROP TABLE IF EXISTS test_orders_bare")
    conn.commit()
    cur.close()

    avg = statistics.mean(all_times)
    std = statistics.stdev(all_times) if len(all_times) > 1 else 0
    return avg, std, all_times


def measure_lineitem_insert(conn, with_indexes):
    """Measure INSERT on lineitem-like table."""
    cur = conn.cursor()

    cur.execute("DROP TABLE IF EXISTS test_lineitem_indexed")
    cur.execute("DROP TABLE IF EXISTS test_lineitem_bare")

    cur.execute("""
        CREATE TABLE test_lineitem_bare (
          l_orderkey   INTEGER,
          l_linenumber INTEGER,
          l_partkey    INTEGER,
          l_suppkey    INTEGER,
          l_quantity   DECIMAL(15,2),
          l_extendedprice DECIMAL(15,2),
          l_discount   DECIMAL(15,2),
          l_tax        DECIMAL(15,2),
          l_returnflag CHAR(1),
          l_linestatus CHAR(1),
          l_shipdate   DATE,
          l_commitdate DATE,
          l_receiptdate DATE,
          l_shipinstruct CHAR(25),
          l_shipmode   CHAR(10),
          l_comment    VARCHAR(44),
          PRIMARY KEY (l_orderkey, l_linenumber)
        ) ENGINE=InnoDB
    """)

    cur.execute("""
        CREATE TABLE test_lineitem_indexed (
          l_orderkey   INTEGER,
          l_linenumber INTEGER,
          l_partkey    INTEGER,
          l_suppkey    INTEGER,
          l_quantity   DECIMAL(15,2),
          l_extendedprice DECIMAL(15,2),
          l_discount   DECIMAL(15,2),
          l_tax        DECIMAL(15,2),
          l_returnflag CHAR(1),
          l_linestatus CHAR(1),
          l_shipdate   DATE,
          l_commitdate DATE,
          l_receiptdate DATE,
          l_shipinstruct CHAR(25),
          l_shipmode   CHAR(10),
          l_comment    VARCHAR(44),
          PRIMARY KEY (l_orderkey, l_linenumber),
          INDEX idx_shipdate    (l_shipdate),
          INDEX idx_returnflag  (l_returnflag),
          INDEX idx_discount    (l_discount),
          INDEX idx_quantity    (l_quantity),
          INDEX idx_shipmode    (l_shipmode)
        ) ENGINE=InnoDB
    """)
    conn.commit()

    target = "test_lineitem_indexed" if with_indexes else "test_lineitem_bare"
    label  = "WITH 5 secondary indexes" if with_indexes else "PK only (baseline)"
    print(f"\n  Measuring INSERT into {target} ({label})")

    all_times = []
    for trial in range(TRIALS + WARMUP):
        cur.execute(f"TRUNCATE TABLE {target}")
        conn.commit()
        t0 = time.time()
        cur.execute(f"""
            INSERT INTO {target}
            SELECT l_orderkey, l_linenumber, l_partkey, l_suppkey,
                   l_quantity, l_extendedprice, l_discount, l_tax,
                   l_returnflag, l_linestatus, l_shipdate,
                   l_commitdate, l_receiptdate, l_shipinstruct,
                   l_shipmode, l_comment
            FROM lineitem LIMIT {BATCH}
        """)
        conn.commit()
        elapsed = (time.time() - t0) * 1000

        if trial < WARMUP:
            print(f"    Warmup {trial+1}: {elapsed:.1f} ms (discarded)")
        else:
            all_times.append(elapsed)
            print(f"    Trial {trial-WARMUP+1}: {elapsed:.1f} ms")

    cur.execute("DROP TABLE IF EXISTS test_lineitem_indexed")
    cur.execute("DROP TABLE IF EXISTS test_lineitem_bare")
    conn.commit()
    cur.close()

    avg = statistics.mean(all_times)
    std = statistics.stdev(all_times) if len(all_times) > 1 else 0
    return avg, std, all_times


def main():
    print("=" * 65)
    print("  WRITE OVERHEAD — Proper Before/After Comparison")
    print(f"  {BATCH} rows per trial, {TRIALS} trials + {WARMUP} warmup")
    print("=" * 65)

    conn = get_conn()
    results = {}

    # ── Orders table ──────────────────────────────────
    print("\n[1/2] ORDERS TABLE (6 secondary ML indexes)")
    avg_bare,    std_bare,    times_bare    = measure_orders_insert(conn, with_indexes=False)
    avg_indexed, std_indexed, times_indexed = measure_orders_insert(conn, with_indexes=True)

    overhead_orders = ((avg_indexed - avg_bare) / avg_bare) * 100
    results["orders"] = {
        "n_secondary_indexes": 6,
        "n_rows":              BATCH,
        "baseline_avg_ms":     round(avg_bare, 2),
        "baseline_std_ms":     round(std_bare, 2),
        "indexed_avg_ms":      round(avg_indexed, 2),
        "indexed_std_ms":      round(std_indexed, 2),
        "overhead_pct":        round(overhead_orders, 1),
        "overhead_ms":         round(avg_indexed - avg_bare, 2),
        "baseline_per_row_ms": round(avg_bare / BATCH, 4),
        "indexed_per_row_ms":  round(avg_indexed / BATCH, 4),
    }

    # ── Lineitem table ────────────────────────────────
    print("\n[2/2] LINEITEM TABLE (5 secondary ML indexes)")
    avg_bare2,    std_bare2,    times_bare2    = measure_lineitem_insert(conn, with_indexes=False)
    avg_indexed2, std_indexed2, times_indexed2 = measure_lineitem_insert(conn, with_indexes=True)

    overhead_lineitem = ((avg_indexed2 - avg_bare2) / avg_bare2) * 100
    results["lineitem"] = {
        "n_secondary_indexes": 5,
        "n_rows":              BATCH,
        "baseline_avg_ms":     round(avg_bare2, 2),
        "baseline_std_ms":     round(std_bare2, 2),
        "indexed_avg_ms":      round(avg_indexed2, 2),
        "indexed_std_ms":      round(std_indexed2, 2),
        "overhead_pct":        round(overhead_lineitem, 1),
        "overhead_ms":         round(avg_indexed2 - avg_bare2, 2),
        "baseline_per_row_ms": round(avg_bare2 / BATCH, 4),
        "indexed_per_row_ms":  round(avg_indexed2 / BATCH, 4),
    }

    conn.close()

    # ── Print summary ─────────────────────────────────
    print("\n" + "=" * 65)
    print("  WRITE OVERHEAD RESULTS")
    print("=" * 65)
    print(f"\n  {'Table':<12} {'Indexes':>8} {'Before(ms)':>12} {'After(ms)':>12} {'Overhead':>10}")
    print(f"  {'-'*56}")
    for tbl, r in results.items():
        print(f"  {tbl:<12} {r['n_secondary_indexes']:>8} "
              f"{r['baseline_avg_ms']:>12.1f} "
              f"{r['indexed_avg_ms']:>12.1f} "
              f"{r['overhead_pct']:>9.1f}%")

    print(f"\n  Key findings:")
    for tbl, r in results.items():
        print(f"  {tbl}: +{r['overhead_pct']:.1f}% write overhead "
              f"({r['n_secondary_indexes']} secondary indexes, "
              f"{r['indexed_per_row_ms']:.4f} ms/row vs "
              f"{r['baseline_per_row_ms']:.4f} ms/row baseline)")

    # Save JSON
    out_path = os.path.join(OUTPUT_DIR, "write_overhead_clean.json")
    with open(out_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\n  Saved: {out_path}")
    print("=" * 65)


if __name__ == "__main__":
    main()
