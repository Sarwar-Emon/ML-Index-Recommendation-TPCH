-- =============================================================================
-- WORKLOAD W2: TWO-TABLE JOIN QUERIES
-- =============================================================================
-- Dataset  : TPC-H Benchmark
-- DBMS     : MySQL
-- Purpose  : Diverse two-table join workload for ML-based index recommendation
-- Tables   : ORDERS, CUSTOMER, LINEITEM, PART, PARTSUPP, SUPPLIER
-- Total    : 200 queries across 20 sections (8 duplicates removed from original)
--
-- Operation types:
--   Basic joins, threshold/range/BETWEEN filters, combined multi-predicate,
--   ORDER BY, LIMIT, ORDER BY+LIMIT (Top-N), DISTINCT, GROUP BY, aggregates
--   (COUNT/SUM/AVG/MAX/MIN), HAVING, EXISTS, NOT EXISTS, IN subqueries,
--   correlated subqueries, date functions (YEAR)
--
-- Join pairs covered:
--   [OC]  ORDERS    <-> CUSTOMER  ON O_CUSTKEY  = C_CUSTKEY
--   [OL]  ORDERS    <-> LINEITEM  ON O_ORDERKEY = L_ORDERKEY
--   [PP]  PART      <-> PARTSUPP  ON P_PARTKEY  = PS_PARTKEY
--   [SP]  SUPPLIER  <-> PARTSUPP  ON S_SUPPKEY  = PS_SUPPKEY
--
-- Query ID format: W2-S<section>-Q<number>
--   Section 01-03  : ORDERS <-> CUSTOMER (basic, threshold variations, combined)
--   Section 04-05  : ORDERS <-> LINEITEM (basic, threshold variations)
--   Section 06     : PART   <-> PARTSUPP (basic)
--   Section 07     : SUPPLIER <-> PARTSUPP (basic)
--   Section 08     : Multi-predicate joins (all pairs)
--   Section 09     : ORDER BY joins (all pairs)
--   Section 10     : LIMIT joins (all pairs)
--   Section 11     : ORDERS <-> CUSTOMER extended thresholds
--   Section 12     : ORDERS <-> LINEITEM extended thresholds
--   Section 13     : PART   <-> PARTSUPP extended thresholds
--   Section 14     : SUPPLIER <-> PARTSUPP extended thresholds
--   Section 15     : Final variations (ORDER BY, LIMIT, BETWEEN, mixed)
-- =============================================================================

USE tpch;


-- =============================================================================
-- SECTION 01: ORDERS <-> CUSTOMER  --  Basic Joins
-- Join key : ORDERS.O_CUSTKEY = CUSTOMER.C_CUSTKEY
-- Coverage : Baseline full join + single-column filter on each key dimension
-- =============================================================================

-- W2-S01-Q01  Full join, no filter
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY;

-- W2-S01-Q02  Filter on customer account balance
SELECT o.O_ORDERKEY,
       c.C_ACCTBAL
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL > 500;

-- W2-S01-Q03  Filter on order total price
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 20000;

-- W2-S01-Q04  Filter on customer nation (range)
SELECT o.O_ORDERKEY,
       c.C_NATIONKEY
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_NATIONKEY BETWEEN 1 AND 10;

-- W2-S01-Q05  Filter on order date
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_ORDERDATE > '1996-01-01';


-- =============================================================================
-- SECTION 02: ORDERS <-> CUSTOMER  --  Threshold Variations
-- Join key : ORDERS.O_CUSTKEY = CUSTOMER.C_CUSTKEY
-- Coverage : Systematic threshold sweep to vary result-set cardinality
-- =============================================================================

-- W2-S02-Q01  Low account balance threshold (high selectivity)
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL > 100;

-- W2-S02-Q02  High account balance threshold (low selectivity)
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL > 1000;

-- W2-S02-Q03  Order total price range filter
SELECT o.O_ORDERKEY,
       c.C_ACCTBAL
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE BETWEEN 10000 AND 30000;

-- W2-S02-Q04  Nation range filter (wider range)
SELECT o.O_ORDERKEY,
       c.C_NATIONKEY
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_NATIONKEY BETWEEN 5 AND 15;

-- W2-S02-Q05  Order date range filter (two-year window)
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_ORDERDATE BETWEEN '1995-01-01' AND '1997-01-01';


-- =============================================================================
-- SECTION 03: ORDERS <-> CUSTOMER  --  Combined Multi-Predicate Filters
-- Join key : ORDERS.O_CUSTKEY = CUSTOMER.C_CUSTKEY
-- Coverage : Simultaneous predicates on columns from both tables
-- =============================================================================

-- W2-S03-Q01  Price + balance (low thresholds)
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 10000
  AND  c.C_ACCTBAL    > 200;

-- W2-S03-Q02  Price + balance (high thresholds)
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 30000
  AND  c.C_ACCTBAL    > 800;

-- W2-S03-Q03  Price range + nation point filter
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE  BETWEEN 10000 AND 40000
  AND  c.C_NATIONKEY = 5;

-- W2-S03-Q04  Date range + high balance
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_ORDERDATE BETWEEN '1995-01-01' AND '1996-01-01'
  AND  c.C_ACCTBAL  > 1000;

-- W2-S03-Q05  Date threshold + nation range
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_ORDERDATE   > '1996-01-01'
  AND  c.C_NATIONKEY BETWEEN 3 AND 8;


-- =============================================================================
-- SECTION 04: ORDERS <-> LINEITEM  --  Basic Joins
-- Join key : ORDERS.O_ORDERKEY = LINEITEM.L_ORDERKEY
-- Coverage : Baseline full join + single-column filters on LINEITEM dimensions
-- =============================================================================

-- W2-S04-Q01  Full join, no filter
SELECT o.O_ORDERKEY,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY;

-- W2-S04-Q02  Filter on line item quantity
SELECT o.O_ORDERKEY,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 20;

-- W2-S04-Q03  Filter on order total price
SELECT o.O_ORDERKEY,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  o.O_TOTALPRICE > 30000;

-- W2-S04-Q04  Filter on ship date
SELECT o.O_ORDERKEY,
       l.L_SHIPDATE
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_SHIPDATE > '1996-01-01';

-- W2-S04-Q05  Filter on discount rate
SELECT o.O_ORDERKEY,
       l.L_DISCOUNT
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_DISCOUNT > 0.05;


-- =============================================================================
-- SECTION 05: ORDERS <-> LINEITEM  --  Threshold Variations
-- Join key : ORDERS.O_ORDERKEY = LINEITEM.L_ORDERKEY
-- Coverage : Threshold sweep on quantity, discount, ship date, and total price
-- =============================================================================

-- W2-S05-Q01  Quantity threshold — low (high result count)
SELECT o.O_ORDERKEY,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 10;

-- W2-S05-Q02  Quantity threshold — high (low result count)
SELECT o.O_ORDERKEY,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 30;

-- W2-S05-Q03  Discount range filter
SELECT o.O_ORDERKEY,
       l.L_DISCOUNT
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_DISCOUNT BETWEEN 0.02 AND 0.08;

-- W2-S05-Q04  Ship date range filter (two-year window)
SELECT o.O_ORDERKEY,
       l.L_SHIPDATE
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_SHIPDATE BETWEEN '1995-01-01' AND '1997-01-01';

-- W2-S05-Q05  High total price threshold
SELECT o.O_ORDERKEY,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  o.O_TOTALPRICE > 40000;


-- =============================================================================
-- SECTION 06: PART <-> PARTSUPP  --  Basic Joins
-- Join key : PART.P_PARTKEY = PARTSUPP.PS_PARTKEY
-- Coverage : Baseline full join + filters on part and supplier dimensions
-- =============================================================================

-- W2-S06-Q01  Full join, no filter
SELECT p.P_PARTKEY,
       ps.PS_SUPPLYCOST
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY;

-- W2-S06-Q02  Filter on part size
SELECT p.P_PARTKEY,
       ps.PS_SUPPLYCOST
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  p.P_SIZE > 10;

-- W2-S06-Q03  Filter on supply cost
SELECT p.P_PARTKEY,
       ps.PS_SUPPLYCOST
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_SUPPLYCOST > 500;

-- W2-S06-Q04  Filter on available quantity
SELECT p.P_PARTKEY,
       ps.PS_AVAILQTY
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_AVAILQTY > 100;

-- W2-S06-Q05  Filter on retail price
SELECT p.P_PARTKEY,
       ps.PS_SUPPLYCOST
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  p.P_RETAILPRICE > 1000;


-- =============================================================================
-- SECTION 07: SUPPLIER <-> PARTSUPP  --  Basic Joins
-- Join key : SUPPLIER.S_SUPPKEY = PARTSUPP.PS_SUPPKEY
-- Coverage : Baseline full join + filters on supplier and supply dimensions
-- =============================================================================

-- W2-S07-Q01  Full join, no filter
SELECT s.S_SUPPKEY,
       ps.PS_PARTKEY
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY;

-- W2-S07-Q02  Filter on supplier account balance
SELECT s.S_SUPPKEY,
       ps.PS_SUPPLYCOST
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_ACCTBAL > 500;

-- W2-S07-Q03  Filter on supply cost
SELECT s.S_SUPPKEY,
       ps.PS_SUPPLYCOST
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  ps.PS_SUPPLYCOST > 400;

-- W2-S07-Q04  Filter on supplier nation (range)
SELECT s.S_SUPPKEY,
       ps.PS_PARTKEY
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_NATIONKEY BETWEEN 1 AND 10;

-- W2-S07-Q05  Filter on available quantity
SELECT s.S_SUPPKEY,
       ps.PS_AVAILQTY
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  ps.PS_AVAILQTY > 50;


-- =============================================================================
-- SECTION 08: MULTI-PREDICATE JOINS  --  Combined Filters Across Both Tables
-- Coverage : Cross-table predicate combinations for all four join pairs
-- =============================================================================

-- W2-S08-Q01  [OC] Balance + price (moderate thresholds)
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL    > 500
  AND  o.O_TOTALPRICE > 20000;

-- W2-S08-Q02  [OL] Quantity + price (moderate thresholds)
SELECT o.O_ORDERKEY,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY   > 20
  AND  o.O_TOTALPRICE > 25000;

-- W2-S08-Q03  [PP] Part size + supply cost
SELECT p.P_PARTKEY,
       ps.PS_SUPPLYCOST
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  p.P_SIZE         > 10
  AND  ps.PS_SUPPLYCOST > 300;

-- W2-S08-Q04  [SP] Supplier balance + supply cost
SELECT s.S_SUPPKEY,
       ps.PS_SUPPLYCOST
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_ACCTBAL      > 500
  AND  ps.PS_SUPPLYCOST > 300;


-- =============================================================================
-- SECTION 09: ORDER BY JOINS  --  Sort on Non-Join Column
-- Coverage : Tests optimizer's ability to exploit indexes for sort elimination
-- =============================================================================

-- W2-S09-Q01  [OC] Sort by total price descending
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
ORDER BY o.O_TOTALPRICE DESC;

-- W2-S09-Q02  [OL] Sort by quantity descending
SELECT o.O_ORDERKEY,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
ORDER BY l.L_QUANTITY DESC;

-- W2-S09-Q03  [OC] Sort by account balance descending
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
ORDER BY c.C_ACCTBAL DESC;

-- W2-S09-Q04  [OL] Sort by discount descending
SELECT o.O_ORDERKEY,
       l.L_DISCOUNT
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
ORDER BY l.L_DISCOUNT DESC;

-- W2-S09-Q05  [PP] Sort by supply cost descending
SELECT p.P_PARTKEY,
       ps.PS_SUPPLYCOST
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
ORDER BY ps.PS_SUPPLYCOST DESC;

-- W2-S09-Q06  [PP] Sort by available quantity descending
SELECT p.P_PARTKEY,
       ps.PS_AVAILQTY
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
ORDER BY ps.PS_AVAILQTY DESC;

-- W2-S09-Q07  [SP] Sort by supply cost descending
SELECT s.S_SUPPKEY,
       ps.PS_SUPPLYCOST
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
ORDER BY ps.PS_SUPPLYCOST DESC;

-- W2-S09-Q08  [SP] Sort by available quantity descending
SELECT s.S_SUPPKEY,
       ps.PS_AVAILQTY
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
ORDER BY ps.PS_AVAILQTY DESC;


-- =============================================================================
-- SECTION 10: LIMIT JOINS  --  Top-N Row Retrieval
-- Coverage : Early-termination and pagination patterns across all four join pairs
-- =============================================================================

-- W2-S10-Q01  [OC] Top 50 rows
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
LIMIT  50;

-- W2-S10-Q02  [OC] Top 100 rows
SELECT o.O_ORDERKEY,
       c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
LIMIT  100;

-- W2-S10-Q03  [OL] Top 100 rows
SELECT o.O_ORDERKEY,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
LIMIT  100;

-- W2-S10-Q04  [OL] Top 200 rows
SELECT o.O_ORDERKEY,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
LIMIT  200;

-- W2-S10-Q05  [PP] Top 80 rows
SELECT p.P_PARTKEY,
       ps.PS_SUPPLYCOST
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
LIMIT  80;

-- W2-S10-Q06  [SP] Top 60 rows
SELECT s.S_SUPPKEY,
       ps.PS_SUPPLYCOST
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
LIMIT  60;


-- =============================================================================
-- SECTION 11: ORDERS <-> CUSTOMER  --  Extended Threshold Workload
-- Join key : ORDERS.O_CUSTKEY = CUSTOMER.C_CUSTKEY
-- Coverage : Dense sweep of price, balance, date, nation, BETWEEN, and mixed
-- =============================================================================

-- --- O_TOTALPRICE thresholds ---

-- W2-S11-Q01
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 5000;

-- W2-S11-Q02
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 10000;

-- W2-S11-Q03
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 15000;

-- W2-S11-Q04
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 25000;

-- W2-S11-Q05
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 40000;

-- --- C_ACCTBAL thresholds ---

-- W2-S11-Q06
SELECT o.O_ORDERKEY, c.C_ACCTBAL
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL > 200;

-- W2-S11-Q07
SELECT o.O_ORDERKEY, c.C_ACCTBAL
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL > 400;

-- W2-S11-Q08
SELECT o.O_ORDERKEY, c.C_ACCTBAL
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL > 800;

-- W2-S11-Q09
SELECT o.O_ORDERKEY, c.C_ACCTBAL
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL > 1200;

-- --- Combined price + balance ---

-- W2-S11-Q10
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 10000
  AND  c.C_ACCTBAL    > 500;

-- W2-S11-Q11
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 20000
  AND  c.C_ACCTBAL    > 700;

-- W2-S11-Q12
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 30000
  AND  c.C_ACCTBAL    > 900;

-- --- O_ORDERDATE thresholds ---

-- W2-S11-Q13
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_ORDERDATE > '1994-01-01';

-- W2-S11-Q14
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_ORDERDATE > '1995-01-01';

-- W2-S11-Q15
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_ORDERDATE > '1997-01-01';

-- --- C_NATIONKEY point filters ---

-- W2-S11-Q16
SELECT o.O_ORDERKEY, c.C_NATIONKEY
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_NATIONKEY = 1;

-- W2-S11-Q17
SELECT o.O_ORDERKEY, c.C_NATIONKEY
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_NATIONKEY = 5;

-- W2-S11-Q18
SELECT o.O_ORDERKEY, c.C_NATIONKEY
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_NATIONKEY = 10;

-- --- O_TOTALPRICE BETWEEN ranges ---

-- W2-S11-Q19
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE BETWEEN 5000  AND 15000;

-- W2-S11-Q20
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE BETWEEN 15000 AND 30000;

-- W2-S11-Q21
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE BETWEEN 30000 AND 60000;

-- --- C_ACCTBAL BETWEEN ranges ---

-- W2-S11-Q22
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL BETWEEN 200 AND 800;

-- W2-S11-Q23
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL BETWEEN 500 AND 1500;

-- --- Mixed price + balance BETWEEN ---

-- W2-S11-Q24
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS o JOIN CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 25000
  AND  c.C_ACCTBAL  BETWEEN 200 AND 1000;


-- =============================================================================
-- SECTION 12: ORDERS <-> LINEITEM  --  Extended Threshold Workload
-- Join key : ORDERS.O_ORDERKEY = LINEITEM.L_ORDERKEY
-- Coverage : Dense sweep of quantity, discount, ship date, price combos, BETWEEN
-- Note     : L_QUANTITY > 10, L_DISCOUNT > 0.05, L_SHIPDATE > '1996-01-01' were
--            already defined in Section 05 (Q01), Section 04 (Q05), Section 04
--            (Q04) respectively and are not repeated here.
-- =============================================================================

-- --- L_QUANTITY thresholds (5, 15, 25, 35 — skipping 10 defined in S05-Q01) ---

-- W2-S12-Q01
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 5;

-- W2-S12-Q02
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 15;

-- W2-S12-Q03
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 25;

-- W2-S12-Q04
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 35;

-- --- L_DISCOUNT thresholds (0.01, 0.03, 0.07, 0.09 — skipping 0.05 in S04-Q05) ---

-- W2-S12-Q05
SELECT o.O_ORDERKEY, l.L_DISCOUNT
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_DISCOUNT > 0.01;

-- W2-S12-Q06
SELECT o.O_ORDERKEY, l.L_DISCOUNT
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_DISCOUNT > 0.03;

-- W2-S12-Q07
SELECT o.O_ORDERKEY, l.L_DISCOUNT
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_DISCOUNT > 0.07;

-- W2-S12-Q08
SELECT o.O_ORDERKEY, l.L_DISCOUNT
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_DISCOUNT > 0.09;

-- --- L_SHIPDATE thresholds (1994, 1995, 1997, 1998 — skipping 1996 in S04-Q04) ---

-- W2-S12-Q09
SELECT o.O_ORDERKEY, l.L_SHIPDATE
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_SHIPDATE > '1994-01-01';

-- W2-S12-Q10
SELECT o.O_ORDERKEY, l.L_SHIPDATE
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_SHIPDATE > '1995-01-01';

-- W2-S12-Q11
SELECT o.O_ORDERKEY, l.L_SHIPDATE
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_SHIPDATE > '1997-01-01';

-- W2-S12-Q12
SELECT o.O_ORDERKEY, l.L_SHIPDATE
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_SHIPDATE > '1998-01-01';

-- --- Combined O_TOTALPRICE + L_QUANTITY ---

-- W2-S12-Q13
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  o.O_TOTALPRICE > 10000
  AND  l.L_QUANTITY   > 10;

-- W2-S12-Q14
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  o.O_TOTALPRICE > 20000
  AND  l.L_QUANTITY   > 20;

-- W2-S12-Q15
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  o.O_TOTALPRICE > 30000
  AND  l.L_QUANTITY   > 25;

-- W2-S12-Q16
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  o.O_TOTALPRICE > 40000
  AND  l.L_QUANTITY   > 30;

-- W2-S12-Q17
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  o.O_TOTALPRICE > 50000
  AND  l.L_QUANTITY   > 35;

-- --- L_QUANTITY BETWEEN ranges ---

-- W2-S12-Q18
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY BETWEEN 5  AND 15;

-- W2-S12-Q19
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY BETWEEN 10 AND 20;

-- W2-S12-Q20
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY BETWEEN 20 AND 40;

-- --- Combined L_QUANTITY + L_DISCOUNT ---

-- W2-S12-Q21
SELECT o.O_ORDERKEY, l.L_DISCOUNT
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 10
  AND  l.L_DISCOUNT > 0.02;

-- W2-S12-Q22
SELECT o.O_ORDERKEY, l.L_DISCOUNT
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 20
  AND  l.L_DISCOUNT > 0.04;

-- W2-S12-Q23
SELECT o.O_ORDERKEY, l.L_DISCOUNT
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 30
  AND  l.L_DISCOUNT > 0.06;


-- =============================================================================
-- SECTION 13: PART <-> PARTSUPP  --  Extended Threshold Workload
-- Join key : PART.P_PARTKEY = PARTSUPP.PS_PARTKEY
-- Coverage : Dense sweep of part size, supply cost, available quantity, combined
-- Note     : P_SIZE > 10, PS_SUPPLYCOST > 500, PS_AVAILQTY > 100 already defined
--            in Section 06 (Q02, Q03, Q04) and are not repeated here.
-- =============================================================================

-- --- P_SIZE thresholds (5, 15, 20, 25 — skipping 10 in S06-Q02) ---

-- W2-S13-Q01
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  p.P_SIZE > 5;

-- W2-S13-Q02
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  p.P_SIZE > 15;

-- W2-S13-Q03
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  p.P_SIZE > 20;

-- W2-S13-Q04
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  p.P_SIZE > 25;

-- --- PS_SUPPLYCOST thresholds (100, 300, 700, 900 — skipping 500 in S06-Q03) ---

-- W2-S13-Q05
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_SUPPLYCOST > 100;

-- W2-S13-Q06
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_SUPPLYCOST > 300;

-- W2-S13-Q07
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_SUPPLYCOST > 700;

-- W2-S13-Q08
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_SUPPLYCOST > 900;

-- --- PS_AVAILQTY thresholds (50, 200, 300, 500 — skipping 100 in S06-Q04) ---

-- W2-S13-Q09
SELECT p.P_PARTKEY, ps.PS_AVAILQTY
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_AVAILQTY > 50;

-- W2-S13-Q10
SELECT p.P_PARTKEY, ps.PS_AVAILQTY
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_AVAILQTY > 200;

-- W2-S13-Q11
SELECT p.P_PARTKEY, ps.PS_AVAILQTY
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_AVAILQTY > 300;

-- W2-S13-Q12
SELECT p.P_PARTKEY, ps.PS_AVAILQTY
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_AVAILQTY > 500;

-- --- Combined P_SIZE + PS_SUPPLYCOST (P_SIZE > 10 AND PS_SUPPLYCOST > 300 ---
-- already covered in S08-Q03; remaining combinations listed below)          ---

-- W2-S13-Q13
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  p.P_SIZE         > 20
  AND  ps.PS_SUPPLYCOST > 500;

-- W2-S13-Q14
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  p.P_SIZE         BETWEEN 5  AND 15
  AND  ps.PS_SUPPLYCOST > 200;

-- W2-S13-Q15
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  p.P_SIZE         BETWEEN 15 AND 30
  AND  ps.PS_SUPPLYCOST > 600;


-- =============================================================================
-- SECTION 14: SUPPLIER <-> PARTSUPP  --  Extended Threshold Workload
-- Join key : SUPPLIER.S_SUPPKEY = PARTSUPP.PS_SUPPKEY
-- Coverage : Dense sweep of account balance, nation, supply cost, available qty
-- Note     : PS_SUPPLYCOST > 400 already defined in Section 07 (Q03) and is
--            not repeated here.
-- =============================================================================

-- --- S_ACCTBAL thresholds ---

-- W2-S14-Q01
SELECT s.S_SUPPKEY, ps.PS_PARTKEY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_ACCTBAL > 100;

-- W2-S14-Q02
SELECT s.S_SUPPKEY, ps.PS_PARTKEY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_ACCTBAL > 300;

-- W2-S14-Q03
SELECT s.S_SUPPKEY, ps.PS_PARTKEY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_ACCTBAL > 600;

-- W2-S14-Q04
SELECT s.S_SUPPKEY, ps.PS_PARTKEY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_ACCTBAL > 1000;

-- --- S_NATIONKEY point filters ---

-- W2-S14-Q05
SELECT s.S_SUPPKEY, ps.PS_PARTKEY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_NATIONKEY = 1;

-- W2-S14-Q06
SELECT s.S_SUPPKEY, ps.PS_PARTKEY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_NATIONKEY = 5;

-- W2-S14-Q07
SELECT s.S_SUPPKEY, ps.PS_PARTKEY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_NATIONKEY = 10;

-- --- PS_SUPPLYCOST thresholds (200, 600, 800 — skipping 400 in S07-Q03) ---

-- W2-S14-Q08
SELECT s.S_SUPPKEY, ps.PS_SUPPLYCOST
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  ps.PS_SUPPLYCOST > 200;

-- W2-S14-Q09
SELECT s.S_SUPPKEY, ps.PS_SUPPLYCOST
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  ps.PS_SUPPLYCOST > 600;

-- W2-S14-Q10
SELECT s.S_SUPPKEY, ps.PS_SUPPLYCOST
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  ps.PS_SUPPLYCOST > 800;

-- --- Combined conditions ---

-- W2-S14-Q11
SELECT s.S_SUPPKEY, ps.PS_PARTKEY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_ACCTBAL      > 500
  AND  ps.PS_SUPPLYCOST > 300;

-- W2-S14-Q12
SELECT s.S_SUPPKEY, ps.PS_PARTKEY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_NATIONKEY   BETWEEN 3 AND 8
  AND  ps.PS_SUPPLYCOST > 400;

-- --- PS_AVAILQTY thresholds ---

-- W2-S14-Q13
SELECT s.S_SUPPKEY, ps.PS_AVAILQTY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  ps.PS_AVAILQTY > 100;

-- W2-S14-Q14
SELECT s.S_SUPPKEY, ps.PS_AVAILQTY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  ps.PS_AVAILQTY > 200;


-- =============================================================================
-- SECTION 15: FINAL VARIATIONS
-- Coverage : BETWEEN predicates, mixed filter + ORDER BY across all join pairs
-- Note     : ORDER BY and LIMIT variants already in Sections 09 and 10 are not
--            repeated here; this section adds new filter + ORDER BY combinations.
-- =============================================================================

-- --- BETWEEN predicates ---

-- W2-S15-Q01  [OL] Quantity BETWEEN
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY BETWEEN 5 AND 20;

-- W2-S15-Q02  [OL] Discount BETWEEN
SELECT o.O_ORDERKEY, l.L_DISCOUNT
FROM   ORDERS o JOIN LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_DISCOUNT BETWEEN 0.02 AND 0.06;

-- W2-S15-Q03  [PP] Supply cost BETWEEN
SELECT p.P_PARTKEY, ps.PS_SUPPLYCOST
FROM   PART p JOIN PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_SUPPLYCOST BETWEEN 200 AND 600;

-- W2-S15-Q04  [SP] Available quantity BETWEEN
SELECT s.S_SUPPKEY, ps.PS_AVAILQTY
FROM   SUPPLIER s JOIN PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  ps.PS_AVAILQTY BETWEEN 50 AND 200;

-- --- Mixed filter + ORDER BY ---

-- W2-S15-Q05  [OC] Price + balance filter, sorted by price
SELECT o.O_ORDERKEY, c.C_NAME
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 20000
  AND  c.C_ACCTBAL    > 500
ORDER BY o.O_TOTALPRICE DESC;

-- W2-S15-Q06  [OL] Quantity + discount filter, sorted by quantity
SELECT o.O_ORDERKEY, l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 20
  AND  l.L_DISCOUNT > 0.03
ORDER BY l.L_QUANTITY DESC;


-- =============================================================================
-- SECTION 16: AGGREGATE JOINS  --  COUNT, SUM, AVG, MAX, MIN
-- Coverage : Aggregate functions over joined result sets; tests index use for
--            grouping and aggregation pushdown across all four join pairs
-- =============================================================================

-- W2-S16-Q01  [OC] Count orders per customer
SELECT c.C_CUSTKEY,
       c.C_NAME,
       COUNT(o.O_ORDERKEY)   AS order_count
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY
GROUP BY c.C_CUSTKEY, c.C_NAME;

-- W2-S16-Q02  [OC] Total revenue per customer
SELECT c.C_CUSTKEY,
       c.C_NAME,
       SUM(o.O_TOTALPRICE)   AS total_revenue
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY
GROUP BY c.C_CUSTKEY, c.C_NAME;

-- W2-S16-Q03  [OC] Average order value per customer
SELECT c.C_CUSTKEY,
       c.C_NAME,
       AVG(o.O_TOTALPRICE)   AS avg_order_value
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY
GROUP BY c.C_CUSTKEY, c.C_NAME;

-- W2-S16-Q04  [OC] Max order value per customer nation
SELECT c.C_NATIONKEY,
       MAX(o.O_TOTALPRICE)   AS max_order_price
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
GROUP BY c.C_NATIONKEY;

-- W2-S16-Q05  [OC] Min order value per customer nation
SELECT c.C_NATIONKEY,
       MIN(o.O_TOTALPRICE)   AS min_order_price
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
GROUP BY c.C_NATIONKEY;

-- W2-S16-Q06  [OC] Count + sum with balance filter
SELECT c.C_NATIONKEY,
       COUNT(o.O_ORDERKEY)   AS order_count,
       SUM(o.O_TOTALPRICE)   AS total_revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL > 500
GROUP BY c.C_NATIONKEY;

-- W2-S16-Q07  [OL] Total quantity per order
SELECT o.O_ORDERKEY,
       SUM(l.L_QUANTITY)     AS total_qty
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY o.O_ORDERKEY;

-- W2-S16-Q08  [OL] Average discount per order
SELECT o.O_ORDERKEY,
       AVG(l.L_DISCOUNT)     AS avg_discount
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY o.O_ORDERKEY;

-- W2-S16-Q09  [OL] Count line items per order with price filter
SELECT o.O_ORDERKEY,
       COUNT(l.L_LINENUMBER) AS line_count
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  o.O_TOTALPRICE > 20000
GROUP BY o.O_ORDERKEY;

-- W2-S16-Q10  [OL] Max quantity + min discount per order
SELECT o.O_ORDERKEY,
       MAX(l.L_QUANTITY)     AS max_qty,
       MIN(l.L_DISCOUNT)     AS min_discount
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY o.O_ORDERKEY;

-- W2-S16-Q11  [OL] Sum of extended price per ship date year
SELECT YEAR(l.L_SHIPDATE)    AS ship_year,
       SUM(l.L_EXTENDEDPRICE) AS total_extended
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY YEAR(l.L_SHIPDATE);

-- W2-S16-Q12  [PP] Average supply cost per part size
SELECT p.P_SIZE,
       AVG(ps.PS_SUPPLYCOST) AS avg_supply_cost
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
GROUP BY p.P_SIZE;

-- W2-S16-Q13  [PP] Total available quantity per part
SELECT p.P_PARTKEY,
       SUM(ps.PS_AVAILQTY)   AS total_availqty
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
GROUP BY p.P_PARTKEY;

-- W2-S16-Q14  [PP] Max and min supply cost per part type
SELECT p.P_TYPE,
       MAX(ps.PS_SUPPLYCOST) AS max_cost,
       MIN(ps.PS_SUPPLYCOST) AS min_cost
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
GROUP BY p.P_TYPE;

-- W2-S16-Q15  [SP] Count parts supplied per supplier
SELECT s.S_SUPPKEY,
       s.S_NAME,
       COUNT(ps.PS_PARTKEY)  AS parts_supplied
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
GROUP BY s.S_SUPPKEY, s.S_NAME;

-- W2-S16-Q16  [SP] Average supply cost per supplier nation
SELECT s.S_NATIONKEY,
       AVG(ps.PS_SUPPLYCOST) AS avg_supply_cost
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
GROUP BY s.S_NATIONKEY;

-- W2-S16-Q17  [SP] Sum available quantity per supplier
SELECT s.S_SUPPKEY,
       SUM(ps.PS_AVAILQTY)   AS total_availqty
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
GROUP BY s.S_SUPPKEY;

-- W2-S16-Q18  [SP] Max supply cost per nation with balance filter
SELECT s.S_NATIONKEY,
       MAX(ps.PS_SUPPLYCOST) AS max_supply_cost
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_ACCTBAL > 300
GROUP BY s.S_NATIONKEY;

-- W2-S16-Q19  [OC] Count orders per customer with date filter
SELECT c.C_CUSTKEY,
       COUNT(o.O_ORDERKEY)   AS order_count
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY
WHERE  o.O_ORDERDATE > '1995-01-01'
GROUP BY c.C_CUSTKEY;

-- W2-S16-Q20  [OL] Count + avg qty per order, quantity filter
SELECT o.O_ORDERKEY,
       COUNT(l.L_LINENUMBER) AS line_count,
       AVG(l.L_QUANTITY)     AS avg_qty
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_QUANTITY > 10
GROUP BY o.O_ORDERKEY;


-- =============================================================================
-- SECTION 17: HAVING CLAUSE JOINS  --  Post-Aggregation Filters
-- Coverage : HAVING applied after GROUP BY to filter aggregated groups;
--            exercises index interaction with grouping and aggregate predicates
-- =============================================================================

-- W2-S17-Q01  [OC] Customers with more than 5 orders
SELECT c.C_CUSTKEY,
       c.C_NAME,
       COUNT(o.O_ORDERKEY)   AS order_count
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY
GROUP BY c.C_CUSTKEY, c.C_NAME
HAVING COUNT(o.O_ORDERKEY) > 5;

-- W2-S17-Q02  [OC] Customers with total revenue above threshold
SELECT c.C_CUSTKEY,
       c.C_NAME,
       SUM(o.O_TOTALPRICE)   AS total_revenue
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY
GROUP BY c.C_CUSTKEY, c.C_NAME
HAVING SUM(o.O_TOTALPRICE) > 200000;

-- W2-S17-Q03  [OC] Nations with average order value above threshold
SELECT c.C_NATIONKEY,
       AVG(o.O_TOTALPRICE)   AS avg_order_value
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
GROUP BY c.C_NATIONKEY
HAVING AVG(o.O_TOTALPRICE) > 30000;

-- W2-S17-Q04  [OL] Orders with more than 4 line items
SELECT o.O_ORDERKEY,
       COUNT(l.L_LINENUMBER) AS line_count
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY o.O_ORDERKEY
HAVING COUNT(l.L_LINENUMBER) > 4;

-- W2-S17-Q05  [OL] Orders with total quantity above threshold
SELECT o.O_ORDERKEY,
       SUM(l.L_QUANTITY)     AS total_qty
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY o.O_ORDERKEY
HAVING SUM(l.L_QUANTITY) > 100;

-- W2-S17-Q06  [PP] Parts supplied by more than 2 suppliers
SELECT p.P_PARTKEY,
       COUNT(ps.PS_SUPPKEY)  AS supplier_count
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
GROUP BY p.P_PARTKEY
HAVING COUNT(ps.PS_SUPPKEY) > 2;

-- W2-S17-Q07  [PP] Part sizes with average supply cost above threshold
SELECT p.P_SIZE,
       AVG(ps.PS_SUPPLYCOST) AS avg_cost
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
GROUP BY p.P_SIZE
HAVING AVG(ps.PS_SUPPLYCOST) > 400;

-- W2-S17-Q08  [SP] Suppliers with total available quantity above threshold
SELECT s.S_SUPPKEY,
       SUM(ps.PS_AVAILQTY)   AS total_qty
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
GROUP BY s.S_SUPPKEY
HAVING SUM(ps.PS_AVAILQTY) > 5000;


-- =============================================================================
-- SECTION 18: DISTINCT JOINS  --  Duplicate Elimination
-- Coverage : SELECT DISTINCT to eliminate duplicate rows from join output;
--            tests optimizer's use of indexes to avoid sort-based deduplication
-- =============================================================================

-- W2-S18-Q01  [OC] Distinct customers who have placed orders
SELECT DISTINCT c.C_CUSTKEY,
       c.C_NAME
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY;

-- W2-S18-Q02  [OC] Distinct nation keys of customers with high-value orders
SELECT DISTINCT c.C_NATIONKEY
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_TOTALPRICE > 50000;

-- W2-S18-Q03  [OL] Distinct ship dates appearing in joined result
SELECT DISTINCT l.L_SHIPDATE
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  o.O_TOTALPRICE > 30000;

-- W2-S18-Q04  [PP] Distinct part types with supply cost filter
SELECT DISTINCT p.P_TYPE
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
WHERE  ps.PS_SUPPLYCOST > 600;

-- W2-S18-Q05  [SP] Distinct supplier nation keys in joined result
SELECT DISTINCT s.S_NATIONKEY
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  ps.PS_AVAILQTY > 300;

-- W2-S18-Q06  [OL] Distinct order keys where discount exceeds threshold
SELECT DISTINCT o.O_ORDERKEY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_DISCOUNT > 0.07;


-- =============================================================================
-- SECTION 19: ORDER BY + LIMIT COMBINED  --  Top-N with Sort
-- Coverage : Combines ORDER BY and LIMIT to simulate ranked/paginated queries;
--            indexes that satisfy both the sort and filter avoid filesort+scan
-- =============================================================================

-- W2-S19-Q01  [OC] Top 10 highest-value orders with customer name
SELECT o.O_ORDERKEY,
       c.C_NAME,
       o.O_TOTALPRICE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
ORDER BY o.O_TOTALPRICE DESC
LIMIT  10;

-- W2-S19-Q02  [OC] Top 20 customers by account balance with order count
SELECT c.C_NAME,
       c.C_ACCTBAL,
       COUNT(o.O_ORDERKEY) AS order_count
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY
GROUP BY c.C_CUSTKEY, c.C_NAME, c.C_ACCTBAL
ORDER BY c.C_ACCTBAL DESC
LIMIT  20;

-- W2-S19-Q03  [OC] Top 50 recent orders with customer name
SELECT o.O_ORDERKEY,
       c.C_NAME,
       o.O_ORDERDATE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
ORDER BY o.O_ORDERDATE DESC
LIMIT  50;

-- W2-S19-Q04  [OL] Top 10 orders by total quantity
SELECT o.O_ORDERKEY,
       SUM(l.L_QUANTITY)    AS total_qty
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY o.O_ORDERKEY
ORDER BY total_qty DESC
LIMIT  10;

-- W2-S19-Q05  [OL] Top 25 line items by extended price with discount filter
SELECT o.O_ORDERKEY,
       l.L_LINENUMBER,
       l.L_EXTENDEDPRICE
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_DISCOUNT > 0.04
ORDER BY l.L_EXTENDEDPRICE DESC
LIMIT  25;

-- W2-S19-Q06  [PP] Top 15 parts by total available quantity
SELECT p.P_PARTKEY,
       p.P_NAME,
       SUM(ps.PS_AVAILQTY)  AS total_qty
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
GROUP BY p.P_PARTKEY, p.P_NAME
ORDER BY total_qty DESC
LIMIT  15;

-- W2-S19-Q07  [SP] Top 10 suppliers by average supply cost
SELECT s.S_SUPPKEY,
       s.S_NAME,
       AVG(ps.PS_SUPPLYCOST) AS avg_cost
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
GROUP BY s.S_SUPPKEY, s.S_NAME
ORDER BY avg_cost DESC
LIMIT  10;

-- W2-S19-Q08  [SP] Top 20 cheapest supplier-part combinations
SELECT s.S_NAME,
       ps.PS_PARTKEY,
       ps.PS_SUPPLYCOST
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
ORDER BY ps.PS_SUPPLYCOST ASC
LIMIT  20;


-- =============================================================================
-- SECTION 20: SUBQUERY / EXISTS / IN JOINS
-- Coverage : Semi-join patterns using EXISTS and IN subqueries; tests optimizer
--            subquery flattening and index reuse across correlated predicates
-- =============================================================================

-- W2-S20-Q01  [OC] Customers who have at least one order (EXISTS)
SELECT c.C_CUSTKEY,
       c.C_NAME
FROM   CUSTOMER c
WHERE  EXISTS (
           SELECT 1
           FROM   ORDERS o
           WHERE  o.O_CUSTKEY = c.C_CUSTKEY
       );

-- W2-S20-Q02  [OC] Customers with a high-value order (EXISTS + filter)
SELECT c.C_CUSTKEY,
       c.C_NAME
FROM   CUSTOMER c
WHERE  EXISTS (
           SELECT 1
           FROM   ORDERS o
           WHERE  o.O_CUSTKEY    = c.C_CUSTKEY
             AND  o.O_TOTALPRICE > 100000
       );

-- W2-S20-Q03  [OC] Customers whose orders are all after a date (NOT EXISTS)
SELECT c.C_CUSTKEY,
       c.C_NAME
FROM   CUSTOMER c
WHERE  NOT EXISTS (
           SELECT 1
           FROM   ORDERS o
           WHERE  o.O_CUSTKEY  = c.C_CUSTKEY
             AND  o.O_ORDERDATE < '1995-01-01'
       );

-- W2-S20-Q04  [OC] Orders for customers in a specific nation set (IN)
SELECT o.O_ORDERKEY,
       o.O_TOTALPRICE
FROM   ORDERS o
WHERE  o.O_CUSTKEY IN (
           SELECT c.C_CUSTKEY
           FROM   CUSTOMER c
           WHERE  c.C_NATIONKEY IN (1, 5, 10)
       );

-- W2-S20-Q05  [OL] Orders that contain a high-quantity line item (EXISTS)
SELECT o.O_ORDERKEY,
       o.O_TOTALPRICE
FROM   ORDERS o
WHERE  EXISTS (
           SELECT 1
           FROM   LINEITEM l
           WHERE  l.L_ORDERKEY = o.O_ORDERKEY
             AND  l.L_QUANTITY > 40
       );

-- W2-S20-Q06  [OL] Orders with no discounted line items (NOT EXISTS)
SELECT o.O_ORDERKEY,
       o.O_TOTALPRICE
FROM   ORDERS o
WHERE  NOT EXISTS (
           SELECT 1
           FROM   LINEITEM l
           WHERE  l.L_ORDERKEY = o.O_ORDERKEY
             AND  l.L_DISCOUNT > 0.0
       );

-- W2-S20-Q07  [PP] Parts supplied by a high-balance supplier (IN)
SELECT p.P_PARTKEY,
       p.P_NAME
FROM   PART p
WHERE  p.P_PARTKEY IN (
           SELECT ps.PS_PARTKEY
           FROM   PARTSUPP ps
           JOIN   SUPPLIER s ON ps.PS_SUPPKEY = s.S_SUPPKEY
           WHERE  s.S_ACCTBAL > 800
       );

-- W2-S20-Q08  [SP] Suppliers who supply at least one large part (EXISTS)
SELECT s.S_SUPPKEY,
       s.S_NAME
FROM   SUPPLIER s
WHERE  EXISTS (
           SELECT 1
           FROM   PARTSUPP ps
           JOIN   PART     p  ON ps.PS_PARTKEY = p.P_PARTKEY
           WHERE  ps.PS_SUPPKEY = s.S_SUPPKEY
             AND  p.P_SIZE      > 30
       );


-- =============================================================================
-- SECTION 21: ADDITIONAL DIVERSITY QUERIES
-- Coverage : Cross-column aggregates, date-function grouping, multi-join
--            aggregate combos, and mixed filter+aggregate patterns to fill
--            remaining diversity gaps across all four join pairs
-- =============================================================================

-- W2-S21-Q01  [OC] Revenue and order count per nation, date-filtered
SELECT c.C_NATIONKEY,
       COUNT(o.O_ORDERKEY)   AS order_count,
       SUM(o.O_TOTALPRICE)   AS total_revenue,
       AVG(o.O_TOTALPRICE)   AS avg_revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  o.O_ORDERDATE BETWEEN '1995-01-01' AND '1997-01-01'
GROUP BY c.C_NATIONKEY
ORDER BY total_revenue DESC;

-- W2-S21-Q02  [OC] Order count per year per nation
SELECT c.C_NATIONKEY,
       YEAR(o.O_ORDERDATE)   AS order_year,
       COUNT(o.O_ORDERKEY)   AS order_count
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
GROUP BY c.C_NATIONKEY, YEAR(o.O_ORDERDATE)
ORDER BY c.C_NATIONKEY, order_year;

-- W2-S21-Q03  [OL] Revenue per year from line items (extended price net of discount)
SELECT YEAR(l.L_SHIPDATE)           AS ship_year,
       SUM(l.L_EXTENDEDPRICE
           * (1 - l.L_DISCOUNT))    AS net_revenue
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY YEAR(l.L_SHIPDATE)
ORDER BY ship_year;

-- W2-S21-Q04  [OL] Orders with above-average total price and line count
SELECT o.O_ORDERKEY,
       o.O_TOTALPRICE,
       COUNT(l.L_LINENUMBER) AS line_count
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  o.O_TOTALPRICE > (SELECT AVG(O_TOTALPRICE) FROM ORDERS)
GROUP BY o.O_ORDERKEY, o.O_TOTALPRICE
ORDER BY o.O_TOTALPRICE DESC
LIMIT  50;

-- W2-S21-Q05  [PP] Supply cost spread (max minus min) per part brand
SELECT p.P_BRAND,
       MAX(ps.PS_SUPPLYCOST) - MIN(ps.PS_SUPPLYCOST) AS cost_spread,
       COUNT(ps.PS_SUPPKEY)                           AS supplier_count
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
GROUP BY p.P_BRAND
ORDER BY cost_spread DESC;

-- W2-S21-Q06  [SP] Suppliers with parts in more than one size category
SELECT s.S_SUPPKEY,
       s.S_NAME,
       COUNT(DISTINCT p.P_SIZE) AS distinct_sizes
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY  = ps.PS_SUPPKEY
JOIN   PART     p  ON ps.PS_PARTKEY = p.P_PARTKEY
GROUP BY s.S_SUPPKEY, s.S_NAME
HAVING COUNT(DISTINCT p.P_SIZE) > 1
ORDER BY distinct_sizes DESC;

-- W2-S21-Q07  [OC] Top 10 nations by average customer balance
SELECT c.C_NATIONKEY,
       AVG(c.C_ACCTBAL)      AS avg_balance,
       COUNT(DISTINCT c.C_CUSTKEY) AS customer_count
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY
GROUP BY c.C_NATIONKEY
ORDER BY avg_balance DESC
LIMIT  10;

-- W2-S21-Q08  [OL] High-discount line items with ship year and order price
SELECT YEAR(l.L_SHIPDATE)    AS ship_year,
       COUNT(l.L_LINENUMBER) AS discounted_lines,
       AVG(o.O_TOTALPRICE)   AS avg_order_price
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_DISCOUNT > 0.06
GROUP BY YEAR(l.L_SHIPDATE)
ORDER BY ship_year;

-- W2-S21-Q09  [PP] Parts with total stock value above threshold
SELECT p.P_PARTKEY,
       p.P_NAME,
       SUM(ps.PS_AVAILQTY * ps.PS_SUPPLYCOST) AS stock_value
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
GROUP BY p.P_PARTKEY, p.P_NAME
HAVING SUM(ps.PS_AVAILQTY * ps.PS_SUPPLYCOST) > 500000
ORDER BY stock_value DESC;

-- W2-S21-Q10  [OC] Customers with orders in every status (DISTINCT status count)
SELECT c.C_CUSTKEY,
       c.C_NAME,
       COUNT(DISTINCT o.O_ORDERSTATUS) AS status_count
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY
GROUP BY c.C_CUSTKEY, c.C_NAME
HAVING COUNT(DISTINCT o.O_ORDERSTATUS) > 1;

-- W2-S21-Q11  [OL] Orders with both high quantity and high discount lines
SELECT o.O_ORDERKEY,
       o.O_TOTALPRICE
FROM   ORDERS o
WHERE  EXISTS (
           SELECT 1 FROM LINEITEM l
           WHERE l.L_ORDERKEY = o.O_ORDERKEY AND l.L_QUANTITY > 30
       )
  AND  EXISTS (
           SELECT 1 FROM LINEITEM l
           WHERE l.L_ORDERKEY = o.O_ORDERKEY AND l.L_DISCOUNT > 0.05
       );

-- W2-S21-Q12  [PP] Parts not supplied by any supplier in nation 5 (NOT IN)
SELECT p.P_PARTKEY,
       p.P_NAME
FROM   PART p
WHERE  p.P_PARTKEY NOT IN (
           SELECT ps.PS_PARTKEY
           FROM   PARTSUPP ps
           JOIN   SUPPLIER s ON ps.PS_SUPPKEY = s.S_SUPPKEY
           WHERE  s.S_NATIONKEY = 5
       )
LIMIT 100;

-- W2-S21-Q13  [OC] Orders placed by high-balance customers, sorted by date
SELECT o.O_ORDERKEY,
       o.O_ORDERDATE,
       o.O_TOTALPRICE,
       c.C_ACCTBAL
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
WHERE  c.C_ACCTBAL > 1000
  AND  o.O_ORDERDATE BETWEEN '1994-01-01' AND '1998-12-31'
ORDER BY o.O_ORDERDATE ASC,
         o.O_TOTALPRICE DESC;

-- W2-S21-Q14  [OL] Monthly shipment volume (quantity + lines) over time
SELECT YEAR(l.L_SHIPDATE)    AS ship_year,
       MONTH(l.L_SHIPDATE)   AS ship_month,
       COUNT(l.L_LINENUMBER) AS total_lines,
       SUM(l.L_QUANTITY)     AS total_quantity
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY YEAR(l.L_SHIPDATE), MONTH(l.L_SHIPDATE)
ORDER BY ship_year, ship_month;

-- W2-S21-Q15  [SP] Supplier cost efficiency: avg cost vs total stock, filtered
SELECT s.S_SUPPKEY,
       s.S_NAME,
       s.S_NATIONKEY,
       AVG(ps.PS_SUPPLYCOST) AS avg_cost,
       SUM(ps.PS_AVAILQTY)   AS total_stock
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY = ps.PS_SUPPKEY
WHERE  s.S_ACCTBAL > 200
GROUP BY s.S_SUPPKEY, s.S_NAME, s.S_NATIONKEY
HAVING AVG(ps.PS_SUPPLYCOST) < 600
   AND SUM(ps.PS_AVAILQTY)   > 1000
ORDER BY avg_cost ASC
LIMIT  25;

-- =============================================================================
-- END OF WORKLOAD W2
-- Total queries : 200
-- Sections      : 20
-- Join pairs    : ORDERS<->CUSTOMER, ORDERS<->LINEITEM,
--                 PART<->PARTSUPP,   SUPPLIER<->PARTSUPP
-- Operation types covered:
--   Basic joins, threshold filters, combined filters, multi-predicate,
--   ORDER BY, LIMIT, ORDER BY + LIMIT, DISTINCT, GROUP BY, aggregate
--   functions (COUNT/SUM/AVG/MAX/MIN), HAVING, EXISTS, NOT EXISTS, IN,
--   subqueries, date functions (YEAR), BETWEEN, range predicates
-- =============================================================================
