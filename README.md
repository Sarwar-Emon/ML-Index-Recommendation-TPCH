# ML-Based Automated Database Index Recommendation

A workload-driven machine learning system for automatically identifying index opportunities, ranking candidate indexes, and evaluating their impact on database performance.

This project investigates whether structural query-plan information can be used to automate database index recommendation without relying on query runtime as an input feature. The system is evaluated on multi-scale TPC-H workloads using MySQL and further validated on PostgreSQL.

## Overview

Database index selection is traditionally performed by database administrators through workload analysis, query-plan inspection, and manual experimentation.

This project develops an automated pipeline that:

1. Parses SQL workloads
2. Extracts structural features from `EXPLAIN`
3. Predicts whether queries need additional index support
4. Identifies candidate columns from SQL predicates and joins
5. Ranks candidate indexes using workload-level signals
6. Automatically creates selected indexes
7. Measures actual before/after query performance

The goal is not simply to achieve high classification accuracy, but to determine whether ML-driven recommendations translate into measurable database performance improvements.

## System Architecture

The pipeline follows a two-stage design:

### Stage 1 — ML Query Filtering

Execution-plan features are extracted from database `EXPLAIN` output.

The classifier determines whether a query is likely to benefit from additional index support.

The evaluated models include:

- Gradient Boosting
- Random Forest
- Support Vector Machine (SVM)

Gradient Boosting was selected as the primary model.

### Stage 2 — Index Candidate Ranking

For queries flagged by the ML model, candidate columns are extracted from:

- `WHERE`
- `JOIN ON`
- `GROUP BY`
- `ORDER BY`

Candidates are ranked using a composite workload score incorporating:

- Column reference frequency
- ML prediction confidence
- SQL clause importance
- Full-scan frequency

Existing indexes are checked before new indexes are created.

## Dataset and Workload

Experiments use the TPC-H decision-support benchmark.

Two database scales are evaluated:

| Scale | Approximate Size | Workload |
|---|---:|---:|
| TPC-H SF-0.1 | ~1 GB | 906 usable queries |
| TPC-H SF-10 | ~10 GB | 860 queries |

The original workload contains 911 parameterized SQL queries covering five categories:

- Single-table filters
- Two-table joins
- Three-table joins
- Aggregation queries
- Complex queries and correlated subqueries

The workload is substantially larger than the standard 22-query TPC-H reference suite and is designed to expose the models to diverse query structures.

## Feature Engineering

The system extracts 30 structural attributes from `EXPLAIN`.

After near-zero-variance filtering, 26 active features are retained for model training.

Feature groups include:

### Scan Type
Examples:
- Maximum join/access type score
- Full-scan indicator
- Number of full-scan tables

### Index Coverage
Examples:
- Index coverage ratio
- Number of indexes used
- No-index indicator

### Row Estimates
Examples:
- Total estimated rows examined
- Maximum estimated rows
- Log-transformed row estimates

### Execution-Plan Flags
Examples:
- Filesort
- Temporary-table usage
- Covering-index usage

### Query Structure
Examples:
- Number of tables
- Subquery presence
- UNION presence
- SELECT-type information

Query runtime is deliberately excluded from the ML feature set.

## Machine Learning Results

### MySQL — TPC-H SF-0.1

| Model | Accuracy | F1 | Random CV-F1 | GroupKFold F1 |
|---|---:|---:|---:|---:|
| Random Forest | 98.90% | 98.90% | 0.9927 | 0.9634 |
| **Gradient Boosting** | **99.45%** | **99.45%** | **0.9973** | **0.9701** |
| SVM | 98.90% | 98.90% | 0.9901 | 0.9512 |

GroupKFold evaluation groups parameter variations of the same query template together, providing a stricter estimate of generalization to unseen query structures.

## Baseline Comparison

The ML system is compared against several non-ML approaches.

| Method | Accuracy | F1 | Recall | False Negatives |
|---|---:|---:|---:|---:|
| Rule-Based | 95.05% | 0.9668 | 93.57% | 9 |
| Frequency-Based | 78.02% | 0.8347 | 72.14% | 39 |
| Join-Only | 67.03% | 0.7857 | 78.57% | 30 |
| **Gradient Boosting** | **95.60%** | **0.9708** | **95.00%** | **7** |

The strong rule-based baseline also highlights an important finding: structural database heuristics already provide substantial predictive power, while the ML model provides a modest additional improvement.

## Index Budget Analysis

The system evaluates different index deployment budgets.

| Top-k | Overall Speedup | Queries Improved | Storage |
|---:|---:|---:|---:|
| 5 | 1.26× | 61.1% | 19.1 MB |
| **10** | **2.65×** | **61.1%** | **51.2 MB** |
| 15 | 2.23× | 66.7% | 83.6 MB |
| 20 | 2.74× | 72.2% | 96.3 MB |

On the evaluated 18-query subset, Top-10 provides the best observed balance between performance improvement and storage cost.

The results also demonstrate that adding more indexes does not necessarily produce monotonic performance improvements.

## End-to-End Performance

### TPC-H SF-0.1

Across 905 comparable queries:

- Total workload speedup: **1.37×**
- Total runtime reduction: **26.97%**
- Mean per-query speedup: **2.59×**
- Median per-query speedup: **0.98×**
- Best individual speedup: **558.6×**

Most queries remain approximately unchanged, while a smaller set of expensive queries accounts for much of the aggregate performance improvement.

## Scalability Experiment — SF-10

The pipeline was also evaluated at TPC-H SF-10.

The larger-scale experiment reveals an important limitation.

Although many individual queries benefit from indexing, aggregate workload performance does not improve:

**Overall SF-10 speedup: 0.86×**

This negative result is intentionally reported.

At larger data volumes, indexes on low-selectivity columns can cause the optimizer to choose index scans that are more expensive than sequential scans.

This demonstrates that:

> More indexes do not automatically mean better performance.

The result motivates selectivity-aware candidate scoring as an important future extension of the system.

## Write Overhead

Indexes improve read performance at the cost of additional write operations and storage.

A controlled INSERT experiment measured approximately:

**133% additional INSERT time**

for the indexed configuration evaluated in the study.

This trade-off makes the current approach most appropriate for read-heavy analytical workloads rather than write-intensive transactional systems.

## Cross-DBMS Validation

To evaluate portability, the methodology was replicated on PostgreSQL 16.

The PostgreSQL experiment required DBMS-specific adaptation of execution-plan features.

Gradient Boosting achieved:

**CV-F1 ≈ 0.9868**

The experiment suggests that the underlying feature-engineering methodology can be adapted across database systems, although plan representations and optimizer behavior remain DBMS-specific.

## Key Findings

The experiments highlight several practical findings:

- Structural `EXPLAIN` features contain strong signals for identifying index opportunities.
- Gradient Boosting performs strongly across both random and template-grouped evaluation.
- Simple database heuristics remain highly competitive with ML.
- Automated recommendations can produce measurable end-to-end workload improvements.
- Index utility is non-monotonic: adding more indexes can sometimes reduce performance.
- Index recommendations that work at small scale may not remain beneficial at larger data volumes.
- Predicate selectivity becomes increasingly important as table cardinality grows.
- Cross-DBMS deployment requires platform-specific adaptation.

## Project Structure

A typical repository organization is:

    .
    ├── data/
    │   └── workloads/
    │
    ├── queries/
    │   ├── single_table/
    │   ├── two_table/
    │   ├── three_table/
    │   ├── aggregation/
    │   └── complex/
    │
    ├── src/
    │   ├── feature_extraction/
    │   ├── ml/
    │   ├── index_recommendation/
    │   └── benchmarking/
    │
    ├── results/
    │   ├── sf01/
    │   ├── sf10/
    │   └── postgresql/
    │
    ├── figures/
    │
    ├── requirements.txt
    └── README.md

Adjust this structure to match the actual repository before publishing.

## Technologies

- Python
- MySQL
- PostgreSQL
- TPC-H
- scikit-learn
- pandas
- NumPy
- SQL
- Gradient Boosting
- Random Forest
- Support Vector Machine

## Reproducibility

The experiments use fixed random seeds where applicable.

The main experimental workflow is:

    TPC-H Database
          ↓
      SQL Workload
          ↓
        EXPLAIN
          ↓
    Feature Extraction
          ↓
     ML Classification
          ↓
    Candidate Extraction
          ↓
     Candidate Ranking
          ↓
      Index Creation
          ↓
    Before/After Benchmark
          ↓
      Result Analysis

Exact commands and environment setup should be added based on the scripts included in this repository.

## Limitations

The current implementation has several limitations:

- Training labels are proxy labels derived from EXPLAIN signals rather than externally provided ground truth.
- Some features used for classification also contribute to label generation.
- Cross-template generalization is lower than random cross-validation performance.
- Candidate-ranking weights are heuristic.
- Selectivity is not explicitly modeled in the current ranking formula.
- Composite-index exploration is limited.
- Experiments were performed on local hardware rather than production database infrastructure.
- Cross-DBMS deployment requires DBMS-specific feature adaptation.

## Future Work

Future development will focus on:

- Selectivity-aware index scoring
- Automated optimization of ranking weights
- Composite-index recommendation
- Workload-aware index budget optimization
- Larger-scale database evaluation
- Additional DBMS platforms
- Production workload validation
- Dynamic index maintenance as workloads evolve

## Research Paper

This repository contains the implementation and experimental artifacts associated with:

**Workload-Driven Automated Index Recommendation Using Machine Learning: A Comprehensive Multi-Scale TPC-H Benchmark Evaluation with Cross-DBMS Validation**

**Authors:**
- Sayem Sarwar
- Majharul Islam Shanto
- Alberto Arteta

Department of Computer Science  
Troy University, Alabama, USA

## Citation

If you use this work, please cite the associated paper after publication.

```bibtex
@article{sarwar2026index,
  title={Workload-Driven Automated Index Recommendation Using Machine Learning: A Comprehensive Multi-Scale TPC-H Benchmark Evaluation with Cross-DBMS Validation},
  author={Sarwar, Sayem and Shanto, Majharul Islam and Arteta, Alberto},
  year={2026},
  note={Manuscript}
}
