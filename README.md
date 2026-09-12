# Workload-Driven Automated Index Recommendation Using Machine Learning

**A Multi-Scale TPC-H Benchmark Evaluation with Cross-DBMS Validation**

> Submitted to ACMSE 2027 — ACM Southeast Conference  
> April 15–17, 2027 · Decatur, Alabama, USA  
> Department of Computer Science, Troy University

---

## Overview

This repository contains the complete implementation, SQL workloads, benchmark scripts, and raw results for our paper on machine learning-based automated database index recommendation.

The system reads structural signals from **MySQL EXPLAIN output**, trains a **Gradient Boosting classifier** on 30 execution-plan features (runtime deliberately excluded to prevent label leakage), and applies recommended indexes without any DBA involvement. A second stage scores and ranks (table, column) candidates using a composite formula derived from SQL parsing alone — no cost model, no pre-enumerated candidate list.

---

## Key Results

| Metric | SF-0.1 (dbgen -s 0.1) | SF-10 (dbgen -s 10) |
|--------|----------------------|---------------------|
| Queries evaluated | 906 | 860 |
| Overall workload speedup | **1.37×** | 0.86× (negative — reported honestly) |
| Queries improved (>5%) | 22.1% | 53.1% |
| Peak individual speedup | **558.6×** | **20,711×** |
| GB CV-F1 (random split) | **0.9973 ± 0.0022** | — |
| GB CV-F1 (GroupKFold) | **0.9701 ± 0.0148** | — |
| GB CV-F1 (PostgreSQL 16) | **0.9868 ± 0.0068** | — |
| Write overhead (INSERT) | +129.5% orders / +137.2% lineitem | — |

### Top-k Index Budget Analysis (SF-0.1, 18-query benchmark)

| k | Speedup | Queries Improved | Storage |
|---|---------|-----------------|---------|
| 5  | 1.26× | 61.1% | 19.1 MB |
| **10** | **2.65×** | **61.1%** | **51.2 MB** ← best trade-off |
| 15 | 2.23× | 66.7% | 83.6 MB |
| 20 | 2.74× | 72.2% | 96.3 MB |

### Per-Category Results at SF-0.1

| Category | Before | After | Mean Speedup | % Improved |
|----------|--------|-------|-------------|-----------|
| Aggregation | 550.7 ms | 251.6 ms | 4.16× | 27.6% |
| Complex | 1,323 ms | 828 ms | 3.85× | 19.4% |
| Single-Table | 151 ms | 152 ms | 1.62× | 21.6% |
| Two-Table | 161 ms | 161 ms | 1.76× | 21.1% |
| Three-Table | 662 ms | 702 ms | 1.18× | 20.5% |

---

## Repository Structure

```
ML-Index-Recommendation-TPCH/
│
├── queries/                           # SQL workload (906 queries across 5 categories)
│   ├── Aggregation.sql                # 200 aggregation queries
│   ├── complex_queries.sql            # 200 complex/correlated subqueries
│   ├── single_table_filters.sql       # 111 single-table filter queries
│   ├── three_table_joins.sql          # 200 three-table join queries
│   └── two_table_joins.sql            # 200 two-table join queries
│
├── queries_pg/                        # PostgreSQL-adapted SQL (66 functions converted)
│   ├── Aggregation_pg.sql             # YEAR() → EXTRACT(), DATE_FORMAT() → TO_CHAR()
│   ├── complex_queries_pg.sql
│   ├── single_table_filters_pg.sql
│   ├── three_table_joins_pg.sql
│   └── two_table_joins_pg.sql
│
├── ml_index_recomendation_3.py        # Main ML pipeline: EXPLAIN extraction + GB training
├── run_queries.py                     # Execute workload and collect runtimes
├── apply_indexes_and_benchmark.py     # Apply recommended indexes + before/after benchmark
├── sf10_resume.py                     # SF-10 benchmark (860 queries, resume-capable)
├── sf10_smart_benchmark.py            # SF-10 with smart composite indexes
├── topk_experiment.py                 # Top-k budget analysis (k = 5, 10, 15, 20)
├── write_overhead_clean.py            # Write overhead (INSERT) controlled experiment
├── pg_ml_benchmark_v2.py             # PostgreSQL cross-DBMS pipeline replication
├── mysql_to_pg.py                     # MySQL → PostgreSQL syntax converter
│
├── results/
│   ├── sf01_before_after.csv          # SF-0.1 per-query runtimes before and after
│   ├── sf10_full_runtime_results.csv  # SF-10 full workload (860 queries)
│   ├── topk_results/
│   │   ├── topk_results.json          # Top-k experiment raw results
│   │   └── topk_summary.csv           # Top-k summary table
│   └── write_overhead_results/
│       └── write_overhead_clean.json  # Write overhead experiment results
│
└── README.md
```

---

## System Requirements

| Component | Version |
|-----------|---------|
| MySQL | 9.1.0 (InnoDB) |
| PostgreSQL | 16 (for cross-DBMS validation) |
| Python | 3.9+ |
| scikit-learn | ≥ 1.3 |
| mysql-connector-python | latest |
| psycopg2-binary | latest |
| pandas, numpy, scipy | latest |

```bash
pip install scikit-learn mysql-connector-python psycopg2-binary pandas numpy scipy
```

---

## Database Setup

### MySQL — SF-0.1

```bash
# Generate TPC-H data
./dbgen -s 0.1

# Load into MySQL
mysql -u root -p
CREATE DATABASE tpch;
USE tpch;
# Run schema DDL, then LOAD DATA INFILE for each .tbl file
# SF-0.1 cardinalities: lineitem (600,572), orders (150,000), partsupp (800,000)
```

### MySQL — SF-10

```bash
./dbgen -s 10

CREATE DATABASE tpch_sf10;
# SF-10 cardinalities: lineitem (59,986,052), orders (15,000,000)
```

### PostgreSQL — SF-0.1

```bash
createdb tpch_pg
# Strip trailing pipe from .tbl files before loading:
sed 's/|$//' nation.tbl | psql tpch_pg -c "\copy nation FROM STDIN WITH (FORMAT csv, DELIMITER '|')"
# Repeat for all 8 tables
```

---

## Running the Experiments

### Step 1 — Baseline Workload (SF-0.1)
```bash
python3 run_queries.py
```
Executes all 906 queries on MySQL SF-0.1 (3 runs each, average recorded).

### Step 2 — ML Feature Extraction and Training
```bash
python3 ml_index_recomendation_3.py
```
- Extracts 30 execution-plan features from MySQL EXPLAIN
- Removes 4 near-zero-variance features → **26 trained features**
- Trains Random Forest, Gradient Boosting (selected: CV-F1 = 0.9973), SVM
- Outputs ranked index candidates with composite scores S(t,c)

### Step 3 — Apply Indexes and Benchmark
```bash
python3 apply_indexes_and_benchmark.py
```
Applies all HIGH and MEDIUM priority candidates; runs before/after benchmark.

### Step 4 — Top-k Budget Analysis
```bash
python3 topk_experiment.py
```
Evaluates k ∈ {5, 10, 15, 20} — measures speedup, storage, and query improvement at each budget level.

### Step 5 — Write Overhead Experiment
```bash
python3 write_overhead_clean.py
```
Controlled INSERT experiment: 5,000-row batches, 5 trials, 2 warmup runs discarded.

### Step 6 — SF-10 Full Benchmark
```bash
caffeinate -i python3 sf10_resume.py   # macOS: keep awake during long run
```
Runs 860 queries on MySQL SF-10 (10 GB). Resume-capable. Estimated: 4–6 hours. 3-minute per-query timeout enforced.

### Step 7 — PostgreSQL Cross-DBMS Validation
```bash
# Step 7a: Convert MySQL syntax to PostgreSQL
python3 mysql_to_pg.py

# Step 7b: Run PostgreSQL ML pipeline
python3 pg_ml_benchmark_v2.py
```
Converts 66 MySQL-specific functions and replicates the full pipeline on PostgreSQL 16.

---

## Key Design Decisions

### Why EXPLAIN Features Only?
Runtime is deliberately excluded. Including execution time would create circular reasoning — the model would learn "slow queries need indexes" instead of structural patterns. By using only EXPLAIN signals (scan types, row estimates, index coverage, sort flags), the system advises on any new query before it runs and generalizes across DBMS platforms without threshold re-tuning.

### Two-Stage Pipeline
**Stage 1 (ML Filter):** Gradient Boosting classifier identifies queries needing index support based on structural EXPLAIN signals.

**Stage 2 (Composite Ranker):** Scores each (table, column) candidate:
```
S(t,c) = 3.0·freq(t,c) + 2.0·μ_ml(t,c) + 1.5·w_clause(t,c) + 4.0·fs(t,c)
```
- `fs(t,c)`: full-scan query count referencing (t,c) — highest weight (4.0)
- `w_clause`: 3.0 for WHERE, 2.5 for JOIN ON, 1.5 for GROUP BY, 1.0 for ORDER BY

### The SF-10 Negative Result
At SF-10, the overall aggregate speedup is **0.86×** — slightly worse than baseline. This is reported honestly and is a genuine finding: low-selectivity predicates (l_returnflag: 3 distinct values; l_discount: 11 values) on 60 million rows cause MySQL to prefer index scans over sequential scans, making aggregation queries slower. Composite indexes improved aggregation from 0.67× to 0.95×, but predicates returning >90% of 60M rows cannot benefit from any index type under our experimental conditions. Selectivity-aware scoring using INFORMATION_SCHEMA histogram statistics is the primary future direction.

### Cross-DBMS Generalizability
The feature-engineering methodology generalizes to PostgreSQL after DBMS-specific adaptation. GB achieves CV-F1 = 0.9868 on PostgreSQL 16 — a drop of only 0.0105 from MySQL — without requiring manual re-tuning of rule thresholds. This cross-system adaptability is the primary practical advantage of the ML approach over a fixed rule engine.

---

## Reproducibility Notes

- **Hardware:** Apple MacBook Pro (M-series ARM64, 16 GB RAM, macOS 15.7.5)
- **MySQL:** 9.1.0, InnoDB, `innodb_buffer_pool_size = 8 GB`
- **PostgreSQL:** 16 (Homebrew)
- **Random seeds:** fixed at 42 throughout
- **Query timing:** 3-run averages (SF-0.1); single run with 3-min timeout (SF-10)
- **Pipeline timing:** single-run measurement (~26 minutes end-to-end)

Results may differ on server hardware due to larger buffer pools, different storage (NVMe vs SSD), and different I/O scheduler behavior.

---

## Citation

```bibtex
@inproceedings{sarwar2027indexrec,
  title     = {Workload-Driven Automated Index Recommendation Using Machine Learning:
               A Multi-Scale {TPC-H} Benchmark Evaluation with Cross-{DBMS} Validation},
  author    = {Sarwar, Sayem and Shanto, Majharul Islam and Arteta, Alberto},
  booktitle = {Proceedings of the 2027 ACM Southeast Conference (ACMSE)},
  year      = {2027},
  address   = {Decatur, Alabama, USA},
  publisher = {ACM}
}
```

---

## License

MIT License — see `LICENSE` for details.

---

## Acknowledgment

This work was conducted at the Department of Computer Science, Troy University, Alabama, USA. Special thanks to Associate Professor Alberto Arteta for guidance and feedback throughout this research project.
