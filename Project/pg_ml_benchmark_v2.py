"""
PostgreSQL TPC-H ML Index Recommendation
==========================================
Extracts 30 structural features from PostgreSQL EXPLAIN
Runs same ML pipeline as MySQL version
Compares cross-DBMS generalizability
"""

import psycopg2
import csv
import os
import json
import statistics
import numpy as np
import warnings
warnings.filterwarnings('ignore')

from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.svm import SVC
from sklearn.model_selection import train_test_split, cross_val_score, StratifiedKFold, GroupKFold
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import f1_score, accuracy_score, classification_report
from scipy import stats

# ── CONFIG ──────────────────────────────────────────
PG_CONFIG = {
    "host":     "127.0.0.1",
    "port":     5432,
    "dbname":   "tpch_pg",
    "user":     "sayememon",
}

PROJECT_DIR = "/Users/sayememon/Desktop/Troy Courses/Adv Database System/Project"
QUERIES_DIR = os.path.join(PROJECT_DIR, "queries_pg")
OUTPUT_DIR  = os.path.join(PROJECT_DIR, "pg_results")
os.makedirs(OUTPUT_DIR, exist_ok=True)

QUERY_FILES = {
    "aggregation":          "Aggregation_pg.sql",
    "complex_queries":      "complex_queries_pg.sql",
    "single_table_filters": "single_table_filters_pg.sql",
    "three_table_joins":    "three_table_joins_pg.sql",
    "two_table_joins":      "two_table_joins_pg.sql",
}

# ── PostgreSQL EXPLAIN feature extraction ────────────

def parse_pg_explain(plan_rows):
    """
    Parse PostgreSQL EXPLAIN output into 30 structural features.
    PostgreSQL EXPLAIN returns text lines describing the plan tree.
    Key signals: Seq Scan = full scan, Index Scan = using index,
    rows = cardinality estimate, cost = optimizer cost estimate.
    """
    features = {
        # Scan type features
        "has_seq_scan":          0,   # equivalent to MySQL type=ALL
        "seq_scan_count":        0,   # number of seq scans
        "has_index_scan":        0,   # using index
        "has_index_only_scan":   0,   # covering index
        "has_bitmap_scan":       0,   # bitmap heap scan
        "max_scan_cost":         0.0, # highest node cost

        # Join features
        "has_nested_loop":       0,
        "has_hash_join":         0,
        "has_merge_join":        0,
        "num_join_nodes":        0,

        # Row estimate features
        "total_rows_estimated":  0,
        "max_rows_estimated":    0,
        "log_total_rows":        0.0,

        # Cost features
        "total_startup_cost":    0.0,
        "total_run_cost":        0.0,
        "max_node_cost":         0.0,

        # Filter features
        "has_filter":            0,
        "has_sort":              0,
        "has_aggregate":         0,
        "has_hash":              0,

        # Index coverage
        "index_coverage_ratio":  0.0, # fraction of scans using index
        "num_index_scans":       0,
        "num_total_scans":       0,
        "has_no_index":          0,   # all scans are seq scans

        # Plan complexity
        "plan_depth":            0,
        "num_nodes":             0,
        "has_subquery":          0,
        "has_cte":               0,

        # Additional
        "num_tables_accessed":   0,
        "max_width":             0,   # row width estimate
    }

    plan_text = "\n".join(str(r[0]) for r in plan_rows)
    lines     = plan_text.split("\n")

    seq_scans   = 0
    idx_scans   = 0
    total_scans = 0
    max_rows    = 0
    total_rows  = 0
    max_cost    = 0.0
    total_cost  = 0.0
    depth       = 0
    nodes       = 0
    tables      = set()

    for line in lines:
        stripped = line.strip()
        nodes += 1

        # Measure depth by indentation
        indent = len(line) - len(line.lstrip())
        depth  = max(depth, indent // 2)

        # Scan types
        if "Seq Scan" in stripped:
            features["has_seq_scan"] = 1
            seq_scans   += 1
            total_scans += 1
            # Extract table name
            if " on " in stripped.lower():
                parts = stripped.split(" on ")
                if len(parts) > 1:
                    tbl = parts[1].split()[0].strip()
                    tables.add(tbl)

        elif "Index Only Scan" in stripped:
            features["has_index_only_scan"] = 1
            features["has_index_scan"]      = 1
            idx_scans   += 1
            total_scans += 1

        elif "Index Scan" in stripped:
            features["has_index_scan"] = 1
            idx_scans   += 1
            total_scans += 1

        elif "Bitmap Heap Scan" in stripped:
            features["has_bitmap_scan"] = 1
            idx_scans   += 1
            total_scans += 1

        # Join types
        if "Nested Loop" in stripped:
            features["has_nested_loop"] = 1
            features["num_join_nodes"] += 1
        if "Hash Join" in stripped:
            features["has_hash_join"]  = 1
            features["num_join_nodes"] += 1
        if "Merge Join" in stripped:
            features["has_merge_join"] = 1
            features["num_join_nodes"] += 1

        # Other operations
        if "Sort" in stripped:
            features["has_sort"] = 1
        if "Aggregate" in stripped or "GroupAggregate" in stripped or "HashAggregate" in stripped:
            features["has_aggregate"] = 1
        if "Hash" in stripped and "Join" not in stripped:
            features["has_hash"] = 1
        if "Filter:" in stripped:
            features["has_filter"] = 1
        if "SubPlan" in stripped or "InitPlan" in stripped:
            features["has_subquery"] = 1
        if "CTE" in stripped:
            features["has_cte"] = 1

        # Extract rows and cost from EXPLAIN output
        # Format: (cost=X..Y rows=Z width=W)
        if "cost=" in stripped and "rows=" in stripped:
            try:
                # Extract cost
                cost_part = stripped.split("cost=")[1].split(")")[0]
                costs     = cost_part.split("..")
                if len(costs) == 2:
                    startup = float(costs[0].strip())
                    run     = float(costs[1].split()[0].strip())
                    total_cost   += run
                    max_cost      = max(max_cost, run)
                    features["total_startup_cost"] += startup

                # Extract rows
                rows_part = stripped.split("rows=")[1].split()[0]
                rows      = int(rows_part.replace(")", "").strip())
                total_rows += rows
                max_rows   = max(max_rows, rows)

                # Extract width
                if "width=" in stripped:
                    width_part = stripped.split("width=")[1].split(")")[0].strip()
                    features["max_width"] = max(features["max_width"], int(width_part))

            except (ValueError, IndexError):
                pass

    # Compute derived features
    features["seq_scan_count"]       = seq_scans
    features["num_index_scans"]      = idx_scans
    features["num_total_scans"]      = total_scans
    features["total_rows_estimated"] = total_rows
    features["max_rows_estimated"]   = max_rows
    features["log_total_rows"]       = float(np.log10(total_rows + 1))
    features["total_run_cost"]       = round(total_cost, 2)
    features["max_node_cost"]        = round(max_cost, 2)
    features["max_scan_cost"]        = round(max_cost, 2)
    features["plan_depth"]           = depth
    features["num_nodes"]            = nodes
    features["num_tables_accessed"]  = len(tables)

    if total_scans > 0:
        features["index_coverage_ratio"] = round(idx_scans / total_scans, 4)
    else:
        features["index_coverage_ratio"] = 0.0

    if seq_scans > 0 and idx_scans == 0:
        features["has_no_index"] = 1

    return features


def label_query_pg(features, p60_rows):
    """
    Generate label using same logic as MySQL version
    but adapted for PostgreSQL features.
    """
    # (a) Full sequential scan detected
    if features["has_seq_scan"] == 1 and features["seq_scan_count"] >= 1:
        if features["total_rows_estimated"] > p60_rows:
            return 1

    # (b) No index used AND high rows
    if features["has_no_index"] == 1 and features["total_rows_estimated"] > p60_rows:
        return 1

    # (c) Sort with high rows (equivalent to filesort)
    if features["has_sort"] == 1 and features["total_rows_estimated"] > p60_rows:
        return 1

    # (d) Multiple tables with low index coverage
    if features["num_tables_accessed"] > 1 and features["index_coverage_ratio"] < 0.5:
        return 1

    return 0


def parse_sql_file(filepath, category):
    queries = []
    cat_prefix = {
        "aggregation":          "AGG",
        "complex_queries":      "COM",
        "single_table_filters": "SIN",
        "three_table_joins":    "THR",
        "two_table_joins":      "TWO",
    }
    prefix = cat_prefix.get(category, "Q")
    with open(filepath, encoding="utf-8", errors="ignore") as f:
        content = f.read()
    raw = content.split(";")
    qnum = 1
    for raw_sql in raw:
        sql = raw_sql.strip()
        lines = [l.strip() for l in sql.split("\n")
                 if l.strip() and not l.strip().startswith("--")]
        if not lines:
            continue
        clean = " ".join(lines)
        if not clean.upper().startswith("SELECT"):
            continue
        queries.append((f"{prefix}_Q{qnum:03d}", category, clean))
        qnum += 1
    return queries


def main():
    print("=" * 65)
    print("  PostgreSQL TPC-H ML Index Recommendation")
    print("  Cross-DBMS Generalizability Experiment")
    print("=" * 65)

    # ── Load queries ──────────────────────────────────
    print("\nLoading queries...")
    all_queries = []
    for category, filename in QUERY_FILES.items():
        filepath = os.path.join(QUERIES_DIR, filename)
        if not os.path.exists(filepath):
            print(f"  WARNING: {filename} not found")
            continue
        qs = parse_sql_file(filepath, category)
        print(f"  {filename:<35} {len(qs):4d} queries")
        all_queries.extend(qs)
    print(f"  Total: {len(all_queries)} queries\n")

    # ── Connect to PostgreSQL ─────────────────────────
    conn = psycopg2.connect(**PG_CONFIG)
    cur  = conn.cursor()
    print("Connected to PostgreSQL tpch_pg ✅\n")

    # ── Extract EXPLAIN features ──────────────────────
    print("Extracting EXPLAIN features...")
    dataset = []
    errors  = 0

    for idx, (qid, category, sql) in enumerate(all_queries, 1):
        print(f"  [{idx:4d}/{len(all_queries)}] {qid:<15}", end="", flush=True)
        try:
            cur.execute(f"EXPLAIN {sql}")
            plan_rows = cur.fetchall()
            features  = parse_pg_explain(plan_rows)
            features["query_id"] = qid
            features["category"] = category
            dataset.append(features)
            print(f"  rows={features['total_rows_estimated']:>10,}  "
                  f"seq={features['seq_scan_count']}  "
                  f"idx_cov={features['index_coverage_ratio']:.2f}")
        except Exception as e:
            print(f"  ERROR: {str(e)[:40]}")
            errors += 1
            conn.rollback()

    cur.close()
    conn.close()

    print(f"\nExtracted {len(dataset)} queries ({errors} errors)\n")

    if len(dataset) < 50:
        print("Not enough queries to train ML model!")
        return

    # ── Save features CSV ─────────────────────────────
    feat_csv = os.path.join(OUTPUT_DIR, "pg_explain_features.csv")
    with open(feat_csv, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=dataset[0].keys())
        writer.writeheader()
        writer.writerows(dataset)
    print(f"Features saved: {feat_csv}")

    # ── Generate labels ───────────────────────────────
    all_rows = [d["total_rows_estimated"] for d in dataset]
    p60      = np.percentile(all_rows, 60)
    print(f"P60 row threshold: {p60:,.0f}")

    for d in dataset:
        d["needs_index"] = label_query_pg(d, p60)

    n_pos = sum(d["needs_index"] for d in dataset)
    n_neg = len(dataset) - n_pos
    print(f"Labels: {n_pos} needs_index=1 ({n_pos/len(dataset)*100:.1f}%), "
          f"{n_neg} needs_index=0 ({n_neg/len(dataset)*100:.1f}%)\n")

    # ── Mann-Whitney label validation ─────────────────
    # Measure actual runtime for label validation
    print("Measuring actual runtimes for label validation...")
    conn2 = psycopg2.connect(**PG_CONFIG)
    cur2  = conn2.cursor()

    import time
    runtimes = {}
    for d in dataset[:200]:  # sample 200 for speed
        qid = d["query_id"]
        cat = d["category"]
        sql = None
        # Find the SQL
        for q_qid, q_cat, q_sql in all_queries:
            if q_qid == qid:
                sql = q_sql
                break
        if not sql:
            continue
        try:
            cur2.execute(f"SET statement_timeout = '30s'")
            t0 = time.time()
            cur2.execute(sql)
            cur2.fetchall()
            elapsed = (time.time() - t0) * 1000
            runtimes[qid] = elapsed
        except Exception:
            conn2.rollback()

    cur2.close()
    conn2.close()

    # Mann-Whitney test
    pos_times = [runtimes[d["query_id"]] for d in dataset
                 if d["query_id"] in runtimes and d["needs_index"] == 1]
    neg_times = [runtimes[d["query_id"]] for d in dataset
                 if d["query_id"] in runtimes and d["needs_index"] == 0]

    if pos_times and neg_times:
        u_stat, p_val = stats.mannwhitneyu(pos_times, neg_times, alternative='greater')
        avg_pos = np.mean(pos_times)
        avg_neg = np.mean(neg_times)
        ratio   = avg_pos / avg_neg if avg_neg > 0 else 0
        print(f"  Mann-Whitney U={u_stat:.0f}, p={p_val:.6f}")
        print(f"  needs_index=1 avg: {avg_pos:.1f}ms")
        print(f"  needs_index=0 avg: {avg_neg:.1f}ms")
        print(f"  Runtime ratio: {ratio:.2f}x\n")
    else:
        print("  Not enough runtime data for Mann-Whitney test\n")
        p_val = None
        ratio = None

    # ── ML Training ──────────────────────────────────
    print("Training ML models on PostgreSQL features...")

    feature_cols = [k for k in dataset[0].keys()
                    if k not in ["query_id","category","needs_index"]]

    X = np.array([[d[f] for f in feature_cols] for d in dataset])
    y = np.array([d["needs_index"] for d in dataset])
    groups = np.array([d["category"] for d in dataset])

    # Add small Gaussian noise to continuous features
    rng = np.random.RandomState(42)
    noise_cols = [i for i,f in enumerate(feature_cols)
                  if "rows" in f or "cost" in f or "width" in f]
    X_noisy = X.copy().astype(float)
    for col in noise_cols:
        X_noisy[:, col] *= (1 + rng.normal(0, 0.08, size=len(X)))

    # Train/test split
    X_train, X_test, y_train, y_test = train_test_split(
        X_noisy, y, test_size=0.2, random_state=42, stratify=y)

    scaler  = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test  = scaler.transform(X_test)
    X_all   = scaler.transform(X_noisy)

    models = {
        "Random Forest":     RandomForestClassifier(n_estimators=200, max_depth=10, random_state=42),
        "Gradient Boosting": GradientBoostingClassifier(n_estimators=200, learning_rate=0.05, max_depth=5, random_state=42),
        "SVM":               SVC(kernel="rbf", C=10, random_state=42, probability=True),
    }

    results = {}
    cv      = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    gkf     = GroupKFold(n_splits=5)

    print(f"\n  {'Model':<22} {'Accuracy':>10} {'F1':>8} {'CV-F1':>12} {'GKF-F1':>12}")
    print(f"  {'-'*66}")

    best_model  = None
    best_cv_f1  = 0

    for name, model in models.items():
        model.fit(X_train, y_train)
        y_pred   = model.predict(X_test)
        acc      = accuracy_score(y_test, y_pred)
        f1       = f1_score(y_test, y_pred)
        cv_f1    = cross_val_score(model, X_all, y, cv=cv, scoring="f1").mean()
        cv_std   = cross_val_score(model, X_all, y, cv=cv, scoring="f1").std()

        # GroupKFold
        gkf_scores = []
        for train_idx, test_idx in gkf.split(X_noisy, y, groups):
            Xtr = scaler.fit_transform(X_noisy[train_idx])
            Xte = scaler.transform(X_noisy[test_idx])
            m2  = models[name].__class__(**models[name].get_params())
            m2.fit(Xtr, y[train_idx])
            gkf_scores.append(f1_score(y[test_idx], m2.predict(Xte)))
        gkf_f1  = np.mean(gkf_scores)
        gkf_std = np.std(gkf_scores)

        selected = " ← BEST" if cv_f1 > best_cv_f1 else ""
        print(f"  {name:<22} {acc:>10.4f} {f1:>8.4f} "
              f"{cv_f1:>6.4f}±{cv_std:.4f} "
              f"{gkf_f1:>6.4f}±{gkf_std:.4f}{selected}")

        results[name] = {
            "accuracy":  round(acc, 4),
            "f1":        round(f1, 4),
            "cv_f1":     round(cv_f1, 4),
            "cv_std":    round(cv_std, 4),
            "gkf_f1":    round(gkf_f1, 4),
            "gkf_std":   round(gkf_std, 4),
        }

        if cv_f1 > best_cv_f1:
            best_cv_f1 = cv_f1
            best_model = name

    print(f"\n  Best model: {best_model} (CV-F1 = {best_cv_f1:.4f})")

    # ── Label distribution comparison ────────────────
    print(f"\n{'='*65}")
    print("  CROSS-DBMS COMPARISON SUMMARY")
    print(f"{'='*65}")
    print(f"\n  Metric                    MySQL SF-1    PostgreSQL SF-1")
    print(f"  {'-'*55}")
    print(f"  Total queries             906           {len(dataset)}")
    print(f"  needs_index=1 (%)         76.5%         {n_pos/len(dataset)*100:.1f}%")
    print(f"  GB CV-F1 (random)         0.9973        {results.get('Gradient Boosting',{}).get('cv_f1',0):.4f}")
    print(f"  GB CV-F1 (GroupKFold)     0.9701        {results.get('Gradient Boosting',{}).get('gkf_f1',0):.4f}")
    if ratio:
        print(f"  Runtime ratio (p<0.001)   3.22x         {ratio:.2f}x")

    # ── Save summary ──────────────────────────────────
    summary = {
        "dbms":              "PostgreSQL 16",
        "database":          "tpch_pg (SF-1)",
        "total_queries":     len(dataset),
        "n_features":        len(feature_cols),
        "label_pos_pct":     round(n_pos/len(dataset)*100, 1),
        "p60_threshold":     round(p60, 0),
        "mann_whitney_p":    round(p_val, 6) if p_val else None,
        "runtime_ratio":     round(ratio, 2) if ratio else None,
        "models":            results,
        "best_model":        best_model,
        "best_cv_f1":        round(best_cv_f1, 4),
    }

    out_path = os.path.join(OUTPUT_DIR, "pg_ml_results.json")
    with open(out_path, "w") as f:
        json.dump(summary, f, indent=2)

    print(f"\n  Results saved: {out_path}")
    print(f"{'='*65}")
    print("\n  ✅ PostgreSQL cross-DBMS experiment complete!")
    print("  Add these results to paper Section V and Table 3")


if __name__ == "__main__":
    main()
