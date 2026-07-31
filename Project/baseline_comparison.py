"""
================================================================
Baseline Comparison for ML Index Recommendation
================================================================
Three baselines compared against Gradient Boosting (ML model):

Baseline 1: Rule-Based
  → Index if EXPLAIN shows type=ALL OR rows > threshold

Baseline 2: Frequency-Based  
  → Index most frequently queried WHERE/JOIN columns

Baseline 3: Join-Only Heuristic
  → Index all columns used in JOIN ON clauses only

All baselines use same feature data as ML model (v3).
Output saved to: baseline_results/
================================================================
"""

import pandas as pd
import numpy as np
import os
import json
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')
from sklearn.metrics import (
    accuracy_score, f1_score, precision_score,
    recall_score, classification_report, confusion_matrix
)
from sklearn.model_selection import train_test_split
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler

OUTPUT_DIR = "baseline_results"
os.makedirs(OUTPUT_DIR, exist_ok=True)

print("=" * 60)
print("  Baseline Comparison — ML vs Rule-Based Methods")
print("=" * 60)

# ── Load Data ──
print("\n[1/5] Loading data...")
# Load from ml_results (v1 has the full feature dataset)
# Then re-apply noise same as v3 for consistency
df = pd.read_csv("ml_results/full_feature_dataset.csv")
print(f"  Loaded from ml_results: {len(df)} rows")

print(f"  Columns: {list(df.columns[:10])}...")
print(f"  Needs index: {df['needs_index'].sum()} / {len(df)}")

# ── Feature Setup ──
print("\n[2/5] Setting up features...")

FEATURE_COLS = [
    'has_full_scan', 'full_scan_table_count', 'max_join_type_score',
    'avg_join_type_score', 'has_index_scan', 'has_range_scan',
    'has_ref_scan', 'has_const_scan', 'index_coverage_ratio',
    'num_indexes_used', 'has_no_index', 'avg_possible_keys',
    'has_possible_keys', 'total_rows_examined', 'max_rows_examined',
    'log_rows_examined', 'avg_rows_examined', 'has_filesort',
    'has_temp_table', 'has_using_index', 'has_using_where',
    'has_impossible_where', 'num_tables', 'has_subquery',
    'has_derived', 'has_union', 'num_select_types',
    'has_range_check', 'min_filtered_pct', 'avg_filtered_pct',
]

# Use only columns that exist
available = [c for c in FEATURE_COLS if c in df.columns]
print(f"  Using {len(available)} features")

X = df[available].fillna(0)
y = df['needs_index']

# Add noise (same as v3)
NOISE_COLS = [c for c in ['total_rows_examined','max_rows_examined',
    'log_rows_examined','avg_rows_examined','min_filtered_pct',
    'avg_filtered_pct','avg_possible_keys'] if c in X.columns]

np.random.seed(42)
X_noisy = X.copy()
for col in NOISE_COLS:
    std = X_noisy[col].std()
    if std > 0:
        noise = np.random.normal(0, 0.08 * std, size=len(X_noisy))
        X_noisy[col] = (X_noisy[col] + noise).clip(lower=0)
X = X_noisy

# Train/test split (same seed as ML model)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)
print(f"  Train: {len(X_train)} | Test: {len(X_test)}")
df_test = df.iloc[y_test.index] if hasattr(y_test, 'index') else df

# ── ML Model (Gradient Boosting) ──
print("\n[3/5] Training ML model (Gradient Boosting)...")
gb = GradientBoostingClassifier(
    n_estimators=200, learning_rate=0.05,
    max_depth=5, random_state=42
)
gb.fit(X_train, y_train)
y_pred_ml = gb.predict(X_test)
print("  ML model trained")

# ── BASELINE 1: Rule-Based ──
print("\n[4/5] Computing baselines...")
print("  Baseline 1: Rule-Based...")

# Rule: needs_index=1 if has_full_scan=1 OR rows > 60th percentile threshold
row_threshold = X_train['total_rows_examined'].quantile(0.60) \
    if 'total_rows_examined' in X_train.columns else 100000

def rule_based_predict(X_data):
    preds = []
    for _, row in X_data.iterrows():
        full_scan = row.get('has_full_scan', 0) >= 1
        high_rows = row.get('total_rows_examined', 0) > row_threshold
        no_index  = row.get('has_no_index', 0) >= 1
        filesort  = row.get('has_filesort', 0) >= 1
        low_cov   = row.get('index_coverage_ratio', 1) < 0.5
        # Rule: flag if full scan OR (no index AND high rows) OR (filesort AND low coverage)
        pred = 1 if (full_scan or (no_index and high_rows) or
                     (filesort and low_cov)) else 0
        preds.append(pred)
    return np.array(preds)

y_pred_rule = rule_based_predict(X_test)
print(f"    Rule-based: {y_pred_rule.sum()} flagged as needs_index")

# ── BASELINE 2: Frequency-Based ──
print("  Baseline 2: Frequency-Based (top column usage)...")

def frequency_based_predict(X_data):
    """
    Frequency heuristic: flag query if it uses many tables
    and has low index coverage — common columns get indexed
    """
    preds = []
    for _, row in X_data.iterrows():
        num_tables   = row.get('num_tables', 1)
        index_cov    = row.get('index_coverage_ratio', 1)
        possible_keys= row.get('avg_possible_keys', 1)
        # Heuristic: multi-table with low coverage = needs index
        pred = 1 if (num_tables >= 2 and index_cov < 0.7) or \
                    (possible_keys == 0 and num_tables >= 1) else 0
        preds.append(pred)
    return np.array(preds)

y_pred_freq = frequency_based_predict(X_test)
print(f"    Frequency-based: {y_pred_freq.sum()} flagged")

# ── BASELINE 3: Join-Only Heuristic ──
print("  Baseline 3: Join-Only Heuristic...")

def join_only_predict(X_data):
    """
    Join heuristic: only flag queries that involve joins
    with non-optimal join types (not eq_ref or ref)
    """
    preds = []
    for _, row in X_data.iterrows():
        num_tables     = row.get('num_tables', 1)
        max_join_score = row.get('max_join_type_score', 0)
        # Join types > 7 include range, index, ALL — suboptimal
        pred = 1 if (num_tables >= 2 and max_join_score >= 7) else 0
        preds.append(pred)
    return np.array(preds)

y_pred_join = join_only_predict(X_test)
print(f"    Join-only: {y_pred_join.sum()} flagged")

# ── Evaluate All Methods ──
print("\n[5/5] Evaluating all methods...")

def evaluate(y_true, y_pred, name):
    acc  = accuracy_score(y_true, y_pred)
    prec = precision_score(y_true, y_pred, zero_division=0)
    rec  = recall_score(y_true, y_pred, zero_division=0)
    f1   = f1_score(y_true, y_pred, zero_division=0)
    cm   = confusion_matrix(y_true, y_pred)
    fp   = cm[0,1] if cm.shape == (2,2) else 0  # False positives
    fn   = cm[1,0] if cm.shape == (2,2) else 0  # False negatives
    return {
        'Method': name,
        'Accuracy': round(acc, 4),
        'Precision': round(prec, 4),
        'Recall': round(rec, 4),
        'F1': round(f1, 4),
        'FP': int(fp),
        'FN': int(fn),
    }

results = [
    evaluate(y_test, y_pred_rule, "Rule-Based Baseline"),
    evaluate(y_test, y_pred_freq, "Frequency-Based Baseline"),
    evaluate(y_test, y_pred_join, "Join-Only Heuristic"),
    evaluate(y_test, y_pred_ml,   "Gradient Boosting (Ours)"),
]

results_df = pd.DataFrame(results)
print("\n" + "="*75)
print("  BASELINE COMPARISON RESULTS")
print("="*75)
print(f"  {'Method':<30} {'Acc':>6} {'Prec':>6} {'Rec':>6} {'F1':>6} {'FP':>5} {'FN':>5}")
print("-"*75)
for r in results:
    print(f"  {r['Method']:<30} {r['Accuracy']:>6.4f} {r['Precision']:>6.4f} "
          f"{r['Recall']:>6.4f} {r['F1']:>6.4f} {r['FP']:>5} {r['FN']:>5}")
print("="*75)

# Save CSV
results_df.to_csv(os.path.join(OUTPUT_DIR, 'baseline_comparison.csv'), index=False)
print(f"\n  Saved: baseline_comparison.csv")

# ── Plot Comparison ──
fig, axes = plt.subplots(1, 4, figsize=(16, 5))
fig.suptitle('Baseline Comparison: ML vs Rule-Based Methods\n(TPC-H Index Recommendation)',
             fontsize=13, fontweight='bold')

metrics = ['Accuracy', 'Precision', 'Recall', 'F1']
colors  = ['#E74C3C', '#E67E22', '#F1C40F', '#2ECC71']
methods = [r['Method'].replace(' Baseline','').replace(' (Ours)','*') for r in results]

for ax, metric in zip(axes, metrics):
    vals = [r[metric] for r in results]
    bars = ax.bar(methods, vals, color=colors, edgecolor='black', linewidth=0.8)
    ax.set_title(metric, fontweight='bold', fontsize=11)
    ax.set_ylim(0, 1.1)
    ax.set_ylabel('Score')
    ax.tick_params(axis='x', rotation=25, labelsize=8)
    for bar, val in zip(bars, vals):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
                f'{val:.3f}', ha='center', va='bottom', fontsize=9, fontweight='bold')
    # Highlight ML bar
    bars[3].set_edgecolor('#1A5276')
    bars[3].set_linewidth(2.5)

plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR, 'fig_baseline_comparison.png'),
            dpi=150, bbox_inches='tight')
plt.close()
print("  Saved: fig_baseline_comparison.png")

# ── Ablation Study ──
print("\n" + "="*60)
print("  ABLATION STUDY — Feature Group Removal")
print("="*60)

feature_groups = {
    'Full Model (All Features)': available,
    'Remove Scan Features':   [c for c in available if c not in
                               ['has_full_scan','full_scan_table_count','has_index_scan','has_range_scan']],
    'Remove Row Estimates':    [c for c in available if c not in
                               ['total_rows_examined','max_rows_examined','log_rows_examined','avg_rows_examined']],
    'Remove Plan Flags':       [c for c in available if c not in
                               ['has_filesort','has_temp_table','has_using_index','has_using_where']],
    'Remove Coverage Features':[c for c in available if c not in
                               ['index_coverage_ratio','num_indexes_used','has_no_index','avg_possible_keys']],
    'Scan Features Only':      [c for c in available if c in
                               ['has_full_scan','full_scan_table_count','max_join_type_score','index_coverage_ratio']],
}

ablation_results = []
for group_name, feat_cols in feature_groups.items():
    if len(feat_cols) == 0:
        continue
    X_tr = X_train[feat_cols]
    X_te = X_test[feat_cols]
    model = GradientBoostingClassifier(
        n_estimators=200, learning_rate=0.05, max_depth=5, random_state=42
    )
    model.fit(X_tr, y_train)
    y_pred = model.predict(X_te)
    f1  = f1_score(y_test, y_pred, zero_division=0)
    acc = accuracy_score(y_test, y_pred)
    ablation_results.append({
        'Feature Group': group_name,
        'Num Features': len(feat_cols),
        'Accuracy': round(acc, 4),
        'F1': round(f1, 4),
        'F1 Drop': round(ablation_results[0]['F1'] - f1, 4) if ablation_results else 0.0
    })
    print(f"  {group_name:<35} Acc={acc:.4f}  F1={f1:.4f}  "
          f"Features={len(feat_cols)}")

ablation_df = pd.DataFrame(ablation_results)
ablation_df.to_csv(os.path.join(OUTPUT_DIR, 'ablation_study.csv'), index=False)
print(f"\n  Saved: ablation_study.csv")

# Plot ablation
fig, ax = plt.subplots(figsize=(10, 5))
names = [r['Feature Group'].replace('Remove ','- ').replace('Full Model (All Features)','Full Model') 
         for r in ablation_results]
f1s   = [r['F1'] for r in ablation_results]
cols  = ['#2ECC71'] + ['#E74C3C']*4 + ['#3498DB']
bars  = ax.barh(names, f1s, color=cols, edgecolor='black', linewidth=0.8)
ax.set_xlabel('F1 Score', fontsize=11)
ax.set_title('Ablation Study: Impact of Feature Group Removal\n(Gradient Boosting)',
             fontsize=12, fontweight='bold')
ax.set_xlim(0.7, 1.05)
for bar, val in zip(bars, f1s):
    ax.text(val + 0.003, bar.get_y() + bar.get_height()/2,
            f'{val:.4f}', va='center', fontsize=9)
ax.axvline(x=f1s[0], color='green', linestyle='--', alpha=0.5, label='Full model F1')
ax.legend()
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR, 'fig_ablation_study.png'),
            dpi=150, bbox_inches='tight')
plt.close()
print("  Saved: fig_ablation_study.png")

# ── Save Summary JSON ──
summary = {
    'baseline_comparison': results,
    'ablation_study': ablation_results,
    'test_set_size': int(len(y_test)),
    'row_threshold_used': float(row_threshold),
    'noise_level': 0.08,
    'random_seed': 42,
}
with open(os.path.join(OUTPUT_DIR, 'baseline_summary.json'), 'w') as f:
    json.dump(summary, f, indent=2)
print("  Saved: baseline_summary.json")

print("\n" + "="*60)
print("  COMPLETE. Output in baseline_results/")
print("  Files:")
for f in os.listdir(OUTPUT_DIR):
    size = os.path.getsize(os.path.join(OUTPUT_DIR, f))
    print(f"    {f:<40} {size:>8} bytes")
print("="*60)