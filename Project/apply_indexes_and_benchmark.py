"""
============================================================
Index Application & Before/After Benchmark (Python timeout)
============================================================
"""

import mysql.connector
import pandas as pd
import numpy as np
import os
import time
import csv
import json
import threading
import warnings
warnings.filterwarnings('ignore')

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────

DB_CONFIG = {
    "host":               "127.0.0.1",
    "port":               3306,
    "user":               "root",
    "password":           "sayem1288",
    "database":           "tpch",
    "connection_timeout": 30,
}

RUNS_PER_QUERY  = 3
QUERY_TIMEOUT_S = 30
RUNTIME_CSV     = "results/runtime_results.csv"
REC_CSV         = "ml_results/index_recommendations.csv"
OUTPUT_DIR      = "after_index_results"
QUERY_FILES     = [
    ("single_table_filters", "queries/single_table_filters.sql"),
    ("two_table_joins",       "queries/two_table_joins.sql"),
    ("three_table_joins",     "queries/three_table_joins.sql"),
    ("aggregation",           "queries/Aggregation.sql"),
    ("complex_queries",       "queries/complex_queries.sql"),
]

os.makedirs(OUTPUT_DIR, exist_ok=True)

print("=" * 65)
print("  Index Application & Before/After Benchmark")
print("  Timeout: {}s per query".format(QUERY_TIMEOUT_S))
print("=" * 65)


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

def parse_queries(sql_text):
    import re
    sql_text = re.sub(r'(?im)^\s*USE\s+\w+\s*;', '', sql_text)
    q_counter = [0]
    def next_id():
        q_counter[0] += 1
        return "Q{:03d}".format(q_counter[0])
    annotated  = []
    pending_id = None
    for raw in sql_text.splitlines():
        s = raw.strip()
        m = re.match(r'^--\s+(Q\d+)\s*:', s)
        if m:
            pending_id = m.group(1)
            continue
        if s.startswith('--') or s.startswith('/*') \
                or s.startswith('*') or s == '':
            continue
        annotated.append((pending_id, s))
        pending_id = None
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
    if buf:
        sql = ' '.join(buf).rstrip(';').strip()
        if sql:
            queries.append((buf_id, sql))
    has_explicit = any(qid is not None for qid, _ in queries)
    if has_explicit:
        seen = {}
        for qid, sql in queries:
            seen[qid] = sql
        return list(seen.items())
    else:
        return [("Q{:03d}".format(i), sql) for i, (_, sql) in enumerate(queries, 1)]


def run_one_query(sql, result_box):
    """Run a single query in a thread and store result in result_box."""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cur  = conn.cursor()
        start = time.perf_counter()
        cur.execute(sql)
        cur.fetchall()
        elapsed = (time.perf_counter() - start) * 1000
        cur.close(); conn.close()
        result_box['time'] = elapsed
        result_box['ok']   = True
    except Exception as e:
        result_box['ok']  = False
        result_box['err'] = str(e)


def run_query_timed(sql, runs=3):
    """Run query N times with thread-based timeout."""
    times = []
    for _ in range(runs):
        result_box = {'ok': False, 'time': None, 'err': ''}
        t = threading.Thread(target=run_one_query, args=(sql, result_box))
        t.start()
        t.join(timeout=QUERY_TIMEOUT_S)

        if t.is_alive():
            # Thread still running = timeout
            return None, None, None, False, "TIMEOUT (>{}s)".format(QUERY_TIMEOUT_S)

        if not result_box['ok']:
            return None, None, None, False, result_box.get('err', 'Unknown error')

        times.append(result_box['time'])

    avg = sum(times) / len(times)
    return round(avg,4), round(min(times),4), round(max(times),4), True, ""


# ─────────────────────────────────────────────
# STEP 1: LOAD DATA
# ─────────────────────────────────────────────
print("\n[1/6] Loading before-index data...")
before_df = pd.read_csv(RUNTIME_CSV)
before_df = before_df[before_df['status'] == 'OK'].copy()
print("  Before-index queries: {:,}".format(len(before_df)))


# ─────────────────────────────────────────────
# STEP 2: APPLY INDEXES
# ─────────────────────────────────────────────
INDEX_DEFINITIONS = [
    ("idx_orders_totalprice",   "CREATE INDEX idx_orders_totalprice   ON orders (o_totalprice)"),
    ("idx_orders_orderdate",    "CREATE INDEX idx_orders_orderdate    ON orders (o_orderdate)"),
    ("idx_orders_custkey",      "CREATE INDEX idx_orders_custkey      ON orders (o_custkey)"),
    ("idx_orders_orderstatus",  "CREATE INDEX idx_orders_orderstatus  ON orders (o_orderstatus)"),
    ("idx_orders_date_price",   "CREATE INDEX idx_orders_date_price   ON orders (o_orderdate, o_totalprice)"),
    ("idx_lineitem_shipdate",   "CREATE INDEX idx_lineitem_shipdate   ON lineitem (l_shipdate)"),
    ("idx_lineitem_quantity",   "CREATE INDEX idx_lineitem_quantity   ON lineitem (l_quantity)"),
    ("idx_lineitem_discount",   "CREATE INDEX idx_lineitem_discount   ON lineitem (l_discount)"),
    ("idx_lineitem_orderkey",   "CREATE INDEX idx_lineitem_orderkey   ON lineitem (l_orderkey)"),
    ("idx_lineitem_partkey",    "CREATE INDEX idx_lineitem_partkey    ON lineitem (l_partkey)"),
    ("idx_lineitem_suppkey",    "CREATE INDEX idx_lineitem_suppkey    ON lineitem (l_suppkey)"),
    ("idx_lineitem_returnflag", "CREATE INDEX idx_lineitem_returnflag ON lineitem (l_returnflag)"),
    ("idx_lineitem_ship_qty",   "CREATE INDEX idx_lineitem_ship_qty   ON lineitem (l_shipdate, l_quantity)"),
    ("idx_customer_nationkey",  "CREATE INDEX idx_customer_nationkey  ON customer (c_nationkey)"),
    ("idx_customer_acctbal",    "CREATE INDEX idx_customer_acctbal    ON customer (c_acctbal)"),
    ("idx_customer_mktsegment", "CREATE INDEX idx_customer_mktsegment ON customer (c_mktsegment)"),
    ("idx_part_size",           "CREATE INDEX idx_part_size           ON part (p_size)"),
    ("idx_part_retailprice",    "CREATE INDEX idx_part_retailprice    ON part (p_retailprice)"),
    ("idx_part_type",           "CREATE INDEX idx_part_type           ON part (p_type)"),
    ("idx_part_brand",          "CREATE INDEX idx_part_brand          ON part (p_brand)"),
    ("idx_supplier_nationkey",  "CREATE INDEX idx_supplier_nationkey  ON supplier (s_nationkey)"),
    ("idx_supplier_acctbal",    "CREATE INDEX idx_supplier_acctbal    ON supplier (s_acctbal)"),
    ("idx_partsupp_partkey",    "CREATE INDEX idx_partsupp_partkey    ON partsupp (ps_partkey)"),
    ("idx_partsupp_suppkey",    "CREATE INDEX idx_partsupp_suppkey    ON partsupp (ps_suppkey)"),
    ("idx_partsupp_supplycost", "CREATE INDEX idx_partsupp_supplycost ON partsupp (ps_supplycost)"),
]

print("\n[2/6] Applying indexes...")
conn = mysql.connector.connect(**DB_CONFIG)
cur  = conn.cursor()
applied = skipped = failed = 0
for idx_name, stmt in INDEX_DEFINITIONS:
    try:
        cur.execute(stmt); conn.commit()
        applied += 1
        print("  ✅ {}".format(idx_name))
    except mysql.connector.Error as e:
        if e.errno == 1061:
            skipped += 1
            print("  ⚠️  {} (exists)".format(idx_name))
        else:
            failed += 1
            print("  ❌ {} -- {}".format(idx_name, e))
cur.close(); conn.close()
print("  Applied:{} Skipped:{} Failed:{}".format(applied, skipped, failed))


# ─────────────────────────────────────────────
# STEP 3: RE-RUN ALL QUERIES
# ─────────────────────────────────────────────
print("\n[3/6] Re-running all queries with {}s timeout...".format(QUERY_TIMEOUT_S))

after_csv = os.path.join(OUTPUT_DIR, "runtime_after_index.csv")
af = open(after_csv, 'w', newline='', encoding='utf-8')
aw = csv.writer(af)
aw.writerow(["category","query_id","query_number",
             "avg_runtime_ms","min_runtime_ms","max_runtime_ms",
             "runs","status","error"])

after_rows   = []
global_q_num = 0
success_q = timeouts_q = errors_q = 0

for category, filepath in QUERY_FILES:
    if not os.path.exists(filepath):
        print("  Not found: {}".format(filepath))
        continue
    with open(filepath, 'r', encoding='utf-8') as f:
        sql_text = f.read()
    queries = parse_queries(sql_text)
    print("\n  {} --> {} queries".format(category.ljust(25), len(queries)))

    for q_idx, (query_id, sql) in enumerate(queries, 1):
        global_q_num += 1

        avg_ms, min_ms, max_ms, ok, err = run_query_timed(sql, RUNS_PER_QUERY)

        if ok:
            success_q += 1
            status = "OK"
            print("   [{:>4}] {}_{:<10} avg={:>10.2f} ms".format(
                global_q_num, category[:3], query_id, avg_ms))
        elif "TIMEOUT" in str(err):
            timeouts_q += 1
            status = "TIMEOUT"
            print("   [{:>4}] {}_{:<10} ⏱  TIMEOUT".format(
                global_q_num, category[:3], query_id))
        else:
            errors_q += 1
            status = "ERROR"
            print("   [{:>4}] {}_{:<10} ❌ {}".format(
                global_q_num, category[:3], query_id, err[:50]))

        aw.writerow([category, query_id, global_q_num,
                     avg_ms if ok else "", min_ms if ok else "",
                     max_ms if ok else "", RUNS_PER_QUERY, status, err])
        after_rows.append({
            'category': category, 'query_id': query_id,
            'avg_runtime_after': avg_ms if ok else None,
            'status_after': status
        })

af.close()
print("\n  Done: {} OK | {} timeouts | {} errors".format(
    success_q, timeouts_q, errors_q))


# ─────────────────────────────────────────────
# STEP 4: COMPARE
# ─────────────────────────────────────────────
print("\n[4/6] Computing speedup...")

after_df   = pd.DataFrame(after_rows)
after_df   = after_df[after_df['status_after'] == 'OK'].copy()
compare_df = before_df[['category','query_id','avg_runtime_ms']].merge(
    after_df[['category','query_id','avg_runtime_after']],
    on=['category','query_id'], how='inner'
).dropna()

compare_df['speedup']         = compare_df['avg_runtime_ms'] / compare_df['avg_runtime_after']
compare_df['improvement_ms']  = compare_df['avg_runtime_ms'] - compare_df['avg_runtime_after']
compare_df['improvement_pct'] = 100 * compare_df['improvement_ms'] / compare_df['avg_runtime_ms']
compare_df['improved']        = (compare_df['speedup'] > 1.05).astype(int)

total_before    = compare_df['avg_runtime_ms'].sum()
total_after     = compare_df['avg_runtime_after'].sum()
overall_speedup = total_before / total_after
avg_speedup     = compare_df['speedup'].mean()
median_speedup  = compare_df['speedup'].median()
pct_improved    = 100 * compare_df['improved'].mean()

print("  Queries compared  : {:,}".format(len(compare_df)))
print("  Total BEFORE      : {:,.0f} ms ({:.1f} min)".format(total_before, total_before/60000))
print("  Total AFTER       : {:,.0f} ms ({:.1f} min)".format(total_after,  total_after/60000))
print("  Overall speedup   : {:.2f}x".format(overall_speedup))
print("  Average speedup   : {:.2f}x".format(avg_speedup))
print("  Median speedup    : {:.2f}x".format(median_speedup))
print("  Queries improved  : {:.1f}%".format(pct_improved))

cat_stats = compare_df.groupby('category').agg(
    count=('query_id','count'),
    avg_before=('avg_runtime_ms','mean'),
    avg_after=('avg_runtime_after','mean'),
    avg_speedup=('speedup','mean'),
    max_speedup=('speedup','max'),
    pct_improved=('improved','mean')
).reset_index()
cat_stats['pct_improved'] = (cat_stats['pct_improved']*100).round(1)
cat_stats['avg_speedup']  = cat_stats['avg_speedup'].round(2)

print("\n  Per-category:")
print("  {:<25} {:>8} {:>12} {:>12} {:>10} {:>10}".format(
    "Category","Queries","Avg Before","Avg After","Speedup","% Better"))
print("  "+"-"*80)
for _, r in cat_stats.iterrows():
    print("  {:<25} {:>8} {:>12.1f} {:>12.1f} {:>10.2f} {:>9.1f}%".format(
        r['category'], int(r['count']),
        r['avg_before'], r['avg_after'],
        r['avg_speedup'], r['pct_improved']))


# ─────────────────────────────────────────────
# STEP 5: CHARTS
# ─────────────────────────────────────────────
print("\n[5/6] Generating charts...")
plt.rcParams.update({'font.size':11,'figure.dpi':150})

# Fig 7: Before vs After
fig, ax = plt.subplots(figsize=(13,6))
x = np.arange(len(cat_stats)); w = 0.35
ax.bar(x-w/2, cat_stats['avg_before'], w, label='Before Index', color='#EF5350', alpha=0.85)
ax.bar(x+w/2, cat_stats['avg_after'],  w, label='After Index',  color='#42A5F5', alpha=0.85)
ax.set_yscale('log')
ax.set_xticks(x)
ax.set_xticklabels([c.replace('_','\n') for c in cat_stats['category']])
ax.set_ylabel('Avg Runtime (ms) - log scale', fontweight='bold')
ax.set_title('Query Runtime: Before vs After ML-Recommended Indexes', fontsize=13, fontweight='bold')
ax.legend()
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR,'fig7_before_after_runtime.png'), bbox_inches='tight')
plt.close()

# Fig 8: Speedup histogram
fig, ax = plt.subplots(figsize=(10,5))
ax.hist(compare_df['speedup'].clip(upper=15), bins=40, color='#42A5F5', edgecolor='white', alpha=0.85)
ax.axvline(x=1.0,            color='gray',   linestyle='--', lw=1.5, label='No change')
ax.axvline(x=avg_speedup,    color='orange', linestyle='-',  lw=2,   label='Mean {:.2f}x'.format(avg_speedup))
ax.axvline(x=median_speedup, color='green',  linestyle='-',  lw=2,   label='Median {:.2f}x'.format(median_speedup))
ax.set_xlabel('Speedup Factor', fontweight='bold')
ax.set_ylabel('Number of Queries', fontweight='bold')
ax.set_title('Speedup Distribution After Indexing', fontsize=13, fontweight='bold')
ax.legend(); ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR,'fig8_speedup_distribution.png'), bbox_inches='tight')
plt.close()

# Fig 9: Scatter
fig, ax = plt.subplots(figsize=(9,7))
sc = ax.scatter(compare_df['avg_runtime_ms'], compare_df['avg_runtime_after'],
                c=compare_df['speedup'].clip(upper=10), cmap='RdYlGn', alpha=0.6, s=30)
mv = max(compare_df['avg_runtime_ms'].max(), compare_df['avg_runtime_after'].max())
ax.plot([0,mv],[0,mv],'k--',lw=1,alpha=0.4,label='No improvement')
ax.set_xscale('log'); ax.set_yscale('log')
ax.set_xlabel('Runtime BEFORE (ms)', fontweight='bold')
ax.set_ylabel('Runtime AFTER (ms)', fontweight='bold')
ax.set_title('Before vs After Runtime (below diagonal = improved)', fontsize=12, fontweight='bold')
plt.colorbar(sc, ax=ax, label='Speedup')
ax.legend()
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR,'fig9_scatter_before_after.png'), bbox_inches='tight')
plt.close()

# Fig 10: Top 20
top20 = compare_df.nlargest(20,'speedup')
fig, ax = plt.subplots(figsize=(12,7))
yp = range(len(top20))
lb = ["{}_{}".format(r['category'][:3].upper(), r['query_id']) for _,r in top20.iterrows()]
ax.barh(yp, top20['speedup'].values, color='#42A5F5', edgecolor='white', alpha=0.85)
ax.set_yticks(yp); ax.set_yticklabels(lb, fontsize=9)
ax.set_xlabel('Speedup Factor (x)', fontweight='bold')
ax.set_title('Top 20 Most Improved Queries', fontsize=13, fontweight='bold')
for i,(_,row) in enumerate(top20.iterrows()):
    ax.text(row['speedup']+0.1, i, '{:.1f}x'.format(row['speedup']), va='center', fontsize=9)
ax.grid(True, alpha=0.3, axis='x')
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR,'fig10_top20_improved.png'), bbox_inches='tight')
plt.close()
print("  Saved 4 charts")


# ─────────────────────────────────────────────
# STEP 6: SAVE
# ─────────────────────────────────────────────
print("\n[6/6] Saving results...")
compare_df.to_csv(os.path.join(OUTPUT_DIR,'before_after_comparison.csv'), index=False)
cat_stats.to_csv(os.path.join(OUTPUT_DIR,'category_speedup_stats.csv'), index=False)
compare_df.nlargest(50,'speedup').to_csv(os.path.join(OUTPUT_DIR,'top_improved_queries.csv'), index=False)

summary = {
    'indexes_applied': applied+skipped,
    'total_queries_compared': int(len(compare_df)),
    'timeouts_skipped': int(timeouts_q),
    'total_runtime_before_ms': round(total_before,2),
    'total_runtime_after_ms':  round(total_after,2),
    'overall_speedup':   round(overall_speedup,4),
    'avg_speedup':       round(avg_speedup,4),
    'median_speedup':    round(median_speedup,4),
    'pct_improved':      round(pct_improved,2),
    'per_category':      cat_stats.to_dict('records'),
    'top5': compare_df.nlargest(5,'speedup')[
        ['category','query_id','avg_runtime_ms','avg_runtime_after','speedup']
    ].round(2).to_dict('records')
}
with open(os.path.join(OUTPUT_DIR,'before_after_summary.json'),'w') as f:
    json.dump(summary, f, indent=2)

print("\n"+"="*65)
print("  BEFORE vs AFTER COMPLETE")
print("="*65)
print("  Indexes applied     : {:,}".format(applied+skipped))
print("  Queries compared    : {:,}".format(len(compare_df)))
print("  Timeouts skipped    : {:,}".format(timeouts_q))
print("  Overall speedup     : {:.2f}x".format(overall_speedup))
print("  Average speedup     : {:.2f}x".format(avg_speedup))
print("  Queries improved    : {:.1f}%".format(pct_improved))
print("="*65)