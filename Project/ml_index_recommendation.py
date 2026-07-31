"""
============================================================
ML-Based Index Recommendation System
============================================================
Thesis: Workload-Driven Automated Index Recommendation
        Using Machine Learning: A Comprehensive TPC-H
        Benchmark Evaluation

Pipeline:
  Step 1: Load & parse explain_results.csv + runtime_results.csv
  Step 2: Extract ML features from EXPLAIN output
  Step 3: Label queries (needs_index = 1 if slow + bad plan)
  Step 4: Train ML models (Random Forest, Gradient Boosting, SVM)
  Step 5: Evaluate models (accuracy, F1, ROC-AUC)
  Step 6: Generate index recommendations
  Step 7: Save all results for thesis

Requirements:
  pip install pandas numpy scikit-learn matplotlib seaborn

Usage:
  python ml_index_recommendation.py
============================================================
"""

import pandas as pd
import numpy as np
import os
import json
import warnings
warnings.filterwarnings('ignore')

from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.svm import SVC
from sklearn.model_selection import train_test_split, cross_val_score, StratifiedKFold
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.metrics import (classification_report, confusion_matrix,
                             roc_auc_score, accuracy_score, f1_score)
from sklearn.inspection import permutation_importance

import matplotlib
matplotlib.use('Agg')  # non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import seaborn as sns

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────

RUNTIME_CSV = "results/runtime_results.csv"
EXPLAIN_CSV = "results/explain_results.csv"
OUTPUT_DIR  = "ml_results"

# Thresholds for labeling
SLOW_QUERY_MS        = 500    # queries slower than this need index attention
BAD_JOIN_TYPES       = ['ALL', 'index']   # full table scan = needs index
RUNTIME_PERCENTILE   = 75     # top 25% slowest = needs index

os.makedirs(OUTPUT_DIR, exist_ok=True)

print("=" * 65)
print("  ML-Based Index Recommendation System")
print("  TPC-H Benchmark Evaluation")
print("=" * 65)


# ─────────────────────────────────────────────
# STEP 1: LOAD DATA
# ─────────────────────────────────────────────
print("\n[1/7] Loading data...")

runtime_df = pd.read_csv(RUNTIME_CSV)
explain_df = pd.read_csv(EXPLAIN_CSV)

# Keep only successful queries
runtime_df = runtime_df[runtime_df['status'] == 'OK'].copy()

print("  Runtime rows  : {:,}".format(len(runtime_df)))
print("  Explain rows  : {:,}".format(len(explain_df)))
print("  Categories    : {}".format(sorted(runtime_df['category'].unique())))


# ─────────────────────────────────────────────
# STEP 2: FEATURE EXTRACTION
# ─────────────────────────────────────────────
print("\n[2/7] Extracting ML features from EXPLAIN data...")

# ── Per-query EXPLAIN aggregation ──
# Each query can have multiple EXPLAIN rows (one per table)
# We aggregate to one row per query

def extract_explain_features(group):
    """Aggregate EXPLAIN rows into per-query features."""
    features = {}

    # Join type encoding (worst join type in query)
    join_type_rank = {
        'system': 0, 'const': 1, 'eq_ref': 2, 'ref': 3,
        'fulltext': 4, 'ref_or_null': 5, 'index_merge': 6,
        'unique_subquery': 7, 'index_subquery': 8,
        'range': 9, 'index': 10, 'ALL': 11
    }
    types = group['type'].fillna('ALL').tolist()
    type_scores = [join_type_rank.get(str(t).strip(), 11) for t in types]
    features['max_join_type_score'] = max(type_scores) if type_scores else 11
    features['avg_join_type_score'] = np.mean(type_scores) if type_scores else 11
    features['has_full_scan']       = int(any(str(t).strip() == 'ALL' for t in types))
    features['has_index_scan']      = int(any(str(t).strip() == 'index' for t in types))
    features['has_range_scan']      = int(any(str(t).strip() == 'range' for t in types))
    features['has_ref_scan']        = int(any(str(t).strip() in ['ref','eq_ref'] for t in types))

    # Index usage
    keys = group['key'].fillna('').tolist()
    features['num_tables']          = len(group)
    features['num_indexes_used']    = sum(1 for k in keys if str(k).strip() not in ['', 'None', 'nan'])
    features['index_coverage_ratio']= features['num_indexes_used'] / max(features['num_tables'], 1)
    features['has_no_index']        = int(features['num_indexes_used'] == 0)

    # Possible keys
    pkeys = group['possible_keys'].fillna('').tolist()
    features['avg_possible_keys']   = np.mean([
        len(str(p).split(',')) if str(p).strip() not in ['', 'None', 'nan'] else 0
        for p in pkeys
    ])

    # Rows examined
    rows = pd.to_numeric(group['rows'], errors='coerce').fillna(0)
    features['total_rows_examined'] = rows.sum()
    features['max_rows_examined']   = rows.max()
    features['avg_rows_examined']   = rows.mean()
    features['log_rows_examined']   = np.log1p(rows.sum())

    # Filtered
    filtered = pd.to_numeric(group['filtered'], errors='coerce').fillna(100)
    features['avg_filtered_pct']    = filtered.mean()
    features['min_filtered_pct']    = filtered.min()

    # Extra column analysis
    extras = ' '.join(group['Extra'].fillna('').astype(str).tolist()).lower()
    features['has_filesort']        = int('filesort' in extras)
    features['has_temp_table']      = int('temporary' in extras)
    features['has_using_index']     = int('using index' in extras)
    features['has_using_where']     = int('using where' in extras)
    features['has_impossible_where']= int('impossible where' in extras)

    # Select type diversity
    select_types = group['select_type'].fillna('SIMPLE').tolist()
    features['has_subquery']        = int(any('SUBQUERY' in str(s).upper() for s in select_types))
    features['has_derived']         = int(any('DERIVED' in str(s).upper() for s in select_types))
    features['has_union']           = int(any('UNION' in str(s).upper() for s in select_types))
    features['num_select_types']    = len(set(str(s).upper() for s in select_types))

    return pd.Series(features)

explain_features = (
    explain_df
    .groupby(['category', 'query_id'])
    .apply(extract_explain_features)
    .reset_index()
)

print("  Features extracted: {} per query".format(
    len([c for c in explain_features.columns if c not in ['category','query_id']])))
print("  Queries with features: {:,}".format(len(explain_features)))


# ─────────────────────────────────────────────
# STEP 3: MERGE + LABEL
# ─────────────────────────────────────────────
print("\n[3/7] Merging runtime + EXPLAIN features and labeling...")

# Merge runtime with explain features
df = runtime_df.merge(explain_features, on=['category', 'query_id'], how='inner')

# ── Category encoding ──
cat_encoder = LabelEncoder()
df['category_encoded'] = cat_encoder.fit_transform(df['category'])

# ── Runtime features ──
df['log_avg_runtime'] = np.log1p(df['avg_runtime_ms'])
df['runtime_ratio']   = df['avg_runtime_ms'] / df['avg_runtime_ms'].median()

# ── LABELING STRATEGY ──
# A query "needs index" if:
#   (a) runtime > 500ms  OR
#   (b) has full table scan (type=ALL)  OR
#   (c) index coverage ratio < 0.5 AND runtime > median
runtime_threshold = df['avg_runtime_ms'].quantile(RUNTIME_PERCENTILE / 100)
median_runtime    = df['avg_runtime_ms'].median()

df['needs_index'] = (
    (df['avg_runtime_ms'] > SLOW_QUERY_MS) |
    (df['has_full_scan'] == 1) |
    ((df['index_coverage_ratio'] < 0.5) & (df['avg_runtime_ms'] > median_runtime))
).astype(int)

n_needs  = df['needs_index'].sum()
n_total  = len(df)
print("  Total queries merged : {:,}".format(n_total))
print("  Needs index (label=1): {:,} ({:.1f}%)".format(n_needs, 100*n_needs/n_total))
print("  No index needed (0)  : {:,} ({:.1f}%)".format(n_total-n_needs, 100*(n_total-n_needs)/n_total))
print("  Runtime threshold    : {:.1f} ms ({}th percentile)".format(runtime_threshold, RUNTIME_PERCENTILE))


# ─────────────────────────────────────────────
# STEP 4: TRAIN ML MODELS
# ─────────────────────────────────────────────
print("\n[4/7] Training ML models...")

FEATURE_COLS = [
    'max_join_type_score', 'avg_join_type_score',
    'has_full_scan', 'has_index_scan', 'has_range_scan', 'has_ref_scan',
    'num_tables', 'num_indexes_used', 'index_coverage_ratio', 'has_no_index',
    'avg_possible_keys',
    'total_rows_examined', 'max_rows_examined', 'avg_rows_examined', 'log_rows_examined',
    'avg_filtered_pct', 'min_filtered_pct',
    'has_filesort', 'has_temp_table', 'has_using_index', 'has_using_where',
    'has_subquery', 'has_derived', 'has_union', 'num_select_types',
    'category_encoded', 'log_avg_runtime', 'runtime_ratio'
]

X = df[FEATURE_COLS].fillna(0)
y = df['needs_index']

# Train/test split (stratified)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# Scale for SVM
scaler  = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled  = scaler.transform(X_test)

print("  Train set: {:,} queries".format(len(X_train)))
print("  Test set : {:,} queries".format(len(X_test)))

# ── Define models ──
models = {
    'Random Forest': RandomForestClassifier(
        n_estimators=200, max_depth=10, min_samples_split=5,
        random_state=42, n_jobs=-1
    ),
    'Gradient Boosting': GradientBoostingClassifier(
        n_estimators=200, learning_rate=0.05, max_depth=5,
        random_state=42
    ),
    'SVM': SVC(
        kernel='rbf', C=10, gamma='scale',
        probability=True, random_state=42
    ),
}

results = {}
cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

for name, model in models.items():
    print("\n  Training {} ...".format(name))

    if name == 'SVM':
        model.fit(X_train_scaled, y_train)
        y_pred  = model.predict(X_test_scaled)
        y_proba = model.predict_proba(X_test_scaled)[:, 1]
        cv_scores = cross_val_score(model, X_train_scaled, y_train,
                                    cv=cv, scoring='f1')
    else:
        model.fit(X_train, y_train)
        y_pred  = model.predict(X_test)
        y_proba = model.predict_proba(X_test)[:, 1]
        cv_scores = cross_val_score(model, X_train, y_train,
                                    cv=cv, scoring='f1')

    acc    = accuracy_score(y_test, y_pred)
    f1     = f1_score(y_test, y_pred, average='weighted')
    roc    = roc_auc_score(y_test, y_proba)
    cv_mean = cv_scores.mean()
    cv_std  = cv_scores.std()

    results[name] = {
        'model': model, 'y_pred': y_pred, 'y_proba': y_proba,
        'accuracy': acc, 'f1': f1, 'roc_auc': roc,
        'cv_mean': cv_mean, 'cv_std': cv_std
    }

    print("    Accuracy  : {:.4f}".format(acc))
    print("    F1 Score  : {:.4f}".format(f1))
    print("    ROC-AUC   : {:.4f}".format(roc))
    print("    CV F1     : {:.4f} (+/- {:.4f})".format(cv_mean, cv_std))


# ─────────────────────────────────────────────
# STEP 5: EVALUATE + VISUALISE
# ─────────────────────────────────────────────
print("\n[5/7] Generating evaluation charts...")

plt.rcParams.update({'font.size': 11, 'figure.dpi': 150})
colors = ['#2196F3', '#4CAF50', '#FF5722']

# ── Fig 1: Model comparison bar chart ──
fig, axes = plt.subplots(1, 3, figsize=(14, 5))
metrics   = ['accuracy', 'f1', 'roc_auc']
labels    = ['Accuracy', 'F1 Score', 'ROC-AUC']
model_names = list(results.keys())

for i, (metric, label) in enumerate(zip(metrics, labels)):
    vals = [results[m][metric] for m in model_names]
    bars = axes[i].bar(model_names, vals, color=colors, edgecolor='white', width=0.5)
    axes[i].set_title(label, fontweight='bold')
    axes[i].set_ylim(0, 1.1)
    axes[i].set_ylabel(label)
    axes[i].tick_params(axis='x', rotation=15)
    for bar, val in zip(bars, vals):
        axes[i].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
                     '{:.3f}'.format(val), ha='center', va='bottom', fontsize=10)

plt.suptitle('ML Model Performance Comparison', fontsize=14, fontweight='bold')
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR, 'fig1_model_comparison.png'), bbox_inches='tight')
plt.close()
print("  Saved: fig1_model_comparison.png")

# ── Fig 2: Confusion matrices ──
fig, axes = plt.subplots(1, 3, figsize=(15, 4))
for i, name in enumerate(model_names):
    cm = confusion_matrix(y_test, results[name]['y_pred'])
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', ax=axes[i],
                xticklabels=['No Index','Needs Index'],
                yticklabels=['No Index','Needs Index'])
    axes[i].set_title(name, fontweight='bold')
    axes[i].set_ylabel('Actual')
    axes[i].set_xlabel('Predicted')

plt.suptitle('Confusion Matrices', fontsize=14, fontweight='bold')
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR, 'fig2_confusion_matrices.png'), bbox_inches='tight')
plt.close()
print("  Saved: fig2_confusion_matrices.png")

# ── Fig 3: Feature importance (Random Forest) ──
rf_model = results['Random Forest']['model']
importances = pd.Series(rf_model.feature_importances_, index=FEATURE_COLS)
importances = importances.sort_values(ascending=True).tail(20)

fig, ax = plt.subplots(figsize=(10, 8))
bars = ax.barh(importances.index, importances.values, color='#2196F3', edgecolor='white')
ax.set_xlabel('Feature Importance', fontweight='bold')
ax.set_title('Top 20 Feature Importances (Random Forest)', fontsize=13, fontweight='bold')
ax.axvline(x=importances.values.mean(), color='red', linestyle='--',
           alpha=0.7, label='Mean importance')
ax.legend()
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR, 'fig3_feature_importance.png'), bbox_inches='tight')
plt.close()
print("  Saved: fig3_feature_importance.png")

# ── Fig 4: Runtime distribution by category ──
fig, ax = plt.subplots(figsize=(12, 5))
cat_order = sorted(df['category'].unique())
data_to_plot = [df[df['category'] == c]['avg_runtime_ms'].values for c in cat_order]
bp = ax.boxplot(data_to_plot, labels=[c.replace('_', '\n') for c in cat_order],
                patch_artist=True, notch=False)
for patch, color in zip(bp['boxes'], colors + ['#9C27B0', '#FF9800']):
    patch.set_facecolor(color)
    patch.set_alpha(0.7)
ax.set_yscale('log')
ax.set_ylabel('Runtime (ms) - log scale', fontweight='bold')
ax.set_title('Query Runtime Distribution by Category', fontsize=13, fontweight='bold')
ax.axhline(y=SLOW_QUERY_MS, color='red', linestyle='--',
           alpha=0.7, label='Slow query threshold ({}ms)'.format(SLOW_QUERY_MS))
ax.legend()
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR, 'fig4_runtime_distribution.png'), bbox_inches='tight')
plt.close()
print("  Saved: fig4_runtime_distribution.png")

# ── Fig 5: ROC curves ──
from sklearn.metrics import roc_curve
fig, ax = plt.subplots(figsize=(8, 6))
for name, color in zip(model_names, colors):
    fpr, tpr, _ = roc_curve(y_test, results[name]['y_proba'])
    ax.plot(fpr, tpr, color=color, lw=2,
            label='{} (AUC = {:.3f})'.format(name, results[name]['roc_auc']))
ax.plot([0,1],[0,1],'k--', lw=1, alpha=0.5)
ax.set_xlabel('False Positive Rate', fontweight='bold')
ax.set_ylabel('True Positive Rate', fontweight='bold')
ax.set_title('ROC Curves - ML Model Comparison', fontsize=13, fontweight='bold')
ax.legend(loc='lower right')
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR, 'fig5_roc_curves.png'), bbox_inches='tight')
plt.close()
print("  Saved: fig5_roc_curves.png")

# ── Fig 6: Index usage by category ──
cat_index_stats = df.groupby('category').agg(
    total=('query_id','count'),
    needs_index=('needs_index','sum'),
    avg_runtime=('avg_runtime_ms','mean')
).reset_index()
cat_index_stats['pct_needs_index'] = 100 * cat_index_stats['needs_index'] / cat_index_stats['total']

fig, ax1 = plt.subplots(figsize=(11, 5))
x = range(len(cat_index_stats))
bars = ax1.bar(x, cat_index_stats['pct_needs_index'], color=colors[0], alpha=0.7,
               label='% Needs Index')
ax1.set_ylabel('% Queries Needing Index', color=colors[0], fontweight='bold')
ax1.set_xticks(x)
ax1.set_xticklabels([c.replace('_','\n') for c in cat_index_stats['category']])
ax2 = ax1.twinx()
ax2.plot(x, cat_index_stats['avg_runtime'], 'o-', color=colors[2],
         linewidth=2, markersize=8, label='Avg Runtime (ms)')
ax2.set_ylabel('Avg Runtime (ms)', color=colors[2], fontweight='bold')
ax1.set_title('Index Need & Avg Runtime by Query Category',
              fontsize=13, fontweight='bold')
lines1, labels1 = ax1.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
ax1.legend(lines1+lines2, labels1+labels2, loc='upper left')
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR, 'fig6_category_analysis.png'), bbox_inches='tight')
plt.close()
print("  Saved: fig6_category_analysis.png")


# ─────────────────────────────────────────────
# STEP 6: INDEX RECOMMENDATIONS
# ─────────────────────────────────────────────
print("\n[6/7] Generating index recommendations...")

# Use best model (highest ROC-AUC)
best_model_name = max(results, key=lambda m: results[m]['roc_auc'])
print("  Best model: {} (ROC-AUC = {:.4f})".format(
    best_model_name, results[best_model_name]['roc_auc']))

# Predict on ALL queries (not just test set)
if best_model_name == 'SVM':
    X_all_scaled = scaler.transform(X.fillna(0))
    all_preds    = results[best_model_name]['model'].predict(X_all_scaled)
    all_probas   = results[best_model_name]['model'].predict_proba(X_all_scaled)[:, 1]
else:
    all_preds  = results[best_model_name]['model'].predict(X.fillna(0))
    all_probas = results[best_model_name]['model'].predict_proba(X.fillna(0))[:, 1]

df['predicted_needs_index'] = all_preds
df['index_priority_score']  = all_probas

# Build recommendations
recommendations = []
needs_index_df = df[df['predicted_needs_index'] == 1].copy()
needs_index_df = needs_index_df.sort_values('index_priority_score', ascending=False)

# Map join type score back to name
join_type_map = {
    0:'system', 1:'const', 2:'eq_ref', 3:'ref', 4:'fulltext',
    5:'ref_or_null', 6:'index_merge', 7:'unique_subquery',
    8:'index_subquery', 9:'range', 10:'index', 11:'ALL'
}

for _, row in needs_index_df.iterrows():
    # Determine recommendation reason
    reasons = []
    if row['has_full_scan']:
        reasons.append('Full table scan detected')
    if row['avg_runtime_ms'] > SLOW_QUERY_MS:
        reasons.append('Slow query ({:.0f}ms > {}ms threshold)'.format(
            row['avg_runtime_ms'], SLOW_QUERY_MS))
    if row['index_coverage_ratio'] < 0.5:
        reasons.append('Low index coverage ({:.0%})'.format(row['index_coverage_ratio']))
    if row['has_filesort']:
        reasons.append('Using filesort (ORDER BY not using index)')
    if row['has_temp_table']:
        reasons.append('Using temporary table')
    if row['total_rows_examined'] > 100000:
        reasons.append('High rows examined ({:,.0f})'.format(row['total_rows_examined']))

    # Priority tier
    score = row['index_priority_score']
    if score >= 0.8:
        priority = 'HIGH'
    elif score >= 0.6:
        priority = 'MEDIUM'
    else:
        priority = 'LOW'

    recommendations.append({
        'query_id':         row['query_id'],
        'category':         row['category'],
        'avg_runtime_ms':   round(row['avg_runtime_ms'], 2),
        'priority':         priority,
        'priority_score':   round(score, 4),
        'join_type':        join_type_map.get(int(row['max_join_type_score']), 'ALL'),
        'rows_examined':    int(row['total_rows_examined']),
        'index_coverage':   round(row['index_coverage_ratio'], 3),
        'has_filesort':     bool(row['has_filesort']),
        'has_full_scan':    bool(row['has_full_scan']),
        'reasons':          '; '.join(reasons) if reasons else 'ML model flagged'
    })

rec_df = pd.DataFrame(recommendations)

# Summary stats
high_count   = (rec_df['priority'] == 'HIGH').sum()
medium_count = (rec_df['priority'] == 'MEDIUM').sum()
low_count    = (rec_df['priority'] == 'LOW').sum()

print("  Queries recommended for indexing: {:,}".format(len(rec_df)))
print("    HIGH priority   : {:,}".format(high_count))
print("    MEDIUM priority : {:,}".format(medium_count))
print("    LOW priority    : {:,}".format(low_count))


# ─────────────────────────────────────────────
# STEP 7: SAVE ALL RESULTS
# ─────────────────────────────────────────────
print("\n[7/7] Saving all results...")

# 1. Model performance summary
perf_rows = []
for name, r in results.items():
    perf_rows.append({
        'model': name,
        'accuracy':  round(r['accuracy'], 4),
        'f1_score':  round(r['f1'], 4),
        'roc_auc':   round(r['roc_auc'], 4),
        'cv_f1_mean': round(r['cv_mean'], 4),
        'cv_f1_std':  round(r['cv_std'], 4),
    })
perf_df = pd.DataFrame(perf_rows)
perf_df.to_csv(os.path.join(OUTPUT_DIR, 'model_performance.csv'), index=False)
print("  Saved: model_performance.csv")

# 2. Feature importance
fi_df = pd.DataFrame({
    'feature': FEATURE_COLS,
    'importance': rf_model.feature_importances_
}).sort_values('importance', ascending=False)
fi_df.to_csv(os.path.join(OUTPUT_DIR, 'feature_importance.csv'), index=False)
print("  Saved: feature_importance.csv")

# 3. Index recommendations
rec_df.to_csv(os.path.join(OUTPUT_DIR, 'index_recommendations.csv'), index=False)
print("  Saved: index_recommendations.csv")

# 4. Full feature dataset (for thesis appendix)
df.to_csv(os.path.join(OUTPUT_DIR, 'full_feature_dataset.csv'), index=False)
print("  Saved: full_feature_dataset.csv")

# 5. Classification reports
report_path = os.path.join(OUTPUT_DIR, 'classification_reports.txt')
with open(report_path, 'w') as f:
    f.write("=" * 60 + "\n")
    f.write("CLASSIFICATION REPORTS\n")
    f.write("TPC-H ML Index Recommendation\n")
    f.write("=" * 60 + "\n\n")
    for name, r in results.items():
        f.write("\n{}\n{}\n".format(name, "-"*40))
        f.write(classification_report(y_test, r['y_pred'],
                target_names=['No Index', 'Needs Index']))
print("  Saved: classification_reports.txt")

# 6. Thesis-ready summary JSON
summary = {
    'dataset': {
        'total_queries': int(n_total),
        'categories': sorted(df['category'].unique().tolist()),
        'needs_index_count': int(n_needs),
        'needs_index_pct': round(100*n_needs/n_total, 1),
        'features_used': len(FEATURE_COLS),
    },
    'models': {
        name: {
            'accuracy':   round(r['accuracy'], 4),
            'f1_score':   round(r['f1'], 4),
            'roc_auc':    round(r['roc_auc'], 4),
            'cv_f1_mean': round(r['cv_mean'], 4),
            'cv_f1_std':  round(r['cv_std'], 4),
        }
        for name, r in results.items()
    },
    'best_model': best_model_name,
    'recommendations': {
        'total': len(rec_df),
        'high_priority': int(high_count),
        'medium_priority': int(medium_count),
        'low_priority': int(low_count),
    },
    'top_features': fi_df.head(10)['feature'].tolist(),
}
with open(os.path.join(OUTPUT_DIR, 'thesis_summary.json'), 'w') as f:
    json.dump(summary, f, indent=2)
print("  Saved: thesis_summary.json")


# ─────────────────────────────────────────────
# FINAL SUMMARY
# ─────────────────────────────────────────────
print("\n" + "=" * 65)
print("  ML PIPELINE COMPLETE")
print("=" * 65)
print("\n  Model Performance:")
print("  {:<22} {:>10} {:>10} {:>10}".format("Model", "Accuracy", "F1", "ROC-AUC"))
print("  " + "-"*55)
for name, r in results.items():
    marker = " <-- BEST" if name == best_model_name else ""
    print("  {:<22} {:>10.4f} {:>10.4f} {:>10.4f}{}".format(
        name, r['accuracy'], r['f1'], r['roc_auc'], marker))

print("\n  Output files in ml_results/:")
for f in sorted(os.listdir(OUTPUT_DIR)):
    size = os.path.getsize(os.path.join(OUTPUT_DIR, f))
    print("    {:40s} {:>8} bytes".format(f, size))

print("\n  Next step: Apply top index recommendations to MySQL")
print("             and measure runtime improvement (before vs after)")
print("=" * 65)
