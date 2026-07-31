-- =============================================================================
-- WORKLOAD W3: MULTI-TABLE JOIN QUERIES
-- =============================================================================
-- Dataset  : TPC-H Benchmark
-- DBMS     : MySQL
-- Purpose  : Diverse multi-table join workload (3+ tables) for ML-based index
--            recommendation experiments
-- Tables   : ORDERS, CUSTOMER, LINEITEM, PART, PARTSUPP, SUPPLIER, NATION, REGION
-- Total    : 200 queries across 20 sections
--
-- Join depth coverage:
--   3-table  : Sections 01–09
--   4-table  : Sections 02, 06, 10
--   5-table  : Section  11
--   6-table  : Section  12
--   Mixed    : Sections 13–20
--
-- Operation types covered:
--   Basic multi-table joins, range/point/BETWEEN filters, combined predicates,
--   ORDER BY, LIMIT, ORDER BY+LIMIT (Top-N), DISTINCT, GROUP BY, aggregates
--   (COUNT/SUM/AVG/MAX/MIN), HAVING, EXISTS, NOT EXISTS, IN subqueries,
--   correlated subqueries, date functions (YEAR/MONTH), computed expressions,
--   multi-level aggregation
--
-- Query ID format: W3-S<section>-Q<number>
-- =============================================================================

USE tpch;


-- =============================================================================
-- SECTION 01: ORDERS + CUSTOMER + NATION  (3-table)
-- Join keys : O_CUSTKEY=C_CUSTKEY, C_NATIONKEY=N_NATIONKEY
-- Coverage  : Basic nation-resolved customer-order queries with filter variety
-- =============================================================================

-- W3-S01-Q01  Full 3-table join, no filter
SELECT o.O_ORDERKEY,
       c.C_NAME,
       n.N_NAME        AS nation
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY;

-- W3-S01-Q02  Filter by nation name
SELECT o.O_ORDERKEY,
       c.C_NAME,
       o.O_TOTALPRICE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
WHERE  n.N_NAME = 'GERMANY';

-- W3-S01-Q03  Filter by order total price
SELECT o.O_ORDERKEY,
       c.C_NAME,
       n.N_NAME        AS nation
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
WHERE  o.O_TOTALPRICE > 100000;

-- W3-S01-Q04  Filter by customer account balance
SELECT o.O_ORDERKEY,
       c.C_NAME,
       n.N_NAME        AS nation
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
WHERE  c.C_ACCTBAL > 5000;

-- W3-S01-Q05  Filter by order date range
SELECT o.O_ORDERKEY,
       c.C_NAME,
       n.N_NAME        AS nation
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
WHERE  o.O_ORDERDATE BETWEEN '1995-01-01' AND '1996-12-31';

-- W3-S01-Q06  Combined: nation + price filter
SELECT o.O_ORDERKEY,
       c.C_NAME,
       o.O_TOTALPRICE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
WHERE  n.N_NAME       = 'FRANCE'
  AND  o.O_TOTALPRICE > 50000;

-- W3-S01-Q07  Combined: nation + balance + date
SELECT o.O_ORDERKEY,
       c.C_NAME,
       c.C_ACCTBAL
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
WHERE  n.N_NAME       = 'UNITED STATES'
  AND  c.C_ACCTBAL   > 3000
  AND  o.O_ORDERDATE > '1996-01-01';

-- W3-S01-Q08  ORDER BY total price
SELECT o.O_ORDERKEY,
       c.C_NAME,
       n.N_NAME        AS nation,
       o.O_TOTALPRICE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
ORDER BY o.O_TOTALPRICE DESC
LIMIT  20;

-- W3-S01-Q09  Aggregate: total revenue per nation
SELECT n.N_NAME        AS nation,
       COUNT(o.O_ORDERKEY)  AS order_count,
       SUM(o.O_TOTALPRICE)  AS total_revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
GROUP BY n.N_NAME
ORDER BY total_revenue DESC;

-- W3-S01-Q10  HAVING: nations with more than 1000 orders
SELECT n.N_NAME        AS nation,
       COUNT(o.O_ORDERKEY)  AS order_count
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
GROUP BY n.N_NAME
HAVING COUNT(o.O_ORDERKEY) > 1000
ORDER BY order_count DESC;


-- =============================================================================
-- SECTION 02: ORDERS + CUSTOMER + NATION + REGION  (4-table)
-- Join keys : O_CUSTKEY=C_CUSTKEY, C_NATIONKEY=N_NATIONKEY, N_REGIONKEY=R_REGIONKEY
-- Coverage  : Full geographic hierarchy resolution with filter and aggregate variety
-- =============================================================================

-- W3-S02-Q01  Full 4-table join
SELECT o.O_ORDERKEY,
       c.C_NAME,
       n.N_NAME        AS nation,
       r.R_NAME        AS region
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY;

-- W3-S02-Q02  Filter by region
SELECT o.O_ORDERKEY,
       c.C_NAME,
       n.N_NAME        AS nation
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
WHERE  r.R_NAME = 'EUROPE';

-- W3-S02-Q03  Filter by region + price
SELECT o.O_ORDERKEY,
       c.C_NAME,
       o.O_TOTALPRICE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
WHERE  r.R_NAME       = 'ASIA'
  AND  o.O_TOTALPRICE > 80000;

-- W3-S02-Q04  Revenue per region
SELECT r.R_NAME        AS region,
       SUM(o.O_TOTALPRICE)  AS total_revenue,
       COUNT(o.O_ORDERKEY)  AS order_count
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
GROUP BY r.R_NAME
ORDER BY total_revenue DESC;

-- W3-S02-Q05  Revenue per nation within a region
SELECT r.R_NAME        AS region,
       n.N_NAME        AS nation,
       SUM(o.O_TOTALPRICE)  AS total_revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
WHERE  r.R_NAME = 'AMERICA'
GROUP BY r.R_NAME, n.N_NAME
ORDER BY total_revenue DESC;

-- W3-S02-Q06  Average order value per region
SELECT r.R_NAME        AS region,
       AVG(o.O_TOTALPRICE)  AS avg_order_value
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
GROUP BY r.R_NAME;

-- W3-S02-Q07  Top customers per region
SELECT r.R_NAME        AS region,
       c.C_NAME,
       SUM(o.O_TOTALPRICE)  AS total_spent
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
GROUP BY r.R_NAME, c.C_CUSTKEY, c.C_NAME
ORDER BY r.R_NAME, total_spent DESC;

-- W3-S02-Q08  Date-filtered revenue per region
SELECT r.R_NAME        AS region,
       SUM(o.O_TOTALPRICE)  AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
WHERE  o.O_ORDERDATE BETWEEN '1995-01-01' AND '1996-12-31'
GROUP BY r.R_NAME;

-- W3-S02-Q09  HAVING: regions with revenue above threshold
SELECT r.R_NAME        AS region,
       SUM(o.O_TOTALPRICE)  AS total_revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
GROUP BY r.R_NAME
HAVING SUM(o.O_TOTALPRICE) > 50000000;

-- W3-S02-Q10  Distinct regions for high-balance customers
SELECT DISTINCT r.R_NAME   AS region,
       n.N_NAME             AS nation
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
WHERE  c.C_ACCTBAL > 8000
ORDER BY r.R_NAME, n.N_NAME;


-- =============================================================================
-- SECTION 03: ORDERS + LINEITEM + PART  (3-table)
-- Join keys : O_ORDERKEY=L_ORDERKEY, L_PARTKEY=P_PARTKEY
-- Coverage  : Part-level detail on orders; filter on part and line attributes
-- =============================================================================

-- W3-S03-Q01  Full 3-table join
SELECT o.O_ORDERKEY,
       p.P_NAME,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART    p  ON l.L_PARTKEY  = p.P_PARTKEY;

-- W3-S03-Q02  Filter by part size
SELECT o.O_ORDERKEY,
       p.P_NAME,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART    p  ON l.L_PARTKEY  = p.P_PARTKEY
WHERE  p.P_SIZE > 20;

-- W3-S03-Q03  Filter by part type
SELECT o.O_ORDERKEY,
       p.P_TYPE,
       l.L_EXTENDEDPRICE
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART    p  ON l.L_PARTKEY  = p.P_PARTKEY
WHERE  p.P_TYPE LIKE 'STANDARD%';

-- W3-S03-Q04  Filter by line quantity + part size
SELECT o.O_ORDERKEY,
       p.P_NAME,
       l.L_QUANTITY
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART    p  ON l.L_PARTKEY  = p.P_PARTKEY
WHERE  l.L_QUANTITY > 30
  AND  p.P_SIZE     > 15;

-- W3-S03-Q05  Filter by ship date + part retail price
SELECT o.O_ORDERKEY,
       p.P_RETAILPRICE,
       l.L_SHIPDATE
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART    p  ON l.L_PARTKEY  = p.P_PARTKEY
WHERE  l.L_SHIPDATE    > '1996-01-01'
  AND  p.P_RETAILPRICE > 1000;

-- W3-S03-Q06  Total revenue per part brand
SELECT p.P_BRAND,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART    p  ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY p.P_BRAND
ORDER BY revenue DESC;

-- W3-S03-Q07  Average quantity per part type
SELECT p.P_TYPE,
       AVG(l.L_QUANTITY)    AS avg_quantity,
       COUNT(l.L_LINENUMBER) AS line_count
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART    p  ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY p.P_TYPE;

-- W3-S03-Q08  Top 10 parts by total quantity sold
SELECT p.P_PARTKEY,
       p.P_NAME,
       SUM(l.L_QUANTITY)    AS total_qty
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART    p  ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY p.P_PARTKEY, p.P_NAME
ORDER BY total_qty DESC
LIMIT  10;

-- W3-S03-Q09  Orders with high-retail-price parts, sorted
SELECT o.O_ORDERKEY,
       o.O_TOTALPRICE,
       MAX(p.P_RETAILPRICE) AS max_part_price
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART    p  ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY o.O_ORDERKEY, o.O_TOTALPRICE
HAVING MAX(p.P_RETAILPRICE) > 1500
ORDER BY o.O_TOTALPRICE DESC
LIMIT  25;

-- W3-S03-Q10  Distinct part brands for high-value orders
SELECT DISTINCT p.P_BRAND
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART    p  ON l.L_PARTKEY  = p.P_PARTKEY
WHERE  o.O_TOTALPRICE > 200000
ORDER BY p.P_BRAND;


-- =============================================================================
-- SECTION 04: ORDERS + LINEITEM + SUPPLIER  (3-table)
-- Join keys : O_ORDERKEY=L_ORDERKEY, L_SUPPKEY=S_SUPPKEY
-- Coverage  : Supplier-resolved line items; filter on supplier and line dims
-- =============================================================================

-- W3-S04-Q01  Full 3-table join
SELECT o.O_ORDERKEY,
       s.S_NAME,
       l.L_QUANTITY
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY  = s.S_SUPPKEY;

-- W3-S04-Q02  Filter by supplier nation
SELECT o.O_ORDERKEY,
       s.S_NAME,
       l.L_EXTENDEDPRICE
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY  = s.S_SUPPKEY
WHERE  s.S_NATIONKEY = 1;

-- W3-S04-Q03  Filter by supplier balance
SELECT o.O_ORDERKEY,
       s.S_NAME,
       l.L_QUANTITY
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY  = s.S_SUPPKEY
WHERE  s.S_ACCTBAL > 5000;

-- W3-S04-Q04  Filter by line discount + order price
SELECT o.O_ORDERKEY,
       s.S_NAME,
       l.L_DISCOUNT
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY  = s.S_SUPPKEY
WHERE  l.L_DISCOUNT   > 0.05
  AND  o.O_TOTALPRICE > 50000;

-- W3-S04-Q05  Revenue per supplier
SELECT s.S_SUPPKEY,
       s.S_NAME,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY  = s.S_SUPPKEY
GROUP BY s.S_SUPPKEY, s.S_NAME
ORDER BY revenue DESC;

-- W3-S04-Q06  Top 10 suppliers by revenue
SELECT s.S_SUPPKEY,
       s.S_NAME,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY  = s.S_SUPPKEY
GROUP BY s.S_SUPPKEY, s.S_NAME
ORDER BY revenue DESC
LIMIT  10;

-- W3-S04-Q07  Average discount per supplier nation
SELECT s.S_NATIONKEY,
       AVG(l.L_DISCOUNT)    AS avg_discount
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY  = s.S_SUPPKEY
GROUP BY s.S_NATIONKEY
ORDER BY avg_discount DESC;

-- W3-S04-Q08  HAVING: suppliers with total quantity above threshold
SELECT s.S_SUPPKEY,
       s.S_NAME,
       SUM(l.L_QUANTITY)    AS total_qty
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY  = s.S_SUPPKEY
GROUP BY s.S_SUPPKEY, s.S_NAME
HAVING SUM(l.L_QUANTITY) > 10000;

-- W3-S04-Q09  Ship date range + supplier balance filter
SELECT o.O_ORDERKEY,
       s.S_NAME,
       l.L_SHIPDATE
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY  = s.S_SUPPKEY
WHERE  l.L_SHIPDATE BETWEEN '1995-01-01' AND '1997-01-01'
  AND  s.S_ACCTBAL  > 3000;

-- W3-S04-Q10  Distinct suppliers who handled high-value orders
SELECT DISTINCT s.S_SUPPKEY,
       s.S_NAME
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY  = s.S_SUPPKEY
WHERE  o.O_TOTALPRICE > 150000
ORDER BY s.S_NAME;


-- =============================================================================
-- SECTION 05: LINEITEM + PART + PARTSUPP  (3-table)
-- Join keys : L_PARTKEY=P_PARTKEY, L_PARTKEY=PS_PARTKEY AND L_SUPPKEY=PS_SUPPKEY
-- Coverage  : Supply-chain detail linking parts to suppliers through partsupp
-- =============================================================================

-- W3-S05-Q01  Full 3-table join
SELECT l.L_ORDERKEY,
       p.P_NAME,
       ps.PS_SUPPLYCOST
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY;

-- W3-S05-Q02  Filter: supply cost below line extended price
SELECT l.L_ORDERKEY,
       p.P_NAME,
       ps.PS_SUPPLYCOST,
       l.L_EXTENDEDPRICE
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
WHERE  ps.PS_SUPPLYCOST < l.L_EXTENDEDPRICE;

-- W3-S05-Q03  Filter by part size + supply cost threshold
SELECT l.L_ORDERKEY,
       p.P_NAME,
       ps.PS_SUPPLYCOST
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
WHERE  p.P_SIZE         > 15
  AND  ps.PS_SUPPLYCOST > 400;

-- W3-S05-Q04  Profit margin: extended price minus supply cost
SELECT p.P_PARTKEY,
       p.P_NAME,
       SUM(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) AS total_margin
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
GROUP BY p.P_PARTKEY, p.P_NAME
ORDER BY total_margin DESC
LIMIT  20;

-- W3-S05-Q05  Average margin per part brand
SELECT p.P_BRAND,
       AVG(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) AS avg_margin
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
GROUP BY p.P_BRAND
ORDER BY avg_margin DESC;

-- W3-S05-Q06  Parts where supply cost exceeds avg supply cost for that size
SELECT p.P_PARTKEY,
       p.P_SIZE,
       ps.PS_SUPPLYCOST
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY = ps.PS_PARTKEY
JOIN   LINEITEM l  ON l.L_PARTKEY = p.P_PARTKEY
                  AND l.L_SUPPKEY = ps.PS_SUPPKEY
WHERE  ps.PS_SUPPLYCOST > 600
ORDER BY p.P_SIZE, ps.PS_SUPPLYCOST DESC;

-- W3-S05-Q07  Count line items per part type with supply cost filter
SELECT p.P_TYPE,
       COUNT(l.L_LINENUMBER) AS line_count,
       AVG(ps.PS_SUPPLYCOST) AS avg_supply_cost
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
GROUP BY p.P_TYPE
ORDER BY line_count DESC;

-- W3-S05-Q08  HAVING: brands with high average margin
SELECT p.P_BRAND,
       AVG(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) AS avg_margin
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
GROUP BY p.P_BRAND
HAVING AVG(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) > 500;

-- W3-S05-Q09  Ship date filter + margin
SELECT l.L_ORDERKEY,
       p.P_NAME,
       l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST AS margin
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
WHERE  l.L_SHIPDATE > '1996-01-01'
ORDER BY margin DESC
LIMIT  30;

-- W3-S05-Q10  Distinct part types with available stock above threshold
SELECT DISTINCT p.P_TYPE,
       p.P_BRAND
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
WHERE  ps.PS_AVAILQTY > 200
ORDER BY p.P_TYPE;


-- =============================================================================
-- SECTION 06: LINEITEM + PART + SUPPLIER + PARTSUPP  (4-table)
-- Join keys : L_PARTKEY=P_PARTKEY, L_SUPPKEY=S_SUPPKEY,
--             L_PARTKEY=PS_PARTKEY AND L_SUPPKEY=PS_SUPPKEY
-- Coverage  : Full supply-chain join linking line items to both part and
--             supplier dimensions through the PARTSUPP bridge table
-- =============================================================================

-- W3-S06-Q01  Full 4-table join
SELECT l.L_ORDERKEY,
       p.P_NAME,
       s.S_NAME,
       ps.PS_SUPPLYCOST
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY  = s.S_SUPPKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY;

-- W3-S06-Q02  Filter: supplier nation + part size
SELECT l.L_ORDERKEY,
       p.P_NAME,
       s.S_NAME
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY  = s.S_SUPPKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
WHERE  s.S_NATIONKEY = 5
  AND  p.P_SIZE      > 10;

-- W3-S06-Q03  Revenue per supplier with part type breakdown
SELECT s.S_NAME,
       p.P_TYPE,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY  = s.S_SUPPKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
GROUP BY s.S_SUPPKEY, s.S_NAME, p.P_TYPE
ORDER BY s.S_NAME, revenue DESC;

-- W3-S06-Q04  Profit margin per supplier
SELECT s.S_SUPPKEY,
       s.S_NAME,
       SUM(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) AS total_margin
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY  = s.S_SUPPKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
GROUP BY s.S_SUPPKEY, s.S_NAME
ORDER BY total_margin DESC
LIMIT  15;

-- W3-S06-Q05  Filter: high supply cost + discount + quantity
SELECT l.L_ORDERKEY,
       p.P_NAME,
       s.S_NAME,
       l.L_QUANTITY
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY  = s.S_SUPPKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
WHERE  ps.PS_SUPPLYCOST > 500
  AND  l.L_DISCOUNT     > 0.04
  AND  l.L_QUANTITY     > 20;

-- W3-S06-Q06  Average supply cost per part brand per supplier nation
SELECT p.P_BRAND,
       s.S_NATIONKEY,
       AVG(ps.PS_SUPPLYCOST) AS avg_cost
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY  = s.S_SUPPKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
GROUP BY p.P_BRAND, s.S_NATIONKEY
ORDER BY p.P_BRAND, s.S_NATIONKEY;

-- W3-S06-Q07  HAVING: suppliers with avg margin above threshold
SELECT s.S_SUPPKEY,
       s.S_NAME,
       AVG(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) AS avg_margin
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY  = s.S_SUPPKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
GROUP BY s.S_SUPPKEY, s.S_NAME
HAVING AVG(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) > 800;

-- W3-S06-Q08  Top 20 part-supplier combinations by revenue
SELECT p.P_NAME,
       s.S_NAME,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY  = s.S_SUPPKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
GROUP BY p.P_PARTKEY, p.P_NAME, s.S_SUPPKEY, s.S_NAME
ORDER BY revenue DESC
LIMIT  20;

-- W3-S06-Q09  Ship date filter + distinct supplier-part combos
SELECT DISTINCT p.P_BRAND,
       s.S_NATIONKEY
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY  = s.S_SUPPKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
WHERE  l.L_SHIPDATE > '1997-01-01'
ORDER BY p.P_BRAND;

-- W3-S06-Q10  Count orders per part brand per supplier nation, date-filtered
SELECT p.P_BRAND,
       s.S_NATIONKEY,
       COUNT(DISTINCT l.L_ORDERKEY) AS order_count
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY  = s.S_SUPPKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY  = ps.PS_PARTKEY
                  AND l.L_SUPPKEY  = ps.PS_SUPPKEY
WHERE  l.L_SHIPDATE BETWEEN '1994-01-01' AND '1998-12-31'
GROUP BY p.P_BRAND, s.S_NATIONKEY;


-- =============================================================================
-- SECTION 07: ORDERS + CUSTOMER + LINEITEM  (3-table)
-- Join keys : O_CUSTKEY=C_CUSTKEY, O_ORDERKEY=L_ORDERKEY
-- Coverage  : Customer-to-line-item resolution; combined filters on all dims
-- =============================================================================

-- W3-S07-Q01  Full 3-table join
SELECT o.O_ORDERKEY,
       c.C_NAME,
       l.L_QUANTITY
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY;

-- W3-S07-Q02  Filter: high balance customer + high quantity
SELECT o.O_ORDERKEY,
       c.C_NAME,
       l.L_QUANTITY
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  c.C_ACCTBAL  > 5000
  AND  l.L_QUANTITY > 30;

-- W3-S07-Q03  Filter: nation + discount + date
SELECT o.O_ORDERKEY,
       c.C_NAME,
       l.L_DISCOUNT
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  c.C_NATIONKEY  = 10
  AND  l.L_DISCOUNT   > 0.05
  AND  o.O_ORDERDATE  > '1995-01-01';

-- W3-S07-Q04  Total spend per customer
SELECT c.C_CUSTKEY,
       c.C_NAME,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS total_spend
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY c.C_CUSTKEY, c.C_NAME
ORDER BY total_spend DESC;

-- W3-S07-Q05  Top 15 customers by total spend
SELECT c.C_CUSTKEY,
       c.C_NAME,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS total_spend
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY c.C_CUSTKEY, c.C_NAME
ORDER BY total_spend DESC
LIMIT  15;

-- W3-S07-Q06  Average line quantity per customer nation
SELECT c.C_NATIONKEY,
       AVG(l.L_QUANTITY)    AS avg_quantity
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY c.C_NATIONKEY
ORDER BY avg_quantity DESC;

-- W3-S07-Q07  HAVING: customers with more than 50 total line items
SELECT c.C_CUSTKEY,
       c.C_NAME,
       COUNT(l.L_LINENUMBER) AS total_lines
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY c.C_CUSTKEY, c.C_NAME
HAVING COUNT(l.L_LINENUMBER) > 50
ORDER BY total_lines DESC;

-- W3-S07-Q08  Revenue per year per customer nation
SELECT c.C_NATIONKEY,
       YEAR(o.O_ORDERDATE)  AS order_year,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY c.C_NATIONKEY, YEAR(o.O_ORDERDATE)
ORDER BY c.C_NATIONKEY, order_year;

-- W3-S07-Q09  High-discount lines for high-balance customers
SELECT o.O_ORDERKEY,
       c.C_NAME,
       l.L_DISCOUNT,
       l.L_EXTENDEDPRICE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  c.C_ACCTBAL > 7000
  AND  l.L_DISCOUNT > 0.07
ORDER BY l.L_DISCOUNT DESC
LIMIT  50;

-- W3-S07-Q10  Distinct nations of customers who received late shipments
SELECT DISTINCT c.C_NATIONKEY
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_RECEIPTDATE > l.L_COMMITDATE
ORDER BY c.C_NATIONKEY;


-- =============================================================================
-- SECTION 08: SUPPLIER + NATION + REGION  (3-table)
-- Join keys : S_NATIONKEY=N_NATIONKEY, N_REGIONKEY=R_REGIONKEY
-- Coverage  : Geographic resolution of supplier data
-- =============================================================================

-- W3-S08-Q01  Full 3-table join
SELECT s.S_SUPPKEY,
       s.S_NAME,
       n.N_NAME        AS nation,
       r.R_NAME        AS region
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY;

-- W3-S08-Q02  Filter by region
SELECT s.S_SUPPKEY,
       s.S_NAME,
       n.N_NAME        AS nation
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  r.R_NAME = 'EUROPE';

-- W3-S08-Q03  Filter by nation + balance
SELECT s.S_SUPPKEY,
       s.S_NAME,
       s.S_ACCTBAL
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  n.N_NAME    = 'GERMANY'
  AND  s.S_ACCTBAL > 4000;

-- W3-S08-Q04  Count suppliers per region
SELECT r.R_NAME        AS region,
       COUNT(s.S_SUPPKEY) AS supplier_count
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY r.R_NAME
ORDER BY supplier_count DESC;

-- W3-S08-Q05  Average balance per nation
SELECT n.N_NAME        AS nation,
       AVG(s.S_ACCTBAL) AS avg_balance,
       COUNT(s.S_SUPPKEY) AS supplier_count
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY n.N_NATIONKEY, n.N_NAME
ORDER BY avg_balance DESC;

-- W3-S08-Q06  Max balance per region
SELECT r.R_NAME        AS region,
       MAX(s.S_ACCTBAL) AS max_balance
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY r.R_NAME;

-- W3-S08-Q07  Top 10 suppliers globally by account balance
SELECT s.S_NAME,
       n.N_NAME        AS nation,
       r.R_NAME        AS region,
       s.S_ACCTBAL
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
ORDER BY s.S_ACCTBAL DESC
LIMIT  10;

-- W3-S08-Q08  HAVING: nations with more than 10 suppliers
SELECT n.N_NAME        AS nation,
       COUNT(s.S_SUPPKEY) AS supplier_count
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY n.N_NATIONKEY, n.N_NAME
HAVING COUNT(s.S_SUPPKEY) > 10
ORDER BY supplier_count DESC;

-- W3-S08-Q09  Distinct regions of high-balance suppliers
SELECT DISTINCT r.R_NAME   AS region
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  s.S_ACCTBAL > 9000;

-- W3-S08-Q10  Balance range filter + region
SELECT s.S_NAME,
       n.N_NAME        AS nation,
       s.S_ACCTBAL
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  r.R_NAME    = 'ASIA'
  AND  s.S_ACCTBAL BETWEEN 2000 AND 8000
ORDER BY s.S_ACCTBAL DESC;


-- =============================================================================
-- SECTION 09: CUSTOMER + NATION + REGION  (3-table)
-- Join keys : C_NATIONKEY=N_NATIONKEY, N_REGIONKEY=R_REGIONKEY
-- Coverage  : Geographic resolution of customer data
-- =============================================================================

-- W3-S09-Q01  Full 3-table join
SELECT c.C_CUSTKEY,
       c.C_NAME,
       n.N_NAME        AS nation,
       r.R_NAME        AS region
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY;

-- W3-S09-Q02  Filter by region
SELECT c.C_CUSTKEY,
       c.C_NAME,
       n.N_NAME        AS nation
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  r.R_NAME = 'MIDDLE EAST';

-- W3-S09-Q03  Filter by region + high balance
SELECT c.C_CUSTKEY,
       c.C_NAME,
       c.C_ACCTBAL
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  r.R_NAME    = 'AMERICA'
  AND  c.C_ACCTBAL > 6000;

-- W3-S09-Q04  Count customers per region
SELECT r.R_NAME        AS region,
       COUNT(c.C_CUSTKEY) AS customer_count
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY r.R_NAME
ORDER BY customer_count DESC;

-- W3-S09-Q05  Average balance per nation
SELECT n.N_NAME        AS nation,
       AVG(c.C_ACCTBAL) AS avg_balance
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY n.N_NATIONKEY, n.N_NAME
ORDER BY avg_balance DESC;

-- W3-S09-Q06  Total customer balance per region
SELECT r.R_NAME        AS region,
       SUM(c.C_ACCTBAL) AS total_balance,
       COUNT(c.C_CUSTKEY) AS customer_count
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY r.R_NAME;

-- W3-S09-Q07  Top 20 customers globally by account balance
SELECT c.C_NAME,
       n.N_NAME        AS nation,
       r.R_NAME        AS region,
       c.C_ACCTBAL
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
ORDER BY c.C_ACCTBAL DESC
LIMIT  20;

-- W3-S09-Q08  HAVING: nations with avg balance above threshold
SELECT n.N_NAME        AS nation,
       AVG(c.C_ACCTBAL) AS avg_balance
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY n.N_NATIONKEY, n.N_NAME
HAVING AVG(c.C_ACCTBAL) > 4000;

-- W3-S09-Q09  Count of high-balance customers per region
SELECT r.R_NAME        AS region,
       COUNT(c.C_CUSTKEY) AS high_balance_count
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  c.C_ACCTBAL > 5000
GROUP BY r.R_NAME
ORDER BY high_balance_count DESC;

-- W3-S09-Q10  Distinct regions with customers in a nation set
SELECT DISTINCT r.R_NAME   AS region,
       n.N_NAME             AS nation
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  n.N_NAME IN ('GERMANY', 'FRANCE', 'UNITED KINGDOM')
ORDER BY r.R_NAME;


-- =============================================================================
-- SECTION 10: ORDERS + CUSTOMER + LINEITEM + PART  (4-table)
-- Join keys : O_CUSTKEY=C_CUSTKEY, O_ORDERKEY=L_ORDERKEY, L_PARTKEY=P_PARTKEY
-- Coverage  : Full customer-order-line-part chain; rich filter and aggregate mix
-- =============================================================================

-- W3-S10-Q01  Full 4-table join
SELECT o.O_ORDERKEY,
       c.C_NAME,
       p.P_NAME,
       l.L_QUANTITY
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY;

-- W3-S10-Q02  Filter: nation + part type + date
SELECT o.O_ORDERKEY,
       c.C_NAME,
       p.P_TYPE,
       l.L_QUANTITY
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
WHERE  c.C_NATIONKEY  = 5
  AND  p.P_TYPE       LIKE 'ECONOMY%'
  AND  o.O_ORDERDATE  > '1995-01-01';

-- W3-S10-Q03  Revenue per customer per part brand
SELECT c.C_CUSTKEY,
       c.C_NAME,
       p.P_BRAND,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY c.C_CUSTKEY, c.C_NAME, p.P_BRAND
ORDER BY revenue DESC
LIMIT  20;

-- W3-S10-Q04  Total spend per nation per part type
SELECT c.C_NATIONKEY,
       p.P_TYPE,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY c.C_NATIONKEY, p.P_TYPE
ORDER BY c.C_NATIONKEY, revenue DESC;

-- W3-S10-Q05  Most popular part brands per nation (by quantity)
SELECT c.C_NATIONKEY,
       p.P_BRAND,
       SUM(l.L_QUANTITY)    AS total_qty
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY c.C_NATIONKEY, p.P_BRAND
ORDER BY c.C_NATIONKEY, total_qty DESC;

-- W3-S10-Q06  HAVING: brand-nation combos with revenue above threshold
SELECT c.C_NATIONKEY,
       p.P_BRAND,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY c.C_NATIONKEY, p.P_BRAND
HAVING SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) > 1000000;

-- W3-S10-Q07  Filter: high-balance customer + large part + high discount
SELECT o.O_ORDERKEY,
       c.C_NAME,
       p.P_NAME,
       l.L_DISCOUNT
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
WHERE  c.C_ACCTBAL > 6000
  AND  p.P_SIZE    > 25
  AND  l.L_DISCOUNT > 0.06
ORDER BY l.L_DISCOUNT DESC;

-- W3-S10-Q08  Distinct part types ordered by nation
SELECT DISTINCT c.C_NATIONKEY,
       p.P_TYPE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
ORDER BY c.C_NATIONKEY, p.P_TYPE;

-- W3-S10-Q09  Revenue per year per part brand
SELECT YEAR(o.O_ORDERDATE) AS order_year,
       p.P_BRAND,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY YEAR(o.O_ORDERDATE), p.P_BRAND
ORDER BY order_year, revenue DESC;

-- W3-S10-Q10  Top 10 orders by net revenue (extended price net of discount)
SELECT o.O_ORDERKEY,
       c.C_NAME,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS net_revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY o.O_ORDERKEY, c.C_NAME
ORDER BY net_revenue DESC
LIMIT  10;


-- =============================================================================
-- SECTION 11: FIVE-TABLE JOINS
-- Coverage  : Combines 5 TPC-H tables; tests deep join chain planning and
--             index selection across long join paths
-- =============================================================================

-- W3-S11-Q01  [O+C+N+R+L] Orders with full geo context and line count
SELECT r.R_NAME        AS region,
       n.N_NAME        AS nation,
       c.C_NAME,
       o.O_ORDERKEY,
       COUNT(l.L_LINENUMBER) AS line_count
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
JOIN   LINEITEM l ON o.O_ORDERKEY   = l.L_ORDERKEY
GROUP BY r.R_NAME, n.N_NAME, c.C_CUSTKEY, c.C_NAME, o.O_ORDERKEY;

-- W3-S11-Q02  [O+C+N+R+L] Revenue per region with date filter
SELECT r.R_NAME        AS region,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
JOIN   LINEITEM l ON o.O_ORDERKEY   = l.L_ORDERKEY
WHERE  o.O_ORDERDATE BETWEEN '1995-01-01' AND '1996-12-31'
GROUP BY r.R_NAME
ORDER BY revenue DESC;

-- W3-S11-Q03  [O+L+P+S+N(supplier)] Revenue per supplier nation per part brand
SELECT n.N_NAME        AS supplier_nation,
       p.P_BRAND,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY  = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
GROUP BY n.N_NAME, p.P_BRAND
ORDER BY n.N_NAME, revenue DESC;

-- W3-S11-Q04  [O+L+P+S+N] Filter: EUROPE suppliers + large parts + date
SELECT o.O_ORDERKEY,
       p.P_NAME,
       s.S_NAME,
       n.N_NAME        AS supplier_nation,
       l.L_EXTENDEDPRICE
FROM   ORDERS   o
JOIN   LINEITEM l ON o.O_ORDERKEY  = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
WHERE  n.N_NAME         IN ('GERMANY', 'FRANCE')
  AND  p.P_SIZE         > 20
  AND  l.L_SHIPDATE     > '1996-01-01';

-- W3-S11-Q05  [O+C+L+P+PS] Order-line-part-supply chain with margin
SELECT o.O_ORDERKEY,
       c.C_NAME,
       p.P_NAME,
       l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST AS margin
FROM   ORDERS   o
JOIN   CUSTOMER c  ON o.O_CUSTKEY   = c.C_CUSTKEY
JOIN   LINEITEM l  ON o.O_ORDERKEY  = l.L_ORDERKEY
JOIN   PART     p  ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY   = ps.PS_PARTKEY
                  AND l.L_SUPPKEY   = ps.PS_SUPPKEY
ORDER BY margin DESC
LIMIT  25;

-- W3-S11-Q06  [O+C+L+P+PS] Total margin per customer
SELECT c.C_CUSTKEY,
       c.C_NAME,
       SUM(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) AS total_margin
FROM   ORDERS   o
JOIN   CUSTOMER c  ON o.O_CUSTKEY   = c.C_CUSTKEY
JOIN   LINEITEM l  ON o.O_ORDERKEY  = l.L_ORDERKEY
JOIN   PART     p  ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   PARTSUPP ps ON l.L_PARTKEY   = ps.PS_PARTKEY
                  AND l.L_SUPPKEY   = ps.PS_SUPPKEY
GROUP BY c.C_CUSTKEY, c.C_NAME
ORDER BY total_margin DESC
LIMIT  20;

-- W3-S11-Q07  [O+C+N+L+P] Revenue per nation per part type, date-filtered
SELECT n.N_NAME        AS nation,
       p.P_TYPE,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   LINEITEM l ON o.O_ORDERKEY   = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY    = p.P_PARTKEY
WHERE  o.O_ORDERDATE BETWEEN '1994-01-01' AND '1997-12-31'
GROUP BY n.N_NAME, p.P_TYPE;

-- W3-S11-Q08  [O+C+N+L+S] Cross-nation trade: customer nation vs supplier nation
SELECT cn.N_NAME       AS cust_nation,
       sn.N_NAME       AS supp_nation,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY   = c.C_CUSTKEY
JOIN   NATION    cn ON c.C_NATIONKEY = cn.N_NATIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY  = l.L_ORDERKEY
JOIN   SUPPLIER  s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION    sn ON s.S_NATIONKEY = sn.N_NATIONKEY
WHERE  o.O_ORDERDATE BETWEEN '1995-01-01' AND '1996-12-31'
GROUP BY cn.N_NAME, sn.N_NAME
ORDER BY revenue DESC;

-- W3-S11-Q09  [O+C+N+L+S] Same-nation trades only
SELECT cn.N_NAME       AS nation,
       COUNT(DISTINCT o.O_ORDERKEY) AS order_count,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY   = c.C_CUSTKEY
JOIN   NATION    cn ON c.C_NATIONKEY = cn.N_NATIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY  = l.L_ORDERKEY
JOIN   SUPPLIER  s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION    sn ON s.S_NATIONKEY = sn.N_NATIONKEY
WHERE  cn.N_NATIONKEY = sn.N_NATIONKEY
GROUP BY cn.N_NAME
ORDER BY revenue DESC;

-- W3-S11-Q10  [O+C+N+L+P] HAVING: nations with high total revenue from large parts
SELECT n.N_NAME        AS nation,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   LINEITEM l ON o.O_ORDERKEY   = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY    = p.P_PARTKEY
WHERE  p.P_SIZE > 20
GROUP BY n.N_NAME
HAVING SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) > 5000000
ORDER BY revenue DESC;

-- W3-S12-Q01  [O+C+N+L+P+S] Full supply chain with customer geo
SELECT o.O_ORDERKEY,
       c.C_NAME,
       cn.N_NAME       AS cust_nation,
       p.P_NAME,
       s.S_NAME,
       l.L_EXTENDEDPRICE
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY   = c.C_CUSTKEY
JOIN   NATION    cn ON c.C_NATIONKEY = cn.N_NATIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY  = l.L_ORDERKEY
JOIN   PART      p  ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   SUPPLIER  s  ON l.L_SUPPKEY   = s.S_SUPPKEY
LIMIT  100;

-- W3-S12-Q02  [O+C+N+L+P+S] Revenue with full context, date-filtered
SELECT cn.N_NAME       AS cust_nation,
       p.P_BRAND,
       s.S_NAME,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY   = c.C_CUSTKEY
JOIN   NATION    cn ON c.C_NATIONKEY = cn.N_NATIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY  = l.L_ORDERKEY
JOIN   PART      p  ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   SUPPLIER  s  ON l.L_SUPPKEY   = s.S_SUPPKEY
WHERE  o.O_ORDERDATE BETWEEN '1995-01-01' AND '1996-12-31'
GROUP BY cn.N_NAME, p.P_BRAND, s.S_SUPPKEY, s.S_NAME
ORDER BY revenue DESC
LIMIT  20;

-- W3-S12-Q03  [O+C+N+R+L+P] Revenue per region per part type
SELECT r.R_NAME        AS region,
       p.P_TYPE,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY  = r.R_REGIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY   = l.L_ORDERKEY
JOIN   PART      p  ON l.L_PARTKEY    = p.P_PARTKEY
GROUP BY r.R_NAME, p.P_TYPE
ORDER BY r.R_NAME, revenue DESC;

-- W3-S12-Q04  [O+C+N+R+L+S] Revenue per region comparing cust vs supp side
SELECT r.R_NAME        AS customer_region,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue,
       AVG(s.S_ACCTBAL)                              AS avg_supplier_balance
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY  = r.R_REGIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY   = l.L_ORDERKEY
JOIN   SUPPLIER  s  ON l.L_SUPPKEY    = s.S_SUPPKEY
GROUP BY r.R_NAME
ORDER BY revenue DESC;

-- W3-S12-Q05  [O+C+N+L+P+PS] Margin analysis with full customer context
SELECT cn.N_NAME       AS cust_nation,
       p.P_BRAND,
       SUM(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) AS total_margin
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    cn ON c.C_NATIONKEY  = cn.N_NATIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY   = l.L_ORDERKEY
JOIN   PART      p  ON l.L_PARTKEY    = p.P_PARTKEY
JOIN   PARTSUPP  ps ON l.L_PARTKEY    = ps.PS_PARTKEY
                   AND l.L_SUPPKEY    = ps.PS_SUPPKEY
GROUP BY cn.N_NAME, p.P_BRAND
ORDER BY total_margin DESC;

-- W3-S12-Q06  [O+C+N+R+L+P] Top 5 part brands per region
SELECT r.R_NAME        AS region,
       p.P_BRAND,
       SUM(l.L_QUANTITY) AS total_qty
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY  = r.R_REGIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY   = l.L_ORDERKEY
JOIN   PART      p  ON l.L_PARTKEY    = p.P_PARTKEY
GROUP BY r.R_NAME, p.P_BRAND
ORDER BY r.R_NAME, total_qty DESC;

-- W3-S12-Q07  [O+C+N+L+P+S] HAVING: cust-nation with revenue above threshold
SELECT cn.N_NAME       AS cust_nation,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY   = c.C_CUSTKEY
JOIN   NATION    cn ON c.C_NATIONKEY = cn.N_NATIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY  = l.L_ORDERKEY
JOIN   PART      p  ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   SUPPLIER  s  ON l.L_SUPPKEY   = s.S_SUPPKEY
GROUP BY cn.N_NAME
HAVING SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) > 10000000
ORDER BY revenue DESC;

-- W3-S12-Q08  [O+C+N+R+L+P] Count distinct customers per region per part brand
SELECT r.R_NAME        AS region,
       p.P_BRAND,
       COUNT(DISTINCT c.C_CUSTKEY) AS cust_count
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY  = r.R_REGIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY   = l.L_ORDERKEY
JOIN   PART      p  ON l.L_PARTKEY    = p.P_PARTKEY
GROUP BY r.R_NAME, p.P_BRAND
ORDER BY r.R_NAME, cust_count DESC;

-- W3-S12-Q09  [O+C+N+L+P+S] Average order value per cust nation per supp nation
SELECT cn.N_NAME       AS cust_nation,
       sn.N_NAME       AS supp_nation,
       AVG(o.O_TOTALPRICE) AS avg_order_value
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY   = c.C_CUSTKEY
JOIN   NATION    cn ON c.C_NATIONKEY = cn.N_NATIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY  = l.L_ORDERKEY
JOIN   SUPPLIER  s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION    sn ON s.S_NATIONKEY = sn.N_NATIONKEY
GROUP BY cn.N_NAME, sn.N_NAME
ORDER BY cn.N_NAME, avg_order_value DESC;

-- W3-S12-Q10  [O+C+N+R+L+P] Monthly revenue per region
SELECT r.R_NAME                 AS region,
       YEAR(o.O_ORDERDATE)      AS yr,
       MONTH(o.O_ORDERDATE)     AS mo,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY  = r.R_REGIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY   = l.L_ORDERKEY
JOIN   PART      p  ON l.L_PARTKEY    = p.P_PARTKEY
WHERE  o.O_ORDERDATE BETWEEN '1995-01-01' AND '1996-12-31'
GROUP BY r.R_NAME, YEAR(o.O_ORDERDATE), MONTH(o.O_ORDERDATE)
ORDER BY r.R_NAME, yr, mo;


-- =============================================================================
-- SECTION 13: AGGREGATE-FOCUSED MULTI-TABLE JOINS
-- Coverage  : COUNT/SUM/AVG/MAX/MIN across 3-6 table joins; rich aggregation
-- =============================================================================

-- W3-S13-Q01  Order count and revenue per customer market segment and nation
SELECT c.C_MKTSEGMENT,
       c.C_NATIONKEY,
       COUNT(o.O_ORDERKEY)   AS order_count,
       SUM(o.O_TOTALPRICE)   AS total_revenue
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
GROUP BY c.C_MKTSEGMENT, c.C_NATIONKEY
ORDER BY c.C_MKTSEGMENT, total_revenue DESC;

-- W3-S13-Q02  Max and min line extended price per part brand per supplier nation
SELECT p.P_BRAND,
       n.N_NAME        AS supplier_nation,
       MAX(l.L_EXTENDEDPRICE) AS max_price,
       MIN(l.L_EXTENDEDPRICE) AS min_price
FROM   LINEITEM l
JOIN   PART     p ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   SUPPLIER s ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
GROUP BY p.P_BRAND, n.N_NAME
ORDER BY p.P_BRAND;

-- W3-S13-Q03  Total net revenue per market segment
SELECT c.C_MKTSEGMENT,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS net_revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY c.C_MKTSEGMENT
ORDER BY net_revenue DESC;

-- W3-S13-Q04  Avg discount per part size bucket per supplier region
SELECT p.P_SIZE,
       r.R_NAME        AS supplier_region,
       AVG(l.L_DISCOUNT) AS avg_discount
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r  ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY p.P_SIZE, r.R_NAME
ORDER BY p.P_SIZE, avg_discount DESC;

-- W3-S13-Q05  Sum of available stock value per supplier region
SELECT r.R_NAME        AS region,
       SUM(ps.PS_AVAILQTY * ps.PS_SUPPLYCOST) AS stock_value
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY   = ps.PS_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r  ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY r.R_NAME
ORDER BY stock_value DESC;

-- W3-S13-Q06  Revenue per ship mode per part type (3-table)
SELECT l.L_SHIPMODE,
       p.P_TYPE,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS  o
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART    p  ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY l.L_SHIPMODE, p.P_TYPE
ORDER BY l.L_SHIPMODE, revenue DESC;

-- W3-S13-Q07  Count orders per market segment per year
SELECT c.C_MKTSEGMENT,
       YEAR(o.O_ORDERDATE) AS order_year,
       COUNT(o.O_ORDERKEY)  AS order_count
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY = o.O_CUSTKEY
GROUP BY c.C_MKTSEGMENT, YEAR(o.O_ORDERDATE)
ORDER BY c.C_MKTSEGMENT, order_year;

-- W3-S13-Q08  Total quantity per part container per supplier nation
SELECT p.P_CONTAINER,
       n.N_NAME        AS nation,
       SUM(l.L_QUANTITY) AS total_qty
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
GROUP BY p.P_CONTAINER, n.N_NAME
ORDER BY total_qty DESC;

-- W3-S13-Q09  Max order total per customer market segment and nation
SELECT c.C_MKTSEGMENT,
       n.N_NAME        AS nation,
       MAX(o.O_TOTALPRICE) AS max_order
FROM   CUSTOMER c
JOIN   ORDERS   o ON c.C_CUSTKEY   = o.O_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
GROUP BY c.C_MKTSEGMENT, n.N_NAME;

-- W3-S13-Q10  Average supply cost per part container per region
SELECT p.P_CONTAINER,
       r.R_NAME        AS region,
       AVG(ps.PS_SUPPLYCOST) AS avg_cost
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY   = ps.PS_PARTKEY
JOIN   SUPPLIER s  ON ps.PS_SUPPKEY = s.S_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r  ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY p.P_CONTAINER, r.R_NAME
ORDER BY p.P_CONTAINER;

-- W3-S13-Q11  Revenue per month per market segment
SELECT c.C_MKTSEGMENT,
       YEAR(o.O_ORDERDATE)   AS yr,
       MONTH(o.O_ORDERDATE)  AS mo,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY c.C_MKTSEGMENT, YEAR(o.O_ORDERDATE), MONTH(o.O_ORDERDATE)
ORDER BY c.C_MKTSEGMENT, yr, mo;

-- W3-S13-Q12  Quantity spread (max-min) per part brand per year
SELECT p.P_BRAND,
       YEAR(l.L_SHIPDATE)    AS ship_year,
       MAX(l.L_QUANTITY) - MIN(l.L_QUANTITY) AS qty_spread
FROM   LINEITEM l
JOIN   PART     p ON l.L_PARTKEY = p.P_PARTKEY
JOIN   ORDERS   o ON l.L_ORDERKEY = o.O_ORDERKEY
GROUP BY p.P_BRAND, YEAR(l.L_SHIPDATE)
ORDER BY p.P_BRAND, ship_year;

-- W3-S13-Q13  Count distinct customers per part type
SELECT p.P_TYPE,
       COUNT(DISTINCT c.C_CUSTKEY) AS customer_count
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
GROUP BY p.P_TYPE
ORDER BY customer_count DESC;

-- W3-S13-Q14  Total stock value per part brand per region
SELECT p.P_BRAND,
       r.R_NAME        AS region,
       SUM(ps.PS_AVAILQTY * ps.PS_SUPPLYCOST) AS stock_value
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY   = ps.PS_PARTKEY
JOIN   SUPPLIER s  ON ps.PS_SUPPKEY = s.S_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r  ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY p.P_BRAND, r.R_NAME
ORDER BY p.P_BRAND, stock_value DESC;

-- W3-S13-Q15  Revenue per order status per customer region
SELECT r.R_NAME        AS region,
       o.O_ORDERSTATUS  AS status,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY  = r.R_REGIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY   = l.L_ORDERKEY
GROUP BY r.R_NAME, o.O_ORDERSTATUS
ORDER BY r.R_NAME, revenue DESC;


-- =============================================================================
-- SECTION 14: HAVING-FOCUSED MULTI-TABLE JOINS
-- Coverage  : Post-aggregation filters across 3-5 table joins on all join pairs
-- =============================================================================

-- W3-S14-Q01  Nations with total revenue exceeding 1 billion
SELECT n.N_NAME        AS nation,
       SUM(o.O_TOTALPRICE)   AS total_revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
GROUP BY n.N_NAME
HAVING SUM(o.O_TOTALPRICE) > 1000000000
ORDER BY total_revenue DESC;

-- W3-S14-Q02  Suppliers with more than 5000 distinct part offerings
SELECT s.S_SUPPKEY,
       s.S_NAME,
       COUNT(ps.PS_PARTKEY) AS part_count
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY   = ps.PS_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
GROUP BY s.S_SUPPKEY, s.S_NAME
HAVING COUNT(ps.PS_PARTKEY) > 5
ORDER BY part_count DESC;

-- W3-S14-Q03  Part brands with avg line revenue above threshold
SELECT p.P_BRAND,
       AVG(l.L_EXTENDEDPRICE) AS avg_line_revenue
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   ORDERS   o  ON l.L_ORDERKEY = o.O_ORDERKEY
GROUP BY p.P_BRAND
HAVING AVG(l.L_EXTENDEDPRICE) > 30000
ORDER BY avg_line_revenue DESC;

-- W3-S14-Q04  Regions with more than 200,000 customers
SELECT r.R_NAME        AS region,
       COUNT(c.C_CUSTKEY) AS customer_count
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY r.R_NAME
HAVING COUNT(c.C_CUSTKEY) > 200000;

-- W3-S14-Q05  Part types with more than 100,000 total lines shipped
SELECT p.P_TYPE,
       COUNT(l.L_LINENUMBER) AS line_count
FROM   LINEITEM l
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   ORDERS   o ON l.L_ORDERKEY = o.O_ORDERKEY
GROUP BY p.P_TYPE
HAVING COUNT(l.L_LINENUMBER) > 100000
ORDER BY line_count DESC;

-- W3-S14-Q06  Customer market segments with avg balance above threshold
SELECT c.C_MKTSEGMENT,
       n.N_NAME        AS nation,
       AVG(c.C_ACCTBAL) AS avg_balance
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   ORDERS   o ON c.C_CUSTKEY   = o.O_CUSTKEY
GROUP BY c.C_MKTSEGMENT, n.N_NATIONKEY, n.N_NAME
HAVING AVG(c.C_ACCTBAL) > 5000
ORDER BY avg_balance DESC;

-- W3-S14-Q07  Supplier nations with total available stock above threshold
SELECT n.N_NAME        AS nation,
       SUM(ps.PS_AVAILQTY) AS total_stock
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY   = ps.PS_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
GROUP BY n.N_NATIONKEY, n.N_NAME
HAVING SUM(ps.PS_AVAILQTY) > 500000
ORDER BY total_stock DESC;

-- W3-S14-Q08  Part containers with avg supply cost below threshold (budget parts)
SELECT p.P_CONTAINER,
       AVG(ps.PS_SUPPLYCOST) AS avg_cost,
       COUNT(DISTINCT p.P_PARTKEY) AS part_count
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY   = ps.PS_PARTKEY
JOIN   SUPPLIER s  ON ps.PS_SUPPKEY = s.S_SUPPKEY
GROUP BY p.P_CONTAINER
HAVING AVG(ps.PS_SUPPLYCOST) < 300
ORDER BY avg_cost ASC;

-- W3-S14-Q09  Ship modes with avg quantity above threshold and date filter
SELECT l.L_SHIPMODE,
       AVG(l.L_QUANTITY)    AS avg_qty,
       COUNT(l.L_LINENUMBER) AS line_count
FROM   LINEITEM l
JOIN   ORDERS   o ON l.L_ORDERKEY = o.O_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
WHERE  l.L_SHIPDATE > '1996-01-01'
GROUP BY l.L_SHIPMODE
HAVING AVG(l.L_QUANTITY) > 25
ORDER BY avg_qty DESC;

-- W3-S14-Q10  Nations with more customers than average customer count per nation
SELECT n.N_NAME        AS nation,
       COUNT(c.C_CUSTKEY) AS customer_count
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY n.N_NATIONKEY, n.N_NAME
HAVING COUNT(c.C_CUSTKEY) > (
    SELECT AVG(cnt) FROM (
        SELECT COUNT(C_CUSTKEY) AS cnt
        FROM   CUSTOMER
        GROUP BY C_NATIONKEY
    ) t
)
ORDER BY customer_count DESC;


-- =============================================================================
-- SECTION 15: ORDER BY + LIMIT MULTI-TABLE (TOP-N)
-- Coverage  : Ranked/paginated result patterns across varying join depths
-- =============================================================================

-- W3-S15-Q01  Top 10 orders by revenue with full geo context
SELECT o.O_ORDERKEY,
       c.C_NAME,
       n.N_NAME        AS nation,
       r.R_NAME        AS region,
       o.O_TOTALPRICE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
ORDER BY o.O_TOTALPRICE DESC
LIMIT  10;

-- W3-S15-Q02  Top 20 supplier-part combinations by available stock value
SELECT s.S_NAME,
       p.P_NAME,
       ps.PS_AVAILQTY * ps.PS_SUPPLYCOST AS stock_value
FROM   SUPPLIER s
JOIN   PARTSUPP ps ON s.S_SUPPKEY  = ps.PS_SUPPKEY
JOIN   PART     p  ON ps.PS_PARTKEY = p.P_PARTKEY
ORDER BY stock_value DESC
LIMIT  20;

-- W3-S15-Q03  Top 15 nations by net revenue from line items
SELECT n.N_NAME        AS nation,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS net_revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   LINEITEM l ON o.O_ORDERKEY   = l.L_ORDERKEY
GROUP BY n.N_NAME
ORDER BY net_revenue DESC
LIMIT  15;

-- W3-S15-Q04  Top 25 customers by order count
SELECT c.C_CUSTKEY,
       c.C_NAME,
       n.N_NAME        AS nation,
       COUNT(o.O_ORDERKEY) AS order_count
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   ORDERS   o ON c.C_CUSTKEY   = o.O_CUSTKEY
GROUP BY c.C_CUSTKEY, c.C_NAME, n.N_NAME
ORDER BY order_count DESC
LIMIT  25;

-- W3-S15-Q05  Top 10 part brands by total revenue, EUROPE region
SELECT p.P_BRAND,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS    o
JOIN   LINEITEM  l  ON o.O_ORDERKEY   = l.L_ORDERKEY
JOIN   PART      p  ON l.L_PARTKEY    = p.P_PARTKEY
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY  = r.R_REGIONKEY
WHERE  r.R_NAME = 'EUROPE'
GROUP BY p.P_BRAND
ORDER BY revenue DESC
LIMIT  10;

-- W3-S15-Q06  Most recent 50 orders with customer and nation info
SELECT o.O_ORDERKEY,
       o.O_ORDERDATE,
       c.C_NAME,
       n.N_NAME        AS nation,
       o.O_TOTALPRICE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
ORDER BY o.O_ORDERDATE DESC
LIMIT  50;

-- W3-S15-Q07  Cheapest 15 part-supplier pairings in ASIA
SELECT p.P_NAME,
       s.S_NAME,
       n.N_NAME        AS nation,
       ps.PS_SUPPLYCOST
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY   = ps.PS_PARTKEY
JOIN   SUPPLIER s  ON ps.PS_SUPPKEY = s.S_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r  ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  r.R_NAME = 'ASIA'
ORDER BY ps.PS_SUPPLYCOST ASC
LIMIT  15;

-- W3-S15-Q08  Top 20 high-discount orders with full customer context
SELECT o.O_ORDERKEY,
       c.C_NAME,
       n.N_NAME        AS nation,
       AVG(l.L_DISCOUNT) AS avg_discount
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   LINEITEM l ON o.O_ORDERKEY   = l.L_ORDERKEY
GROUP BY o.O_ORDERKEY, c.C_NAME, n.N_NAME
ORDER BY avg_discount DESC
LIMIT  20;

-- W3-S15-Q09  Bottom 10 suppliers by average supply cost in AMERICA
SELECT s.S_NAME,
       n.N_NAME        AS nation,
       AVG(ps.PS_SUPPLYCOST) AS avg_cost
FROM   SUPPLIER s
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r  ON n.N_REGIONKEY = r.R_REGIONKEY
JOIN   PARTSUPP ps ON s.S_SUPPKEY   = ps.PS_SUPPKEY
WHERE  r.R_NAME = 'AMERICA'
GROUP BY s.S_SUPPKEY, s.S_NAME, n.N_NAME
ORDER BY avg_cost ASC
LIMIT  10;

-- W3-S15-Q10  Top 30 nation-year revenue combinations
SELECT n.N_NAME        AS nation,
       YEAR(o.O_ORDERDATE) AS order_year,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   LINEITEM l ON o.O_ORDERKEY   = l.L_ORDERKEY
GROUP BY n.N_NAME, YEAR(o.O_ORDERDATE)
ORDER BY revenue DESC
LIMIT  30;


-- =============================================================================
-- SECTION 16: EXISTS / IN SUBQUERIES OVER MULTI-TABLE JOINS
-- Coverage  : Semi-join and anti-join patterns using correlated subqueries
-- =============================================================================

-- W3-S16-Q01  Customers in EUROPE who have placed orders (EXISTS)
SELECT c.C_CUSTKEY,
       c.C_NAME,
       n.N_NAME        AS nation
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  r.R_NAME = 'EUROPE'
  AND  EXISTS (
           SELECT 1 FROM ORDERS o
           WHERE  o.O_CUSTKEY = c.C_CUSTKEY
       );

-- W3-S16-Q02  Customers with a high-value order in ASIA (EXISTS + price filter)
SELECT c.C_CUSTKEY,
       c.C_NAME,
       n.N_NAME        AS nation
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  r.R_NAME = 'ASIA'
  AND  EXISTS (
           SELECT 1 FROM ORDERS o
           WHERE  o.O_CUSTKEY    = c.C_CUSTKEY
             AND  o.O_TOTALPRICE > 150000
       );

-- W3-S16-Q03  Suppliers in EUROPE who supply large parts (EXISTS)
SELECT s.S_SUPPKEY,
       s.S_NAME,
       n.N_NAME        AS nation
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  r.R_NAME = 'EUROPE'
  AND  EXISTS (
           SELECT 1
           FROM   PARTSUPP ps
           JOIN   PART     p ON ps.PS_PARTKEY = p.P_PARTKEY
           WHERE  ps.PS_SUPPKEY = s.S_SUPPKEY
             AND  p.P_SIZE      > 30
       );

-- W3-S16-Q04  Orders shipped late (receipt after commit date) with customer context
SELECT o.O_ORDERKEY,
       c.C_NAME,
       n.N_NAME        AS nation
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
WHERE  EXISTS (
           SELECT 1 FROM LINEITEM l
           WHERE  l.L_ORDERKEY    = o.O_ORDERKEY
             AND  l.L_RECEIPTDATE > l.L_COMMITDATE
       );

-- W3-S16-Q05  Parts supplied only by high-balance suppliers (IN)
SELECT p.P_PARTKEY,
       p.P_NAME
FROM   PART p
WHERE  p.P_PARTKEY IN (
           SELECT ps.PS_PARTKEY
           FROM   PARTSUPP ps
           JOIN   SUPPLIER s ON ps.PS_SUPPKEY = s.S_SUPPKEY
           WHERE  s.S_ACCTBAL > 7000
       )
ORDER BY p.P_NAME;

-- W3-S16-Q06  Customers who never ordered (NOT EXISTS) with geo context
SELECT c.C_CUSTKEY,
       c.C_NAME,
       n.N_NAME        AS nation,
       r.R_NAME        AS region
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  NOT EXISTS (
           SELECT 1 FROM ORDERS o
           WHERE  o.O_CUSTKEY = c.C_CUSTKEY
       );

-- W3-S16-Q07  Orders containing parts from EUROPE suppliers (IN with join)
SELECT DISTINCT o.O_ORDERKEY,
       o.O_TOTALPRICE
FROM   ORDERS o
WHERE  o.O_ORDERKEY IN (
           SELECT l.L_ORDERKEY
           FROM   LINEITEM l
           JOIN   SUPPLIER s ON l.L_SUPPKEY   = s.S_SUPPKEY
           JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
           JOIN   REGION   r ON n.N_REGIONKEY = r.R_REGIONKEY
           WHERE  r.R_NAME = 'EUROPE'
       )
ORDER BY o.O_TOTALPRICE DESC
LIMIT  50;

-- W3-S16-Q08  Suppliers with no high-cost parts (NOT EXISTS anti-join)
SELECT s.S_SUPPKEY,
       s.S_NAME,
       n.N_NAME        AS nation
FROM   SUPPLIER s
JOIN   NATION   n ON s.S_NATIONKEY = n.N_NATIONKEY
WHERE  NOT EXISTS (
           SELECT 1
           FROM   PARTSUPP ps
           WHERE  ps.PS_SUPPKEY   = s.S_SUPPKEY
             AND  ps.PS_SUPPLYCOST > 900
       )
ORDER BY s.S_NAME;

-- W3-S16-Q09  Customers in nations where avg supplier balance is high (IN)
SELECT c.C_CUSTKEY,
       c.C_NAME,
       c.C_NATIONKEY
FROM   CUSTOMER c
WHERE  c.C_NATIONKEY IN (
           SELECT s.S_NATIONKEY
           FROM   SUPPLIER s
           GROUP BY s.S_NATIONKEY
           HAVING AVG(s.S_ACCTBAL) > 5000
       )
ORDER BY c.C_NATIONKEY, c.C_NAME;

-- W3-S16-Q10  Parts ordered by customers in AMERICA (IN with 4-table chain)
SELECT DISTINCT p.P_PARTKEY,
       p.P_NAME,
       p.P_BRAND
FROM   PART p
WHERE  p.P_PARTKEY IN (
           SELECT l.L_PARTKEY
           FROM   LINEITEM  l
           JOIN   ORDERS    o  ON l.L_ORDERKEY  = o.O_ORDERKEY
           JOIN   CUSTOMER  c  ON o.O_CUSTKEY   = c.C_CUSTKEY
           JOIN   NATION    n  ON c.C_NATIONKEY = n.N_NATIONKEY
           JOIN   REGION    r  ON n.N_REGIONKEY = r.R_REGIONKEY
           WHERE  r.R_NAME = 'AMERICA'
       )
ORDER BY p.P_BRAND, p.P_NAME;


-- =============================================================================
-- SECTION 17: DISTINCT MULTI-TABLE JOINS
-- Coverage  : SELECT DISTINCT across 3-5 table joins; index-assisted dedup
-- =============================================================================

-- W3-S17-Q01  Distinct nations that have customers with orders
SELECT DISTINCT n.N_NAME   AS nation
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   ORDERS   o ON c.C_CUSTKEY   = o.O_CUSTKEY
ORDER BY n.N_NAME;

-- W3-S17-Q02  Distinct regions with high-value orders
SELECT DISTINCT r.R_NAME   AS region
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
WHERE  o.O_TOTALPRICE > 200000;

-- W3-S17-Q03  Distinct part brands appearing in ASIA orders
SELECT DISTINCT p.P_BRAND
FROM   LINEITEM  l
JOIN   ORDERS    o  ON l.L_ORDERKEY   = o.O_ORDERKEY
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY  = r.R_REGIONKEY
JOIN   PART      p  ON l.L_PARTKEY    = p.P_PARTKEY
WHERE  r.R_NAME = 'ASIA'
ORDER BY p.P_BRAND;

-- W3-S17-Q04  Distinct supplier-nation pairs that handled high-value orders
SELECT DISTINCT sn.N_NAME  AS supplier_nation,
       cn.N_NAME            AS customer_nation
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY   = c.C_CUSTKEY
JOIN   NATION    cn ON c.C_NATIONKEY = cn.N_NATIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY  = l.L_ORDERKEY
JOIN   SUPPLIER  s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION    sn ON s.S_NATIONKEY = sn.N_NATIONKEY
WHERE  o.O_TOTALPRICE > 100000
ORDER BY sn.N_NAME, cn.N_NAME;

-- W3-S17-Q05  Distinct part containers in orders from MIDDLE EAST customers
SELECT DISTINCT p.P_CONTAINER
FROM   LINEITEM  l
JOIN   ORDERS    o  ON l.L_ORDERKEY   = o.O_ORDERKEY
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY  = r.R_REGIONKEY
JOIN   PART      p  ON l.L_PARTKEY    = p.P_PARTKEY
WHERE  r.R_NAME = 'MIDDLE EAST'
ORDER BY p.P_CONTAINER;

-- W3-S17-Q06  Distinct market segments of customers who ordered large parts
SELECT DISTINCT c.C_MKTSEGMENT
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
WHERE  p.P_SIZE > 40
ORDER BY c.C_MKTSEGMENT;

-- W3-S17-Q07  Distinct region-brand pairs with available stock
SELECT DISTINCT r.R_NAME  AS region,
       p.P_BRAND
FROM   PART     p
JOIN   PARTSUPP ps ON p.P_PARTKEY   = ps.PS_PARTKEY
JOIN   SUPPLIER s  ON ps.PS_SUPPKEY = s.S_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r  ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  ps.PS_AVAILQTY > 500
ORDER BY r.R_NAME, p.P_BRAND;

-- W3-S17-Q08  Distinct ship modes used for orders from high-balance customers
SELECT DISTINCT l.L_SHIPMODE
FROM   LINEITEM l
JOIN   ORDERS   o ON l.L_ORDERKEY = o.O_ORDERKEY
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
WHERE  c.C_ACCTBAL > 8000
ORDER BY l.L_SHIPMODE;


-- =============================================================================
-- SECTION 18: DATE-FILTERED MULTI-TABLE JOINS
-- Coverage  : Time-range predicates on O_ORDERDATE, L_SHIPDATE, L_RECEIPTDATE;
--             yearly and monthly grouping patterns
-- =============================================================================

-- W3-S18-Q01  Revenue per region per year (1993–1998)
SELECT r.R_NAME        AS region,
       YEAR(o.O_ORDERDATE) AS order_year,
       SUM(o.O_TOTALPRICE) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
WHERE  o.O_ORDERDATE BETWEEN '1993-01-01' AND '1998-12-31'
GROUP BY r.R_NAME, YEAR(o.O_ORDERDATE)
ORDER BY r.R_NAME, order_year;

-- W3-S18-Q02  Monthly line item revenue for 1996
SELECT MONTH(l.L_SHIPDATE)   AS ship_month,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   LINEITEM l
JOIN   ORDERS   o ON l.L_ORDERKEY = o.O_ORDERKEY
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
WHERE  YEAR(l.L_SHIPDATE) = 1996
GROUP BY MONTH(l.L_SHIPDATE)
ORDER BY ship_month;

-- W3-S18-Q03  Orders with late receipt grouped by customer nation
SELECT n.N_NAME        AS nation,
       COUNT(DISTINCT o.O_ORDERKEY) AS late_orders
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   LINEITEM l ON o.O_ORDERKEY   = l.L_ORDERKEY
WHERE  l.L_RECEIPTDATE > l.L_COMMITDATE
GROUP BY n.N_NAME
ORDER BY late_orders DESC;

-- W3-S18-Q04  High-value orders placed in Q4 with customer context
SELECT o.O_ORDERKEY,
       c.C_NAME,
       n.N_NAME        AS nation,
       o.O_TOTALPRICE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
WHERE  MONTH(o.O_ORDERDATE) IN (10, 11, 12)
  AND  o.O_TOTALPRICE        > 100000
ORDER BY o.O_TOTALPRICE DESC
LIMIT  30;

-- W3-S18-Q05  Parts shipped in 1997 with supplier nation breakdown
SELECT n.N_NAME        AS supplier_nation,
       p.P_BRAND,
       SUM(l.L_QUANTITY) AS total_qty
FROM   LINEITEM l
JOIN   PART     p  ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   SUPPLIER s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
WHERE  YEAR(l.L_SHIPDATE) = 1997
GROUP BY n.N_NAME, p.P_BRAND
ORDER BY n.N_NAME, total_qty DESC;

-- W3-S18-Q06  Revenue growth: compare 1995 vs 1996 per nation
SELECT n.N_NAME        AS nation,
       SUM(CASE WHEN YEAR(o.O_ORDERDATE) = 1995
                THEN o.O_TOTALPRICE ELSE 0 END) AS revenue_1995,
       SUM(CASE WHEN YEAR(o.O_ORDERDATE) = 1996
                THEN o.O_TOTALPRICE ELSE 0 END) AS revenue_1996
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
GROUP BY n.N_NAME
ORDER BY n.N_NAME;

-- W3-S18-Q07  Line items shipped within 30 days of order date
SELECT o.O_ORDERKEY,
       c.C_NAME,
       l.L_SHIPDATE,
       o.O_ORDERDATE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  DATEDIFF(l.L_SHIPDATE, o.O_ORDERDATE) <= 30
ORDER BY DATEDIFF(l.L_SHIPDATE, o.O_ORDERDATE) ASC
LIMIT  50;

-- W3-S18-Q08  Supplier delivery performance: avg days to ship by nation
SELECT n.N_NAME        AS supplier_nation,
       AVG(DATEDIFF(l.L_RECEIPTDATE, l.L_SHIPDATE)) AS avg_transit_days
FROM   LINEITEM l
JOIN   SUPPLIER s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   ORDERS   o  ON l.L_ORDERKEY  = o.O_ORDERKEY
WHERE  l.L_SHIPDATE BETWEEN '1994-01-01' AND '1997-12-31'
GROUP BY n.N_NAME
ORDER BY avg_transit_days ASC;

-- W3-S18-Q09  Peak month for orders per region
SELECT r.R_NAME        AS region,
       MONTH(o.O_ORDERDATE) AS peak_month,
       COUNT(o.O_ORDERKEY)  AS order_count
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
GROUP BY r.R_NAME, MONTH(o.O_ORDERDATE)
ORDER BY r.R_NAME, order_count DESC;

-- W3-S18-Q10  Late-shipment rate per supplier region per year
SELECT r.R_NAME            AS region,
       YEAR(l.L_SHIPDATE)  AS ship_year,
       COUNT(CASE WHEN l.L_RECEIPTDATE > l.L_COMMITDATE THEN 1 END) AS late_count,
       COUNT(l.L_LINENUMBER) AS total_count
FROM   LINEITEM l
JOIN   SUPPLIER s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r  ON n.N_REGIONKEY = r.R_REGIONKEY
GROUP BY r.R_NAME, YEAR(l.L_SHIPDATE)
ORDER BY r.R_NAME, ship_year;


-- =============================================================================
-- SECTION 19: COMBINED FILTER + AGGREGATE MULTI-TABLE
-- Coverage  : WHERE + GROUP BY + HAVING + ORDER BY across 3-5 table joins;
--             compound query patterns requiring multiple index interactions
-- =============================================================================

-- W3-S19-Q01  Revenue per nation for high-balance customers, date-filtered
SELECT n.N_NAME        AS nation,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   LINEITEM l ON o.O_ORDERKEY   = l.L_ORDERKEY
WHERE  c.C_ACCTBAL   > 5000
  AND  o.O_ORDERDATE BETWEEN '1994-01-01' AND '1997-12-31'
GROUP BY n.N_NAME
HAVING SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) > 1000000
ORDER BY revenue DESC;

-- W3-S19-Q02  Top suppliers by revenue, EUROPE only, with quantity filter
SELECT s.S_SUPPKEY,
       s.S_NAME,
       n.N_NAME        AS nation,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   LINEITEM  l
JOIN   SUPPLIER  s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION    n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY = r.R_REGIONKEY
JOIN   ORDERS    o  ON l.L_ORDERKEY  = o.O_ORDERKEY
WHERE  r.R_NAME      = 'EUROPE'
  AND  l.L_QUANTITY  > 10
  AND  l.L_SHIPDATE  > '1995-01-01'
GROUP BY s.S_SUPPKEY, s.S_NAME, n.N_NAME
ORDER BY revenue DESC
LIMIT  15;

-- W3-S19-Q03  Parts with high margin sold to AMERICA customers
SELECT p.P_BRAND,
       p.P_TYPE,
       SUM(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) AS total_margin
FROM   LINEITEM  l
JOIN   PART      p  ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   PARTSUPP  ps ON l.L_PARTKEY   = ps.PS_PARTKEY
                   AND l.L_SUPPKEY   = ps.PS_SUPPKEY
JOIN   ORDERS    o  ON l.L_ORDERKEY  = o.O_ORDERKEY
JOIN   CUSTOMER  c  ON o.O_CUSTKEY   = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  r.R_NAME = 'AMERICA'
  AND  p.P_SIZE > 10
GROUP BY p.P_BRAND, p.P_TYPE
HAVING SUM(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) > 500000
ORDER BY total_margin DESC;

-- W3-S19-Q04  Market segment revenue in 1995-1996 with filter + sort
SELECT c.C_MKTSEGMENT,
       YEAR(o.O_ORDERDATE) AS yr,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue,
       COUNT(DISTINCT o.O_ORDERKEY)  AS order_count
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  o.O_ORDERDATE BETWEEN '1995-01-01' AND '1996-12-31'
  AND  l.L_DISCOUNT <= 0.06
GROUP BY c.C_MKTSEGMENT, YEAR(o.O_ORDERDATE)
ORDER BY c.C_MKTSEGMENT, yr;

-- W3-S19-Q05  Nations with growing revenue: 1996 higher than 1995
SELECT n.N_NAME        AS nation,
       SUM(CASE WHEN YEAR(o.O_ORDERDATE) = 1995 THEN l.L_EXTENDEDPRICE*(1-l.L_DISCOUNT) ELSE 0 END) AS rev_1995,
       SUM(CASE WHEN YEAR(o.O_ORDERDATE) = 1996 THEN l.L_EXTENDEDPRICE*(1-l.L_DISCOUNT) ELSE 0 END) AS rev_1996
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   LINEITEM l ON o.O_ORDERKEY   = l.L_ORDERKEY
GROUP BY n.N_NAME
HAVING SUM(CASE WHEN YEAR(o.O_ORDERDATE) = 1996 THEN l.L_EXTENDEDPRICE*(1-l.L_DISCOUNT) ELSE 0 END)
     > SUM(CASE WHEN YEAR(o.O_ORDERDATE) = 1995 THEN l.L_EXTENDEDPRICE*(1-l.L_DISCOUNT) ELSE 0 END)
ORDER BY n.N_NAME;

-- W3-S19-Q06  Suppliers with low avg cost and high stock in same region
SELECT s.S_NAME,
       n.N_NAME        AS nation,
       r.R_NAME        AS region,
       AVG(ps.PS_SUPPLYCOST) AS avg_cost,
       SUM(ps.PS_AVAILQTY)   AS total_stock
FROM   SUPPLIER s
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION   r  ON n.N_REGIONKEY = r.R_REGIONKEY
JOIN   PARTSUPP ps ON s.S_SUPPKEY   = ps.PS_SUPPKEY
WHERE  s.S_ACCTBAL > 1000
GROUP BY s.S_SUPPKEY, s.S_NAME, n.N_NAME, r.R_NAME
HAVING AVG(ps.PS_SUPPLYCOST) < 400
   AND SUM(ps.PS_AVAILQTY)   > 2000
ORDER BY avg_cost ASC, total_stock DESC;

-- W3-S19-Q07  Part brands with consistent demand across all regions
SELECT p.P_BRAND,
       COUNT(DISTINCT r.R_REGIONKEY) AS region_count,
       SUM(l.L_QUANTITY)             AS total_qty
FROM   LINEITEM  l
JOIN   PART      p  ON l.L_PARTKEY    = p.P_PARTKEY
JOIN   ORDERS    o  ON l.L_ORDERKEY   = o.O_ORDERKEY
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY  = r.R_REGIONKEY
GROUP BY p.P_BRAND
HAVING COUNT(DISTINCT r.R_REGIONKEY) = 5
ORDER BY total_qty DESC;

-- W3-S19-Q08  High-margin part types per supplier region with discount filter
SELECT r.R_NAME        AS supplier_region,
       p.P_TYPE,
       AVG(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) AS avg_margin
FROM   LINEITEM  l
JOIN   PART      p  ON l.L_PARTKEY   = p.P_PARTKEY
JOIN   PARTSUPP  ps ON l.L_PARTKEY   = ps.PS_PARTKEY
                   AND l.L_SUPPKEY   = ps.PS_SUPPKEY
JOIN   SUPPLIER  s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION    n  ON s.S_NATIONKEY = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE  l.L_DISCOUNT < 0.05
GROUP BY r.R_NAME, p.P_TYPE
HAVING AVG(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST) > 1000
ORDER BY r.R_NAME, avg_margin DESC;

-- W3-S19-Q09  Revenue per ship mode per customer region with date filter
SELECT r.R_NAME        AS customer_region,
       l.L_SHIPMODE,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   ORDERS    o
JOIN   CUSTOMER  c  ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    n  ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION    r  ON n.N_REGIONKEY  = r.R_REGIONKEY
JOIN   LINEITEM  l  ON o.O_ORDERKEY   = l.L_ORDERKEY
WHERE  l.L_SHIPDATE BETWEEN '1995-01-01' AND '1997-12-31'
GROUP BY r.R_NAME, l.L_SHIPMODE
ORDER BY r.R_NAME, revenue DESC;

-- W3-S19-Q10  Customer segments with high avg order value and low late rate
SELECT c.C_MKTSEGMENT,
       AVG(o.O_TOTALPRICE)   AS avg_order_value,
       COUNT(DISTINCT o.O_ORDERKEY) AS order_count
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY  = c.C_CUSTKEY
JOIN   LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE  l.L_RECEIPTDATE <= l.L_COMMITDATE
GROUP BY c.C_MKTSEGMENT
HAVING AVG(o.O_TOTALPRICE) > 50000
ORDER BY avg_order_value DESC;


-- =============================================================================
-- SECTION 20: ADVANCED DIVERSE PATTERNS
-- Coverage  : Self-joins, CASE expressions, multi-level subqueries, cross-join
--             patterns, and other advanced SQL constructs over multi-table joins
-- =============================================================================

-- W3-S20-Q01  Self-join: pairs of customers in the same nation with similar balance
SELECT a.C_NAME        AS customer_a,
       b.C_NAME        AS customer_b,
       n.N_NAME        AS nation,
       a.C_ACCTBAL     AS balance_a,
       b.C_ACCTBAL     AS balance_b
FROM   CUSTOMER a
JOIN   CUSTOMER b  ON  a.C_NATIONKEY = b.C_NATIONKEY
                   AND a.C_CUSTKEY   < b.C_CUSTKEY
                   AND ABS(a.C_ACCTBAL - b.C_ACCTBAL) < 100
JOIN   NATION   n  ON  a.C_NATIONKEY = n.N_NATIONKEY
ORDER BY n.N_NAME, balance_a
LIMIT  30;

-- W3-S20-Q02  CASE: classify orders as small/medium/large with customer context
SELECT c.C_NAME,
       n.N_NAME        AS nation,
       o.O_ORDERKEY,
       CASE
           WHEN o.O_TOTALPRICE < 30000  THEN 'SMALL'
           WHEN o.O_TOTALPRICE < 100000 THEN 'MEDIUM'
           ELSE                              'LARGE'
       END             AS order_size,
       o.O_TOTALPRICE
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
ORDER BY o.O_TOTALPRICE DESC
LIMIT  50;

-- W3-S20-Q03  Count by order size category per region
SELECT r.R_NAME        AS region,
       SUM(CASE WHEN o.O_TOTALPRICE < 30000  THEN 1 ELSE 0 END) AS small_orders,
       SUM(CASE WHEN o.O_TOTALPRICE BETWEEN 30000 AND 100000 THEN 1 ELSE 0 END) AS medium_orders,
       SUM(CASE WHEN o.O_TOTALPRICE > 100000 THEN 1 ELSE 0 END) AS large_orders
FROM   ORDERS   o
JOIN   CUSTOMER c ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION   n ON c.C_NATIONKEY  = n.N_NATIONKEY
JOIN   REGION   r ON n.N_REGIONKEY  = r.R_REGIONKEY
GROUP BY r.R_NAME
ORDER BY r.R_NAME;

-- W3-S20-Q04  Suppliers with above-average revenue vs their nation peers
SELECT s.S_SUPPKEY,
       s.S_NAME,
       n.N_NAME        AS nation,
       SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue
FROM   LINEITEM l
JOIN   SUPPLIER s  ON l.L_SUPPKEY   = s.S_SUPPKEY
JOIN   NATION   n  ON s.S_NATIONKEY = n.N_NATIONKEY
GROUP BY s.S_SUPPKEY, s.S_NAME, n.N_NATIONKEY, n.N_NAME
HAVING SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) > (
    SELECT AVG(nation_rev)
    FROM (
        SELECT s2.S_NATIONKEY,
               SUM(l2.L_EXTENDEDPRICE * (1 - l2.L_DISCOUNT)) AS nation_rev
        FROM   LINEITEM  l2
        JOIN   SUPPLIER  s2 ON l2.L_SUPPKEY = s2.S_SUPPKEY
        GROUP BY s2.S_SUPPKEY
    ) t
    WHERE t.S_NATIONKEY = s.S_NATIONKEY
)
ORDER BY revenue DESC
LIMIT  20;

-- W3-S20-Q05  Parts ordered more in 1996 than in 1995 (trend detection)
SELECT p.P_PARTKEY,
       p.P_NAME,
       SUM(CASE WHEN YEAR(l.L_SHIPDATE) = 1995 THEN l.L_QUANTITY ELSE 0 END) AS qty_1995,
       SUM(CASE WHEN YEAR(l.L_SHIPDATE) = 1996 THEN l.L_QUANTITY ELSE 0 END) AS qty_1996
FROM   LINEITEM l
JOIN   PART     p ON l.L_PARTKEY  = p.P_PARTKEY
JOIN   ORDERS   o ON l.L_ORDERKEY = o.O_ORDERKEY
GROUP BY p.P_PARTKEY, p.P_NAME
HAVING SUM(CASE WHEN YEAR(l.L_SHIPDATE) = 1996 THEN l.L_QUANTITY ELSE 0 END)
     > SUM(CASE WHEN YEAR(l.L_SHIPDATE) = 1995 THEN l.L_QUANTITY ELSE 0 END)
ORDER BY qty_1996 DESC
LIMIT  20;

-- W3-S20-Q06  Customer retention proxy: customers with orders in both 1995 and 1996
SELECT c.C_CUSTKEY,
       c.C_NAME,
       n.N_NAME        AS nation
FROM   CUSTOMER c
JOIN   NATION   n ON c.C_NATIONKEY = n.N_NATIONKEY
WHERE  EXISTS (SELECT 1 FROM ORDERS o
               WHERE o.O_CUSTKEY = c.C_CUSTKEY AND YEAR(o.O_ORDERDATE) = 1995)
  AND  EXISTS (SELECT 1 FROM ORDERS o
               WHERE o.O_CUSTKEY = c.C_CUSTKEY AND YEAR(o.O_ORDERDATE) = 1996)
ORDER BY n.N_NAME, c.C_NAME;

-- W3-S20-Q07  Full supply chain profitability summary by region pair
SELECT cr.R_NAME       AS customer_region,
       sr.R_NAME       AS supplier_region,
       COUNT(DISTINCT o.O_ORDERKEY)             AS order_count,
       SUM(l.L_EXTENDEDPRICE * (1-l.L_DISCOUNT)) AS gross_revenue,
       SUM(l.L_EXTENDEDPRICE - ps.PS_SUPPLYCOST)  AS gross_margin
FROM   ORDERS    o
JOIN   CUSTOMER  c   ON o.O_CUSTKEY    = c.C_CUSTKEY
JOIN   NATION    cn  ON c.C_NATIONKEY  = cn.N_NATIONKEY
JOIN   REGION    cr  ON cn.N_REGIONKEY = cr.R_REGIONKEY
JOIN   LINEITEM  l   ON o.O_ORDERKEY   = l.L_ORDERKEY
JOIN   SUPPLIER  s   ON l.L_SUPPKEY    = s.S_SUPPKEY
JOIN   NATION    sn  ON s.S_NATIONKEY  = sn.N_NATIONKEY
JOIN   REGION    sr  ON sn.N_REGIONKEY = sr.R_REGIONKEY
JOIN   PARTSUPP  ps  ON l.L_PARTKEY    = ps.PS_PARTKEY
                    AND l.L_SUPPKEY    = ps.PS_SUPPKEY
GROUP BY cr.R_NAME, sr.R_NAME
ORDER BY gross_margin DESC;


-- =============================================================================
-- END OF WORKLOAD W3
-- Total queries : 200
-- Sections      : 20
-- Tables used   : ORDERS, CUSTOMER, LINEITEM, PART, PARTSUPP,
--                 SUPPLIER, NATION, REGION
-- Join depth    : 3-table (S01-S09), 4-table (S02,S06,S10),
--                 5-table (S11), 6-table (S12), mixed (S13-S20)
-- Operation types covered:
--   Inner joins, multi-table chains, range/point/BETWEEN/LIKE filters,
--   combined predicates, ORDER BY, LIMIT, ORDER BY+LIMIT (Top-N),
--   DISTINCT, GROUP BY, COUNT/SUM/AVG/MAX/MIN, HAVING, EXISTS,
--   NOT EXISTS, IN subqueries, correlated subqueries, self-joins,
--   CASE expressions, DATEDIFF, YEAR/MONTH date functions,
--   computed column expressions, multi-level aggregation
-- =============================================================================