"""
================================================================
NO-INDEX BASELINE BENCHMARK
================================================================
Step 1: Save all current indexes
Step 2: Drop all non-PK indexes  
Step 3: Run all 911 queries → record "No Index" time
Step 4: Restore all indexes
Step 5: Generate 3-way comparison table + chart
================================================================
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
    "host": "127.0.0.1", "port": 3306,
    "user": "root", "password": "sayem1288",
    "database": "tpch", "connection_timeout": 30,
}

RUNS_PER_QUERY  = 3
QUERY_TIMEOUT_S = 45
OUTPUT_DIR      = "no_index_results"
QUERY_FILES     = [
    ("single_table_filters", "queries/single_table_filters.sql"),
    ("two_table_joins",       "queries/two_table_joins.sql"),
    ("three_table_joins",     "queries/three_table_joins.sql"),
    ("aggregation",           "queries/Aggregation.sql"),
    ("complex_queries",       "queries/complex_queries.sql"),
]

os.makedirs(OUTPUT_DIR, exist_ok=True)

print("=" * 65)
print("  NO-INDEX BASELINE BENCHMARK")
print("  3-Way Comparison: No Index → Before ML → After ML")
print("=" * 65)


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────
def parse_queries(sql_text):
    import re
    sql_text = re.sub(r'(?im)^\s*USE\s+\w+\s*;', '', sql_text)
    annotated = []
    pending_id = None
    for raw in sql_text.splitlines():
        s = raw.strip()
        m = re.match(r'^--\s+(Q\d+)\s*:', s)
        if m:
            pending_id = m.group(1); continue
        if s.startswith('--') or s.startswith('/*') or s.startswith('*') or s == '':
            continue
        annotated.append((pending_id, s))
        pending_id = None
    queries = []; buf = []; buf_id = None
    for qid, line in annotated:
        if buf_id is None: buf_id = qid
        buf.append(line)
        if line.endswith(';'):
            sql = ' '.join(buf).rstrip(';').strip()
            if sql: queries.append((buf_id, sql))
            buf = []; buf_id = None
    if buf:
        sql = ' '.join(buf).rstrip(';').strip()
        if sql: queries.append((buf_id, sql))
    has_explicit = any(qid is not None for qid, _ in queries)
    if has_explicit:
        seen = {}
        for qid, sql in queries: seen[qid] = sql
        return list(seen.items())
    return [("Q{:03d}".format(i), sql) for i, (_, sql) in enumerate(queries, 1)]


def run_one_query(sql, result_box):
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
    times = []
    for _ in range(runs):
        result_box = {'ok': False, 'time': None, 'err': ''}
        t = threading.Thread(target=run_one_query, args=(sql, result_box))
        t.start()
        t.join(timeout=QUERY_TIMEOUT_S)
        if t.is_alive():
            return None, None, None, False, "TIMEOUT (>{}s)".format(QUERY_TIMEOUT_S)
        if not result_box['ok']:
            return None, None, None, False, result_box.get('err','')
        times.append(result_box['time'])
    avg = sum(times)/len(times)
    return round(avg,4), round(min(times),4), round(max(times),4), True, ""


def get_all_indexes(cursor):
    """Get all non-PK, non-UNIQUE indexes."""
    cursor.execute("""
        SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME, NON_UNIQUE
        FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = 'tpch'
          AND INDEX_NAME != 'PRIMARY'
        ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX
    """)
    rows = cursor.fetchall()
    # Group by index name
    indexes = {}
    for (tbl, idx, col, non_unique) in rows:
        if idx not in indexes:
            indexes[idx] = {'table': tbl, 'index_name': idx,
                           'columns': [], 'non_unique': non_unique}
        indexes[idx]['columns'].append(col)
    return list(indexes.values())


def run_all_queries(label):
    """Run all 911 queries and return results DataFrame."""
    print("\n  Running all queries ({})...".format(label))
    rows = []
    global_q = 0
    ok_q = timeout_q = err_q = 0

    csv_path = os.path.join(OUTPUT_DIR, "runtime_{}.csv".format(
        label.lower().replace(' ','_')))
    f  = open(csv_path, 'w', newline='', encoding='utf-8')
    w  = csv.writer(f)
    w.writerow(["category","query_id","query_number",
                "avg_runtime_ms","status","error"])

    for category, filepath in QUERY_FILES:
        if not os.path.exists(filepath): continue
        with open(filepath,'r',encoding='utf-8') as qf:
            sql_text = qf.read()
        queries = parse_queries(sql_text)

        for query_id, sql in queries:
            global_q += 1
            avg_ms, min_ms, max_ms, ok, err = run_query_timed(sql, RUNS_PER_QUERY)

            if ok:
                ok_q += 1; status = "OK"
                print("   [{:>4}] {}_{:<10} {:>10.2f} ms".format(
                    global_q, category[:3], query_id, avg_ms))
            elif "TIMEOUT" in str(err):
                timeout_q += 1; status = "TIMEOUT"
                print("   [{:>4}] {}_{:<10} ⏱  TIMEOUT".format(
                    global_q, category[:3], query_id))
            else:
                err_q += 1; status = "ERROR"
                print("   [{:>4}] {}_{:<10} ❌ {}".format(
                    global_q, category[:3], query_id, err[:40]))

            w.writerow([category, query_id, global_q,
                        avg_ms if ok else "", status, err])
            rows.append({
                'category': category, 'query_id': query_id,
                'avg_runtime_ms': avg_ms if ok else None,
                'status': status
            })

    f.close()
    print("  {} done: {} OK | {} timeouts | {} errors".format(
        label, ok_q, timeout_q, err_q))
    return pd.DataFrame(rows)


# ─────────────────────────────────────────────
# STEP 1: CONNECT & SAVE CURRENT INDEXES
# ─────────────────────────────────────────────
print("\n[1/6] Connecting and saving current indexes...")
conn   = mysql.connector.connect(**DB_CONFIG)
cursor = conn.cursor()

all_indexes = get_all_indexes(cursor)
print("  Found {:,} non-PK indexes to temporarily drop".format(len(all_indexes)))

# Save index definitions for restoration
restore_stmts = []
for idx in all_indexes:
    cols = ', '.join(idx['columns'])
    stmt = "CREATE INDEX {} ON {} ({})".format(
        idx['index_name'], idx['table'], cols)
    restore_stmts.append(stmt)

with open(os.path.join(OUTPUT_DIR,'index_restore_stmts.sql'), 'w') as f:
    f.write("-- Restore statements (auto-generated safety backup)\n\n")
    for s in restore_stmts:
        f.write("{};\n".format(s))
print("  Saved restore script ({} statements)".format(len(restore_stmts)))


# ─────────────────────────────────────────────
# STEP 2: DROP ALL NON-PK INDEXES
# ─────────────────────────────────────────────
print("\n[2/6] Dropping all non-PK indexes...")
dropped = 0
for idx in all_indexes:
    try:
        cursor.execute("DROP INDEX {} ON {}".format(
            idx['index_name'], idx['table']))
        conn.commit()
        dropped += 1
        print("  🗑  Dropped: {} on {}".format(idx['index_name'], idx['table']))
    except Exception as e:
        print("  ⚠️  Could not drop {}: {}".format(idx['index_name'], e))

print("  Dropped {:,} indexes".format(dropped))
cursor.close(); conn.close()


# ─────────────────────────────────────────────
# STEP 3: RUN ALL QUERIES (NO INDEX)
# ─────────────────────────────────────────────
print("\n[3/6] Benchmarking with NO indexes...")
no_index_df = run_all_queries("no_index")


# ─────────────────────────────────────────────
# STEP 4: RESTORE ALL INDEXES
# ─────────────────────────────────────────────
print("\n[4/6] Restoring all indexes...")
conn   = mysql.connector.connect(**DB_CONFIG)
cursor = conn.cursor()

restored = failed_restore = 0
for stmt in restore_stmts:
    try:
        cursor.execute(stmt)
        conn.commit()
        restored += 1
        print("  ✅ Restored: {}".format(stmt.split()[2]))
    except mysql.connector.Error as e:
        if e.errno == 1061:
            restored += 1
            print("  ⚠️  Already exists: {}".format(stmt.split()[2]))
        else:
            failed_restore += 1
            print("  ❌ Failed: {}".format(e))

print("  Restored {:,} indexes | Failed: {:,}".format(restored, failed_restore))
cursor.close(); conn.close()


# ─────────────────────────────────────────────
# STEP 5: BUILD 3-WAY COMPARISON
# ─────────────────────────────────────────────
print("\n[5/6] Building 3-way comparison...")

# Load before-ML and after-ML results
before_df = pd.read_csv("results/runtime_results.csv")
before_df = before_df[before_df['status']=='OK'][['category','query_id','avg_runtime_ms']]
before_df = before_df.rename(columns={'avg_runtime_ms':'before_ml_ms'})

after_df  = pd.read_csv("after_index_results/runtime_after_index.csv")
after_df  = after_df[after_df['status']=='OK'][['category','query_id','avg_runtime_ms']]
after_df  = after_df.rename(columns={'avg_runtime_ms':'after_ml_ms'})

no_idx_df = no_index_df[no_index_df['status']=='OK'][['category','query_id','avg_runtime_ms']]
no_idx_df = no_idx_df.rename(columns={'avg_runtime_ms':'no_index_ms'})

# Merge all three
compare = no_idx_df.merge(before_df, on=['category','query_id'], how='inner')
compare = compare.merge(after_df,   on=['category','query_id'], how='inner')
compare = compare.dropna()

# Compute speedups (relative to no-index baseline)
compare['speedup_before'] = compare['no_index_ms'] / compare['before_ml_ms']
compare['speedup_after']  = compare['no_index_ms'] / compare['after_ml_ms']
compare['speedup_ml_vs_before'] = compare['before_ml_ms'] / compare['after_ml_ms']

# Overall numbers
avg_no_index = compare['no_index_ms'].mean()
avg_before   = compare['before_ml_ms'].mean()
avg_after    = compare['after_ml_ms'].mean()

total_no_index = compare['no_index_ms'].sum()
total_before   = compare['before_ml_ms'].sum()
total_after    = compare['after_ml_ms'].sum()

speedup_before_vs_none = avg_no_index / avg_before
speedup_after_vs_none  = avg_no_index / avg_after
speedup_ml_vs_before   = avg_before   / avg_after

print("\n  ┌─────────────────────────────────────────────────────┐")
print("  │           3-WAY COMPARISON RESULTS                  │")
print("  ├─────────────────────────────────────────────────────┤")
print("  │ Configuration        Avg Query Time    Speedup      │")
print("  ├─────────────────────────────────────────────────────┤")
print("  │ No Indexes           {:>10.1f} ms     1.00x        │".format(avg_no_index))
print("  │ Before ML (baseline) {:>10.1f} ms     {:.2f}x        │".format(avg_before, speedup_before_vs_none))
print("  │ ML Recommended       {:>10.1f} ms     {:.2f}x        │".format(avg_after,  speedup_after_vs_none))
print("  └─────────────────────────────────────────────────────┘")

# Per-category breakdown
cat_stats = compare.groupby('category').agg(
    count=('query_id','count'),
    avg_no_index=('no_index_ms','mean'),
    avg_before=('before_ml_ms','mean'),
    avg_after=('after_ml_ms','mean'),
).reset_index()
cat_stats['speedup_vs_none'] = cat_stats['avg_no_index'] / cat_stats['avg_after']

print("\n  Per-category (No Index → ML Recommended):")
print("  {:<25} {:>8} {:>12} {:>12} {:>10}".format(
    "Category","Queries","No Index","ML Index","Speedup"))
print("  "+"-"*70)
for _, r in cat_stats.iterrows():
    print("  {:<25} {:>8} {:>12.1f} {:>12.1f} {:>10.2f}x".format(
        r['category'], int(r['count']),
        r['avg_no_index'], r['avg_after'],
        r['speedup_vs_none']))


# ─────────────────────────────────────────────
# STEP 6: CHARTS + SAVE
# ─────────────────────────────────────────────
print("\n[6/6] Generating charts and saving...")

plt.rcParams.update({'font.size':11,'figure.dpi':150})

# ── Fig 12: 3-way bar chart per category ──
fig, ax = plt.subplots(figsize=(14,6))
x = np.arange(len(cat_stats)); w = 0.25
ax.bar(x-w,   cat_stats['avg_no_index'], w, label='No Indexes',
       color='#EF5350', alpha=0.85)
ax.bar(x,     cat_stats['avg_before'],   w, label='Before ML (Baseline)',
       color='#FFA726', alpha=0.85)
ax.bar(x+w,   cat_stats['avg_after'],    w, label='ML Recommended',
       color='#42A5F5', alpha=0.85)
ax.set_yscale('log')
ax.set_xticks(x)
ax.set_xticklabels([c.replace('_','\n') for c in cat_stats['category']])
ax.set_ylabel('Avg Runtime (ms) - log scale', fontweight='bold')
ax.set_title('3-Way Comparison: No Index vs Baseline vs ML-Recommended Indexes',
             fontsize=12, fontweight='bold')
ax.legend()
ax.grid(True, alpha=0.3, axis='y')
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR,'fig12_3way_comparison.png'), bbox_inches='tight')
plt.close()
print("  Saved: fig12_3way_comparison.png")

# ── Fig 13: Overall 3-way summary bar ──
fig, ax = plt.subplots(figsize=(8,5))
configs = ['No Indexes\n(Baseline)', 'Before ML\n(Existing Indexes)', 'ML Recommended\n(This Work)']
values  = [avg_no_index, avg_before, avg_after]
colors  = ['#EF5350','#FFA726','#42A5F5']
bars    = ax.bar(configs, values, color=colors, alpha=0.85, edgecolor='white', width=0.5)
for bar, val in zip(bars, values):
    ax.text(bar.get_x()+bar.get_width()/2, bar.get_height()+5,
            '{:.0f} ms'.format(val), ha='center', va='bottom', fontweight='bold')
ax.set_ylabel('Average Query Runtime (ms)', fontweight='bold')
ax.set_title('Overall Average Query Runtime\nAcross 3 Configurations',
             fontsize=12, fontweight='bold')
ax.set_ylim(0, max(values)*1.2)
# Add speedup annotations
ax.annotate('', xy=(1, avg_before), xytext=(0, avg_no_index),
            arrowprops=dict(arrowstyle='->', color='green', lw=2))
ax.annotate('', xy=(2, avg_after), xytext=(0, avg_no_index),
            arrowprops=dict(arrowstyle='->', color='green', lw=2))
ax.text(0.5, max(values)*1.1,
        '{:.2f}x faster'.format(speedup_before_vs_none),
        ha='center', color='green', fontsize=10)
ax.text(1.5, max(values)*1.15,
        '{:.2f}x faster'.format(speedup_after_vs_none),
        ha='center', color='green', fontsize=10, fontweight='bold')
ax.grid(True, alpha=0.3, axis='y')
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR,'fig13_overall_summary.png'), bbox_inches='tight')
plt.close()
print("  Saved: fig13_overall_summary.png")

# Save comparison CSV
compare.to_csv(os.path.join(OUTPUT_DIR,'3way_comparison.csv'), index=False)
cat_stats.to_csv(os.path.join(OUTPUT_DIR,'3way_category_stats.csv'), index=False)

# Save thesis summary JSON
summary = {
    'queries_compared': int(len(compare)),
    'no_index': {
        'avg_ms': round(avg_no_index, 2),
        'total_ms': round(total_no_index, 2),
        'speedup': 1.0
    },
    'before_ml': {
        'avg_ms': round(avg_before, 2),
        'total_ms': round(total_before, 2),
        'speedup_vs_no_index': round(speedup_before_vs_none, 4)
    },
    'ml_recommended': {
        'avg_ms': round(avg_after, 2),
        'total_ms': round(total_after, 2),
        'speedup_vs_no_index': round(speedup_after_vs_none, 4),
        'speedup_vs_before': round(speedup_ml_vs_before, 4)
    },
    'per_category': cat_stats.round(2).to_dict('records')
}
with open(os.path.join(OUTPUT_DIR,'3way_summary.json'), 'w') as f:
    json.dump(summary, f, indent=2)
print("  Saved: 3way_summary.json")

print("\n" + "="*65)
print("  3-WAY BENCHMARK COMPLETE")
print("="*65)
print("  Configuration        Avg Runtime    Speedup vs No-Index")
print("  "+"-"*55)
print("  No Indexes           {:>8.1f} ms     1.00x".format(avg_no_index))
print("  Before ML (baseline) {:>8.1f} ms     {:.2f}x".format(avg_before, speedup_before_vs_none))
print("  ML Recommended       {:>8.1f} ms     {:.2f}x".format(avg_after,  speedup_after_vs_none))
print("="*65)
print("\n  This is your KEY RESULT TABLE for the IEEE paper!")
print("="*65)