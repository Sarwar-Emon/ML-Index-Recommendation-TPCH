-- ============================================================
-- TPC-H COMPLEX QUERIES FOR MYSQL
-- Total: 200 Queries | Maximum Diversity
-- Tables: customer, orders, lineitem, part, partsupp,
--         supplier, nation, region
-- ------------------------------------------------------------
-- REQUIREMENTS:
--   MySQL 8.0+ required for CTEs (WITH clause) and window
--   functions used throughout this file.
--   MySQL 5.7 is NOT supported for most queries here.
-- ============================================================
-- CATEGORIES:
--   Q001-Q025 : CTEs (Common Table Expressions)
--   Q026-Q050 : Correlated Subqueries
--   Q051-Q075 : UNION / INTERSECT / EXCEPT patterns
--   Q076-Q100 : EXISTS / NOT EXISTS
--   Q101-Q125 : Multi-level Subqueries & Derived Tables
--   Q126-Q150 : Advanced Window Functions
--   Q151-Q170 : Self-Joins & Recursive-style Patterns
--   Q171-Q185 : TPC-H Benchmark Inspired Queries
--   Q186-Q200 : Full Pipeline / Analytical Queries
-- ============================================================

-- ============================================================
-- SECTION 1: CTEs (Q001-Q025)
-- ============================================================

-- Q001: Top customers by revenue using CTE
WITH customer_revenue AS (
    SELECT o_custkey,
           SUM(o_totalprice) AS total_revenue
    FROM orders
    GROUP BY o_custkey
)
SELECT c_custkey,
       c_name,
       c_mktsegment,
       total_revenue
FROM customer
JOIN customer_revenue ON c_custkey = o_custkey
ORDER BY total_revenue DESC
LIMIT 20;

-- Q002: Supplier performance CTE — revenue vs inventory cost
WITH supplier_revenue AS (
    SELECT l_suppkey,
           SUM(l_extendedprice * (1 - l_discount)) AS revenue
    FROM lineitem
    GROUP BY l_suppkey
),
supplier_cost AS (
    SELECT ps_suppkey,
           SUM(ps_supplycost * ps_availqty) AS inventory_cost
    FROM partsupp
    GROUP BY ps_suppkey
)
SELECT s_suppkey,
       s_name,
       revenue,
       inventory_cost,
       revenue - inventory_cost AS net_margin
FROM supplier
JOIN supplier_revenue  ON s_suppkey = l_suppkey
JOIN supplier_cost     ON s_suppkey = ps_suppkey
ORDER BY net_margin DESC;

-- Q003: CTE — nation-level order statistics
WITH nation_orders AS (
    SELECT n_name,
           COUNT(DISTINCT o_orderkey) AS order_count,
           SUM(o_totalprice)          AS total_value,
           AVG(o_totalprice)          AS avg_value
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    GROUP BY n_name
)
SELECT *,
       total_value / SUM(total_value) OVER () * 100 AS global_share_pct
FROM nation_orders
ORDER BY total_value DESC;

-- Q004: CTE chain — part supply chain summary
WITH part_demand AS (
    SELECT l_partkey,
           SUM(l_quantity)                          AS total_ordered,
           SUM(l_extendedprice * (1 - l_discount))  AS total_revenue
    FROM lineitem
    GROUP BY l_partkey
),
part_supply AS (
    SELECT ps_partkey,
           SUM(ps_availqty)   AS total_supply,
           AVG(ps_supplycost) AS avg_cost
    FROM partsupp
    GROUP BY ps_partkey
)
SELECT p_partkey,
       p_name,
       p_brand,
       total_ordered,
       total_supply,
       total_revenue,
       avg_cost,
       total_supply - total_ordered AS stock_balance
FROM part
JOIN part_demand ON p_partkey = l_partkey
JOIN part_supply ON p_partkey = ps_partkey
ORDER BY stock_balance ASC;

-- Q005: CTE — identify repeat customers (ordered in 3+ years)
WITH customer_years AS (
    SELECT o_custkey,
           COUNT(DISTINCT YEAR(o_orderdate)) AS active_years
    FROM orders
    GROUP BY o_custkey
)
SELECT c_custkey,
       c_name,
       c_mktsegment,
       active_years
FROM customer
JOIN customer_years ON c_custkey = o_custkey
WHERE active_years >= 3
ORDER BY active_years DESC;

-- Q006: CTE — region revenue breakdown with rank
WITH region_revenue AS (
    SELECT r_name,
           SUM(l_extendedprice * (1 - l_discount)) AS revenue
    FROM lineitem
    JOIN orders  ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey = c_custkey
    JOIN nation  ON c_nationkey = n_nationkey
    JOIN region  ON n_regionkey = r_regionkey
    GROUP BY r_name
)
SELECT r_name,
       revenue,
       RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM region_revenue
ORDER BY revenue_rank;

-- Q007: CTE — monthly revenue with 3-month moving average
WITH monthly_revenue AS (
    SELECT DATE_FORMAT(o_orderdate, '%Y-%m') AS order_month,
           SUM(o_totalprice)                 AS monthly_total
    FROM orders
    GROUP BY DATE_FORMAT(o_orderdate, '%Y-%m')
)
SELECT order_month,
       monthly_total,
       AVG(monthly_total) OVER (
           ORDER BY order_month
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS moving_avg_3m
FROM monthly_revenue
ORDER BY order_month;

-- Q008: CTE — supplier nation revenue share
WITH nation_supply AS (
    SELECT n_name,
           SUM(l_extendedprice * (1 - l_discount)) AS supply_revenue
    FROM lineitem
    JOIN supplier ON l_suppkey = s_suppkey
    JOIN nation   ON s_nationkey = n_nationkey
    GROUP BY n_name
),
total AS (
    SELECT SUM(supply_revenue) AS grand_total FROM nation_supply
)
SELECT n_name,
       supply_revenue,
       supply_revenue / grand_total * 100 AS share_pct
FROM nation_supply
CROSS JOIN total
ORDER BY supply_revenue DESC;

-- Q009: CTE — customer order frequency bucket
WITH order_counts AS (
    SELECT o_custkey,
           COUNT(*) AS num_orders
    FROM orders
    GROUP BY o_custkey
),
buckets AS (
    SELECT o_custkey,
           num_orders,
           CASE
             WHEN num_orders = 1  THEN 'One-time'
             WHEN num_orders <= 5 THEN 'Occasional'
             WHEN num_orders <= 15 THEN 'Regular'
             ELSE 'Frequent'
           END AS frequency_bucket
    FROM order_counts
)
SELECT frequency_bucket,
       COUNT(*) AS customer_count,
       AVG(num_orders) AS avg_orders
FROM buckets
GROUP BY frequency_bucket
ORDER BY avg_orders;

-- Q010: CTE — part profitability ranked by type
WITH part_profit AS (
    SELECT p_type,
           p_partkey,
           p_name,
           SUM(l_extendedprice * (1 - l_discount))                  AS revenue,
           SUM(l_quantity * ps_supplycost)                           AS cost,
           SUM(l_extendedprice * (1 - l_discount)) -
               SUM(l_quantity * ps_supplycost)                       AS profit
    FROM lineitem
    JOIN part    ON l_partkey  = p_partkey
    JOIN partsupp ON l_partkey = ps_partkey AND l_suppkey = ps_suppkey
    GROUP BY p_type, p_partkey, p_name
)
SELECT *,
       RANK() OVER (PARTITION BY p_type ORDER BY profit DESC) AS type_rank
FROM part_profit
ORDER BY p_type, type_rank;

-- Q011: CTE — identify top 10% revenue customers
WITH customer_totals AS (
    SELECT o_custkey,
           SUM(o_totalprice) AS total_spend
    FROM orders
    GROUP BY o_custkey
),
percentiles AS (
    SELECT o_custkey,
           total_spend,
           PERCENT_RANK() OVER (ORDER BY total_spend) AS pct_rank
    FROM customer_totals
)
SELECT c_name,
       c_mktsegment,
       total_spend,
       ROUND(pct_rank * 100, 2) AS percentile
FROM percentiles
JOIN customer ON o_custkey = c_custkey
WHERE pct_rank >= 0.90
ORDER BY total_spend DESC;

-- Q012: CTE — supply chain risk: low stock parts
WITH stock_levels AS (
    SELECT ps_partkey,
           SUM(ps_availqty) AS total_stock
    FROM partsupp
    GROUP BY ps_partkey
),
demand_levels AS (
    SELECT l_partkey,
           SUM(l_quantity) AS total_demand
    FROM lineitem
    WHERE l_shipdate >= DATE_SUB('1998-12-01', INTERVAL 365 DAY)
    GROUP BY l_partkey
)
SELECT p_partkey,
       p_name,
       p_brand,
       total_stock,
       total_demand,
       total_stock - total_demand AS net_stock
FROM part
JOIN stock_levels  ON p_partkey = ps_partkey
JOIN demand_levels ON p_partkey = l_partkey
WHERE total_stock < total_demand
ORDER BY net_stock ASC;

-- Q013: CTE — year-over-year revenue growth per region
WITH yearly_regional AS (
    SELECT r_name,
           YEAR(o_orderdate) AS yr,
           SUM(o_totalprice) AS revenue
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    JOIN region   ON n_regionkey = r_regionkey
    GROUP BY r_name, YEAR(o_orderdate)
)
SELECT r_name,
       yr,
       revenue,
       LAG(revenue) OVER (PARTITION BY r_name ORDER BY yr) AS prev_revenue,
       ROUND(
           (revenue - LAG(revenue) OVER (PARTITION BY r_name ORDER BY yr))
           / LAG(revenue) OVER (PARTITION BY r_name ORDER BY yr) * 100, 2
       ) AS yoy_growth_pct
FROM yearly_regional
ORDER BY r_name, yr;

-- Q014: CTE — clerk performance summary
WITH clerk_stats AS (
    SELECT o_clerk,
           COUNT(*)          AS total_orders,
           SUM(o_totalprice) AS total_value,
           AVG(o_totalprice) AS avg_value,
           MIN(o_orderdate)  AS first_order,
           MAX(o_orderdate)  AS last_order
    FROM orders
    GROUP BY o_clerk
)
SELECT *,
       RANK() OVER (ORDER BY total_value DESC) AS value_rank,
       RANK() OVER (ORDER BY total_orders DESC) AS volume_rank
FROM clerk_stats
ORDER BY value_rank
LIMIT 20;

-- Q015: CTE — average order gap per customer (days between orders)
WITH ordered_dates AS (
    SELECT o_custkey,
           o_orderdate,
           LAG(o_orderdate) OVER (PARTITION BY o_custkey ORDER BY o_orderdate) AS prev_date
    FROM orders
)
SELECT o_custkey,
       AVG(DATEDIFF(o_orderdate, prev_date)) AS avg_days_between_orders
FROM ordered_dates
WHERE prev_date IS NOT NULL
GROUP BY o_custkey
ORDER BY avg_days_between_orders
LIMIT 30;

-- Q016: CTE — top nation pairs by cross-border trade
WITH trade_pairs AS (
    SELECT n1.n_name AS supplier_nation,
           n2.n_name AS customer_nation,
           SUM(l_extendedprice * (1 - l_discount)) AS trade_value
    FROM lineitem
    JOIN orders   ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey  = c_custkey
    JOIN supplier ON l_suppkey  = s_suppkey
    JOIN nation n1 ON s_nationkey = n1.n_nationkey
    JOIN nation n2 ON c_nationkey = n2.n_nationkey
    WHERE n1.n_nationkey <> n2.n_nationkey
    GROUP BY n1.n_name, n2.n_name
)
SELECT *,
       RANK() OVER (ORDER BY trade_value DESC) AS trade_rank
FROM trade_pairs
ORDER BY trade_rank
LIMIT 15;

-- Q017: CTE — customers with above-average balance per segment
WITH segment_avg AS (
    SELECT c_mktsegment,
           AVG(c_acctbal) AS avg_balance
    FROM customer
    GROUP BY c_mktsegment
)
SELECT c_custkey,
       c_name,
       c_mktsegment,
       c_acctbal,
       avg_balance,
       c_acctbal - avg_balance AS balance_diff
FROM customer
JOIN segment_avg USING (c_mktsegment)
WHERE c_acctbal > avg_balance
ORDER BY balance_diff DESC;

-- Q018: CTE — brand revenue concentration (top 3 brands per region)
WITH brand_region_revenue AS (
    SELECT r_name,
           p_brand,
           SUM(l_extendedprice * (1 - l_discount)) AS revenue
    FROM lineitem
    JOIN part    ON l_partkey  = p_partkey
    JOIN orders  ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey = c_custkey
    JOIN nation  ON c_nationkey = n_nationkey
    JOIN region  ON n_regionkey = r_regionkey
    GROUP BY r_name, p_brand
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY r_name ORDER BY revenue DESC) AS brand_rank
    FROM brand_region_revenue
)
SELECT r_name, p_brand, revenue, brand_rank
FROM ranked
WHERE brand_rank <= 3
ORDER BY r_name, brand_rank;

-- Q019: CTE — suppliers with declining revenue trend
WITH supplier_yearly AS (
    SELECT l_suppkey,
           YEAR(l_shipdate) AS yr,
           SUM(l_extendedprice * (1 - l_discount)) AS yearly_revenue
    FROM lineitem
    GROUP BY l_suppkey, YEAR(l_shipdate)
),
with_growth AS (
    SELECT l_suppkey,
           yr,
           yearly_revenue,
           LAG(yearly_revenue) OVER (PARTITION BY l_suppkey ORDER BY yr) AS prev_revenue
    FROM supplier_yearly
)
SELECT l_suppkey,
       COUNT(*) AS decline_years
FROM with_growth
WHERE yearly_revenue < prev_revenue
GROUP BY l_suppkey
HAVING COUNT(*) >= 2
ORDER BY decline_years DESC;

-- Q020: CTE — order value distribution by percentile bucket
WITH order_values AS (
    SELECT o_orderkey,
           o_totalprice,
           NTILE(10) OVER (ORDER BY o_totalprice) AS decile
    FROM orders
)
SELECT decile,
       COUNT(*)              AS order_count,
       MIN(o_totalprice)     AS min_value,
       MAX(o_totalprice)     AS max_value,
       AVG(o_totalprice)     AS avg_value,
       SUM(o_totalprice)     AS total_value
FROM order_values
GROUP BY decile
ORDER BY decile;

-- Q021: CTE — multi-supplier parts vs single-supplier parts
WITH supplier_counts AS (
    SELECT ps_partkey,
           COUNT(DISTINCT ps_suppkey) AS num_suppliers
    FROM partsupp
    GROUP BY ps_partkey
)
SELECT CASE WHEN num_suppliers = 1 THEN 'Single Supplier'
            WHEN num_suppliers <= 3 THEN '2-3 Suppliers'
            ELSE '4+ Suppliers' END AS supply_risk,
       COUNT(*)           AS part_count,
       AVG(num_suppliers) AS avg_suppliers
FROM supplier_counts
GROUP BY supply_risk
ORDER BY avg_suppliers;

-- Q022: CTE — seasonal order pattern (by quarter)
WITH quarterly AS (
    SELECT YEAR(o_orderdate)    AS yr,
           QUARTER(o_orderdate) AS qtr,
           COUNT(*)              AS order_count,
           SUM(o_totalprice)     AS revenue
    FROM orders
    GROUP BY YEAR(o_orderdate), QUARTER(o_orderdate)
)
SELECT yr,
       qtr,
       order_count,
       revenue,
       revenue / SUM(revenue) OVER (PARTITION BY yr) * 100 AS quarterly_share_pct
FROM quarterly
ORDER BY yr, qtr;

-- Q023: CTE — parts never returned
WITH returned_parts AS (
    SELECT DISTINCT l_partkey
    FROM lineitem
    WHERE l_returnflag = 'R'
)
SELECT p_partkey,
       p_name,
       p_brand,
       p_type
FROM part
WHERE p_partkey NOT IN (SELECT l_partkey FROM returned_parts)
ORDER BY p_brand, p_name
LIMIT 20;

-- Q024: CTE — shipment delay analysis by nation
WITH ship_delays AS (
    SELECT c_nationkey,
           l_orderkey,
           DATEDIFF(l_shipdate, o_orderdate)    AS order_to_ship,
           DATEDIFF(l_receiptdate, l_shipdate)  AS ship_to_receipt
    FROM lineitem
    JOIN orders   ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey  = c_custkey
)
SELECT n_name,
       AVG(order_to_ship)   AS avg_processing_days,
       AVG(ship_to_receipt) AS avg_transit_days,
       MAX(order_to_ship)   AS max_processing_days,
       MAX(ship_to_receipt) AS max_transit_days
FROM ship_delays
JOIN nation ON c_nationkey = n_nationkey
GROUP BY n_name
ORDER BY avg_processing_days DESC;

-- Q025: CTE — multi-step customer churn analysis
WITH last_orders AS (
    SELECT o_custkey,
           MAX(o_orderdate) AS last_order_date
    FROM orders
    GROUP BY o_custkey
),
churn_flag AS (
    SELECT o_custkey,
           last_order_date,
           DATEDIFF('1998-12-31', last_order_date) AS days_since_last_order,
           CASE
             WHEN DATEDIFF('1998-12-31', last_order_date) > 365 THEN 'Churned'
             WHEN DATEDIFF('1998-12-31', last_order_date) > 180 THEN 'At Risk'
             ELSE 'Active'
           END AS churn_status
    FROM last_orders
)
SELECT churn_status,
       COUNT(*)                        AS customer_count,
       AVG(days_since_last_order)      AS avg_days_inactive
FROM churn_flag
GROUP BY churn_status
ORDER BY avg_days_inactive DESC;

-- ============================================================
-- SECTION 2: Correlated Subqueries (Q026-Q050)
-- ============================================================

-- Q026: Customers whose latest order is above their personal average
SELECT c_custkey,
       c_name,
       o_orderkey,
       o_totalprice
FROM customer
JOIN orders ON c_custkey = o_custkey
WHERE o_totalprice > (
    SELECT AVG(o2.o_totalprice)
    FROM orders o2
    WHERE o2.o_custkey = o_custkey
)
AND o_orderdate = (
    SELECT MAX(o3.o_orderdate)
    FROM orders o3
    WHERE o3.o_custkey = o_custkey
)
ORDER BY o_totalprice DESC;

-- Q027: Parts whose retail price exceeds avg price in their brand
SELECT p_partkey,
       p_name,
       p_brand,
       p_retailprice
FROM part p
WHERE p_retailprice > (
    SELECT AVG(p2.p_retailprice)
    FROM part p2
    WHERE p2.p_brand = p.p_brand
)
ORDER BY p_brand, p_retailprice DESC;

-- Q028: Suppliers who supply more parts than avg supplier in their nation
SELECT s_suppkey,
       s_name,
       s_nationkey,
       part_count
FROM supplier
JOIN (
    SELECT ps_suppkey,
           COUNT(DISTINCT ps_partkey) AS part_count
    FROM partsupp
    GROUP BY ps_suppkey
) AS pc ON s_suppkey = ps_suppkey
WHERE part_count > (
    SELECT AVG(pc2.part_count)
    FROM (
        SELECT s2.s_nationkey,
               COUNT(DISTINCT ps2.ps_partkey) AS part_count
        FROM supplier s2
        JOIN partsupp ps2 ON s2.s_suppkey = ps2.ps_suppkey
        GROUP BY s2.s_suppkey, s2.s_nationkey
    ) AS pc2
    WHERE pc2.s_nationkey = s_nationkey
)
ORDER BY part_count DESC;

-- Q029: Orders with more lineitems than average for that customer
SELECT o_orderkey,
       o_custkey,
       o_totalprice,
       item_count
FROM orders
JOIN (
    SELECT l_orderkey,
           COUNT(*) AS item_count
    FROM lineitem
    GROUP BY l_orderkey
) AS lc ON o_orderkey = l_orderkey
WHERE item_count > (
    SELECT AVG(lc2.item_count)
    FROM orders o2
    JOIN (
        SELECT l_orderkey, COUNT(*) AS item_count
        FROM lineitem GROUP BY l_orderkey
    ) AS lc2 ON o2.o_orderkey = lc2.l_orderkey
    WHERE o2.o_custkey = o_custkey
)
ORDER BY item_count DESC;

-- Q030: Nations where avg customer balance exceeds global avg
SELECT n_name,
       AVG(c_acctbal) AS avg_balance
FROM customer
JOIN nation ON c_nationkey = n_nationkey
GROUP BY n_name
HAVING AVG(c_acctbal) > (
    SELECT AVG(c_acctbal) FROM customer
)
ORDER BY avg_balance DESC;

-- Q031: Parts with supply cost below cheapest alternative supplier
SELECT ps1.ps_partkey,
       ps1.ps_suppkey,
       ps1.ps_supplycost
FROM partsupp ps1
WHERE ps1.ps_supplycost = (
    SELECT MIN(ps2.ps_supplycost)
    FROM partsupp ps2
    WHERE ps2.ps_partkey = ps1.ps_partkey
)
ORDER BY ps1.ps_partkey;

-- Q032: Customers who spent more than double the segment average
SELECT c_custkey,
       c_name,
       c_mktsegment,
       total_spend
FROM customer
JOIN (
    SELECT o_custkey,
           SUM(o_totalprice) AS total_spend
    FROM orders
    GROUP BY o_custkey
) AS cs ON c_custkey = o_custkey
WHERE total_spend > 2 * (
    SELECT AVG(cs2.total_spend)
    FROM customer c2
    JOIN (
        SELECT o_custkey, SUM(o_totalprice) AS total_spend
        FROM orders GROUP BY o_custkey
    ) AS cs2 ON c2.c_custkey = cs2.o_custkey
    WHERE c2.c_mktsegment = c_mktsegment
)
ORDER BY total_spend DESC;

-- Q033: Suppliers whose cheapest part is below global avg supply cost
SELECT s_suppkey,
       s_name,
       MIN(ps_supplycost) AS cheapest_part_cost
FROM supplier
JOIN partsupp ON s_suppkey = ps_suppkey
GROUP BY s_suppkey, s_name
HAVING MIN(ps_supplycost) < (
    SELECT AVG(ps_supplycost) FROM partsupp
)
ORDER BY cheapest_part_cost;

-- Q034: Lineitems with quantity above average for that part
SELECT l_orderkey,
       l_partkey,
       l_quantity
FROM lineitem l
WHERE l_quantity > (
    SELECT AVG(l2.l_quantity)
    FROM lineitem l2
    WHERE l2.l_partkey = l.l_partkey
)
ORDER BY l_partkey, l_quantity DESC;

-- Q035: Orders placed after customer's first order in the same year
SELECT o_orderkey,
       o_custkey,
       o_orderdate,
       o_totalprice
FROM orders o
WHERE o_orderdate > (
    SELECT MIN(o2.o_orderdate)
    FROM orders o2
    WHERE o2.o_custkey = o.o_custkey
      AND YEAR(o2.o_orderdate) = YEAR(o.o_orderdate)
)
ORDER BY o_custkey, o_orderdate;

-- Q036: Parts whose total revenue exceeds avg revenue per part type
SELECT l_partkey,
       p_type,
       SUM(l_extendedprice * (1 - l_discount)) AS part_revenue
FROM lineitem
JOIN part ON l_partkey = p_partkey
GROUP BY l_partkey, p_type
HAVING SUM(l_extendedprice * (1 - l_discount)) > (
    SELECT AVG(type_rev)
    FROM (
        SELECT p2.p_type,
               SUM(l2.l_extendedprice * (1 - l2.l_discount)) AS type_rev
        FROM lineitem l2
        JOIN part p2 ON l2.l_partkey = p2.p_partkey
        GROUP BY p2.p_type
    ) AS t
    WHERE t.p_type = p_type
)
ORDER BY part_revenue DESC;

-- Q037: Customers who placed an order in every year of the dataset
SELECT o_custkey,
       COUNT(DISTINCT YEAR(o_orderdate)) AS active_years
FROM orders
GROUP BY o_custkey
HAVING COUNT(DISTINCT YEAR(o_orderdate)) = (
    SELECT COUNT(DISTINCT YEAR(o2.o_orderdate)) FROM orders o2
)
ORDER BY o_custkey;

-- Q038: Suppliers with all parts priced below market average
SELECT s_suppkey,
       s_name
FROM supplier
WHERE NOT EXISTS (
    SELECT 1
    FROM partsupp ps
    WHERE ps.ps_suppkey = s_suppkey
      AND ps.ps_supplycost > (
          SELECT AVG(ps2.ps_supplycost)
          FROM partsupp ps2
          WHERE ps2.ps_partkey = ps.ps_partkey
      )
);

-- Q039: Orders where every lineitem was shipped on time
SELECT DISTINCT o_orderkey
FROM orders
WHERE NOT EXISTS (
    SELECT 1
    FROM lineitem l
    WHERE l.l_orderkey = o_orderkey
      AND l.l_shipdate > l.l_commitdate
)
ORDER BY o_orderkey
LIMIT 20;

-- Q040: Customers whose best single order exceeds their avg * 3
SELECT o_custkey,
       MAX(o_totalprice)  AS best_order,
       AVG(o_totalprice)  AS avg_order
FROM orders
GROUP BY o_custkey
HAVING MAX(o_totalprice) > 3 * AVG(o_totalprice)
ORDER BY best_order DESC;

-- Q041: Parts supplied by more than the median number of suppliers
SELECT ps_partkey,
       COUNT(DISTINCT ps_suppkey) AS supplier_count
FROM partsupp
GROUP BY ps_partkey
HAVING COUNT(DISTINCT ps_suppkey) > (
    SELECT AVG(cnt) FROM (
        SELECT COUNT(DISTINCT ps_suppkey) AS cnt
        FROM partsupp
        GROUP BY ps_partkey
    ) AS sub
)
ORDER BY supplier_count DESC;

-- Q042: Nations whose total supply exceeds total demand
SELECT n_name
FROM nation
WHERE (
    SELECT SUM(ps_availqty)
    FROM partsupp
    JOIN supplier ON ps_suppkey = s_suppkey
    WHERE s_nationkey = n_nationkey
) > (
    SELECT SUM(l_quantity)
    FROM lineitem
    JOIN orders   ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey  = c_custkey
    WHERE c_nationkey = n_nationkey
)
ORDER BY n_name;

-- Q043: Lineitems shipped later than any item in the same order
SELECT l_orderkey,
       l_linenumber,
       l_shipdate
FROM lineitem l
WHERE l_shipdate = (
    SELECT MAX(l2.l_shipdate)
    FROM lineitem l2
    WHERE l2.l_orderkey = l.l_orderkey
)
ORDER BY l_orderkey;

-- Q044: Customers whose first order was their largest
SELECT o_custkey
FROM orders o
WHERE o_totalprice = (SELECT MAX(o2.o_totalprice) FROM orders o2 WHERE o2.o_custkey = o.o_custkey)
  AND o_orderdate  = (SELECT MIN(o3.o_orderdate)  FROM orders o3 WHERE o3.o_custkey = o.o_custkey)
ORDER BY o_custkey;

-- Q045: Parts with highest price variance across suppliers
SELECT ps_partkey,
       MAX(ps_supplycost) - MIN(ps_supplycost) AS cost_spread,
       MAX(ps_supplycost)                      AS max_cost,
       MIN(ps_supplycost)                      AS min_cost
FROM partsupp
GROUP BY ps_partkey
ORDER BY cost_spread DESC
LIMIT 20;

-- Q046: Orders below the 10th percentile in value per priority group
SELECT o_orderkey,
       o_orderpriority,
       o_totalprice
FROM orders o
WHERE o_totalprice < (
    SELECT MIN_10PCT
    FROM (
        SELECT o_orderpriority,
               MIN(o_totalprice) + (MAX(o_totalprice) - MIN(o_totalprice)) * 0.10 AS MIN_10PCT
        FROM orders
        GROUP BY o_orderpriority
    ) AS p
    WHERE p.o_orderpriority = o.o_orderpriority
)
ORDER BY o_orderpriority, o_totalprice;

-- Q047: Suppliers whose revenue exceeds any competitor in their nation
SELECT DISTINCT s_suppkey,
       s_name
FROM supplier s
JOIN (
    SELECT l_suppkey,
           SUM(l_extendedprice * (1 - l_discount)) AS revenue
    FROM lineitem
    GROUP BY l_suppkey
) AS sr ON s_suppkey = sr.l_suppkey
WHERE sr.revenue > ALL (
    SELECT sr2.revenue
    FROM supplier s2
    JOIN (
        SELECT l_suppkey,
               SUM(l_extendedprice * (1 - l_discount)) AS revenue
        FROM lineitem GROUP BY l_suppkey
    ) AS sr2 ON s2.s_suppkey = sr2.l_suppkey
    WHERE s2.s_nationkey = s.s_nationkey
      AND s2.s_suppkey   <> s.s_suppkey
);

-- Q048: Customer with lowest account balance in each nation
SELECT n_name,
       c_custkey,
       c_name,
       c_acctbal
FROM customer
JOIN nation ON c_nationkey = n_nationkey
WHERE c_acctbal = (
    SELECT MIN(c2.c_acctbal)
    FROM customer c2
    WHERE c2.c_nationkey = c_nationkey
)
ORDER BY n_name;

-- Q049: Orders that have at least one returned and one accepted item
SELECT DISTINCT o_orderkey
FROM orders
WHERE EXISTS (
    SELECT 1 FROM lineitem l1
    WHERE l1.l_orderkey = o_orderkey AND l1.l_returnflag = 'R'
)
AND EXISTS (
    SELECT 1 FROM lineitem l2
    WHERE l2.l_orderkey = o_orderkey AND l2.l_returnflag = 'A'
)
ORDER BY o_orderkey
LIMIT 20;

-- Q050: Parts ordered every year in the dataset
SELECT l_partkey
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
GROUP BY l_partkey
HAVING COUNT(DISTINCT YEAR(o_orderdate)) = (
    SELECT COUNT(DISTINCT YEAR(o2.o_orderdate)) FROM orders o2
)
ORDER BY l_partkey;

-- ============================================================
-- SECTION 3: UNION / UNION ALL Patterns (Q051-Q075)
-- ============================================================

-- Q051: All entities (customers and suppliers) with their nation
SELECT 'Customer' AS entity_type,
       c_name     AS entity_name,
       n_name     AS nation
FROM customer
JOIN nation ON c_nationkey = n_nationkey
UNION ALL
SELECT 'Supplier',
       s_name,
       n_name
FROM supplier
JOIN nation ON s_nationkey = n_nationkey
ORDER BY nation, entity_type;

-- Q052: High-value customers UNION high-balance customers
SELECT c_custkey, c_name, 'High Spender' AS tag
FROM customer
JOIN (
    SELECT o_custkey, SUM(o_totalprice) AS total
    FROM orders GROUP BY o_custkey
) AS ts ON c_custkey = o_custkey
WHERE total > 500000
UNION
SELECT c_custkey, c_name, 'High Balance'
FROM customer
WHERE c_acctbal > 9000
ORDER BY c_custkey;

-- Q053: Top parts by revenue UNION top parts by volume
(SELECT l_partkey, 'Top Revenue' AS category, SUM(l_extendedprice * (1 - l_discount)) AS metric
FROM lineitem
GROUP BY l_partkey
ORDER BY metric DESC
LIMIT 10)
UNION ALL
(SELECT l_partkey, 'Top Volume', SUM(l_quantity)
FROM lineitem
GROUP BY l_partkey
ORDER BY SUM(l_quantity) DESC
LIMIT 10);

-- Q054: Customers with no orders UNION customers with 1 order
SELECT c_custkey, c_name, 0 AS order_count
FROM customer
WHERE c_custkey NOT IN (SELECT DISTINCT o_custkey FROM orders)
UNION ALL
SELECT c_custkey, c_name, 1
FROM customer
JOIN orders ON c_custkey = o_custkey
GROUP BY c_custkey, c_name
HAVING COUNT(*) = 1
ORDER BY order_count, c_custkey;

-- Q055: Urgent + high-priority orders combined
SELECT o_orderkey, o_custkey, o_totalprice, '1-URGENT' AS priority_label
FROM orders
WHERE o_orderpriority = '1-URGENT'
UNION ALL
SELECT o_orderkey, o_custkey, o_totalprice, '2-HIGH'
FROM orders
WHERE o_orderpriority = '2-HIGH'
ORDER BY o_totalprice DESC
LIMIT 30;

-- Q056: Nations that are both top-5 in customers AND top-5 in suppliers
SELECT n_name FROM (
    SELECT n_name, COUNT(*) AS cnt
    FROM customer JOIN nation ON c_nationkey = n_nationkey
    GROUP BY n_name
    ORDER BY cnt DESC LIMIT 5
) AS top_cust
WHERE n_name IN (
    SELECT n_name FROM (
        SELECT n_name, COUNT(*) AS cnt
        FROM supplier JOIN nation ON s_nationkey = n_nationkey
        GROUP BY n_name
        ORDER BY cnt DESC LIMIT 5
    ) AS top_supp
);

-- Q057: Lineitems returned OR late (union of problem items)
SELECT l_orderkey, l_linenumber, 'Returned' AS issue
FROM lineitem
WHERE l_returnflag = 'R'
UNION ALL
SELECT l_orderkey, l_linenumber, 'Late Shipment'
FROM lineitem
WHERE l_shipdate > l_commitdate
ORDER BY l_orderkey, l_linenumber
LIMIT 30;

-- Q058: All high-value transactions across order types
SELECT o_orderkey, o_totalprice, o_orderpriority, 'Order' AS source
FROM orders
WHERE o_totalprice > 300000
UNION ALL
SELECT l_orderkey, l_extendedprice, l_shipmode, 'Lineitem'
FROM lineitem
WHERE l_extendedprice > 100000
ORDER BY o_totalprice DESC
LIMIT 20;

-- Q059: Part brands appearing in both EUROPE and ASIA regions
SELECT DISTINCT p_brand
FROM lineitem
JOIN part    ON l_partkey  = p_partkey
JOIN orders  ON l_orderkey = o_orderkey
JOIN customer ON o_custkey = c_custkey
JOIN nation  ON c_nationkey = n_nationkey
JOIN region  ON n_regionkey = r_regionkey
WHERE r_name = 'EUROPE'
AND p_brand IN (
    SELECT DISTINCT p_brand
    FROM lineitem
    JOIN part    ON l_partkey  = p_partkey
    JOIN orders  ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey = c_custkey
    JOIN nation  ON c_nationkey = n_nationkey
    JOIN region  ON n_regionkey = r_regionkey
    WHERE r_name = 'ASIA'
)
ORDER BY p_brand;

-- Q060: Suppliers in AMERICA or EUROPE with high account balance
SELECT s_suppkey, s_name, s_acctbal, r_name
FROM supplier
JOIN nation ON s_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
WHERE r_name = 'AMERICA' AND s_acctbal > 7000
UNION ALL
SELECT s_suppkey, s_name, s_acctbal, r_name
FROM supplier
JOIN nation ON s_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
WHERE r_name = 'EUROPE' AND s_acctbal > 7000
ORDER BY s_acctbal DESC;

-- Q061: Revenue summary UNION cost summary per nation
SELECT n_name, 'Revenue' AS type, SUM(l_extendedprice * (1 - l_discount)) AS amount
FROM lineitem
JOIN orders   ON l_orderkey = o_orderkey
JOIN customer ON o_custkey  = c_custkey
JOIN nation   ON c_nationkey = n_nationkey
GROUP BY n_name
UNION ALL
SELECT n_name, 'Supply Cost', SUM(ps_supplycost * ps_availqty)
FROM partsupp
JOIN supplier ON ps_suppkey = s_suppkey
JOIN nation   ON s_nationkey = n_nationkey
GROUP BY n_name
ORDER BY n_name, type;

-- Q062: Brand performance union: top 5 by revenue vs top 5 by qty
(SELECT p_brand, 'Top Revenue' AS category
FROM lineitem JOIN part ON l_partkey = p_partkey
GROUP BY p_brand
ORDER BY SUM(l_extendedprice * (1 - l_discount)) DESC
LIMIT 5)
UNION
(SELECT p_brand, 'Top Volume'
FROM lineitem JOIN part ON l_partkey = p_partkey
GROUP BY p_brand
ORDER BY SUM(l_quantity) DESC
LIMIT 5);

-- Q063: Orders with both MAIL and SHIP mode lineitems
SELECT DISTINCT l1.l_orderkey
FROM lineitem l1
WHERE l1.l_shipmode = 'MAIL'
  AND l1.l_orderkey IN (
      SELECT l2.l_orderkey FROM lineitem l2 WHERE l2.l_shipmode = 'SHIP'
  )
ORDER BY l1.l_orderkey
LIMIT 20;

-- Q064: Combined nation activity score (customers + suppliers + orders)
SELECT n_name,
       cust_count,
       supp_count,
       order_count,
       cust_count + supp_count + order_count AS activity_score
FROM (
    SELECT n_name,
           COUNT(DISTINCT c_custkey) AS cust_count
    FROM customer JOIN nation ON c_nationkey = n_nationkey
    GROUP BY n_name
) AS c
JOIN (
    SELECT n_name,
           COUNT(DISTINCT s_suppkey) AS supp_count
    FROM supplier JOIN nation ON s_nationkey = n_nationkey
    GROUP BY n_name
) AS s USING (n_name)
JOIN (
    SELECT n_name,
           COUNT(DISTINCT o_orderkey) AS order_count
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    GROUP BY n_name
) AS o USING (n_name)
ORDER BY activity_score DESC;

-- Q065: Lineitems that were both discounted and taxed above average
SELECT l_orderkey,
       l_linenumber,
       l_discount,
       l_tax
FROM lineitem
WHERE l_discount > (SELECT AVG(l_discount) FROM lineitem)
  AND l_tax      > (SELECT AVG(l_tax)      FROM lineitem)
ORDER BY l_discount DESC, l_tax DESC
LIMIT 20;

-- Q066: UNION of best and worst orders per customer
SELECT o_custkey, o_orderkey, o_totalprice, 'Best' AS label
FROM orders o
WHERE o_totalprice = (
    SELECT MAX(o2.o_totalprice) FROM orders o2 WHERE o2.o_custkey = o.o_custkey
)
UNION ALL
SELECT o_custkey, o_orderkey, o_totalprice, 'Worst'
FROM orders o
WHERE o_totalprice = (
    SELECT MIN(o2.o_totalprice) FROM orders o2 WHERE o2.o_custkey = o.o_custkey
)
ORDER BY o_custkey, label;

-- Q067: Parts ordered in Q1 UNION parts ordered in Q4
SELECT DISTINCT l_partkey, 'Q1' AS quarter
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
WHERE QUARTER(o_orderdate) = 1
UNION
SELECT DISTINCT l_partkey, 'Q4'
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
WHERE QUARTER(o_orderdate) = 4
ORDER BY l_partkey, quarter;

-- Q068: Customers from AMERICA UNION suppliers from AMERICA
SELECT 'Customer' AS role, c_name AS name, c_acctbal AS balance
FROM customer
JOIN nation ON c_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
WHERE r_name = 'AMERICA'
UNION ALL
SELECT 'Supplier', s_name, s_acctbal
FROM supplier
JOIN nation ON s_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
WHERE r_name = 'AMERICA'
ORDER BY balance DESC
LIMIT 20;

-- Q069: High-discount items UNION high-tax items
SELECT l_orderkey, l_linenumber, l_discount AS value, 'High Discount' AS flag
FROM lineitem WHERE l_discount >= 0.09
UNION ALL
SELECT l_orderkey, l_linenumber, l_tax, 'High Tax'
FROM lineitem WHERE l_tax >= 0.07
ORDER BY value DESC
LIMIT 30;

-- Q070: All order keys with both urgent priority and returned items
SELECT o_orderkey
FROM orders
WHERE o_orderpriority = '1-URGENT'
AND o_orderkey IN (
    SELECT DISTINCT l_orderkey
    FROM lineitem
    WHERE l_returnflag = 'R'
)
ORDER BY o_orderkey
LIMIT 20;

-- Q071: Customers in nations that have both high avg balance AND high order count
SELECT n_name
FROM (
    SELECT n_name
    FROM customer JOIN nation ON c_nationkey = n_nationkey
    GROUP BY n_name
    HAVING AVG(c_acctbal) > 4500
) AS high_balance
WHERE n_name IN (
    SELECT n_name
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    GROUP BY n_name
    HAVING COUNT(*) > 5000
);

-- Q072: Revenue in 1994 UNION revenue in 1997 for comparison
SELECT '1994' AS yr, n_name, SUM(o_totalprice) AS revenue
FROM orders
JOIN customer ON o_custkey = c_custkey
JOIN nation   ON c_nationkey = n_nationkey
WHERE YEAR(o_orderdate) = 1994
GROUP BY n_name
UNION ALL
SELECT '1997', n_name, SUM(o_totalprice)
FROM orders
JOIN customer ON o_custkey = c_custkey
JOIN nation   ON c_nationkey = n_nationkey
WHERE YEAR(o_orderdate) = 1997
GROUP BY n_name
ORDER BY n_name, yr;

-- Q073: Parts that appear in both standard and economy types
SELECT DISTINCT p_partkey
FROM part
WHERE p_type LIKE 'STANDARD%'
AND p_partkey IN (
    SELECT p_partkey FROM part WHERE p_type LIKE 'ECONOMY%'
);

-- Q074: Ship modes used in both 1994 and 1998
SELECT DISTINCT l_shipmode
FROM lineitem
WHERE YEAR(l_shipdate) = 1994
AND l_shipmode IN (
    SELECT DISTINCT l_shipmode
    FROM lineitem
    WHERE YEAR(l_shipdate) = 1998
)
ORDER BY l_shipmode;

-- Q075: Customers who ordered in both Q1 and Q3 of same year
SELECT DISTINCT o1.o_custkey
FROM orders o1
JOIN orders o2
  ON o1.o_custkey = o2.o_custkey
  AND YEAR(o1.o_orderdate) = YEAR(o2.o_orderdate)
  AND QUARTER(o1.o_orderdate) = 1
  AND QUARTER(o2.o_orderdate) = 3
ORDER BY o1.o_custkey;

-- ============================================================
-- SECTION 4: EXISTS / NOT EXISTS (Q076-Q100)
-- ============================================================

-- Q076: Customers who have placed at least one urgent order
SELECT c_custkey,
       c_name
FROM customer
WHERE EXISTS (
    SELECT 1
    FROM orders
    WHERE o_custkey = c_custkey
      AND o_orderpriority = '1-URGENT'
)
ORDER BY c_custkey;

-- Q077: Suppliers who have never had a returned item
SELECT s_suppkey,
       s_name
FROM supplier
WHERE NOT EXISTS (
    SELECT 1
    FROM lineitem
    WHERE l_suppkey = s_suppkey
      AND l_returnflag = 'R'
)
ORDER BY s_suppkey;

-- Q078: Parts that have been ordered by customers in ASIA
SELECT DISTINCT p_partkey,
       p_name
FROM part
WHERE EXISTS (
    SELECT 1
    FROM lineitem
    JOIN orders   ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey  = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    JOIN region   ON n_regionkey = r_regionkey
    WHERE l_partkey = p_partkey
      AND r_name = 'ASIA'
)
ORDER BY p_partkey;

-- Q079: Nations with no suppliers
SELECT n_name
FROM nation
WHERE NOT EXISTS (
    SELECT 1
    FROM supplier
    WHERE s_nationkey = n_nationkey
)
ORDER BY n_name;

-- Q080: Customers who placed orders in every quarter of 1996
SELECT o_custkey
FROM orders
WHERE YEAR(o_orderdate) = 1996
GROUP BY o_custkey
HAVING COUNT(DISTINCT QUARTER(o_orderdate)) = 4
ORDER BY o_custkey;

-- Q081: Parts supplied by at least 3 different suppliers
SELECT ps_partkey
FROM partsupp
GROUP BY ps_partkey
HAVING COUNT(DISTINCT ps_suppkey) >= 3
ORDER BY ps_partkey;

-- Q082: Suppliers who have supplied every part type
SELECT s_suppkey,
       s_name
FROM supplier
WHERE NOT EXISTS (
    SELECT DISTINCT p_type FROM part
    WHERE NOT EXISTS (
        SELECT 1
        FROM partsupp
        JOIN part p2 ON ps_partkey = p2.p_partkey
        WHERE ps_suppkey = s_suppkey
          AND p2.p_type = p_type
    )
)
ORDER BY s_suppkey;

-- Q083: Orders with all lineitems using the same ship mode
SELECT o_orderkey
FROM orders
WHERE EXISTS (
    SELECT l_shipmode
    FROM lineitem
    WHERE l_orderkey = o_orderkey
    GROUP BY l_shipmode
    HAVING COUNT(DISTINCT l_shipmode) = 1
)
AND (SELECT COUNT(DISTINCT l_shipmode) FROM lineitem WHERE l_orderkey = o_orderkey) = 1
ORDER BY o_orderkey
LIMIT 20;

-- Q084: Customers who exist in both BUILDING and MACHINERY segments (sanity check — should be 0)
SELECT c_custkey
FROM customer
WHERE c_mktsegment = 'BUILDING'
AND c_custkey IN (
    SELECT c_custkey FROM customer WHERE c_mktsegment = 'MACHINERY'
);

-- Q085: Suppliers who supply parts to customers in the same nation
SELECT DISTINCT s_suppkey,
       s_name
FROM supplier
WHERE EXISTS (
    SELECT 1
    FROM lineitem
    JOIN orders   ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey  = c_custkey
    WHERE l_suppkey = s_suppkey
      AND c_nationkey = s_nationkey
)
ORDER BY s_suppkey;

-- Q086: Parts that have never been ordered in large quantity (>40)
SELECT p_partkey,
       p_name
FROM part
WHERE NOT EXISTS (
    SELECT 1
    FROM lineitem
    WHERE l_partkey = p_partkey
      AND l_quantity > 40
)
ORDER BY p_partkey
LIMIT 20;

-- Q087: Customers who placed orders in all 7 years (1992-1998)
SELECT o_custkey
FROM orders
GROUP BY o_custkey
HAVING COUNT(DISTINCT YEAR(o_orderdate)) = 7
ORDER BY o_custkey;

-- Q088: Regions that have at least one supplier AND one customer
SELECT r_name
FROM region
WHERE EXISTS (
    SELECT 1 FROM supplier
    JOIN nation ON s_nationkey = n_nationkey
    WHERE n_regionkey = r_regionkey
)
AND EXISTS (
    SELECT 1 FROM customer
    JOIN nation ON c_nationkey = n_nationkey
    WHERE n_regionkey = r_regionkey
)
ORDER BY r_name;

-- Q089: Orders that contain a part from every major brand group
SELECT l_orderkey
FROM lineitem
JOIN part ON l_partkey = p_partkey
GROUP BY l_orderkey
HAVING COUNT(DISTINCT SUBSTRING(p_brand, 1, 6)) >= 5
ORDER BY l_orderkey
LIMIT 20;

-- Q090: Suppliers who supply more than 100 distinct parts
SELECT s_suppkey,
       s_name,
       COUNT(DISTINCT ps_partkey) AS part_count
FROM supplier
JOIN partsupp ON s_suppkey = ps_suppkey
GROUP BY s_suppkey, s_name
HAVING COUNT(DISTINCT ps_partkey) > 100
ORDER BY part_count DESC;

-- Q091: Customers with no negative account balance orders (all orders positive)
SELECT c_custkey,
       c_name
FROM customer
WHERE c_acctbal >= 0
  AND NOT EXISTS (
      SELECT 1
      FROM orders
      WHERE o_custkey = c_custkey
        AND o_totalprice <= 0
  )
ORDER BY c_custkey
LIMIT 20;

-- Q092: Parts ordered with all 7 ship modes
SELECT l_partkey
FROM lineitem
GROUP BY l_partkey
HAVING COUNT(DISTINCT l_shipmode) = 7
ORDER BY l_partkey;

-- Q093: Customers who placed their largest order in 1997
SELECT o_custkey
FROM orders o
WHERE YEAR(o_orderdate) = 1997
  AND o_totalprice = (
      SELECT MAX(o2.o_totalprice)
      FROM orders o2
      WHERE o2.o_custkey = o.o_custkey
  )
ORDER BY o_custkey;

-- Q094: Nations where every supplier has positive account balance
SELECT n_name
FROM nation
WHERE NOT EXISTS (
    SELECT 1
    FROM supplier
    WHERE s_nationkey = n_nationkey
      AND s_acctbal <= 0
)
ORDER BY n_name;

-- Q095: Parts ordered by customers in AMERICA but supplied from EUROPE
SELECT DISTINCT l_partkey
FROM lineitem
JOIN orders   ON l_orderkey = o_orderkey
JOIN customer ON o_custkey  = c_custkey
JOIN nation n1 ON c_nationkey = n1.n_nationkey
JOIN region r1 ON n1.n_regionkey = r1.r_regionkey
JOIN supplier ON l_suppkey = s_suppkey
JOIN nation n2 ON s_nationkey = n2.n_nationkey
JOIN region r2 ON n2.n_regionkey = r2.r_regionkey
WHERE r1.r_name = 'AMERICA'
  AND r2.r_name = 'EUROPE'
ORDER BY l_partkey;

-- Q096: Customers who placed orders with all 5 priority levels
SELECT o_custkey
FROM orders
GROUP BY o_custkey
HAVING COUNT(DISTINCT o_orderpriority) = 5
ORDER BY o_custkey;

-- Q097: Suppliers who supplied in both 1993 and 1997
SELECT DISTINCT l_suppkey
FROM lineitem
WHERE YEAR(l_shipdate) = 1993
AND l_suppkey IN (
    SELECT DISTINCT l_suppkey FROM lineitem WHERE YEAR(l_shipdate) = 1997
)
ORDER BY l_suppkey;

-- Q098: Parts with supply cost range > 500 across suppliers
SELECT ps_partkey,
       MAX(ps_supplycost) - MIN(ps_supplycost) AS cost_range
FROM partsupp
GROUP BY ps_partkey
HAVING MAX(ps_supplycost) - MIN(ps_supplycost) > 500
ORDER BY cost_range DESC;

-- Q099: Customers whose total discount savings > 10000
SELECT o_custkey,
       SUM(l_extendedprice * l_discount) AS discount_savings
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
GROUP BY o_custkey
HAVING SUM(l_extendedprice * l_discount) > 10000
ORDER BY discount_savings DESC;

-- Q100: All orders with at least 6 lineitems
SELECT o_orderkey,
       COUNT(*) AS lineitem_count,
       SUM(l_extendedprice * (1 - l_discount)) AS order_revenue
FROM lineitem
GROUP BY o_orderkey
HAVING COUNT(*) >= 6
ORDER BY lineitem_count DESC, order_revenue DESC;

-- ============================================================
-- SECTION 5: Multi-level Subqueries & Derived Tables (Q101-Q125)
-- ============================================================

-- Q101: Revenue share per customer decile
SELECT decile,
       COUNT(*)          AS customers,
       SUM(total_spend)  AS decile_revenue,
       AVG(total_spend)  AS avg_spend
FROM (
    SELECT o_custkey,
           SUM(o_totalprice) AS total_spend,
           NTILE(10) OVER (ORDER BY SUM(o_totalprice)) AS decile
    FROM orders
    GROUP BY o_custkey
) AS deciled
GROUP BY decile
ORDER BY decile;

-- Q102: Nations ranked by weighted supply score
SELECT n_name,
       total_parts,
       total_stock,
       avg_cost,
       RANK() OVER (ORDER BY total_stock * (1.0 / NULLIF(avg_cost, 0)) DESC) AS supply_score_rank
FROM (
    SELECT n_name,
           COUNT(DISTINCT ps_partkey)     AS total_parts,
           SUM(ps_availqty)               AS total_stock,
           AVG(ps_supplycost)             AS avg_cost
    FROM partsupp
    JOIN supplier ON ps_suppkey = s_suppkey
    JOIN nation   ON s_nationkey = n_nationkey
    GROUP BY n_name
) AS ns
ORDER BY supply_score_rank;

-- Q103: Customer revenue tier analysis (3-level nesting)
-- Note: MySQL 8 does not support PERCENTILE_CONT; using NTILE(4) to
-- approximate Q1/Q3 quartile boundaries per bucket.
SELECT tier,
       COUNT(*)         AS customer_count,
       AVG(total_spend) AS avg_spend,
       SUM(total_spend) AS tier_revenue
FROM (
    SELECT o_custkey,
           total_spend,
           CASE
             WHEN ntile_bucket = 1      THEN 'Low'
             WHEN ntile_bucket IN (2,3) THEN 'Mid'
             ELSE                            'High'
           END AS tier
    FROM (
        SELECT o_custkey,
               total_spend,
               NTILE(4) OVER (ORDER BY total_spend) AS ntile_bucket
        FROM (
            SELECT o_custkey, SUM(o_totalprice) AS total_spend
            FROM orders
            GROUP BY o_custkey
        ) AS base
    ) AS with_ntile
) AS tiered
GROUP BY tier
ORDER BY avg_spend;

-- Q104: Part supply efficiency (demand coverage ratio)
SELECT p_brand,
       p_type,
       SUM(total_stock)   AS total_supply,
       SUM(total_demand)  AS total_demand,
       ROUND(SUM(total_stock) / NULLIF(SUM(total_demand), 0), 2) AS coverage_ratio
FROM (
    SELECT ps_partkey,
           SUM(ps_availqty) AS total_stock
    FROM partsupp
    GROUP BY ps_partkey
) AS supply
JOIN (
    SELECT l_partkey,
           SUM(l_quantity) AS total_demand
    FROM lineitem
    GROUP BY l_partkey
) AS demand ON supply.ps_partkey = demand.l_partkey
JOIN part ON ps_partkey = p_partkey
GROUP BY p_brand, p_type
ORDER BY coverage_ratio;

-- Q105: Supplier profitability index
SELECT s_suppkey,
       s_name,
       revenue,
       cost,
       ROUND(revenue / NULLIF(cost, 0), 4) AS profitability_index
FROM (
    SELECT l_suppkey,
           SUM(l_extendedprice * (1 - l_discount)) AS revenue
    FROM lineitem
    GROUP BY l_suppkey
) AS rev
JOIN (
    SELECT ps_suppkey,
           SUM(ps_supplycost * ps_availqty) AS cost
    FROM partsupp
    GROUP BY ps_suppkey
) AS cst ON rev.l_suppkey = cst.ps_suppkey
JOIN supplier ON l_suppkey = s_suppkey
ORDER BY profitability_index DESC
LIMIT 20;

-- Q106: Region-level order stats with nation breakdown
SELECT r_name,
       n_name,
       orders_count,
       total_revenue,
       total_revenue / SUM(total_revenue) OVER (PARTITION BY r_name) * 100 AS region_share
FROM (
    SELECT r_name,
           n_name,
           COUNT(DISTINCT o_orderkey) AS orders_count,
           SUM(o_totalprice)          AS total_revenue
    FROM orders
    JOIN customer ON o_custkey  = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    JOIN region   ON n_regionkey = r_regionkey
    GROUP BY r_name, n_name
) AS rn
ORDER BY r_name, total_revenue DESC;

-- Q107: Orders in the top 5% by value per year
SELECT o_orderkey,
       o_custkey,
       YEAR(o_orderdate) AS order_year,
       o_totalprice,
       pct_rank
FROM (
    SELECT *,
           PERCENT_RANK() OVER (
               PARTITION BY YEAR(o_orderdate)
               ORDER BY o_totalprice
           ) AS pct_rank
    FROM orders
) AS ranked
WHERE pct_rank >= 0.95
ORDER BY order_year, o_totalprice DESC;

-- Q108: Parts with highest return rate
SELECT l_partkey,
       p_name,
       total_ordered,
       total_returned,
       ROUND(total_returned / NULLIF(total_ordered, 0) * 100, 2) AS return_rate_pct
FROM (
    SELECT l_partkey,
           COUNT(*)                                        AS total_ordered,
           SUM(CASE WHEN l_returnflag = 'R' THEN 1 END)   AS total_returned
    FROM lineitem
    GROUP BY l_partkey
) AS return_stats
JOIN part ON l_partkey = p_partkey
ORDER BY return_rate_pct DESC
LIMIT 20;

-- Q109: Customer activity heatmap by month and segment
SELECT c_mktsegment,
       MONTH(o_orderdate) AS order_month,
       COUNT(*)           AS order_count,
       SUM(o_totalprice)  AS revenue
FROM orders
JOIN customer ON o_custkey = c_custkey
GROUP BY c_mktsegment, MONTH(o_orderdate)
ORDER BY c_mktsegment, order_month;

-- Q110: Supplier market concentration (HHI-style index)
SELECT n_name,
       ROUND(SUM(POWER(revenue_share, 2)), 4) AS hhi_index
FROM (
    SELECT n_name,
           l_suppkey,
           nation_revenue,
           supp_revenue,
           supp_revenue / nation_revenue AS revenue_share
    FROM (
        SELECT n_name,
               l_suppkey,
               SUM(l_extendedprice * (1 - l_discount)) AS supp_revenue,
               SUM(SUM(l_extendedprice * (1 - l_discount)))
                   OVER (PARTITION BY n_name) AS nation_revenue
        FROM lineitem
        JOIN supplier ON l_suppkey = s_suppkey
        JOIN nation   ON s_nationkey = n_nationkey
        GROUP BY n_name, l_suppkey
    ) AS shares
) AS hhi
GROUP BY n_name
ORDER BY hhi_index DESC;

-- Q111: Avg ship lag by part size bucket
SELECT size_bucket,
       AVG(ship_lag) AS avg_ship_lag_days,
       COUNT(*)      AS item_count
FROM (
    SELECT CASE
             WHEN p_size <= 10  THEN 'XSmall'
             WHEN p_size <= 20  THEN 'Small'
             WHEN p_size <= 35  THEN 'Medium'
             WHEN p_size <= 45  THEN 'Large'
             ELSE 'XLarge'
           END AS size_bucket,
           DATEDIFF(l_shipdate, o_orderdate) AS ship_lag
    FROM lineitem
    JOIN orders ON l_orderkey = o_orderkey
    JOIN part   ON l_partkey  = p_partkey
) AS bucketed
GROUP BY size_bucket
ORDER BY avg_ship_lag_days;

-- Q112: Rolling 12-month customer acquisition rate
SELECT order_month,
       new_customers,
       SUM(new_customers) OVER (
           ORDER BY order_month
           ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
       ) AS rolling_12m_new_customers
FROM (
    SELECT DATE_FORMAT(first_order, '%Y-%m') AS order_month,
           COUNT(*) AS new_customers
    FROM (
        SELECT o_custkey,
               MIN(o_orderdate) AS first_order
        FROM orders
        GROUP BY o_custkey
    ) AS first_orders
    GROUP BY DATE_FORMAT(first_order, '%Y-%m')
) AS monthly
ORDER BY order_month;

-- Q113: Ship mode efficiency (revenue per unit shipped)
SELECT l_shipmode,
       total_revenue,
       total_qty,
       ROUND(total_revenue / total_qty, 2) AS revenue_per_unit
FROM (
    SELECT l_shipmode,
           SUM(l_extendedprice * (1 - l_discount)) AS total_revenue,
           SUM(l_quantity)                          AS total_qty
    FROM lineitem
    GROUP BY l_shipmode
) AS mode_stats
ORDER BY revenue_per_unit DESC;

-- Q114: Customer segmentation by recency, frequency, value (RFV)
SELECT o_custkey,
       recency_days,
       order_frequency,
       total_value,
       NTILE(3) OVER (ORDER BY recency_days DESC)  AS recency_score,
       NTILE(3) OVER (ORDER BY order_frequency)    AS frequency_score,
       NTILE(3) OVER (ORDER BY total_value)        AS value_score
FROM (
    SELECT o_custkey,
           DATEDIFF('1998-12-31', MAX(o_orderdate)) AS recency_days,
           COUNT(*)                                  AS order_frequency,
           SUM(o_totalprice)                         AS total_value
    FROM orders
    GROUP BY o_custkey
) AS rfv
ORDER BY value_score DESC, frequency_score DESC
LIMIT 30;

-- Q115: Part price elasticity proxy (price vs quantity ordered)
SELECT p_partkey,
       p_name,
       avg_price,
       total_qty,
       RANK() OVER (ORDER BY avg_price DESC)  AS price_rank,
       RANK() OVER (ORDER BY total_qty DESC)  AS qty_rank
FROM (
    SELECT l_partkey AS p_partkey,
           AVG(l_extendedprice / l_quantity) AS avg_price,
           SUM(l_quantity)                   AS total_qty
    FROM lineitem
    GROUP BY l_partkey
) AS price_qty
JOIN part ON p_partkey = l_partkey
ORDER BY price_rank
LIMIT 30;

-- Q116: Supplier reliability score (% on-time deliveries)
SELECT l_suppkey,
       s_name,
       total_shipments,
       on_time_shipments,
       ROUND(on_time_shipments / NULLIF(total_shipments, 0) * 100, 2) AS on_time_pct
FROM (
    SELECT l_suppkey,
           COUNT(*)                                              AS total_shipments,
           SUM(CASE WHEN l_shipdate <= l_commitdate THEN 1 END) AS on_time_shipments
    FROM lineitem
    GROUP BY l_suppkey
) AS reliability
JOIN supplier ON l_suppkey = s_suppkey
ORDER BY on_time_pct DESC;

-- Q117: Nation pair trade imbalance
SELECT supplier_nation,
       customer_nation,
       export_value,
       import_value,
       export_value - import_value AS trade_balance
FROM (
    SELECT n1.n_name AS supplier_nation,
           n2.n_name AS customer_nation,
           SUM(l_extendedprice * (1 - l_discount)) AS export_value
    FROM lineitem
    JOIN orders   ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey  = c_custkey
    JOIN supplier ON l_suppkey  = s_suppkey
    JOIN nation n1 ON s_nationkey = n1.n_nationkey
    JOIN nation n2 ON c_nationkey = n2.n_nationkey
    WHERE n1.n_nationkey <> n2.n_nationkey
    GROUP BY n1.n_name, n2.n_name
) AS exports
JOIN (
    SELECT n2.n_name AS supplier_nation,
           n1.n_name AS customer_nation,
           SUM(l_extendedprice * (1 - l_discount)) AS import_value
    FROM lineitem
    JOIN orders   ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey  = c_custkey
    JOIN supplier ON l_suppkey  = s_suppkey
    JOIN nation n1 ON s_nationkey = n1.n_nationkey
    JOIN nation n2 ON c_nationkey = n2.n_nationkey
    WHERE n1.n_nationkey <> n2.n_nationkey
    GROUP BY n2.n_name, n1.n_name
) AS imports USING (supplier_nation, customer_nation)
ORDER BY ABS(trade_balance) DESC
LIMIT 15;

-- Q118: Weekly order velocity (orders per week per year)
SELECT order_year,
       order_week,
       order_count,
       AVG(order_count) OVER (
           PARTITION BY order_year
           ORDER BY order_week
           ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
       ) AS smoothed_weekly_orders
FROM (
    SELECT YEAR(o_orderdate)       AS order_year,
           WEEK(o_orderdate)       AS order_week,
           COUNT(*)                 AS order_count
    FROM orders
    GROUP BY YEAR(o_orderdate), WEEK(o_orderdate)
) AS weekly
ORDER BY order_year, order_week;

-- Q119: Multi-level part category revenue roll-up
SELECT material_type,
       p_brand,
       p_type,
       SUM(revenue) AS total_revenue
FROM (
    SELECT SUBSTRING_INDEX(p_type, ' ', -1) AS material_type,
           p_brand,
           p_type,
           l_extendedprice * (1 - l_discount) AS revenue
    FROM lineitem
    JOIN part ON l_partkey = p_partkey
) AS exploded
GROUP BY material_type, p_brand, p_type
ORDER BY material_type, total_revenue DESC;

-- Q120: Order value anomaly detection (> 3 std deviations from mean)
SELECT o_orderkey,
       o_custkey,
       o_totalprice,
       global_mean,
       global_std,
       (o_totalprice - global_mean) / global_std AS z_score
FROM orders
CROSS JOIN (
    SELECT AVG(o_totalprice)    AS global_mean,
           STDDEV(o_totalprice) AS global_std
    FROM orders
) AS stats
WHERE ABS((o_totalprice - global_mean) / global_std) > 3
ORDER BY z_score DESC;

-- Q121: Cumulative market share by supplier (top suppliers = 80% revenue)
SELECT l_suppkey,
       s_name,
       supplier_revenue,
       cumulative_revenue,
       cumulative_revenue / NULLIF(total_revenue, 0) * 100 AS cumulative_pct
FROM (
    SELECT l_suppkey,
           supplier_revenue,
           SUM(supplier_revenue) OVER (ORDER BY supplier_revenue DESC) AS cumulative_revenue,
           SUM(supplier_revenue) OVER ()                                AS total_revenue
    FROM (
        SELECT l_suppkey,
               SUM(l_extendedprice * (1 - l_discount)) AS supplier_revenue
        FROM lineitem
        GROUP BY l_suppkey
    ) AS sr
) AS cum
JOIN supplier ON l_suppkey = s_suppkey
ORDER BY cumulative_pct
LIMIT 30;

-- Q122: Year-on-year growth rate per market segment
SELECT c_mktsegment,
       order_year,
       segment_revenue,
       ROUND(
           (segment_revenue - LAG(segment_revenue) OVER (PARTITION BY c_mktsegment ORDER BY order_year))
           / LAG(segment_revenue) OVER (PARTITION BY c_mktsegment ORDER BY order_year) * 100, 2
       ) AS yoy_growth_pct
FROM (
    SELECT c_mktsegment,
           YEAR(o_orderdate) AS order_year,
           SUM(o_totalprice) AS segment_revenue
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    GROUP BY c_mktsegment, YEAR(o_orderdate)
) AS segment_yearly
ORDER BY c_mktsegment, order_year;

-- Q123: Discount effectiveness (does higher discount = more quantity?)
SELECT discount_bracket,
       AVG(l_quantity)                          AS avg_quantity,
       AVG(l_extendedprice * (1 - l_discount))  AS avg_net_price,
       COUNT(*)                                  AS item_count
FROM (
    SELECT l_quantity,
           l_extendedprice,
           l_discount,
           ROUND(l_discount * 10) / 10 AS discount_bracket
    FROM lineitem
) AS bracketed
GROUP BY discount_bracket
ORDER BY discount_bracket;

-- Q124: Late orders by nation (shipped after commit date)
SELECT n_name,
       late_count,
       total_count,
       ROUND(late_count / NULLIF(total_count, 0) * 100, 2) AS late_rate_pct
FROM (
    SELECT c_nationkey,
           SUM(CASE WHEN l_shipdate > l_commitdate THEN 1 ELSE 0 END) AS late_count,
           COUNT(*) AS total_count
    FROM lineitem
    JOIN orders   ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey  = c_custkey
    GROUP BY c_nationkey
) AS nation_late
JOIN nation ON c_nationkey = n_nationkey
ORDER BY late_rate_pct DESC;

-- Q125: Best month for each market segment by revenue
SELECT c_mktsegment,
       best_month,
       max_revenue
FROM (
    SELECT c_mktsegment,
           DATE_FORMAT(o_orderdate, '%Y-%m') AS best_month,
           SUM(o_totalprice) AS max_revenue,
           RANK() OVER (
               PARTITION BY c_mktsegment
               ORDER BY SUM(o_totalprice) DESC
           ) AS rnk
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    GROUP BY c_mktsegment, DATE_FORMAT(o_orderdate, '%Y-%m')
) AS ranked
WHERE rnk = 1
ORDER BY c_mktsegment;

-- ============================================================
-- SECTION 6: Advanced Window Functions (Q126-Q150)
-- ============================================================

-- Q126: Customer spend percentile within their market segment
SELECT o_custkey,
       c_mktsegment,
       total_spend,
       PERCENT_RANK() OVER (
           PARTITION BY c_mktsegment
           ORDER BY total_spend
       ) AS segment_percentile
FROM (
    SELECT o_custkey, SUM(o_totalprice) AS total_spend
    FROM orders GROUP BY o_custkey
) AS cs
JOIN customer ON o_custkey = c_custkey
ORDER BY c_mktsegment, segment_percentile DESC;

-- Q127: 3-month rolling sum of orders per region
SELECT r_name,
       order_month,
       monthly_orders,
       SUM(monthly_orders) OVER (
           PARTITION BY r_name
           ORDER BY order_month
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS rolling_3m_orders
FROM (
    SELECT r_name,
           DATE_FORMAT(o_orderdate, '%Y-%m') AS order_month,
           COUNT(*) AS monthly_orders
    FROM orders
    JOIN customer ON o_custkey  = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    JOIN region   ON n_regionkey = r_regionkey
    GROUP BY r_name, DATE_FORMAT(o_orderdate, '%Y-%m')
) AS monthly
ORDER BY r_name, order_month;

-- Q128: Supplier revenue vs prior month (lead/lag)
SELECT l_suppkey,
       ship_month,
       monthly_revenue,
       LAG(monthly_revenue)  OVER (PARTITION BY l_suppkey ORDER BY ship_month) AS prev_month,
       LEAD(monthly_revenue) OVER (PARTITION BY l_suppkey ORDER BY ship_month) AS next_month
FROM (
    SELECT l_suppkey,
           DATE_FORMAT(l_shipdate, '%Y-%m') AS ship_month,
           SUM(l_extendedprice * (1 - l_discount)) AS monthly_revenue
    FROM lineitem
    GROUP BY l_suppkey, DATE_FORMAT(l_shipdate, '%Y-%m')
) AS monthly
ORDER BY l_suppkey, ship_month;

-- Q129: Part revenue rank within each container type
SELECT p_container,
       l_partkey,
       part_revenue,
       DENSE_RANK() OVER (
           PARTITION BY p_container
           ORDER BY part_revenue DESC
       ) AS container_rank
FROM (
    SELECT p_container,
           l_partkey,
           SUM(l_extendedprice * (1 - l_discount)) AS part_revenue
    FROM lineitem
    JOIN part ON l_partkey = p_partkey
    GROUP BY p_container, l_partkey
) AS pr
ORDER BY p_container, container_rank;

-- Q130: First and last lineitem per order by ship date
SELECT l_orderkey,
       FIRST_VALUE(l_linenumber) OVER (
           PARTITION BY l_orderkey ORDER BY l_shipdate
       ) AS first_shipped_line,
       LAST_VALUE(l_linenumber) OVER (
           PARTITION BY l_orderkey ORDER BY l_shipdate
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS last_shipped_line
FROM lineitem
ORDER BY l_orderkey;

-- Q131: Cumulative discount savings per customer
SELECT o_custkey,
       o_orderdate,
       order_discount,
       SUM(order_discount) OVER (
           PARTITION BY o_custkey
           ORDER BY o_orderdate
       ) AS cumulative_discount_savings
FROM (
    SELECT o_custkey,
           o_orderdate,
           SUM(l_extendedprice * l_discount) AS order_discount
    FROM orders
    JOIN lineitem ON o_orderkey = l_orderkey
    GROUP BY o_custkey, o_orderdate, o_orderkey
) AS order_discounts
ORDER BY o_custkey, o_orderdate;

-- Q132: Percentile rank of parts by supply cost per brand
SELECT p_brand,
       ps_partkey,
       avg_cost,
       PERCENT_RANK() OVER (
           PARTITION BY p_brand
           ORDER BY avg_cost
       ) AS brand_cost_percentile
FROM (
    SELECT ps_partkey,
           AVG(ps_supplycost) AS avg_cost
    FROM partsupp
    GROUP BY ps_partkey
) AS part_costs
JOIN part ON ps_partkey = p_partkey
ORDER BY p_brand, brand_cost_percentile DESC;

-- Q133: Order value quartile boundaries per priority
SELECT o_orderpriority,
       MIN(o_totalprice)                          AS q0_min,
       MAX(CASE WHEN rnk_pct <= 0.25 THEN o_totalprice END) AS q1_25pct,
       MAX(CASE WHEN rnk_pct <= 0.50 THEN o_totalprice END) AS q2_median,
       MAX(CASE WHEN rnk_pct <= 0.75 THEN o_totalprice END) AS q3_75pct,
       MAX(o_totalprice)                          AS q4_max
FROM (
    SELECT o_orderpriority,
           o_totalprice,
           PERCENT_RANK() OVER (
               PARTITION BY o_orderpriority ORDER BY o_totalprice
           ) AS rnk_pct
    FROM orders
) AS ranked
GROUP BY o_orderpriority
ORDER BY o_orderpriority;

-- Q134: Supplier revenue deviation from nation average
SELECT l_suppkey,
       n_name,
       supp_revenue,
       nation_avg_revenue,
       supp_revenue - nation_avg_revenue AS deviation,
       (supp_revenue - nation_avg_revenue) / nation_avg_revenue * 100 AS deviation_pct
FROM (
    SELECT l_suppkey,
           n_name,
           supp_revenue,
           AVG(supp_revenue) OVER (PARTITION BY n_name) AS nation_avg_revenue
    FROM (
        SELECT l_suppkey,
               n_name,
               SUM(l_extendedprice * (1 - l_discount)) AS supp_revenue
        FROM lineitem
        JOIN supplier ON l_suppkey = s_suppkey
        JOIN nation   ON s_nationkey = n_nationkey
        GROUP BY l_suppkey, n_name
    ) AS sr
) AS with_avg
ORDER BY deviation DESC;

-- Q135: Customer order rank within nation by year
SELECT o_custkey,
       n_name,
       order_year,
       yearly_spend,
       RANK() OVER (
           PARTITION BY n_name, order_year
           ORDER BY yearly_spend DESC
       ) AS nation_year_rank
FROM (
    SELECT o_custkey,
           n_name,
           YEAR(o_orderdate) AS order_year,
           SUM(o_totalprice) AS yearly_spend
    FROM orders
    JOIN customer ON o_custkey  = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    GROUP BY o_custkey, n_name, YEAR(o_orderdate)
) AS yearly
ORDER BY n_name, order_year, nation_year_rank;

-- Q136: Shipment volume moving average by mode
SELECT l_shipmode,
       ship_week,
       weekly_qty,
       AVG(weekly_qty) OVER (
           PARTITION BY l_shipmode
           ORDER BY ship_week
           ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
       ) AS moving_avg_4w
FROM (
    SELECT l_shipmode,
           YEARWEEK(l_shipdate) AS ship_week,
           SUM(l_quantity)      AS weekly_qty
    FROM lineitem
    GROUP BY l_shipmode, YEARWEEK(l_shipdate)
) AS weekly
ORDER BY l_shipmode, ship_week;

-- Q137: Order revenue Z-score per customer
SELECT o_orderkey,
       o_custkey,
       o_totalprice,
       customer_avg,
       customer_std,
       ROUND((o_totalprice - customer_avg) / NULLIF(customer_std, 0), 3) AS z_score
FROM orders
JOIN (
    SELECT o_custkey,
           AVG(o_totalprice)    AS customer_avg,
           STDDEV(o_totalprice) AS customer_std
    FROM orders
    GROUP BY o_custkey
) AS stats USING (o_custkey)
ORDER BY ABS((o_totalprice - customer_avg) / NULLIF(customer_std, 0)) DESC
LIMIT 30;

-- Q138: Consecutive order growth per customer
SELECT o_custkey,
       o_orderdate,
       o_totalprice,
       prev_price,
       o_totalprice - prev_price AS order_growth
FROM (
    SELECT o_custkey,
           o_orderdate,
           o_totalprice,
           LAG(o_totalprice) OVER (
               PARTITION BY o_custkey ORDER BY o_orderdate
           ) AS prev_price
    FROM orders
) AS lagged
WHERE prev_price IS NOT NULL
ORDER BY order_growth DESC
LIMIT 20;

-- Q139: Region monthly revenue with YTD accumulation
SELECT r_name,
       order_month,
       monthly_revenue,
       SUM(monthly_revenue) OVER (
           PARTITION BY r_name, LEFT(order_month, 4)
           ORDER BY order_month
       ) AS ytd_revenue
FROM (
    SELECT r_name,
           DATE_FORMAT(o_orderdate, '%Y-%m') AS order_month,
           SUM(o_totalprice)                  AS monthly_revenue
    FROM orders
    JOIN customer ON o_custkey  = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    JOIN region   ON n_regionkey = r_regionkey
    GROUP BY r_name, DATE_FORMAT(o_orderdate, '%Y-%m')
) AS monthly
ORDER BY r_name, order_month;

-- Q140: Supplier rank flip (rank in 1994 vs rank in 1997)
SELECT s_name,
       rank_1994,
       rank_1997,
       rank_1997 - rank_1994 AS rank_change
FROM (
    SELECT l_suppkey,
           RANK() OVER (ORDER BY rev_1994 DESC) AS rank_1994,
           RANK() OVER (ORDER BY rev_1997 DESC) AS rank_1997
    FROM (
        SELECT l_suppkey,
               SUM(CASE WHEN YEAR(l_shipdate) = 1994 THEN l_extendedprice * (1 - l_discount) ELSE 0 END) AS rev_1994,
               SUM(CASE WHEN YEAR(l_shipdate) = 1997 THEN l_extendedprice * (1 - l_discount) ELSE 0 END) AS rev_1997
        FROM lineitem
        GROUP BY l_suppkey
    ) AS yearly_rev
) AS ranked
JOIN supplier ON l_suppkey = s_suppkey
ORDER BY ABS(rank_change) DESC
LIMIT 20;

-- Q141: Part demand seasonality (monthly index)
SELECT l_partkey,
       order_month,
       monthly_qty,
       monthly_qty / AVG(monthly_qty) OVER (PARTITION BY l_partkey) AS seasonality_index
FROM (
    SELECT l_partkey,
           MONTH(o_orderdate) AS order_month,
           SUM(l_quantity)    AS monthly_qty
    FROM lineitem
    JOIN orders ON l_orderkey = o_orderkey
    GROUP BY l_partkey, MONTH(o_orderdate)
) AS monthly
ORDER BY l_partkey, order_month
LIMIT 50;

-- Q142: Customer order streak (consecutive months with orders)
SELECT o_custkey,
       MAX(streak) AS longest_streak_months
FROM (
    SELECT o_custkey,
           COUNT(*) AS streak
    FROM (
        SELECT o_custkey,
               order_month,
               DATE_FORMAT(DATE_SUB(
                   STR_TO_DATE(CONCAT(order_month, '-01'), '%Y-%m-%d'),
                   INTERVAL ROW_NUMBER() OVER (PARTITION BY o_custkey ORDER BY order_month) MONTH
               ), '%Y-%m') AS streak_group
        FROM (
            SELECT DISTINCT o_custkey,
                   DATE_FORMAT(o_orderdate, '%Y-%m') AS order_month
            FROM orders
        ) AS monthly_orders
    ) AS grouped
    GROUP BY o_custkey, streak_group
) AS streaks
GROUP BY o_custkey
ORDER BY longest_streak_months DESC
LIMIT 20;

-- Q143: Revenue contribution of top N suppliers (Pareto analysis)
SELECT top_n,
       supplier_count,
       cumulative_revenue,
       total_revenue,
       ROUND(cumulative_revenue / NULLIF(total_revenue, 0) * 100, 2) AS revenue_pct
FROM (
    SELECT ROW_NUMBER() OVER (ORDER BY supplier_revenue DESC) AS top_n,
           COUNT(*) OVER (ORDER BY supplier_revenue DESC ROWS UNBOUNDED PRECEDING) AS supplier_count,
           SUM(supplier_revenue) OVER (ORDER BY supplier_revenue DESC ROWS UNBOUNDED PRECEDING) AS cumulative_revenue,
           SUM(supplier_revenue) OVER () AS total_revenue,
           supplier_revenue
    FROM (
        SELECT l_suppkey,
               SUM(l_extendedprice * (1 - l_discount)) AS supplier_revenue
        FROM lineitem
        GROUP BY l_suppkey
    ) AS sr
) AS pareto
WHERE top_n IN (1, 5, 10, 20, 50, 100)
ORDER BY top_n;

-- Q144: Weekly revenue vs same week prior year
SELECT curr.ship_week,
       curr.weekly_revenue AS this_year,
       prev.weekly_revenue AS prior_year,
       ROUND(
           (curr.weekly_revenue - prev.weekly_revenue) / prev.weekly_revenue * 100, 2
       ) AS yoy_pct
FROM (
    SELECT WEEK(l_shipdate) AS ship_week,
           YEAR(l_shipdate) AS yr,
           SUM(l_extendedprice * (1 - l_discount)) AS weekly_revenue
    FROM lineitem
    GROUP BY WEEK(l_shipdate), YEAR(l_shipdate)
) AS curr
JOIN (
    SELECT WEEK(l_shipdate) AS ship_week,
           YEAR(l_shipdate) AS yr,
           SUM(l_extendedprice * (1 - l_discount)) AS weekly_revenue
    FROM lineitem
    GROUP BY WEEK(l_shipdate), YEAR(l_shipdate)
) AS prev ON curr.ship_week = prev.ship_week AND curr.yr = prev.yr + 1
ORDER BY curr.yr, curr.ship_week;

-- Q145: Supplier stock turnover ratio (revenue / inventory cost)
SELECT s_name,
       n_name,
       annual_revenue,
       inventory_cost,
       ROUND(annual_revenue / NULLIF(inventory_cost, 0), 2) AS stock_turnover
FROM (
    SELECT l_suppkey,
           SUM(l_extendedprice * (1 - l_discount)) AS annual_revenue
    FROM lineitem
    GROUP BY l_suppkey
) AS rev
JOIN (
    SELECT ps_suppkey,
           SUM(ps_supplycost * ps_availqty) AS inventory_cost
    FROM partsupp
    GROUP BY ps_suppkey
) AS inv ON rev.l_suppkey = inv.ps_suppkey
JOIN supplier ON l_suppkey = s_suppkey
JOIN nation   ON s_nationkey = n_nationkey
ORDER BY stock_turnover DESC
LIMIT 20;

-- ============================================================
-- SECTION 7: Self-Joins & Recursive-style Patterns (Q151-Q170)
-- ============================================================

-- Q146: Self-join — find orders from same customer on same day
SELECT o1.o_custkey,
       o1.o_orderkey  AS order1,
       o2.o_orderkey  AS order2,
       o1.o_orderdate AS order_date
FROM orders o1
JOIN orders o2
  ON o1.o_custkey    = o2.o_custkey
 AND o1.o_orderdate  = o2.o_orderdate
 AND o1.o_orderkey   < o2.o_orderkey
ORDER BY o1.o_custkey, order_date
LIMIT 20;

-- Q147: Self-join — parts with same retail price from different brands
SELECT p1.p_partkey AS part1,
       p2.p_partkey AS part2,
       p1.p_retailprice,
       p1.p_brand   AS brand1,
       p2.p_brand   AS brand2
FROM part p1
JOIN part p2
  ON p1.p_retailprice = p2.p_retailprice
 AND p1.p_brand       <> p2.p_brand
 AND p1.p_partkey     < p2.p_partkey
ORDER BY p1.p_retailprice, part1
LIMIT 20;

-- Q148: Self-join — supplier pairs in same nation
SELECT s1.s_suppkey AS supp1,
       s2.s_suppkey AS supp2,
       n_name        AS nation
FROM supplier s1
JOIN supplier s2 ON s1.s_nationkey = s2.s_nationkey
                AND s1.s_suppkey   < s2.s_suppkey
JOIN nation   ON s1.s_nationkey = n_nationkey
ORDER BY nation, supp1
LIMIT 20;

-- Q149: Orders placed on consecutive days by same customer
SELECT o1.o_custkey,
       o1.o_orderdate          AS day1,
       o2.o_orderdate          AS day2,
       o1.o_totalprice + o2.o_totalprice AS combined_value
FROM orders o1
JOIN orders o2
  ON o1.o_custkey = o2.o_custkey
 AND DATEDIFF(o2.o_orderdate, o1.o_orderdate) = 1
ORDER BY combined_value DESC
LIMIT 20;

-- Q150: Parts supplied by two specific competing suppliers
SELECT ps1.ps_partkey,
       ps1.ps_suppkey   AS supplier_a,
       ps1.ps_supplycost AS cost_a,
       ps2.ps_suppkey   AS supplier_b,
       ps2.ps_supplycost AS cost_b,
       ps1.ps_supplycost - ps2.ps_supplycost AS cost_difference
FROM partsupp ps1
JOIN partsupp ps2
  ON ps1.ps_partkey = ps2.ps_partkey
 AND ps1.ps_suppkey < ps2.ps_suppkey
ORDER BY ABS(ps1.ps_supplycost - ps2.ps_supplycost) DESC
LIMIT 20;

-- Q151: Customers who share the same nation and segment
SELECT c1.c_custkey   AS customer_a,
       c2.c_custkey   AS customer_b,
       c1.c_mktsegment,
       n_name          AS nation
FROM customer c1
JOIN customer c2
  ON c1.c_nationkey   = c2.c_nationkey
 AND c1.c_mktsegment  = c2.c_mktsegment
 AND c1.c_custkey     < c2.c_custkey
JOIN nation ON c1.c_nationkey = n_nationkey
ORDER BY nation, c1.c_mktsegment
LIMIT 20;

-- Q152: Nation-to-nation revenue matrix (self-join on nation)
SELECT n1.n_name AS from_nation,
       n2.n_name AS to_nation,
       COALESCE(trade_value, 0) AS trade_value
FROM nation n1
CROSS JOIN nation n2
LEFT JOIN (
    SELECT n1i.n_name AS from_nation,
           n2i.n_name AS to_nation,
           SUM(l_extendedprice * (1 - l_discount)) AS trade_value
    FROM lineitem
    JOIN orders   ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey  = c_custkey
    JOIN supplier ON l_suppkey  = s_suppkey
    JOIN nation n1i ON s_nationkey = n1i.n_nationkey
    JOIN nation n2i ON c_nationkey = n2i.n_nationkey
    WHERE n1i.n_nationkey <> n2i.n_nationkey
    GROUP BY n1i.n_name, n2i.n_name
) AS flows ON n1.n_name = flows.from_nation AND n2.n_name = flows.to_nation
WHERE n1.n_nationkey <> n2.n_nationkey
ORDER BY trade_value DESC
LIMIT 25;

-- Q153: Parts that share the same container and brand but differ in size
SELECT p1.p_partkey AS part_a,
       p2.p_partkey AS part_b,
       p1.p_brand,
       p1.p_container,
       p1.p_size AS size_a,
       p2.p_size AS size_b
FROM part p1
JOIN part p2
  ON p1.p_brand     = p2.p_brand
 AND p1.p_container = p2.p_container
 AND p1.p_size      <> p2.p_size
 AND p1.p_partkey   < p2.p_partkey
ORDER BY p1.p_brand, p1.p_container
LIMIT 20;

-- Q154: Orders from same customer where later order is smaller
SELECT o1.o_custkey,
       o1.o_orderkey AS earlier_order,
       o1.o_totalprice AS earlier_value,
       o2.o_orderkey AS later_order,
       o2.o_totalprice AS later_value
FROM orders o1
JOIN orders o2
  ON o1.o_custkey   = o2.o_custkey
 AND o1.o_orderdate < o2.o_orderdate
 AND o1.o_totalprice > o2.o_totalprice
ORDER BY o1.o_custkey, o1.o_orderdate
LIMIT 20;

-- Q155: Detect supplier pricing inconsistency — same part, large cost gap
SELECT ps1.ps_partkey,
       ps1.ps_suppkey AS supp_low,
       ps1.ps_supplycost AS cost_low,
       ps2.ps_suppkey AS supp_high,
       ps2.ps_supplycost AS cost_high,
       ROUND((ps2.ps_supplycost - ps1.ps_supplycost) / ps1.ps_supplycost * 100, 1) AS pct_gap
FROM partsupp ps1
JOIN partsupp ps2
  ON ps1.ps_partkey   = ps2.ps_partkey
 AND ps1.ps_supplycost < ps2.ps_supplycost
 AND (ps2.ps_supplycost - ps1.ps_supplycost) / ps1.ps_supplycost > 0.5
ORDER BY pct_gap DESC
LIMIT 20;

-- Q156: Customers whose second order was larger than their first
SELECT o1.o_custkey,
       o1.o_totalprice AS first_order_value,
       o2.o_totalprice AS second_order_value
FROM orders o1
JOIN orders o2
  ON o1.o_custkey = o2.o_custkey
WHERE o1.o_orderdate = (
    SELECT MIN(o3.o_orderdate) FROM orders o3 WHERE o3.o_custkey = o1.o_custkey
)
AND o2.o_orderdate = (
    SELECT MIN(o4.o_orderdate) FROM orders o4
    WHERE o4.o_custkey = o1.o_custkey
      AND o4.o_orderdate > o1.o_orderdate
)
AND o2.o_totalprice > o1.o_totalprice
ORDER BY second_order_value DESC
LIMIT 20;

-- Q157: Parts with identical price and brand but different manufacturer
SELECT p1.p_partkey   AS part_a,
       p2.p_partkey   AS part_b,
       p1.p_brand,
       p1.p_retailprice,
       p1.p_mfgr      AS mfgr_a,
       p2.p_mfgr      AS mfgr_b
FROM part p1
JOIN part p2
  ON p1.p_brand       = p2.p_brand
 AND p1.p_retailprice = p2.p_retailprice
 AND p1.p_mfgr        <> p2.p_mfgr
 AND p1.p_partkey     < p2.p_partkey
ORDER BY p1.p_brand, p1.p_retailprice
LIMIT 20;

-- Q158: Supplier pairs who supply the same set of parts (top overlapping)
SELECT a.ps_suppkey AS supp_a,
       b.ps_suppkey AS supp_b,
       COUNT(DISTINCT a.ps_partkey) AS shared_parts
FROM partsupp a
JOIN partsupp b ON a.ps_partkey = b.ps_partkey
               AND a.ps_suppkey < b.ps_suppkey
GROUP BY a.ps_suppkey, b.ps_suppkey
ORDER BY shared_parts DESC
LIMIT 10;

-- Q159: Customers who placed orders in back-to-back months
SELECT o1.o_custkey,
       o1.o_orderdate AS month1_order,
       o2.o_orderdate AS month2_order
FROM orders o1
JOIN orders o2
  ON o1.o_custkey = o2.o_custkey
 AND YEAR(o1.o_orderdate)  = YEAR(o2.o_orderdate)
 AND MONTH(o2.o_orderdate) = MONTH(o1.o_orderdate) + 1
ORDER BY o1.o_custkey
LIMIT 20;

-- Q160: Region self-comparison: compare each region to all others
SELECT r1.r_name AS region_a,
       r2.r_name AS region_b,
       rev_a,
       rev_b,
       ROUND(rev_a / rev_b, 3) AS revenue_ratio
FROM (
    SELECT r_name,
           SUM(o_totalprice) AS rev_a
    FROM orders
    JOIN customer ON o_custkey  = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    JOIN region   ON n_regionkey = r_regionkey
    GROUP BY r_name
) AS r1
JOIN (
    SELECT r_name,
           SUM(o_totalprice) AS rev_b
    FROM orders
    JOIN customer ON o_custkey  = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    JOIN region   ON n_regionkey = r_regionkey
    GROUP BY r_name
) AS r2 ON r1.r_name < r2.r_name
ORDER BY revenue_ratio DESC;

-- ============================================================
-- SECTION 8: TPC-H Benchmark Inspired Queries (Q161-Q175)
-- ============================================================

-- Q161: TPC-H Q2 style — minimum cost supplier per part in EUROPE
SELECT s_acctbal, s_name, n_name, p_partkey, p_mfgr,
       s_address, s_phone, s_comment
FROM part, supplier, partsupp, nation, region
WHERE p_partkey = ps_partkey
  AND s_suppkey = ps_suppkey
  AND p_size = 15
  AND p_type LIKE '%BRASS'
  AND s_nationkey = n_nationkey
  AND n_regionkey = r_regionkey
  AND r_name = 'EUROPE'
  AND ps_supplycost = (
      SELECT MIN(ps_supplycost)
      FROM partsupp, supplier, nation, region
      WHERE p_partkey = ps_partkey
        AND s_suppkey = ps_suppkey
        AND s_nationkey = n_nationkey
        AND n_regionkey = r_regionkey
        AND r_name = 'EUROPE'
  )
ORDER BY s_acctbal DESC, n_name, s_name, p_partkey
LIMIT 10;

-- Q162: TPC-H Q4 style — order priority checking
SELECT o_orderpriority,
       COUNT(*) AS order_count
FROM orders
WHERE o_orderdate >= '1993-07-01'
  AND o_orderdate <  '1993-10-01'
  AND EXISTS (
      SELECT 1
      FROM lineitem
      WHERE l_orderkey = o_orderkey
        AND l_commitdate < l_receiptdate
  )
GROUP BY o_orderpriority
ORDER BY o_orderpriority;

-- Q163: TPC-H Q7 style — volume shipping between nations
SELECT supp_nation,
       cust_nation,
       l_year,
       SUM(volume) AS revenue
FROM (
    SELECT n1.n_name AS supp_nation,
           n2.n_name AS cust_nation,
           YEAR(l_shipdate) AS l_year,
           l_extendedprice * (1 - l_discount) AS volume
    FROM supplier, lineitem, orders, customer,
         nation n1, nation n2
    WHERE s_suppkey = l_suppkey
      AND o_orderkey = l_orderkey
      AND c_custkey  = o_custkey
      AND s_nationkey = n1.n_nationkey
      AND c_nationkey = n2.n_nationkey
      AND (
          (n1.n_name = 'FRANCE' AND n2.n_name = 'GERMANY')
          OR
          (n1.n_name = 'GERMANY' AND n2.n_name = 'FRANCE')
      )
      AND l_shipdate BETWEEN '1995-01-01' AND '1996-12-31'
) AS shipping
GROUP BY supp_nation, cust_nation, l_year
ORDER BY supp_nation, cust_nation, l_year;

-- Q164: TPC-H Q8 style — national market share
SELECT o_year,
       SUM(CASE WHEN nation = 'BRAZIL' THEN volume ELSE 0 END) /
           SUM(volume) AS mkt_share
FROM (
    SELECT YEAR(o_orderdate) AS o_year,
           l_extendedprice * (1 - l_discount) AS volume,
           n2.n_name AS nation
    FROM part, supplier, lineitem, orders, customer, nation n1, nation n2, region
    WHERE p_partkey    = l_partkey
      AND s_suppkey    = l_suppkey
      AND l_orderkey   = o_orderkey
      AND o_custkey    = c_custkey
      AND c_nationkey  = n1.n_nationkey
      AND n1.n_regionkey = r_regionkey
      AND r_name       = 'AMERICA'
      AND s_nationkey  = n2.n_nationkey
      AND o_orderdate  BETWEEN '1995-01-01' AND '1996-12-31'
      AND p_type       = 'ECONOMY ANODIZED STEEL'
) AS all_nations
GROUP BY o_year
ORDER BY o_year;

-- Q165: TPC-H Q9 style — profit by nation and year
SELECT nation,
       o_year,
       SUM(amount) AS sum_profit
FROM (
    SELECT n_name AS nation,
           YEAR(o_orderdate) AS o_year,
           l_extendedprice * (1 - l_discount) - ps_supplycost * l_quantity AS amount
    FROM part, supplier, lineitem, partsupp, orders, nation
    WHERE s_suppkey    = l_suppkey
      AND ps_suppkey   = l_suppkey
      AND ps_partkey   = l_partkey
      AND p_partkey    = l_partkey
      AND o_orderkey   = l_orderkey
      AND s_nationkey  = n_nationkey
      AND p_name LIKE '%green%'
) AS profit
GROUP BY nation, o_year
ORDER BY nation, o_year DESC;

-- Q166: TPC-H Q10 style — returned item reporting
SELECT c_custkey, c_name,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue,
       c_acctbal,
       n_name,
       c_address,
       c_phone,
       c_comment
FROM customer, orders, lineitem, nation
WHERE c_custkey  = o_custkey
  AND l_orderkey = o_orderkey
  AND o_orderdate >= '1993-10-01'
  AND o_orderdate <  '1994-01-01'
  AND l_returnflag = 'R'
  AND c_nationkey  = n_nationkey
GROUP BY c_custkey, c_name, c_acctbal, c_phone, n_name, c_address, c_comment
ORDER BY revenue DESC
LIMIT 20;

-- Q167: TPC-H Q11 style — important stock identification
SELECT ps_partkey,
       SUM(ps_supplycost * ps_availqty) AS part_value
FROM partsupp, supplier, nation
WHERE ps_suppkey  = s_suppkey
  AND s_nationkey = n_nationkey
  AND n_name      = 'GERMANY'
GROUP BY ps_partkey
HAVING SUM(ps_supplycost * ps_availqty) > (
    SELECT SUM(ps_supplycost * ps_availqty) * 0.0001
    FROM partsupp, supplier, nation
    WHERE ps_suppkey  = s_suppkey
      AND s_nationkey = n_nationkey
      AND n_name      = 'GERMANY'
)
ORDER BY part_value DESC;

-- Q168: TPC-H Q12 style — shipping modes and order priority
SELECT l_shipmode,
       SUM(CASE WHEN o_orderpriority = '1-URGENT' OR o_orderpriority = '2-HIGH'
                THEN 1 ELSE 0 END) AS high_line_count,
       SUM(CASE WHEN o_orderpriority <> '1-URGENT' AND o_orderpriority <> '2-HIGH'
                THEN 1 ELSE 0 END) AS low_line_count
FROM orders, lineitem
WHERE o_orderkey  = l_orderkey
  AND l_shipmode  IN ('MAIL', 'SHIP')
  AND l_commitdate < l_receiptdate
  AND l_shipdate   < l_commitdate
  AND l_shipdate  >= '1994-01-01'
  AND l_shipdate   < '1995-01-01'
GROUP BY l_shipmode
ORDER BY l_shipmode;

-- Q169: TPC-H Q13 style — customer order distribution
SELECT c_count,
       COUNT(*) AS custdist
FROM (
    SELECT c_custkey,
           COUNT(o_orderkey) AS c_count
    FROM customer
    LEFT JOIN orders ON c_custkey = o_custkey
                     AND o_comment NOT LIKE '%special%requests%'
    GROUP BY c_custkey
) AS c_orders
GROUP BY c_count
ORDER BY custdist DESC, c_count DESC;

-- Q170: TPC-H Q14 style — promotional revenue effect
SELECT ROUND(
    100.00 * SUM(CASE WHEN p_type LIKE 'PROMO%'
                 THEN l_extendedprice * (1 - l_discount) ELSE 0 END)
    / SUM(l_extendedprice * (1 - l_discount)), 2
) AS promo_revenue_pct
FROM lineitem, part
WHERE l_partkey  = p_partkey
  AND l_shipdate >= '1995-09-01'
  AND l_shipdate <  '1995-10-01';

-- Q171: TPC-H Q15 style — top supplier by revenue (via derived table)
SELECT s_suppkey,
       s_name,
       s_address,
       s_phone,
       total_revenue
FROM supplier
JOIN (
    SELECT l_suppkey,
           SUM(l_extendedprice * (1 - l_discount)) AS total_revenue
    FROM lineitem
    WHERE l_shipdate >= '1996-01-01'
      AND l_shipdate <  '1996-04-01'
    GROUP BY l_suppkey
) AS revenue ON s_suppkey = l_suppkey
WHERE total_revenue = (
    SELECT MAX(total_revenue)
    FROM (
        SELECT SUM(l_extendedprice * (1 - l_discount)) AS total_revenue
        FROM lineitem
        WHERE l_shipdate >= '1996-01-01'
          AND l_shipdate <  '1996-04-01'
        GROUP BY l_suppkey
    ) AS max_rev
)
ORDER BY s_suppkey;

-- Q172: TPC-H Q16 style — parts/supplier relationship
SELECT p_brand,
       p_type,
       p_size,
       COUNT(DISTINCT ps_suppkey) AS supplier_cnt
FROM partsupp, part
WHERE p_partkey = ps_partkey
  AND p_brand   <> 'Brand#45'
  AND p_type NOT LIKE 'MEDIUM POLISHED%'
  AND p_size IN (49, 14, 23, 45, 19, 3, 36, 9)
  AND ps_suppkey NOT IN (
      SELECT s_suppkey FROM supplier
      WHERE s_comment LIKE '%Customer%Complaints%'
  )
GROUP BY p_brand, p_type, p_size
ORDER BY supplier_cnt DESC, p_brand, p_type, p_size;

-- Q173: TPC-H Q17 style — small quantity ordering loss
SELECT ROUND(SUM(l_extendedprice) / 7.0, 2) AS avg_yearly
FROM lineitem, part
WHERE p_partkey = l_partkey
  AND p_brand   = 'Brand#23'
  AND p_container = 'MED BOX'
  AND l_quantity < (
      SELECT 0.2 * AVG(l2.l_quantity)
      FROM lineitem l2
      WHERE l2.l_partkey = p_partkey
  );

-- Q174: TPC-H Q18 style — large volume customers
SELECT c_name, c_custkey, o_orderkey, o_orderdate, o_totalprice,
       SUM(l_quantity) AS total_qty
FROM customer, orders, lineitem
WHERE o_orderkey = l_orderkey
  AND c_custkey  = o_custkey
  AND o_orderkey IN (
      SELECT l_orderkey
      FROM lineitem
      GROUP BY l_orderkey
      HAVING SUM(l_quantity) > 300
  )
GROUP BY c_name, c_custkey, o_orderkey, o_orderdate, o_totalprice
ORDER BY o_totalprice DESC, o_orderdate
LIMIT 10;

-- Q175: TPC-H Q19 style — discounted revenue for specific parts
SELECT SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem, part
WHERE (
    p_partkey = l_partkey
    AND p_brand = 'Brand#12'
    AND p_container IN ('SM CASE','SM BOX','SM PACK','SM PKG')
    AND l_quantity >= 1 AND l_quantity <= 11
    AND p_size BETWEEN 1 AND 5
    AND l_shipmode IN ('AIR','AIR REG')
    AND l_shipinstruct = 'DELIVER IN PERSON'
) OR (
    p_partkey = l_partkey
    AND p_brand = 'Brand#23'
    AND p_container IN ('MED BAG','MED BOX','MED PKG','MED PACK')
    AND l_quantity >= 10 AND l_quantity <= 20
    AND p_size BETWEEN 1 AND 10
    AND l_shipmode IN ('AIR','AIR REG')
    AND l_shipinstruct = 'DELIVER IN PERSON'
) OR (
    p_partkey = l_partkey
    AND p_brand = 'Brand#34'
    AND p_container IN ('LG CASE','LG BOX','LG PACK','LG PKG')
    AND l_quantity >= 20 AND l_quantity <= 30
    AND p_size BETWEEN 1 AND 15
    AND l_shipmode IN ('AIR','AIR REG')
    AND l_shipinstruct = 'DELIVER IN PERSON'
);

-- ============================================================
-- SECTION 9: Full Pipeline / Analytical Queries (Q176-Q200)
-- ============================================================

-- Q176: End-to-end order pipeline efficiency report
WITH pipeline AS (
    SELECT o_orderkey,
           o_custkey,
           o_orderdate,
           o_orderpriority,
           MIN(l_shipdate)                              AS first_ship,
           MAX(l_receiptdate)                           AS last_receipt,
           SUM(l_extendedprice * (1 - l_discount))     AS net_revenue,
           SUM(l_quantity)                              AS total_qty,
           COUNT(*)                                     AS line_count,
           SUM(CASE WHEN l_returnflag = 'R' THEN 1 END) AS returns
    FROM orders
    JOIN lineitem ON o_orderkey = l_orderkey
    GROUP BY o_orderkey, o_custkey, o_orderdate, o_orderpriority
)
SELECT o_orderpriority,
       COUNT(*)                              AS orders,
       AVG(DATEDIFF(first_ship, o_orderdate)) AS avg_days_to_first_ship,
       AVG(DATEDIFF(last_receipt, o_orderdate)) AS avg_days_to_fulfil,
       AVG(net_revenue)                      AS avg_order_revenue,
       AVG(line_count)                       AS avg_lines,
       SUM(returns)                          AS total_returns,
       ROUND(SUM(returns) / SUM(line_count) * 100, 2) AS return_rate_pct
FROM pipeline
GROUP BY o_orderpriority
ORDER BY o_orderpriority;

-- Q177: Full supplier scorecard
WITH supp_metrics AS (
    SELECT l_suppkey,
           COUNT(*)                                                   AS shipments,
           SUM(l_extendedprice * (1 - l_discount))                    AS revenue,
           AVG(DATEDIFF(l_shipdate, o_orderdate))                      AS avg_lead_time,
           SUM(CASE WHEN l_shipdate > l_commitdate THEN 1 END)         AS late_deliveries,
           SUM(CASE WHEN l_returnflag = 'R'        THEN 1 END)         AS returns
    FROM lineitem
    JOIN orders ON l_orderkey = o_orderkey
    GROUP BY l_suppkey
)
SELECT s_name,
       n_name,
       shipments,
       revenue,
       avg_lead_time,
       ROUND(late_deliveries / NULLIF(shipments, 0) * 100, 2) AS late_pct,
       ROUND(returns        / NULLIF(shipments, 0) * 100, 2) AS return_pct,
       RANK() OVER (ORDER BY revenue DESC)         AS revenue_rank,
       RANK() OVER (ORDER BY avg_lead_time)        AS speed_rank
FROM supp_metrics
JOIN supplier ON l_suppkey = s_suppkey
JOIN nation   ON s_nationkey = n_nationkey
ORDER BY revenue_rank;

-- Q178: Comprehensive customer health dashboard
WITH cust_metrics AS (
    SELECT o_custkey,
           COUNT(DISTINCT o_orderkey)                   AS total_orders,
           SUM(o_totalprice)                             AS lifetime_value,
           AVG(o_totalprice)                             AS avg_order_value,
           DATEDIFF('1998-12-31', MAX(o_orderdate))      AS days_since_last_order,
           COUNT(DISTINCT YEAR(o_orderdate))             AS active_years,
           STDDEV(o_totalprice)                          AS order_value_std
    FROM orders
    GROUP BY o_custkey
)
SELECT c_custkey,
       c_name,
       c_mktsegment,
       n_name,
       total_orders,
       ROUND(lifetime_value, 2)     AS ltv,
       ROUND(avg_order_value, 2)    AS aov,
       days_since_last_order,
       active_years,
       CASE
         WHEN days_since_last_order <= 90  THEN 'Active'
         WHEN days_since_last_order <= 365 THEN 'Lapsing'
         ELSE 'Churned'
       END AS customer_status,
       NTILE(5) OVER (ORDER BY lifetime_value) AS ltv_quintile
FROM cust_metrics
JOIN customer ON o_custkey = c_custkey
JOIN nation   ON c_nationkey = n_nationkey
ORDER BY ltv DESC
LIMIT 30;

-- Q179: Product portfolio analysis
WITH part_sales AS (
    SELECT l_partkey,
           SUM(l_quantity)                            AS units_sold,
           SUM(l_extendedprice * (1 - l_discount))   AS net_revenue,
           SUM(l_extendedprice * l_discount)          AS discount_given,
           COUNT(DISTINCT l_orderkey)                 AS order_appearances,
           SUM(CASE WHEN l_returnflag='R' THEN 1 END) AS returns
    FROM lineitem
    GROUP BY l_partkey
),
part_supply AS (
    SELECT ps_partkey,
           MIN(ps_supplycost) AS min_cost,
           MAX(ps_supplycost) AS max_cost,
           AVG(ps_supplycost) AS avg_cost,
           SUM(ps_availqty)   AS stock
    FROM partsupp
    GROUP BY ps_partkey
)
SELECT p_brand,
       p_type,
       COUNT(DISTINCT p_partkey)            AS sku_count,
       SUM(units_sold)                      AS total_units,
       SUM(net_revenue)                     AS total_revenue,
       SUM(net_revenue) / SUM(units_sold)   AS revenue_per_unit,
       AVG(avg_cost)                        AS avg_unit_cost,
       SUM(net_revenue) - SUM(avg_cost * units_sold) AS gross_profit,
       SUM(stock)                           AS total_stock
FROM part
JOIN part_sales  ON p_partkey = l_partkey
JOIN part_supply ON p_partkey = ps_partkey
GROUP BY p_brand, p_type
ORDER BY gross_profit DESC;

-- Q180: Geographic revenue intelligence report
SELECT r_name    AS region,
       n_name    AS nation,
       order_year,
       order_count,
       total_revenue,
       avg_order_value,
       revenue_per_customer,
       RANK() OVER (PARTITION BY order_year ORDER BY total_revenue DESC) AS global_rank,
       RANK() OVER (PARTITION BY r_name, order_year ORDER BY total_revenue DESC) AS region_rank
FROM (
    SELECT r_name,
           n_name,
           YEAR(o_orderdate)                        AS order_year,
           COUNT(DISTINCT o_orderkey)               AS order_count,
           SUM(o_totalprice)                        AS total_revenue,
           AVG(o_totalprice)                        AS avg_order_value,
           SUM(o_totalprice) / COUNT(DISTINCT o_custkey) AS revenue_per_customer
    FROM orders
    JOIN customer ON o_custkey  = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    JOIN region   ON n_regionkey = r_regionkey
    GROUP BY r_name, n_name, YEAR(o_orderdate)
) AS geo_yearly
ORDER BY order_year, global_rank;

-- Q181: Multi-dimensional discount impact analysis
SELECT p_brand,
       l_shipmode,
       c_mktsegment,
       COUNT(*)                                          AS line_items,
       AVG(l_discount)                                  AS avg_discount,
       SUM(l_extendedprice)                             AS gross_revenue,
       SUM(l_extendedprice * l_discount)                AS discount_cost,
       SUM(l_extendedprice * (1 - l_discount))          AS net_revenue,
       ROUND(SUM(l_extendedprice * l_discount) /
             SUM(l_extendedprice) * 100, 2)             AS effective_discount_pct
FROM lineitem
JOIN part     ON l_partkey  = p_partkey
JOIN orders   ON l_orderkey = o_orderkey
JOIN customer ON o_custkey  = c_custkey
GROUP BY p_brand, l_shipmode, c_mktsegment
ORDER BY effective_discount_pct DESC
LIMIT 30;

-- Q182: Supply chain cost vs revenue waterfall by region
WITH region_metrics AS (
    SELECT r_name,
           SUM(l_extendedprice)                          AS gross_revenue,
           SUM(l_extendedprice * l_discount)             AS total_discounts,
           SUM(l_extendedprice * (1 - l_discount))       AS net_revenue,
           SUM(l_extendedprice * (1-l_discount)*l_tax)   AS tax_collected,
           SUM(ps_supplycost * l_quantity)                AS supply_cost
    FROM lineitem
    JOIN orders   ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey  = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    JOIN region   ON n_regionkey = r_regionkey
    JOIN partsupp ON l_partkey  = ps_partkey AND l_suppkey = ps_suppkey
    GROUP BY r_name
)
SELECT r_name,
       ROUND(gross_revenue, 0)   AS gross_revenue,
       ROUND(total_discounts, 0) AS discounts_given,
       ROUND(net_revenue, 0)     AS net_revenue,
       ROUND(supply_cost, 0)     AS supply_cost,
       ROUND(net_revenue - supply_cost, 0) AS operating_profit,
       ROUND((net_revenue - supply_cost) / net_revenue * 100, 2) AS profit_margin_pct
FROM region_metrics
ORDER BY operating_profit DESC;

-- Q183: Cohort analysis — first order year vs lifetime value
SELECT first_order_year,
       COUNT(DISTINCT o_custkey)  AS cohort_size,
       AVG(lifetime_value)        AS avg_ltv,
       SUM(lifetime_value)        AS cohort_total_ltv,
       AVG(total_orders)          AS avg_orders_per_customer,
       AVG(active_years)          AS avg_active_years
FROM (
    SELECT o_custkey,
           MIN(YEAR(o_orderdate))           AS first_order_year,
           COUNT(DISTINCT o_orderkey)       AS total_orders,
           SUM(o_totalprice)                AS lifetime_value,
           COUNT(DISTINCT YEAR(o_orderdate)) AS active_years
    FROM orders
    GROUP BY o_custkey
) AS cohorts
GROUP BY first_order_year
ORDER BY first_order_year;

-- Q184: Integrated ABC classification of parts (by revenue contribution)
WITH part_revenue AS (
    SELECT l_partkey,
           SUM(l_extendedprice * (1 - l_discount)) AS revenue
    FROM lineitem
    GROUP BY l_partkey
),
cumulative AS (
    SELECT l_partkey,
           revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC) AS cum_revenue,
           SUM(revenue) OVER ()                      AS total_revenue
    FROM part_revenue
)
SELECT p_partkey,
       p_name,
       p_brand,
       revenue,
       ROUND(cum_revenue / NULLIF(total_revenue, 0) * 100, 2) AS cumulative_pct,
       CASE
         WHEN cum_revenue / total_revenue <= 0.80 THEN 'A - Top 80%'
         WHEN cum_revenue / total_revenue <= 0.95 THEN 'B - Next 15%'
         ELSE 'C - Bottom 5%'
       END AS abc_class
FROM cumulative
JOIN part ON l_partkey = p_partkey
ORDER BY revenue DESC;

-- Q185: Full TPC-H analytics pipeline — executive summary
WITH yearly_summary AS (
    SELECT YEAR(o_orderdate)                        AS yr,
           COUNT(DISTINCT o_custkey)                AS active_customers,
           COUNT(DISTINCT o_orderkey)               AS total_orders,
           SUM(o_totalprice)                        AS gross_revenue,
           AVG(o_totalprice)                        AS avg_order_value,
           COUNT(DISTINCT c_nationkey)              AS nations_active
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    GROUP BY YEAR(o_orderdate)
),
yearly_lineitem AS (
    SELECT YEAR(l_shipdate)                         AS yr,
           COUNT(*)                                 AS total_lineitems,
           SUM(l_quantity)                          AS total_qty,
           SUM(l_extendedprice * (1-l_discount))   AS net_revenue,
           SUM(l_extendedprice * l_discount)        AS total_discounts,
           AVG(l_discount) * 100                    AS avg_discount_pct,
           SUM(CASE WHEN l_returnflag='R' THEN 1 END) AS returns
    FROM lineitem
    GROUP BY YEAR(l_shipdate)
)
SELECT ys.yr,
       active_customers,
       total_orders,
       ROUND(gross_revenue, 0)     AS gross_revenue,
       ROUND(net_revenue, 0)       AS net_revenue,
       ROUND(avg_order_value, 0)   AS avg_order_value,
       total_lineitems,
       total_qty,
       ROUND(avg_discount_pct, 2)  AS avg_discount_pct,
       returns,
       ROUND(returns / NULLIF(total_lineitems, 0) * 100, 2) AS return_rate_pct,
       nations_active,
       ROUND(
           (gross_revenue - LAG(gross_revenue) OVER (ORDER BY ys.yr))
           / LAG(gross_revenue) OVER (ORDER BY ys.yr) * 100, 2
       ) AS revenue_yoy_growth_pct
FROM yearly_summary ys
JOIN yearly_lineitem yl ON ys.yr = yl.yr
ORDER BY ys.yr;

-- Q186: Supplier nation competitive landscape
WITH nation_supplier_stats AS (
    SELECT n_name,
           COUNT(DISTINCT s_suppkey)                   AS supplier_count,
           AVG(s_acctbal)                              AS avg_balance,
           SUM(ps_supplycost * ps_availqty)            AS total_inventory_value,
           COUNT(DISTINCT ps_partkey)                  AS distinct_parts_supplied
    FROM supplier
    JOIN nation   ON s_nationkey = n_nationkey
    JOIN partsupp ON s_suppkey   = ps_suppkey
    GROUP BY n_name
)
SELECT n_name,
       supplier_count,
       ROUND(avg_balance, 2)          AS avg_supplier_balance,
       ROUND(total_inventory_value,0) AS total_inventory_value,
       distinct_parts_supplied,
       ROUND(total_inventory_value / supplier_count, 0) AS inventory_per_supplier,
       RANK() OVER (ORDER BY total_inventory_value DESC) AS inventory_rank,
       RANK() OVER (ORDER BY supplier_count DESC)        AS size_rank
FROM nation_supplier_stats
ORDER BY inventory_rank;

-- Q187: Part lifecycle analysis — introduction to retirement
SELECT l_partkey,
       p_name,
       p_brand,
       MIN(o_orderdate)  AS first_ordered,
       MAX(o_orderdate)  AS last_ordered,
       DATEDIFF(MAX(o_orderdate), MIN(o_orderdate)) AS lifecycle_days,
       COUNT(DISTINCT o_orderkey) AS total_orders,
       SUM(l_quantity)            AS total_units_sold,
       SUM(l_extendedprice * (1-l_discount)) AS total_revenue
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
JOIN part   ON l_partkey  = p_partkey
GROUP BY l_partkey, p_name, p_brand
ORDER BY lifecycle_days DESC
LIMIT 20;

-- Q188: Customer cross-sell analysis — how many different parts per customer
SELECT c_mktsegment,
       avg_distinct_parts,
       avg_distinct_brands,
       avg_distinct_types,
       COUNT(*) AS customer_count
FROM (
    SELECT o_custkey,
           c_mktsegment,
           COUNT(DISTINCT l_partkey) AS avg_distinct_parts,
           COUNT(DISTINCT p_brand)   AS avg_distinct_brands,
           COUNT(DISTINCT p_type)    AS avg_distinct_types
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    JOIN lineitem ON o_orderkey = l_orderkey
    JOIN part     ON l_partkey  = p_partkey
    GROUP BY o_custkey, c_mktsegment
) AS customer_breadth
GROUP BY c_mktsegment, avg_distinct_parts, avg_distinct_brands, avg_distinct_types
ORDER BY avg_distinct_parts DESC
LIMIT 20;

-- Q189: Shipment network efficiency (utilization by mode and region)
SELECT r_name,
       l_shipmode,
       shipment_count,
       total_qty,
       total_revenue,
       ROUND(total_revenue / shipment_count, 2) AS revenue_per_shipment,
       ROUND(total_qty     / shipment_count, 2) AS qty_per_shipment,
       RANK() OVER (PARTITION BY l_shipmode ORDER BY total_revenue DESC) AS mode_region_rank
FROM (
    SELECT r_name,
           l_shipmode,
           COUNT(*)                                        AS shipment_count,
           SUM(l_quantity)                                 AS total_qty,
           SUM(l_extendedprice * (1 - l_discount))        AS total_revenue
    FROM lineitem
    JOIN orders   ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey  = c_custkey
    JOIN nation   ON c_nationkey = n_nationkey
    JOIN region   ON n_regionkey = r_regionkey
    GROUP BY r_name, l_shipmode
) AS mode_region
ORDER BY l_shipmode, mode_region_rank;

-- Q190: Revenue at risk — items currently in uncertain return status
SELECT n_name,
       c_mktsegment,
       COUNT(*)                                         AS items_at_risk,
       SUM(l_extendedprice * (1 - l_discount))         AS revenue_at_risk,
       AVG(DATEDIFF('1998-12-31', l_receiptdate))       AS avg_days_open
FROM lineitem
JOIN orders   ON l_orderkey = o_orderkey
JOIN customer ON o_custkey  = c_custkey
JOIN nation   ON c_nationkey = n_nationkey
WHERE l_returnflag = 'A'
  AND l_linestatus = 'F'
GROUP BY n_name, c_mktsegment
ORDER BY revenue_at_risk DESC;

-- Q191: Weekly sales velocity and trend classification
WITH weekly_sales AS (
    SELECT YEARWEEK(o_orderdate) AS yr_week,
           SUM(o_totalprice)      AS weekly_revenue,
           COUNT(*)               AS order_count
    FROM orders
    GROUP BY YEARWEEK(o_orderdate)
),
with_trend AS (
    SELECT yr_week,
           weekly_revenue,
           order_count,
           AVG(weekly_revenue) OVER (
               ORDER BY yr_week ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
           ) AS moving_avg,
           LAG(weekly_revenue) OVER (ORDER BY yr_week) AS prev_week
    FROM weekly_sales
)
SELECT yr_week,
       weekly_revenue,
       ROUND(moving_avg, 0)  AS moving_avg,
       CASE
         WHEN weekly_revenue > moving_avg * 1.10 THEN 'Spike'
         WHEN weekly_revenue < moving_avg * 0.90 THEN 'Dip'
         ELSE 'Normal'
       END AS trend_label
FROM with_trend
ORDER BY yr_week;

-- Q192: Inventory optimization — overstock vs understock parts
WITH supply AS (
    SELECT ps_partkey,
           SUM(ps_availqty) AS total_supply
    FROM partsupp GROUP BY ps_partkey
),
demand AS (
    SELECT l_partkey,
           SUM(l_quantity) AS annual_demand
    FROM lineitem
    WHERE l_shipdate >= '1997-01-01'
    GROUP BY l_partkey
)
SELECT p_partkey, p_name, p_brand,
       total_supply,
       annual_demand,
       total_supply - annual_demand AS surplus,
       CASE
         WHEN total_supply > annual_demand * 2  THEN 'Overstocked'
         WHEN total_supply < annual_demand * 0.5 THEN 'Understocked'
         ELSE 'Balanced'
       END AS stock_status
FROM part
JOIN supply ON p_partkey = ps_partkey
JOIN demand ON p_partkey = l_partkey
ORDER BY ABS(total_supply - annual_demand) DESC
LIMIT 30;

-- Q193: Customer wallet share analysis per segment
SELECT c_mktsegment,
       wallet_tier,
       COUNT(*) AS customers,
       AVG(wallet_share_pct) AS avg_wallet_share
FROM (
    SELECT o_custkey,
           c_mktsegment,
           customer_spend,
           segment_total,
           ROUND(customer_spend / segment_total * 100, 4) AS wallet_share_pct,
           CASE
             WHEN customer_spend / segment_total > 0.01 THEN 'Dominant'
             WHEN customer_spend / segment_total > 0.005 THEN 'Major'
             ELSE 'Minor'
           END AS wallet_tier
    FROM (
        SELECT o_custkey,
               c_mktsegment,
               SUM(o_totalprice) AS customer_spend,
               SUM(SUM(o_totalprice)) OVER (PARTITION BY c_mktsegment) AS segment_total
        FROM orders
        JOIN customer ON o_custkey = c_custkey
        GROUP BY o_custkey, c_mktsegment
    ) AS shares
) AS tiered
GROUP BY c_mktsegment, wallet_tier
ORDER BY c_mktsegment, avg_wallet_share DESC;

-- Q194: Predictive reorder signal — parts with declining availability
SELECT ps_partkey,
       p_name,
       p_brand,
       total_stock,
       avg_monthly_demand,
       ROUND(total_stock / NULLIF(avg_monthly_demand, 0), 1) AS months_of_stock,
       CASE
         WHEN total_stock / NULLIF(avg_monthly_demand, 0) < 1  THEN 'CRITICAL'
         WHEN total_stock / NULLIF(avg_monthly_demand, 0) < 3  THEN 'LOW'
         WHEN total_stock / NULLIF(avg_monthly_demand, 0) < 6  THEN 'MEDIUM'
         ELSE 'ADEQUATE'
       END AS reorder_signal
FROM (
    SELECT ps_partkey,
           SUM(ps_availqty) AS total_stock
    FROM partsupp GROUP BY ps_partkey
) AS stock
JOIN (
    SELECT l_partkey,
           SUM(l_quantity) / COUNT(DISTINCT DATE_FORMAT(l_shipdate,'%Y-%m')) AS avg_monthly_demand
    FROM lineitem
    GROUP BY l_partkey
) AS demand ON ps_partkey = l_partkey
JOIN part ON ps_partkey = p_partkey
ORDER BY months_of_stock
LIMIT 30;

-- Q195: Full order-to-cash cycle time analysis
SELECT o_orderpriority,
       l_shipmode,
       ROUND(AVG(DATEDIFF(l_shipdate,    o_orderdate)),  1) AS avg_order_to_ship,
       ROUND(AVG(DATEDIFF(l_commitdate,  o_orderdate)),  1) AS avg_order_to_commit,
       ROUND(AVG(DATEDIFF(l_receiptdate, l_shipdate)),   1) AS avg_ship_to_receipt,
       ROUND(AVG(DATEDIFF(l_receiptdate, o_orderdate)),  1) AS avg_total_cycle,
       ROUND(STDDEV(DATEDIFF(l_receiptdate, o_orderdate)), 1) AS cycle_std_dev,
       COUNT(*) AS sample_size
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
GROUP BY o_orderpriority, l_shipmode
ORDER BY avg_total_cycle DESC;

-- Q196: Nation-level economic health index
WITH nation_scores AS (
    SELECT n_name,
           cust_count,
           supp_count,
           order_count,
           total_revenue,
           avg_balance,
           -- Normalize each dimension 0-1 using min-max scaling
           (total_revenue - MIN(total_revenue) OVER ()) /
               NULLIF(MAX(total_revenue) OVER () - MIN(total_revenue) OVER (), 0) AS rev_score,
           (avg_balance - MIN(avg_balance) OVER ()) /
               NULLIF(MAX(avg_balance) OVER () - MIN(avg_balance) OVER (), 0)    AS balance_score,
           (order_count - MIN(order_count) OVER ()) /
               NULLIF(MAX(order_count) OVER () - MIN(order_count) OVER (), 0)    AS activity_score
    FROM (
        SELECT n.n_name,
               COUNT(DISTINCT c_custkey)   AS cust_count,
               COUNT(DISTINCT s_suppkey)   AS supp_count,
               COUNT(DISTINCT o_orderkey)  AS order_count,
               SUM(o_totalprice)           AS total_revenue,
               AVG(c_acctbal)              AS avg_balance
        FROM nation n
        LEFT JOIN customer ON c_nationkey = n.n_nationkey
        LEFT JOIN orders   ON o_custkey   = c_custkey
        LEFT JOIN supplier ON s_nationkey = n.n_nationkey
        GROUP BY n.n_name
    ) AS raw
)
SELECT n_name,
       cust_count,
       supp_count,
       order_count,
       ROUND(total_revenue, 0)  AS total_revenue,
       ROUND(avg_balance, 2)    AS avg_cust_balance,
       ROUND((rev_score + balance_score + activity_score) / 3 * 100, 2) AS health_index
FROM nation_scores
ORDER BY health_index DESC;

-- Q197: Dynamic pricing analysis — price vs discount interaction
SELECT price_tier,
       discount_tier,
       COUNT(*)                                       AS transactions,
       AVG(l_quantity)                               AS avg_qty,
       AVG(l_extendedprice * (1 - l_discount))       AS avg_net_revenue,
       SUM(l_extendedprice * (1 - l_discount))       AS total_net_revenue
FROM (
    SELECT l_quantity,
           l_extendedprice,
           l_discount,
           CASE
             WHEN l_extendedprice / l_quantity < 500  THEN 'Budget'
             WHEN l_extendedprice / l_quantity < 1500 THEN 'Mid'
             ELSE 'Premium'
           END AS price_tier,
           CASE
             WHEN l_discount = 0    THEN 'No Discount'
             WHEN l_discount < 0.05 THEN 'Low (< 5%)'
             WHEN l_discount < 0.08 THEN 'Mid (5-8%)'
             ELSE 'High (>= 8%)'
           END AS discount_tier
    FROM lineitem
) AS segmented
GROUP BY price_tier, discount_tier
ORDER BY price_tier, discount_tier;

-- Q198: Comprehensive region vs region benchmark
SELECT r1.r_name AS region,
       total_orders,
       active_customers,
       total_revenue,
       avg_order_value,
       total_lineitems,
       avg_items_per_order,
       return_rate_pct,
       on_time_pct,
       RANK() OVER (ORDER BY total_revenue DESC)    AS revenue_rank,
       RANK() OVER (ORDER BY avg_order_value DESC)  AS aov_rank,
       RANK() OVER (ORDER BY on_time_pct DESC)      AS service_rank
FROM region r1
JOIN (
    SELECT r_name,
           COUNT(DISTINCT o_orderkey)                AS total_orders,
           COUNT(DISTINCT o_custkey)                 AS active_customers,
           SUM(o_totalprice)                         AS total_revenue,
           AVG(o_totalprice)                         AS avg_order_value,
           COUNT(l_linenumber)                       AS total_lineitems,
           AVG(item_count)                           AS avg_items_per_order,
           ROUND(SUM(returned) / COUNT(l_linenumber) * 100, 2)  AS return_rate_pct,
           ROUND(SUM(on_time)  / COUNT(l_linenumber) * 100, 2)  AS on_time_pct
    FROM (
        SELECT r_name,
               o_orderkey,
               o_custkey,
               o_totalprice,
               l_linenumber,
               COUNT(l_linenumber) OVER (PARTITION BY l_orderkey) AS item_count,
               CASE WHEN l_returnflag = 'R' THEN 1 ELSE 0 END    AS returned,
               CASE WHEN l_shipdate <= l_commitdate THEN 1 ELSE 0 END AS on_time
        FROM lineitem
        JOIN orders   ON l_orderkey = o_orderkey
        JOIN customer ON o_custkey  = c_custkey
        JOIN nation   ON c_nationkey = n_nationkey
        JOIN region   ON n_regionkey = r_regionkey
    ) AS base
    GROUP BY r_name
) AS metrics ON r1.r_name = metrics.r_name
ORDER BY revenue_rank;

-- Q199: Long-term trend: part type demand shift over years
SELECT p_type,
       order_year,
       annual_revenue,
       annual_qty,
       ROUND(
           annual_revenue / SUM(annual_revenue) OVER (PARTITION BY order_year) * 100, 2
       ) AS yearly_market_share_pct,
       ROUND(
           (annual_revenue - LAG(annual_revenue) OVER (PARTITION BY p_type ORDER BY order_year))
           / LAG(annual_revenue) OVER (PARTITION BY p_type ORDER BY order_year) * 100, 2
       ) AS yoy_growth_pct
FROM (
    SELECT p_type,
           YEAR(o_orderdate)                       AS order_year,
           SUM(l_extendedprice * (1-l_discount))   AS annual_revenue,
           SUM(l_quantity)                         AS annual_qty
    FROM lineitem
    JOIN orders ON l_orderkey = o_orderkey
    JOIN part   ON l_partkey  = p_partkey
    GROUP BY p_type, YEAR(o_orderdate)
) AS type_yearly
ORDER BY p_type, order_year;

-- Q200: Ultimate TPC-H complex query — full business intelligence report
WITH order_metrics AS (
    SELECT o_custkey,
           YEAR(o_orderdate)                        AS yr,
           COUNT(DISTINCT o_orderkey)               AS orders,
           SUM(o_totalprice)                        AS spend,
           AVG(o_totalprice)                        AS avg_spend
    FROM orders GROUP BY o_custkey, YEAR(o_orderdate)
),
lineitem_metrics AS (
    SELECT o_custkey,
           YEAR(o_orderdate)                        AS yr,
           SUM(l_extendedprice * (1-l_discount))   AS net_revenue,
           SUM(l_quantity)                          AS qty,
           AVG(l_discount)                          AS avg_discount,
           SUM(CASE WHEN l_returnflag='R' THEN 1 END) AS returns,
           COUNT(*)                                 AS line_items
    FROM lineitem
    JOIN orders ON l_orderkey = o_orderkey
    GROUP BY o_custkey, YEAR(o_orderdate)
)
SELECT c_name,
       c_mktsegment,
       n_name     AS nation,
       r_name     AS region,
       om.yr,
       orders,
       ROUND(spend, 0)           AS gross_spend,
       ROUND(net_revenue, 0)     AS net_revenue,
       ROUND(avg_spend, 0)       AS avg_order_value,
       qty                       AS total_qty,
       line_items,
       ROUND(avg_discount*100,2) AS avg_discount_pct,
       returns,
       ROUND(returns/line_items*100,2) AS return_rate,
       RANK() OVER (PARTITION BY r_name, om.yr ORDER BY net_revenue DESC) AS region_yr_rank,
       NTILE(4) OVER (PARTITION BY c_mktsegment ORDER BY net_revenue) AS segment_quartile
FROM order_metrics om
JOIN lineitem_metrics lm ON om.o_custkey = lm.o_custkey AND om.yr = lm.yr
JOIN customer ON om.o_custkey = c_custkey
JOIN nation   ON c_nationkey = n_nationkey
JOIN region   ON n_regionkey = r_regionkey
ORDER BY net_revenue DESC, om.yr
LIMIT 50;

-- ============================================================
-- END OF COMPLEX QUERIES (Q001 - Q200)
-- ============================================================
