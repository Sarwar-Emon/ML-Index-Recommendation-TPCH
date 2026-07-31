# ML-Index-Recommendation-TPCH

**Workload-Driven Automated Index Recommendation Using Machine Learning: A Comprehensive TPC-H Benchmark Evaluation**

An end-to-end system that recommends and applies database indexes automatically — using machine learning on structural query-plan features instead of manual DBA analysis, cost models, or pre-enumerated candidate sets.

[![MySQL](https://img.shields.io/badge/MySQL-9.1.0-blue)]()
[![Python](https://img.shields.io/badge/Python-3.x-blue)]()
[![scikit--learn](https://img.shields.io/badge/scikit--learn-ML-orange)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

---

## Overview

Selecting the right database indexes is traditionally a manual, reactive process handled by experienced DBAs. This project automates that process end-to-end: it profiles a SQL workload, extracts structural features from MySQL `EXPLAIN` output only (no runtime data, no leakage), trains a classifier to predict which queries genuinely need index support, and automatically generates and applies the resulting indexes.

Evaluated on a 911-query TPC-H SF-1 benchmark — 40× larger than the standard 22-query TPC-H suite — the system achieves:

- **99.45% accuracy** / **CV F1 = 0.9973 ± 0.0022** (Gradient Boosting)
- **1.37× overall runtime reduction**, **2.59× mean per-query speedup**
- A maximum single-query improvement of **558.6×**
- Outperforms three non-ML baselines, including a rule-based baseline that directly encodes the same labeling logic

## Research Questions

1. **RQ1** — Can structural features from MySQL `EXPLAIN` accurately predict index necessity without runtime leakage?
2. **RQ2** — Does an ML-guided pipeline produce measurable performance improvements on TPC-H?
3. **RQ3** — How does performance impact vary across query complexity categories?

## Key Contributions

- **911-query TPC-H workload** across 5 complexity categories (single-table, two-table join, three-table join, aggregation, complex) — 40× larger than the standard TPC-H suite
- **Leakage-free feature extraction**: 30 structural features derived exclusively from `EXPLAIN` output, with runtime deliberately excluded
- **Rigorous ML evaluation**: Gradient Boosting vs. Random Forest vs. SVM, plus 3 non-ML baselines and a full ablation study
- **Fully automated pipeline**: SQL parsing → candidate generation → composite scoring → `CREATE INDEX` application, with no DBA input, no cost model, and no pre-enumerated candidates
- **Empirical before/after evaluation** on 905 queries with case-study analysis

## Method Summary

### Feature Extraction
30 structural features are aggregated from `EXPLAIN` output across 5 groups:

| Group | Example Features |
|---|---|
| Scan type | `has_full_scan`, `max_join_type_score` |
| Index coverage | `index_coverage_ratio`, `num_indexes_used`, `has_no_index` |
| Row estimates | `total_rows_examined`, `log_rows_examined` |
| Execution flags | `has_filesort`, `has_temp_table`, `has_using_index` |
| Query structure | `num_tables`, `has_subquery`, `has_union` |

### Label Generation
Queries are labeled `needs_index=1` based on `EXPLAIN` signals (full scans, low index coverage, filesort/temp-table usage on high-row queries). Labels are heuristic, not ground truth — validity is confirmed empirically: labeled queries run **3.22× slower** on average (Mann-Whitney U test, p < 0.001).

### Models

| Model | Accuracy | F1 | CV F1 (±std) |
|---|---|---|---|
| Random Forest | 98.90% | 98.90% | 0.9927 ± 0.0047 |
| **Gradient Boosting** ✅ | **99.45%** | **99.45%** | **0.9973 ± 0.0022** |
| SVM | 98.90% | 98.90% | 0.9901 ± 0.0034 |

### Baseline Comparison

| Method | Accuracy | F1 | Recall | False Negatives |
|---|---|---|---|---|
| Rule-Based | 95.05% | 0.9668 | 93.57% | 9 |
| Frequency-Based | 78.02% | 0.8347 | 72.14% | 39 |
| Join-Only Heuristic | 67.03% | 0.7857 | 78.57% | 30 |
| **Gradient Boosting (Ours)** | **95.60%** | **0.9708** | **95.00%** | **7** |

### Results: Before vs. After Indexing

| Configuration | Avg Time | Total Runtime | Speedup |
|---|---|---|---|
| Before ML Indexes | 607.2 ms | 550,091 ms (9.2 min) | 1.00× |
| After ML Indexes | 443.9 ms | 401,731 ms (6.7 min) | **1.37×** |

22.1% of queries improved by >5%, 74.9% unchanged, 3.0% slightly degraded (max regression 1.5×, capped below 900ms).

## Pipeline

```
1. Parse queries → extract WHERE / JOIN / GROUP BY / ORDER BY columns
2. Run EXPLAIN → detect full scans and structural features
3. Cross-reference columns with ML relevance scores
4. Compute composite score per index candidate
5. Rank candidates
6. Assign HIGH / MEDIUM / LOW priority tiers
7. Auto-apply HIGH and MEDIUM indexes to MySQL
```

**Composite Score** = `(query_freq × 3.0) + (avg_ml_score × 2.0) + (clause_weight × 1.5) + (full_scan_count × 4.0)`

## Tech Stack

- **Database**: MySQL 9.1.0 (InnoDB), TPC-H SF-1 (~1.59M rows across 8 tables)
- **ML**: scikit-learn — Gradient Boosting, Random Forest, SVM
- **Language**: Python
- **Validation**: Mann-Whitney U test, paired t-tests, 5-fold stratified cross-validation

## Repository Structure

```
├── data/                  # TPC-H workload queries and benchmarking scripts
├── feature_extraction/    # EXPLAIN-based structural feature extraction
├── models/                # Model training, evaluation, ablation study
├── pipeline/              # Automated index generation and application
├── results/               # Benchmark results, figures, case studies
└── README.md
```

*(Update this section to match your actual folder layout.)*

## Getting Started

```bash
# Clone the repository
git clone https://github.com/Sarwar-Emon/ML-Index-Recommendation-TPCH.git
cd ML-Index-Recommendation-TPCH

# Install dependencies
pip install -r requirements.txt

# Run the pipeline
python run_pipeline.py
```

*(Update install/run instructions to match your actual scripts.)*

## Limitations

- Results are specific to TPC-H SF-1 on MySQL 9.1.0; generalization to larger scale factors (SF-10/SF-100) or other DBMSs is not yet empirically validated.
- Labels are heuristic (derived from `EXPLAIN` signals), not ground-truth runtime measurements.
- Generates single-column indexes only; composite multi-column indexing is future work.
- Static offline recommender — does not adapt to workload drift without retraining.

## Future Work

- SF-10 / SF-100 evaluation on server-grade hardware
- Composite (multi-column) index recommendation
- Cross-DBMS validation (PostgreSQL, SQL Server)
- Online adaptive index tuning via reinforcement learning

## Authors

- **Sayem Sarwar** — Computer Science, Troy University (Corresponding Author)
- **Majharul Islam Shanto** — Computer Science, Troy University

## Citation

If you use this work, please cite:

```bibtex
@inproceedings{sarwar2026indexrecommendation,
  title     = {Workload-Driven Automated Index Recommendation Using Machine Learning: A Comprehensive TPC-H Benchmark Evaluation},
  author    = {Sarwar, Sayem and Shanto, Majharul Islam},
  year      = {2026},
  note      = {Troy University}
}
```

*(Update with full venue/publication details once finalized.)*

## Acknowledgments

The authors thank the Department of Computer Science at Troy University for lab resources and support, and Professor Arteta for guidance throughout this research project.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
