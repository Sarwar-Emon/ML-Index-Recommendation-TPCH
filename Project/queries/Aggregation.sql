-- ============================================================
-- TPC-H AGGREGATION QUERIES FOR MYSQL
-- Total: 200 Queries | Max Diversity
-- Tables: customer, orders, lineitem, part, partsupp,
--         supplier, nation, region
-- ------------------------------------------------------------
-- REQUIREMENTS:
--   MySQL 8.0+ required for Section 6 (Q146-Q165) which uses
--   window functions: RANK(), DENSE_RANK(), PERCENT_RANK(),
--   NTILE(), LAG(), LEAD(), FIRST_VALUE(), ROW_NUMBER().
--   Sections 1-5 and 7-8 are compatible with MySQL 5.7+.
-- ============================================================
-- CATEGORIES:
--   Q001-Q030 : Basic COUNT / SUM / AVG / MIN / MAX
--   Q031-Q060 : GROUP BY Single Column
--   Q061-Q090 : GROUP BY Multiple Columns
--   Q091-Q120 : HAVING Filters
--   Q121-Q145 : Nested / Subquery Aggregations
--   Q146-Q165 : Window Functions (ROW_NUMBER, RANK, etc.)
--   Q166-Q180 : Conditional Aggregations (CASE + AGG)
--   Q181-Q200 : Complex / Multi-level Aggregations
-- ============================================================

-- ============================================================
-- SECTION 1: Basic COUNT / SUM / AVG / MIN / MAX (Q001-Q030)
-- ============================================================

-- Q001: Total number of orders
SELECT COUNT(*) AS total_orders
FROM orders;

-- Q002: Total revenue from all lineitems
SELECT SUM(l_extendedprice * (1 - l_discount)) AS total_revenue
FROM lineitem;

-- Q003: Average account balance of all customers
SELECT AVG(c_acctbal) AS avg_account_balance
FROM customer;

-- Q004: Minimum and maximum part retail price
SELECT MIN(p_retailprice) AS min_price,
       MAX(p_retailprice) AS max_price
FROM part;

-- Q005: Total quantity of all line items ordered
SELECT SUM(l_quantity) AS total_quantity
FROM lineitem;

-- Q006: Count of distinct customers who placed orders
SELECT COUNT(DISTINCT o_custkey) AS distinct_customers
FROM orders;

-- Q007: Average discount applied across all lineitems
SELECT AVG(l_discount) AS avg_discount
FROM lineitem;

-- Q008: Total number of suppliers
SELECT COUNT(*) AS total_suppliers
FROM supplier;

-- Q009: Total available quantity across all part-supplier combos
SELECT SUM(ps_availqty) AS total_available_qty
FROM partsupp;

-- Q010: Average supply cost across all part-supplier combos
SELECT AVG(ps_supplycost) AS avg_supply_cost
FROM partsupp;

-- Q011: Min and max order total price
SELECT MIN(o_totalprice) AS min_order_price,
       MAX(o_totalprice) AS max_order_price
FROM orders;

-- Q012: Count of lineitems with discount greater than 0.05
SELECT COUNT(*) AS high_discount_items
FROM lineitem
WHERE l_discount > 0.05;

-- Q013: Total extended price before discount
SELECT SUM(l_extendedprice) AS total_gross_revenue
FROM lineitem;

-- Q014: Average quantity per lineitem
SELECT AVG(l_quantity) AS avg_quantity
FROM lineitem;

-- Q015: Count of parts by container type
SELECT COUNT(*) AS total_parts
FROM part
WHERE p_container LIKE '%BOX%';

-- Q016: Total tax collected from all lineitems
SELECT SUM(l_extendedprice * l_tax) AS total_tax
FROM lineitem;

-- Q017: Count of customers with positive account balance
SELECT COUNT(*) AS customers_positive_balance
FROM customer
WHERE c_acctbal > 0;

-- Q018: Average order total price
SELECT AVG(o_totalprice) AS avg_order_total
FROM orders;

-- Q019: Total number of parts
SELECT COUNT(*) AS total_parts
FROM part;

-- Q020: Min and max customer account balance
SELECT MIN(c_acctbal) AS min_balance,
       MAX(c_acctbal) AS max_balance
FROM customer;

-- Q021: Count of orders per order status
SELECT o_orderstatus, COUNT(*) AS order_count
FROM orders
GROUP BY o_orderstatus;

-- Q022: Total revenue from shipped lineitems
SELECT SUM(l_extendedprice * (1 - l_discount)) AS shipped_revenue
FROM lineitem
WHERE l_shipinstruct = 'DELIVER IN PERSON';

-- Q023: Count of distinct nations
SELECT COUNT(DISTINCT n_nationkey) AS total_nations
FROM nation;

-- Q024: Average part size
SELECT AVG(p_size) AS avg_part_size
FROM part;

-- Q025: Total number of line items
SELECT COUNT(*) AS total_lineitems
FROM lineitem;

-- Q026: Sum of order totals for urgent orders
SELECT SUM(o_totalprice) AS urgent_order_total
FROM orders
WHERE o_orderpriority = '1-URGENT';

-- Q027: Count of parts with size > 20
SELECT COUNT(*) AS large_parts
FROM part
WHERE p_size > 20;

-- Q028: Average supplier account balance
SELECT AVG(s_acctbal) AS avg_supplier_balance
FROM supplier;

-- Q029: Min and max lineitem quantity
SELECT MIN(l_quantity) AS min_qty,
       MAX(l_quantity) AS max_qty
FROM lineitem;

-- Q030: Total number of regions
SELECT COUNT(*) AS total_regions
FROM region;

-- ============================================================
-- SECTION 2: GROUP BY Single Column (Q031-Q060)
-- ============================================================

-- Q031: Total orders per customer
SELECT o_custkey,
       COUNT(*) AS order_count
FROM orders
GROUP BY o_custkey
ORDER BY order_count DESC;

-- Q032: Total revenue per order
SELECT l_orderkey,
       SUM(l_extendedprice * (1 - l_discount)) AS order_revenue
FROM lineitem
GROUP BY l_orderkey
ORDER BY order_revenue DESC;

-- Q033: Average account balance per nation
SELECT c_nationkey,
       AVG(c_acctbal) AS avg_balance
FROM customer
GROUP BY c_nationkey
ORDER BY avg_balance DESC;

-- Q034: Count of parts per manufacturer
SELECT p_mfgr,
       COUNT(*) AS part_count
FROM part
GROUP BY p_mfgr
ORDER BY part_count DESC;

-- Q035: Total available quantity per supplier
SELECT ps_suppkey,
       SUM(ps_availqty) AS total_qty
FROM partsupp
GROUP BY ps_suppkey
ORDER BY total_qty DESC;

-- Q036: Average supply cost per part
SELECT ps_partkey,
       AVG(ps_supplycost) AS avg_cost
FROM partsupp
GROUP BY ps_partkey
ORDER BY avg_cost;

-- Q037: Count of orders per order priority
SELECT o_orderpriority,
       COUNT(*) AS order_count
FROM orders
GROUP BY o_orderpriority
ORDER BY order_count DESC;

-- Q038: Total quantity shipped per ship mode
SELECT l_shipmode,
       SUM(l_quantity) AS total_quantity
FROM lineitem
GROUP BY l_shipmode
ORDER BY total_quantity DESC;

-- Q039: Average discount per ship mode
SELECT l_shipmode,
       AVG(l_discount) AS avg_discount
FROM lineitem
GROUP BY l_shipmode
ORDER BY avg_discount DESC;

-- Q040: Revenue per return flag
SELECT l_returnflag,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem
GROUP BY l_returnflag;

-- Q041: Count of suppliers per nation
SELECT s_nationkey,
       COUNT(*) AS supplier_count
FROM supplier
GROUP BY s_nationkey
ORDER BY supplier_count DESC;

-- Q042: Average retail price per part type
SELECT p_type,
       AVG(p_retailprice) AS avg_price
FROM part
GROUP BY p_type
ORDER BY avg_price DESC;

-- Q043: Total order value per ship year
SELECT YEAR(o_orderdate) AS order_year,
       SUM(o_totalprice) AS total_value
FROM orders
GROUP BY YEAR(o_orderdate)
ORDER BY order_year;

-- Q044: Count of lineitems per line status
SELECT l_linestatus,
       COUNT(*) AS lineitem_count
FROM lineitem
GROUP BY l_linestatus;

-- Q045: Average order total per order year
SELECT YEAR(o_orderdate) AS order_year,
       AVG(o_totalprice) AS avg_order_value
FROM orders
GROUP BY YEAR(o_orderdate)
ORDER BY order_year;

-- Q046: Min and max supply cost per part
SELECT ps_partkey,
       MIN(ps_supplycost) AS min_cost,
       MAX(ps_supplycost) AS max_cost
FROM partsupp
GROUP BY ps_partkey;

-- Q047: Total extended price per part
SELECT l_partkey,
       SUM(l_extendedprice) AS total_price
FROM lineitem
GROUP BY l_partkey
ORDER BY total_price DESC;

-- Q048: Count of customers per market segment
SELECT c_mktsegment,
       COUNT(*) AS customer_count
FROM customer
GROUP BY c_mktsegment
ORDER BY customer_count DESC;

-- Q049: Average account balance per market segment
SELECT c_mktsegment,
       AVG(c_acctbal) AS avg_balance
FROM customer
GROUP BY c_mktsegment
ORDER BY avg_balance DESC;

-- Q050: Total revenue per supplier
SELECT l_suppkey,
       SUM(l_extendedprice * (1 - l_discount)) AS supplier_revenue
FROM lineitem
GROUP BY l_suppkey
ORDER BY supplier_revenue DESC;

-- Q051: Count of parts per brand
SELECT p_brand,
       COUNT(*) AS part_count
FROM part
GROUP BY p_brand
ORDER BY part_count DESC;

-- Q052: Average part size per brand
SELECT p_brand,
       AVG(p_size) AS avg_size
FROM part
GROUP BY p_brand
ORDER BY avg_size DESC;

-- Q053: Total orders per ship year-month
SELECT DATE_FORMAT(o_orderdate, '%Y-%m') AS order_month,
       COUNT(*) AS order_count
FROM orders
GROUP BY DATE_FORMAT(o_orderdate, '%Y-%m')
ORDER BY order_month;

-- Q054: Total tax per order
SELECT l_orderkey,
       SUM(l_extendedprice * l_tax) AS total_tax
FROM lineitem
GROUP BY l_orderkey
ORDER BY total_tax DESC;

-- Q055: Average quantity per supplier
SELECT l_suppkey,
       AVG(l_quantity) AS avg_quantity
FROM lineitem
GROUP BY l_suppkey
ORDER BY avg_quantity DESC;

-- Q056: Count of parts per container type
SELECT p_container,
       COUNT(*) AS part_count
FROM part
GROUP BY p_container
ORDER BY part_count DESC;

-- Q057: Revenue per order priority
SELECT o_orderpriority,
       SUM(o_totalprice) AS total_revenue
FROM orders
GROUP BY o_orderpriority
ORDER BY total_revenue DESC;

-- Q058: Count of lineitems per supplier
SELECT l_suppkey,
       COUNT(*) AS lineitem_count
FROM lineitem
GROUP BY l_suppkey
ORDER BY lineitem_count DESC;

-- Q059: Min order date per customer
SELECT o_custkey,
       MIN(o_orderdate) AS first_order_date
FROM orders
GROUP BY o_custkey;

-- Q060: Max order date per customer
SELECT o_custkey,
       MAX(o_orderdate) AS last_order_date
FROM orders
GROUP BY o_custkey;

-- ============================================================
-- SECTION 3: GROUP BY Multiple Columns (Q061-Q090)
-- ============================================================

-- Q061: Revenue per nation and year
SELECT c_nationkey,
       YEAR(o_orderdate) AS order_year,
       SUM(o_totalprice) AS total_revenue
FROM orders
JOIN customer ON o_custkey = c_custkey
GROUP BY c_nationkey, YEAR(o_orderdate)
ORDER BY c_nationkey, order_year;

-- Q062: Count of orders per customer and priority
SELECT o_custkey,
       o_orderpriority,
       COUNT(*) AS order_count
FROM orders
GROUP BY o_custkey, o_orderpriority
ORDER BY o_custkey;

-- Q063: Revenue per ship mode and return flag
SELECT l_shipmode,
       l_returnflag,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem
GROUP BY l_shipmode, l_returnflag
ORDER BY l_shipmode, l_returnflag;

-- Q064: Average supply cost per supplier and part
SELECT ps_suppkey,
       ps_partkey,
       AVG(ps_supplycost) AS avg_cost
FROM partsupp
GROUP BY ps_suppkey, ps_partkey
ORDER BY avg_cost DESC;

-- Q065: Count of parts per brand and container
SELECT p_brand,
       p_container,
       COUNT(*) AS part_count
FROM part
GROUP BY p_brand, p_container
ORDER BY p_brand, p_container;

-- Q066: Revenue per part type and brand
SELECT p_type,
       p_brand,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem
JOIN part ON l_partkey = p_partkey
GROUP BY p_type, p_brand
ORDER BY revenue DESC;

-- Q067: Orders per market segment and year
SELECT c_mktsegment,
       YEAR(o_orderdate) AS order_year,
       COUNT(*) AS order_count
FROM orders
JOIN customer ON o_custkey = c_custkey
GROUP BY c_mktsegment, YEAR(o_orderdate)
ORDER BY c_mktsegment, order_year;

-- Q068: Avg discount per ship mode and line status
SELECT l_shipmode,
       l_linestatus,
       AVG(l_discount) AS avg_discount
FROM lineitem
GROUP BY l_shipmode, l_linestatus
ORDER BY l_shipmode, l_linestatus;

-- Q069: Revenue per nation and market segment
SELECT n_name,
       c_mktsegment,
       SUM(o_totalprice) AS total_revenue
FROM orders
JOIN customer ON o_custkey = c_custkey
JOIN nation ON c_nationkey = n_nationkey
GROUP BY n_name, c_mktsegment
ORDER BY total_revenue DESC;

-- Q070: Quantity per supplier and ship mode
SELECT l_suppkey,
       l_shipmode,
       SUM(l_quantity) AS total_qty
FROM lineitem
GROUP BY l_suppkey, l_shipmode
ORDER BY l_suppkey;

-- Q071: Count of orders per year and priority
SELECT YEAR(o_orderdate) AS order_year,
       o_orderpriority,
       COUNT(*) AS order_count
FROM orders
GROUP BY YEAR(o_orderdate), o_orderpriority
ORDER BY order_year, o_orderpriority;

-- Q072: Avg balance per nation and market segment
SELECT c_nationkey,
       c_mktsegment,
       AVG(c_acctbal) AS avg_balance
FROM customer
GROUP BY c_nationkey, c_mktsegment
ORDER BY c_nationkey;

-- Q073: Revenue per region and year
SELECT r_name,
       YEAR(o_orderdate) AS order_year,
       SUM(o_totalprice) AS total_revenue
FROM orders
JOIN customer ON o_custkey = c_custkey
JOIN nation ON c_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
GROUP BY r_name, YEAR(o_orderdate)
ORDER BY r_name, order_year;

-- Q074: Part count per manufacturer and brand
SELECT p_mfgr,
       p_brand,
       COUNT(*) AS part_count
FROM part
GROUP BY p_mfgr, p_brand
ORDER BY p_mfgr, p_brand;

-- Q075: Avg order value per year and ship mode
SELECT YEAR(o_orderdate) AS order_year,
       l_shipmode,
       AVG(o_totalprice) AS avg_order_value
FROM orders
JOIN lineitem ON o_orderkey = l_orderkey
GROUP BY YEAR(o_orderdate), l_shipmode
ORDER BY order_year, l_shipmode;

-- Q076: Total supply cost per nation and part type
SELECT n_name,
       p_type,
       SUM(ps_supplycost * ps_availqty) AS total_supply_cost
FROM partsupp
JOIN supplier ON ps_suppkey = s_suppkey
JOIN nation ON s_nationkey = n_nationkey
JOIN part ON ps_partkey = p_partkey
GROUP BY n_name, p_type
ORDER BY total_supply_cost DESC;

-- Q077: Revenue per customer segment and return flag
SELECT c_mktsegment,
       l_returnflag,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
JOIN customer ON o_custkey = c_custkey
GROUP BY c_mktsegment, l_returnflag
ORDER BY c_mktsegment;

-- Q078: Avg extended price per brand and ship mode
SELECT p_brand,
       l_shipmode,
       AVG(l_extendedprice) AS avg_price
FROM lineitem
JOIN part ON l_partkey = p_partkey
GROUP BY p_brand, l_shipmode
ORDER BY p_brand, l_shipmode;

-- Q079: Count of orders per clerk and year
SELECT o_clerk,
       YEAR(o_orderdate) AS order_year,
       COUNT(*) AS order_count
FROM orders
GROUP BY o_clerk, YEAR(o_orderdate)
ORDER BY o_clerk, order_year;

-- Q080: Avg quantity per part and return flag
SELECT l_partkey,
       l_returnflag,
       AVG(l_quantity) AS avg_qty
FROM lineitem
GROUP BY l_partkey, l_returnflag
ORDER BY l_partkey;

-- Q081: Supply cost per region and brand
SELECT r_name,
       p_brand,
       AVG(ps_supplycost) AS avg_supply_cost
FROM partsupp
JOIN part ON ps_partkey = p_partkey
JOIN supplier ON ps_suppkey = s_suppkey
JOIN nation ON s_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
GROUP BY r_name, p_brand
ORDER BY r_name, p_brand;

-- Q082: Revenue per month and return flag
SELECT DATE_FORMAT(l_shipdate, '%Y-%m') AS ship_month,
       l_returnflag,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem
GROUP BY DATE_FORMAT(l_shipdate, '%Y-%m'), l_returnflag
ORDER BY ship_month;

-- Q083: Count of parts per size and container
SELECT p_size,
       p_container,
       COUNT(*) AS part_count
FROM part
GROUP BY p_size, p_container
ORDER BY p_size, p_container;

-- Q084: Revenue per nation pair (supplier nation vs customer nation)
SELECT n1.n_name AS supplier_nation,
       n2.n_name AS customer_nation,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
JOIN customer ON o_custkey = c_custkey
JOIN supplier ON l_suppkey = s_suppkey
JOIN nation n1 ON s_nationkey = n1.n_nationkey
JOIN nation n2 ON c_nationkey = n2.n_nationkey
GROUP BY n1.n_name, n2.n_name
ORDER BY revenue DESC;

-- Q085: Avg retail price per type and size
SELECT p_type,
       p_size,
       AVG(p_retailprice) AS avg_price
FROM part
GROUP BY p_type, p_size
ORDER BY p_type, p_size;

-- Q086: Orders per market segment and priority
SELECT c_mktsegment,
       o_orderpriority,
       COUNT(*) AS order_count
FROM orders
JOIN customer ON o_custkey = c_custkey
GROUP BY c_mktsegment, o_orderpriority
ORDER BY c_mktsegment, o_orderpriority;

-- Q087: Revenue per region and market segment
SELECT r_name,
       c_mktsegment,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
JOIN customer ON o_custkey = c_custkey
JOIN nation ON c_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
GROUP BY r_name, c_mktsegment
ORDER BY r_name, revenue DESC;

-- Q088: Avg balance per region and segment
SELECT r_name,
       c_mktsegment,
       AVG(c_acctbal) AS avg_balance
FROM customer
JOIN nation ON c_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
GROUP BY r_name, c_mktsegment
ORDER BY r_name;

-- Q089: Total discount per year and ship mode
SELECT YEAR(l_shipdate) AS ship_year,
       l_shipmode,
       SUM(l_extendedprice * l_discount) AS total_discount
FROM lineitem
GROUP BY YEAR(l_shipdate), l_shipmode
ORDER BY ship_year, l_shipmode;

-- Q090: Count of lineitems per year and return flag
SELECT YEAR(l_shipdate) AS ship_year,
       l_returnflag,
       COUNT(*) AS item_count
FROM lineitem
GROUP BY YEAR(l_shipdate), l_returnflag
ORDER BY ship_year, l_returnflag;

-- ============================================================
-- SECTION 4: HAVING Filters (Q091-Q120)
-- ============================================================

-- Q091: Customers with more than 10 orders
SELECT o_custkey,
       COUNT(*) AS order_count
FROM orders
GROUP BY o_custkey
HAVING COUNT(*) > 10
ORDER BY order_count DESC;

-- Q092: Suppliers with total available qty > 50000
SELECT ps_suppkey,
       SUM(ps_availqty) AS total_qty
FROM partsupp
GROUP BY ps_suppkey
HAVING SUM(ps_availqty) > 50000
ORDER BY total_qty DESC;

-- Q093: Parts with average supply cost > 500
SELECT ps_partkey,
       AVG(ps_supplycost) AS avg_cost
FROM partsupp
GROUP BY ps_partkey
HAVING AVG(ps_supplycost) > 500
ORDER BY avg_cost DESC;

-- Q094: Ship modes with average discount > 0.05
SELECT l_shipmode,
       AVG(l_discount) AS avg_discount
FROM lineitem
GROUP BY l_shipmode
HAVING AVG(l_discount) > 0.05
ORDER BY avg_discount DESC;

-- Q095: Nations with more than 1000 customers
SELECT c_nationkey,
       COUNT(*) AS customer_count
FROM customer
GROUP BY c_nationkey
HAVING COUNT(*) > 1000
ORDER BY customer_count DESC;

-- Q096: Orders with total revenue > 200000
SELECT l_orderkey,
       SUM(l_extendedprice * (1 - l_discount)) AS order_revenue
FROM lineitem
GROUP BY l_orderkey
HAVING SUM(l_extendedprice * (1 - l_discount)) > 200000
ORDER BY order_revenue DESC;

-- Q097: Manufacturers with more than 200 parts
SELECT p_mfgr,
       COUNT(*) AS part_count
FROM part
GROUP BY p_mfgr
HAVING COUNT(*) > 200
ORDER BY part_count DESC;

-- Q098: Customers with avg order value > 100000
SELECT o_custkey,
       AVG(o_totalprice) AS avg_order_value
FROM orders
GROUP BY o_custkey
HAVING AVG(o_totalprice) > 100000
ORDER BY avg_order_value DESC;

-- Q099: Suppliers whose avg supply cost > global avg
SELECT ps_suppkey,
       AVG(ps_supplycost) AS avg_cost
FROM partsupp
GROUP BY ps_suppkey
HAVING AVG(ps_supplycost) > (SELECT AVG(ps_supplycost) FROM partsupp)
ORDER BY avg_cost DESC;

-- Q100: Part-supplier pairs with low stock (availqty < 100)
SELECT ps_partkey,
       ps_suppkey,
       ps_availqty
FROM partsupp
WHERE ps_availqty < 100
ORDER BY ps_availqty;

-- Q101: Nations where avg customer balance > 4000
SELECT c_nationkey,
       AVG(c_acctbal) AS avg_balance
FROM customer
GROUP BY c_nationkey
HAVING AVG(c_acctbal) > 4000
ORDER BY avg_balance DESC;

-- Q102: Ship modes with total quantity > 5000000
SELECT l_shipmode,
       SUM(l_quantity) AS total_qty
FROM lineitem
GROUP BY l_shipmode
HAVING SUM(l_quantity) > 5000000
ORDER BY total_qty DESC;

-- Q103: Brands with more than 500 distinct parts
SELECT p_brand,
       COUNT(DISTINCT p_partkey) AS distinct_parts
FROM part
GROUP BY p_brand
HAVING COUNT(DISTINCT p_partkey) > 500
ORDER BY distinct_parts DESC;

-- Q104: Clerks handling > 500 orders
SELECT o_clerk,
       COUNT(*) AS order_count
FROM orders
GROUP BY o_clerk
HAVING COUNT(*) > 500
ORDER BY order_count DESC;

-- Q105: Part types with max retail price > 2000
SELECT p_type,
       MAX(p_retailprice) AS max_price
FROM part
GROUP BY p_type
HAVING MAX(p_retailprice) > 2000
ORDER BY max_price DESC;

-- Q106: Suppliers with revenue contribution > 500000
SELECT l_suppkey,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem
GROUP BY l_suppkey
HAVING SUM(l_extendedprice * (1 - l_discount)) > 500000
ORDER BY revenue DESC;

-- Q107: Years with total order value > 1 billion
SELECT YEAR(o_orderdate) AS order_year,
       SUM(o_totalprice) AS total_value
FROM orders
GROUP BY YEAR(o_orderdate)
HAVING SUM(o_totalprice) > 1000000000
ORDER BY order_year;

-- Q108: Nations with more than 50 suppliers
SELECT s_nationkey,
       COUNT(*) AS supplier_count
FROM supplier
GROUP BY s_nationkey
HAVING COUNT(*) > 50
ORDER BY supplier_count DESC;

-- Q109: Market segments with avg balance > global avg
SELECT c_mktsegment,
       AVG(c_acctbal) AS avg_balance
FROM customer
GROUP BY c_mktsegment
HAVING AVG(c_acctbal) > (SELECT AVG(c_acctbal) FROM customer)
ORDER BY avg_balance DESC;

-- Q110: Parts ordered more than 1000 times
SELECT l_partkey,
       COUNT(*) AS order_times
FROM lineitem
GROUP BY l_partkey
HAVING COUNT(*) > 1000
ORDER BY order_times DESC;

-- Q111: Suppliers providing more than 5 distinct parts
SELECT ps_suppkey,
       COUNT(DISTINCT ps_partkey) AS distinct_parts
FROM partsupp
GROUP BY ps_suppkey
HAVING COUNT(DISTINCT ps_partkey) > 5
ORDER BY distinct_parts DESC;

-- Q112: Order priority groups with avg total > 150000
SELECT o_orderpriority,
       AVG(o_totalprice) AS avg_total
FROM orders
GROUP BY o_orderpriority
HAVING AVG(o_totalprice) > 150000
ORDER BY avg_total DESC;

-- Q113: Customers with orders in more than 5 different years
SELECT o_custkey,
       COUNT(DISTINCT YEAR(o_orderdate)) AS active_years
FROM orders
GROUP BY o_custkey
HAVING COUNT(DISTINCT YEAR(o_orderdate)) > 5
ORDER BY active_years DESC;

-- Q114: Part containers with avg size > 30
SELECT p_container,
       AVG(p_size) AS avg_size
FROM part
GROUP BY p_container
HAVING AVG(p_size) > 30
ORDER BY avg_size DESC;

-- Q115: Return flags with total discount > 50 million
SELECT l_returnflag,
       SUM(l_extendedprice * l_discount) AS total_discount
FROM lineitem
GROUP BY l_returnflag
HAVING SUM(l_extendedprice * l_discount) > 50000000
ORDER BY total_discount DESC;

-- Q116: Suppliers with min supply cost < 10
SELECT ps_suppkey,
       MIN(ps_supplycost) AS min_cost
FROM partsupp
GROUP BY ps_suppkey
HAVING MIN(ps_supplycost) < 10
ORDER BY min_cost;

-- Q117: Customers in nations where total orders > 10000
SELECT c_nationkey,
       COUNT(*) AS customer_count,
       COUNT(DISTINCT o_orderkey) AS total_orders
FROM customer
JOIN orders ON c_custkey = o_custkey
GROUP BY c_nationkey
HAVING COUNT(DISTINCT o_orderkey) > 10000
ORDER BY total_orders DESC;

-- Q118: Brands with avg retail price between 1000 and 2000
SELECT p_brand,
       AVG(p_retailprice) AS avg_retail_price
FROM part
GROUP BY p_brand
HAVING AVG(p_retailprice) BETWEEN 1000 AND 2000
ORDER BY avg_retail_price;

-- Q119: Ship modes where returned item count > 100000
SELECT l_shipmode,
       COUNT(*) AS returned_count
FROM lineitem
WHERE l_returnflag = 'R'
GROUP BY l_shipmode
HAVING COUNT(*) > 100000
ORDER BY returned_count DESC;

-- Q120: Regions with more than 5 nations
SELECT r_regionkey,
       COUNT(*) AS nation_count
FROM nation
GROUP BY r_regionkey
HAVING COUNT(*) > 5
ORDER BY nation_count DESC;

-- ============================================================
-- SECTION 5: Nested / Subquery Aggregations (Q121-Q145)
-- ============================================================

-- Q121: Customers with above-average number of orders
SELECT o_custkey,
       COUNT(*) AS order_count
FROM orders
GROUP BY o_custkey
HAVING COUNT(*) > (
    SELECT AVG(cnt) FROM (
        SELECT COUNT(*) AS cnt
        FROM orders
        GROUP BY o_custkey
    ) AS sub
)
ORDER BY order_count DESC;

-- Q122: Parts with above-average retail price per type
SELECT p_partkey,
       p_type,
       p_retailprice
FROM part p
WHERE p_retailprice > (
    SELECT AVG(p2.p_retailprice)
    FROM part p2
    WHERE p2.p_type = p.p_type
)
ORDER BY p_type, p_retailprice DESC;

-- Q123: Suppliers with supply cost below category average
SELECT ps_suppkey,
       ps_partkey,
       ps_supplycost
FROM partsupp ps
WHERE ps_supplycost < (
    SELECT AVG(ps2.ps_supplycost)
    FROM partsupp ps2
    WHERE ps2.ps_partkey = ps.ps_partkey
)
ORDER BY ps_supplycost;

-- Q124: Top 10 customers by total order value
SELECT o_custkey,
       SUM(o_totalprice) AS total_value
FROM orders
GROUP BY o_custkey
ORDER BY total_value DESC
LIMIT 10;

-- Q125: Revenue per nation as % of total revenue
SELECT n_name,
       SUM(l_extendedprice * (1 - l_discount)) AS nation_revenue,
       SUM(l_extendedprice * (1 - l_discount)) /
           (SELECT SUM(l2.l_extendedprice * (1 - l2.l_discount)) FROM lineitem l2) * 100
           AS revenue_pct
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
JOIN customer ON o_custkey = c_custkey
JOIN nation ON c_nationkey = n_nationkey
GROUP BY n_name
ORDER BY nation_revenue DESC;

-- Q126: Parts never ordered
SELECT p_partkey, p_name
FROM part
WHERE p_partkey NOT IN (
    SELECT DISTINCT l_partkey FROM lineitem
);

-- Q127: Customers with no orders
SELECT c_custkey, c_name
FROM customer
WHERE c_custkey NOT IN (
    SELECT DISTINCT o_custkey FROM orders
);

-- Q128: Average order count per customer by market segment
SELECT c_mktsegment,
       AVG(order_count) AS avg_orders_per_customer
FROM (
    SELECT c_mktsegment,
           o_custkey,
           COUNT(*) AS order_count
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    GROUP BY c_mktsegment, o_custkey
) AS sub
GROUP BY c_mktsegment
ORDER BY avg_orders_per_customer DESC;

-- Q129: Nations ranked by total revenue
SELECT n_name,
       SUM(l_extendedprice * (1 - l_discount)) AS total_revenue,
       RANK() OVER (ORDER BY SUM(l_extendedprice * (1 - l_discount)) DESC) AS revenue_rank
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
JOIN customer ON o_custkey = c_custkey
JOIN nation ON c_nationkey = n_nationkey
GROUP BY n_name
ORDER BY revenue_rank;

-- Q130: Supplier with highest single supply cost per nation
SELECT n_name,
       s_name,
       MAX(ps_supplycost) AS max_supply_cost
FROM partsupp
JOIN supplier ON ps_suppkey = s_suppkey
JOIN nation ON s_nationkey = n_nationkey
GROUP BY n_name, s_name
ORDER BY n_name, max_supply_cost DESC;

-- Q131: Revenue growth year-over-year
SELECT order_year,
       total_revenue,
       LAG(total_revenue) OVER (ORDER BY order_year) AS prev_year_revenue,
       total_revenue - LAG(total_revenue) OVER (ORDER BY order_year) AS yoy_growth
FROM (
    SELECT YEAR(o_orderdate) AS order_year,
           SUM(o_totalprice) AS total_revenue
    FROM orders
    GROUP BY YEAR(o_orderdate)
) AS yearly
ORDER BY order_year;

-- Q132: Top 5 parts by revenue per brand
SELECT p_brand,
       p_name,
       revenue
FROM (
    SELECT p_brand,
           p_name,
           SUM(l_extendedprice * (1 - l_discount)) AS revenue,
           RANK() OVER (PARTITION BY p_brand ORDER BY SUM(l_extendedprice * (1 - l_discount)) DESC) AS rnk
    FROM lineitem
    JOIN part ON l_partkey = p_partkey
    GROUP BY p_brand, p_name
) AS ranked
WHERE rnk <= 5
ORDER BY p_brand, revenue DESC;

-- Q133: Percentage of orders per priority per year
SELECT order_year,
       o_orderpriority,
       order_count,
       order_count / SUM(order_count) OVER (PARTITION BY order_year) * 100 AS pct
FROM (
    SELECT YEAR(o_orderdate) AS order_year,
           o_orderpriority,
           COUNT(*) AS order_count
    FROM orders
    GROUP BY YEAR(o_orderdate), o_orderpriority
) AS sub
ORDER BY order_year, o_orderpriority;

-- Q134: Avg number of lineitems per order per year
SELECT order_year,
       AVG(lineitem_count) AS avg_lineitems_per_order
FROM (
    SELECT YEAR(o_orderdate) AS order_year,
           l_orderkey,
           COUNT(*) AS lineitem_count
    FROM lineitem
    JOIN orders ON l_orderkey = o_orderkey
    GROUP BY YEAR(o_orderdate), l_orderkey
) AS sub
GROUP BY order_year
ORDER BY order_year;

-- Q135: Nations where supplier revenue exceeds customer spend
SELECT n_name
FROM (
    SELECT n_name,
           SUM(l_extendedprice * (1 - l_discount)) AS nation_supply_revenue
    FROM lineitem
    JOIN supplier ON l_suppkey = s_suppkey
    JOIN nation ON s_nationkey = n_nationkey
    GROUP BY n_name
) AS supply
WHERE nation_supply_revenue > (
    SELECT SUM(o_totalprice) / COUNT(DISTINCT n_nationkey)
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    JOIN nation ON c_nationkey = n_nationkey
);

-- Q136: Top supplier per part by available quantity
SELECT ps_partkey,
       ps_suppkey,
       ps_availqty
FROM partsupp ps
WHERE ps_availqty = (
    SELECT MAX(ps2.ps_availqty)
    FROM partsupp ps2
    WHERE ps2.ps_partkey = ps.ps_partkey
)
ORDER BY ps_partkey;

-- Q137: Customers whose total spend exceeds 10x their account balance
SELECT c_custkey,
       c_name,
       c_acctbal,
       total_spend
FROM customer
JOIN (
    SELECT o_custkey,
           SUM(o_totalprice) AS total_spend
    FROM orders
    GROUP BY o_custkey
) AS spend ON c_custkey = spend.o_custkey
WHERE total_spend > 10 * c_acctbal
ORDER BY total_spend DESC;

-- Q138: Revenue share per ship mode per year
SELECT ship_year,
       l_shipmode,
       mode_revenue,
       mode_revenue / SUM(mode_revenue) OVER (PARTITION BY ship_year) * 100 AS revenue_pct
FROM (
    SELECT YEAR(l_shipdate) AS ship_year,
           l_shipmode,
           SUM(l_extendedprice * (1 - l_discount)) AS mode_revenue
    FROM lineitem
    GROUP BY YEAR(l_shipdate), l_shipmode
) AS sub
ORDER BY ship_year, revenue_pct DESC;

-- Q139: Parts with highest price deviation from type average
SELECT p_partkey,
       p_type,
       p_retailprice,
       ABS(p_retailprice - avg_type_price) AS price_deviation
FROM part
JOIN (
    SELECT p_type,
           AVG(p_retailprice) AS avg_type_price
    FROM part
    GROUP BY p_type
) AS avg_prices USING (p_type)
ORDER BY price_deviation DESC
LIMIT 20;

-- Q140: Cumulative revenue by order date
SELECT o_orderdate,
       SUM(o_totalprice) AS daily_revenue,
       SUM(SUM(o_totalprice)) OVER (ORDER BY o_orderdate) AS cumulative_revenue
FROM orders
GROUP BY o_orderdate
ORDER BY o_orderdate;

-- Q141: Nations with above-median supplier count
SELECT n_name,
       supplier_count
FROM (
    SELECT n_name,
           COUNT(*) AS supplier_count
    FROM supplier
    JOIN nation ON s_nationkey = n_nationkey
    GROUP BY n_name
) AS nation_suppliers
WHERE supplier_count > (
    SELECT AVG(cnt) FROM (
        SELECT COUNT(*) AS cnt
        FROM supplier
        GROUP BY s_nationkey
    ) AS avg_sub
)
ORDER BY supplier_count DESC;

-- Q142: Total discount savings per market segment
SELECT c_mktsegment,
       SUM(l_extendedprice * l_discount) AS total_discount_savings
FROM lineitem
JOIN orders ON l_orderkey = o_orderkey
JOIN customer ON o_custkey = c_custkey
GROUP BY c_mktsegment
ORDER BY total_discount_savings DESC;

-- Q143: Avg lineitems per order by priority
SELECT o_orderpriority,
       AVG(item_count) AS avg_lineitems
FROM (
    SELECT o_orderkey,
           o_orderpriority,
           COUNT(*) AS item_count
    FROM orders
    JOIN lineitem ON o_orderkey = l_orderkey
    GROUP BY o_orderkey, o_orderpriority
) AS sub
GROUP BY o_orderpriority
ORDER BY avg_lineitems DESC;

-- Q144: Revenue from parts with size > 30 vs <= 30
SELECT CASE WHEN p_size > 30 THEN 'Large' ELSE 'Small' END AS size_group,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem
JOIN part ON l_partkey = p_partkey
GROUP BY size_group
ORDER BY revenue DESC;

-- Q145: Average days between order and ship date
SELECT YEAR(o_orderdate) AS order_year,
       AVG(DATEDIFF(l_shipdate, o_orderdate)) AS avg_ship_lag_days
FROM orders
JOIN lineitem ON o_orderkey = l_orderkey
GROUP BY YEAR(o_orderdate)
ORDER BY order_year;

-- ============================================================
-- SECTION 6: Window Functions (Q146-Q165)
-- ============================================================

-- Q146: Rank customers by total spend
SELECT o_custkey,
       SUM(o_totalprice) AS total_spend,
       RANK() OVER (ORDER BY SUM(o_totalprice) DESC) AS spend_rank
FROM orders
GROUP BY o_custkey
ORDER BY spend_rank;

-- Q147: Dense rank of nations by supplier count
SELECT n_name,
       COUNT(*) AS supplier_count,
       DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS nation_rank
FROM supplier
JOIN nation ON s_nationkey = n_nationkey
GROUP BY n_name
ORDER BY nation_rank;

-- Q148: Running total of orders per year
SELECT YEAR(o_orderdate) AS order_year,
       COUNT(*) AS yearly_orders,
       SUM(COUNT(*)) OVER (ORDER BY YEAR(o_orderdate)) AS running_total_orders
FROM orders
GROUP BY YEAR(o_orderdate)
ORDER BY order_year;

-- Q149: Revenue percentile per nation
SELECT n_name,
       nation_revenue,
       PERCENT_RANK() OVER (ORDER BY nation_revenue) AS revenue_percentile
FROM (
    SELECT n_name,
           SUM(l_extendedprice * (1 - l_discount)) AS nation_revenue
    FROM lineitem
    JOIN orders ON l_orderkey = o_orderkey
    JOIN customer ON o_custkey = c_custkey
    JOIN nation ON c_nationkey = n_nationkey
    GROUP BY n_name
) AS sub
ORDER BY revenue_percentile DESC;

-- Q150: Moving average of daily order value (7-day)
SELECT o_orderdate,
       daily_total,
       AVG(daily_total) OVER (ORDER BY o_orderdate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7d
FROM (
    SELECT o_orderdate,
           SUM(o_totalprice) AS daily_total
    FROM orders
    GROUP BY o_orderdate
) AS daily
ORDER BY o_orderdate;

-- Q151: First and last order per customer
SELECT o_custkey,
       MIN(o_orderdate) AS first_order,
       MAX(o_orderdate) AS last_order,
       DATEDIFF(MAX(o_orderdate), MIN(o_orderdate)) AS customer_lifespan_days
FROM orders
GROUP BY o_custkey
ORDER BY customer_lifespan_days DESC;

-- Q152: Row number of lineitems per order by price
SELECT l_orderkey,
       l_linenumber,
       l_extendedprice,
       ROW_NUMBER() OVER (PARTITION BY l_orderkey ORDER BY l_extendedprice DESC) AS price_rank
FROM lineitem
ORDER BY l_orderkey, price_rank;

-- Q153: Cumulative quantity shipped per mode
SELECT l_shipmode,
       ship_year,
       yearly_qty,
       SUM(yearly_qty) OVER (PARTITION BY l_shipmode ORDER BY ship_year) AS cumulative_qty
FROM (
    SELECT l_shipmode,
           YEAR(l_shipdate) AS ship_year,
           SUM(l_quantity) AS yearly_qty
    FROM lineitem
    GROUP BY l_shipmode, YEAR(l_shipdate)
) AS sub
ORDER BY l_shipmode, ship_year;

-- Q154: Ntile buckets of customers by spend (quartiles)
SELECT o_custkey,
       total_spend,
       NTILE(4) OVER (ORDER BY total_spend) AS spend_quartile
FROM (
    SELECT o_custkey,
           SUM(o_totalprice) AS total_spend
    FROM orders
    GROUP BY o_custkey
) AS sub
ORDER BY total_spend DESC;

-- Q155: Lag/Lead: Compare nation revenue year over year
SELECT n_name,
       order_year,
       nation_revenue,
       LAG(nation_revenue) OVER (PARTITION BY n_name ORDER BY order_year) AS prev_year,
       nation_revenue - LAG(nation_revenue) OVER (PARTITION BY n_name ORDER BY order_year) AS delta
FROM (
    SELECT n_name,
           YEAR(o_orderdate) AS order_year,
           SUM(o_totalprice) AS nation_revenue
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    JOIN nation ON c_nationkey = n_nationkey
    GROUP BY n_name, YEAR(o_orderdate)
) AS sub
ORDER BY n_name, order_year;

-- Q156: Max revenue ship mode per year using window
SELECT ship_year,
       l_shipmode,
       mode_revenue,
       MAX(mode_revenue) OVER (PARTITION BY ship_year) AS max_mode_revenue
FROM (
    SELECT YEAR(l_shipdate) AS ship_year,
           l_shipmode,
           SUM(l_extendedprice * (1 - l_discount)) AS mode_revenue
    FROM lineitem
    GROUP BY YEAR(l_shipdate), l_shipmode
) AS sub
ORDER BY ship_year, mode_revenue DESC;

-- Q157: Rank parts by revenue within each brand
SELECT p_brand,
       p_partkey,
       part_revenue,
       RANK() OVER (PARTITION BY p_brand ORDER BY part_revenue DESC) AS brand_rank
FROM (
    SELECT p_brand,
           l_partkey AS p_partkey,
           SUM(l_extendedprice * (1 - l_discount)) AS part_revenue
    FROM lineitem
    JOIN part ON l_partkey = p_partkey
    GROUP BY p_brand, l_partkey
) AS sub
ORDER BY p_brand, brand_rank;

-- Q158: Supplier rank by available qty per part
SELECT ps_partkey,
       ps_suppkey,
       ps_availqty,
       RANK() OVER (PARTITION BY ps_partkey ORDER BY ps_availqty DESC) AS avail_rank
FROM partsupp
ORDER BY ps_partkey, avail_rank;

-- Q159: Customer spend compared to segment average
SELECT o_custkey,
       c_mktsegment,
       customer_spend,
       AVG(customer_spend) OVER (PARTITION BY c_mktsegment) AS segment_avg_spend,
       customer_spend - AVG(customer_spend) OVER (PARTITION BY c_mktsegment) AS deviation_from_avg
FROM (
    SELECT o_custkey,
           c_mktsegment,
           SUM(o_totalprice) AS customer_spend
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    GROUP BY o_custkey, c_mktsegment
) AS sub
ORDER BY deviation_from_avg DESC;

-- Q160: Cumulative revenue per region
SELECT r_name,
       order_year,
       yearly_revenue,
       SUM(yearly_revenue) OVER (PARTITION BY r_name ORDER BY order_year) AS cumulative_revenue
FROM (
    SELECT r_name,
           YEAR(o_orderdate) AS order_year,
           SUM(o_totalprice) AS yearly_revenue
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    JOIN nation ON c_nationkey = n_nationkey
    JOIN region ON n_regionkey = r_regionkey
    GROUP BY r_name, YEAR(o_orderdate)
) AS sub
ORDER BY r_name, order_year;

-- Q161: First value of order per customer (highest value)
SELECT DISTINCT o_custkey,
       FIRST_VALUE(o_orderkey) OVER (
           PARTITION BY o_custkey
           ORDER BY o_totalprice DESC
       ) AS highest_value_order
FROM orders
ORDER BY o_custkey;

-- Q162: Rank suppliers by total supplied value per nation
SELECT n_name,
       s_name,
       total_supply_value,
       RANK() OVER (PARTITION BY n_name ORDER BY total_supply_value DESC) AS nation_rank
FROM (
    SELECT n_name,
           s_name,
           SUM(ps_supplycost * ps_availqty) AS total_supply_value
    FROM partsupp
    JOIN supplier ON ps_suppkey = s_suppkey
    JOIN nation ON s_nationkey = n_nationkey
    GROUP BY n_name, s_name
) AS sub
ORDER BY n_name, nation_rank;

-- Q163: Running min/max order total per customer
SELECT o_custkey,
       o_orderdate,
       o_totalprice,
       MIN(o_totalprice) OVER (PARTITION BY o_custkey ORDER BY o_orderdate) AS running_min,
       MAX(o_totalprice) OVER (PARTITION BY o_custkey ORDER BY o_orderdate) AS running_max
FROM orders
ORDER BY o_custkey, o_orderdate;

-- Q164: Avg supply cost deviation per part type
SELECT p_type,
       ps_partkey,
       ps_supplycost,
       AVG(ps_supplycost) OVER (PARTITION BY p_type) AS type_avg_cost,
       ps_supplycost - AVG(ps_supplycost) OVER (PARTITION BY p_type) AS deviation
FROM partsupp
JOIN part ON ps_partkey = p_partkey
ORDER BY deviation DESC;

-- Q165: Lead: Next year's projected revenue per nation
SELECT n_name,
       order_year,
       nation_revenue,
       LEAD(nation_revenue) OVER (PARTITION BY n_name ORDER BY order_year) AS next_year_revenue
FROM (
    SELECT n_name,
           YEAR(o_orderdate) AS order_year,
           SUM(o_totalprice) AS nation_revenue
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    JOIN nation ON c_nationkey = n_nationkey
    GROUP BY n_name, YEAR(o_orderdate)
) AS sub
ORDER BY n_name, order_year;

-- ============================================================
-- SECTION 7: Conditional Aggregations (Q166-Q180)
-- ============================================================

-- Q166: Revenue split by return flag using CASE
SELECT l_shipmode,
       SUM(CASE WHEN l_returnflag = 'R' THEN l_extendedprice * (1 - l_discount) ELSE 0 END) AS returned_revenue,
       SUM(CASE WHEN l_returnflag = 'N' THEN l_extendedprice * (1 - l_discount) ELSE 0 END) AS non_returned_revenue,
       SUM(CASE WHEN l_returnflag = 'A' THEN l_extendedprice * (1 - l_discount) ELSE 0 END) AS accepted_revenue
FROM lineitem
GROUP BY l_shipmode
ORDER BY l_shipmode;

-- Q167: Count of high/low value orders per customer
SELECT o_custkey,
       COUNT(CASE WHEN o_totalprice > 200000 THEN 1 END) AS high_value_orders,
       COUNT(CASE WHEN o_totalprice <= 200000 THEN 1 END) AS low_value_orders
FROM orders
GROUP BY o_custkey
ORDER BY high_value_orders DESC;

-- Q168: Revenue from urgent vs non-urgent orders
SELECT CASE WHEN o_orderpriority = '1-URGENT' THEN 'Urgent' ELSE 'Non-Urgent' END AS priority_group,
       SUM(o_totalprice) AS total_revenue,
       COUNT(*) AS order_count
FROM orders
GROUP BY priority_group
ORDER BY total_revenue DESC;

-- Q169: Avg discount by discount tier
SELECT CASE
         WHEN l_discount < 0.02 THEN 'Low (< 2%)'
         WHEN l_discount < 0.05 THEN 'Medium (2-5%)'
         WHEN l_discount < 0.08 THEN 'High (5-8%)'
         ELSE 'Very High (>= 8%)'
       END AS discount_tier,
       COUNT(*) AS item_count,
       AVG(l_extendedprice) AS avg_price
FROM lineitem
GROUP BY discount_tier
ORDER BY avg_price DESC;

-- Q170: Supplier balance tier distribution
SELECT CASE
         WHEN s_acctbal < 0 THEN 'Negative'
         WHEN s_acctbal < 2500 THEN 'Low'
         WHEN s_acctbal < 5000 THEN 'Medium'
         ELSE 'High'
       END AS balance_tier,
       COUNT(*) AS supplier_count,
       AVG(s_acctbal) AS avg_balance
FROM supplier
GROUP BY balance_tier
ORDER BY avg_balance DESC;

-- Q171: Orders per quarter per year
SELECT YEAR(o_orderdate) AS order_year,
       QUARTER(o_orderdate) AS order_quarter,
       COUNT(*) AS order_count,
       SUM(o_totalprice) AS quarterly_revenue
FROM orders
GROUP BY YEAR(o_orderdate), QUARTER(o_orderdate)
ORDER BY order_year, order_quarter;

-- Q172: Large vs small parts revenue
SELECT CASE WHEN p_size > 25 THEN 'Large' ELSE 'Small' END AS part_size_group,
       COUNT(DISTINCT l_partkey) AS distinct_parts,
       SUM(l_extendedprice * (1 - l_discount)) AS total_revenue,
       AVG(l_extendedprice) AS avg_price
FROM lineitem
JOIN part ON l_partkey = p_partkey
GROUP BY part_size_group;

-- Q173: Weekend vs weekday order analysis
SELECT CASE
         WHEN DAYOFWEEK(o_orderdate) IN (1, 7) THEN 'Weekend'
         ELSE 'Weekday'
       END AS day_type,
       COUNT(*) AS order_count,
       AVG(o_totalprice) AS avg_order_value,
       SUM(o_totalprice) AS total_revenue
FROM orders
GROUP BY day_type
ORDER BY total_revenue DESC;

-- Q174: Positive vs negative customer account balance analysis
SELECT CASE WHEN c_acctbal >= 0 THEN 'Positive' ELSE 'Negative' END AS balance_type,
       COUNT(*) AS customer_count,
       AVG(c_acctbal) AS avg_balance,
       SUM(c_acctbal) AS total_balance
FROM customer
GROUP BY balance_type;

-- Q175: Revenue contribution by part type category
SELECT CASE
         WHEN p_type LIKE 'STANDARD%' THEN 'Standard'
         WHEN p_type LIKE 'SMALL%' THEN 'Small'
         WHEN p_type LIKE 'MEDIUM%' THEN 'Medium'
         WHEN p_type LIKE 'LARGE%' THEN 'Large'
         WHEN p_type LIKE 'ECONOMY%' THEN 'Economy'
         WHEN p_type LIKE 'PROMO%' THEN 'Promo'
         ELSE 'Other'
       END AS type_category,
       COUNT(DISTINCT p_partkey) AS part_count,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem
JOIN part ON l_partkey = p_partkey
GROUP BY type_category
ORDER BY revenue DESC;

-- Q176: Count items by shipment delay category
SELECT CASE
         WHEN DATEDIFF(l_receiptdate, l_shipdate) <= 3 THEN 'Fast (<=3 days)'
         WHEN DATEDIFF(l_receiptdate, l_shipdate) <= 7 THEN 'Normal (4-7 days)'
         ELSE 'Slow (>7 days)'
       END AS delivery_speed,
       COUNT(*) AS item_count,
       AVG(l_extendedprice) AS avg_price
FROM lineitem
GROUP BY delivery_speed
ORDER BY item_count DESC;

-- Q177: Revenue by order age category
SELECT CASE
         WHEN DATEDIFF('1998-12-31', o_orderdate) <= 365 THEN 'Recent'
         WHEN DATEDIFF('1998-12-31', o_orderdate) <= 730 THEN 'Moderate'
         ELSE 'Old'
       END AS order_age,
       COUNT(*) AS order_count,
       SUM(o_totalprice) AS total_revenue
FROM orders
GROUP BY order_age
ORDER BY total_revenue DESC;

-- Q178: High vs low discount revenue impact
SELECT l_returnflag,
       SUM(CASE WHEN l_discount >= 0.05 THEN l_extendedprice * l_discount ELSE 0 END) AS high_discount_savings,
       SUM(CASE WHEN l_discount < 0.05  THEN l_extendedprice * l_discount ELSE 0 END) AS low_discount_savings
FROM lineitem
GROUP BY l_returnflag;

-- Q179: Customer segments by number of orders placed
SELECT c_mktsegment,
       COUNT(CASE WHEN order_count = 0            THEN 1 END) AS no_orders,
       COUNT(CASE WHEN order_count BETWEEN 1 AND 5  THEN 1 END) AS low_activity,
       COUNT(CASE WHEN order_count BETWEEN 6 AND 20 THEN 1 END) AS medium_activity,
       COUNT(CASE WHEN order_count > 20            THEN 1 END) AS high_activity
FROM (
    SELECT c_custkey,
           c_mktsegment,
           COUNT(o_orderkey) AS order_count
    FROM customer
    LEFT JOIN orders ON c_custkey = o_custkey
    GROUP BY c_custkey, c_mktsegment
) AS sub
GROUP BY c_mktsegment
ORDER BY c_mktsegment;

-- Q180: Monthly revenue trend with growth flag
SELECT order_month,
       monthly_revenue,
       LAG(monthly_revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
       CASE
         WHEN monthly_revenue > LAG(monthly_revenue) OVER (ORDER BY order_month) THEN 'Growth'
         WHEN monthly_revenue < LAG(monthly_revenue) OVER (ORDER BY order_month) THEN 'Decline'
         ELSE 'Stable'
       END AS trend
FROM (
    SELECT DATE_FORMAT(o_orderdate, '%Y-%m') AS order_month,
           SUM(o_totalprice) AS monthly_revenue
    FROM orders
    GROUP BY DATE_FORMAT(o_orderdate, '%Y-%m')
) AS monthly
ORDER BY order_month;

-- ============================================================
-- SECTION 8: Complex / Multi-level Aggregations (Q181-Q200)
-- ============================================================

-- Q181: TPC-H Q1 style - pricing summary report
SELECT l_returnflag,
       l_linestatus,
       SUM(l_quantity)                                          AS sum_qty,
       SUM(l_extendedprice)                                     AS sum_base_price,
       SUM(l_extendedprice * (1 - l_discount))                  AS sum_disc_price,
       SUM(l_extendedprice * (1 - l_discount) * (1 + l_tax))   AS sum_charge,
       AVG(l_quantity)                                          AS avg_qty,
       AVG(l_extendedprice)                                     AS avg_price,
       AVG(l_discount)                                          AS avg_disc,
       COUNT(*)                                                 AS count_order
FROM lineitem
WHERE l_shipdate <= DATE_SUB('1998-12-01', INTERVAL 90 DAY)
GROUP BY l_returnflag, l_linestatus
ORDER BY l_returnflag, l_linestatus;

-- Q182: TPC-H Q3 style - unshipped orders with highest value
SELECT l_orderkey,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue,
       o_orderdate,
       o_shippriority
FROM customer
JOIN orders ON c_custkey = o_custkey
JOIN lineitem ON o_orderkey = l_orderkey
WHERE c_mktsegment = 'BUILDING'
  AND o_orderdate < '1995-03-15'
  AND l_shipdate > '1995-03-15'
GROUP BY l_orderkey, o_orderdate, o_shippriority
ORDER BY revenue DESC, o_orderdate
LIMIT 10;

-- Q183: TPC-H Q5 style - local supplier volume
SELECT n_name,
       SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM customer
JOIN orders ON c_custkey = o_custkey
JOIN lineitem ON o_orderkey = l_orderkey
JOIN supplier ON l_suppkey = s_suppkey
JOIN nation ON c_nationkey = n_nationkey AND s_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
WHERE r_name = 'ASIA'
  AND o_orderdate >= '1994-01-01'
  AND o_orderdate < '1995-01-01'
GROUP BY n_name
ORDER BY revenue DESC;

-- Q184: TPC-H Q6 style - revenue change from discount
SELECT SUM(l_extendedprice * l_discount) AS revenue_change
FROM lineitem
WHERE l_shipdate >= '1994-01-01'
  AND l_shipdate < '1995-01-01'
  AND l_discount BETWEEN 0.05 AND 0.07
  AND l_quantity < 24;

-- Q185: Revenue per segment with market share
SELECT c_mktsegment,
       SUM(o_totalprice) AS segment_revenue,
       SUM(o_totalprice) / (SELECT SUM(o_totalprice) FROM orders) * 100 AS market_share_pct
FROM orders
JOIN customer ON o_custkey = c_custkey
GROUP BY c_mktsegment
ORDER BY segment_revenue DESC;

-- Q186: Top 10 suppliers by number of parts supplied and avg cost
SELECT s_name,
       n_name,
       COUNT(DISTINCT ps_partkey) AS parts_supplied,
       AVG(ps_supplycost) AS avg_supply_cost,
       SUM(ps_availqty) AS total_available
FROM partsupp
JOIN supplier ON ps_suppkey = s_suppkey
JOIN nation ON s_nationkey = n_nationkey
GROUP BY s_name, n_name
ORDER BY parts_supplied DESC, avg_supply_cost
LIMIT 10;

-- Q187: Revenue efficiency score (revenue per lineitem per order)
SELECT o_custkey,
       COUNT(DISTINCT o_orderkey) AS total_orders,
       COUNT(l_linenumber) AS total_lineitems,
       SUM(l_extendedprice * (1 - l_discount)) AS total_revenue,
       SUM(l_extendedprice * (1 - l_discount)) / COUNT(l_linenumber) AS revenue_per_lineitem
FROM orders
JOIN lineitem ON o_orderkey = l_orderkey
GROUP BY o_custkey
ORDER BY revenue_per_lineitem DESC
LIMIT 20;

-- Q188: Comprehensive supplier performance report
SELECT s_name,
       n_name AS nation,
       COUNT(DISTINCT ps_partkey) AS unique_parts,
       SUM(ps_availqty) AS total_stock,
       MIN(ps_supplycost) AS min_cost,
       MAX(ps_supplycost) AS max_cost,
       AVG(ps_supplycost) AS avg_cost,
       SUM(ps_supplycost * ps_availqty) AS total_inventory_value
FROM partsupp
JOIN supplier ON ps_suppkey = s_suppkey
JOIN nation ON s_nationkey = n_nationkey
GROUP BY s_name, n_name
ORDER BY total_inventory_value DESC;

-- Q189: Customer lifetime value analysis
SELECT c_custkey,
       c_name,
       c_mktsegment,
       n_name AS nation,
       COUNT(DISTINCT o_orderkey) AS total_orders,
       MIN(o_orderdate) AS first_order,
       MAX(o_orderdate) AS last_order,
       SUM(o_totalprice) AS lifetime_value,
       AVG(o_totalprice) AS avg_order_value
FROM customer
LEFT JOIN orders ON c_custkey = o_custkey
JOIN nation ON c_nationkey = n_nationkey
GROUP BY c_custkey, c_name, c_mktsegment, n_name
ORDER BY lifetime_value DESC
LIMIT 20;

-- Q190: Part popularity and revenue summary
SELECT p_brand,
       p_type,
       p_size,
       COUNT(DISTINCT l_orderkey) AS order_appearances,
       SUM(l_quantity) AS total_qty_sold,
       SUM(l_extendedprice * (1 - l_discount)) AS total_revenue,
       AVG(l_extendedprice) AS avg_sale_price,
       MIN(l_discount) AS min_discount,
       MAX(l_discount) AS max_discount
FROM lineitem
JOIN part ON l_partkey = p_partkey
GROUP BY p_brand, p_type, p_size
ORDER BY total_revenue DESC;

-- Q191: Multi-dimensional revenue cube (region/segment/year)
SELECT r_name,
       c_mktsegment,
       YEAR(o_orderdate) AS order_year,
       COUNT(DISTINCT o_orderkey) AS order_count,
       SUM(o_totalprice) AS total_revenue,
       AVG(o_totalprice) AS avg_order_value
FROM orders
JOIN customer ON o_custkey = c_custkey
JOIN nation ON c_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
GROUP BY r_name, c_mktsegment, YEAR(o_orderdate)
ORDER BY r_name, c_mktsegment, order_year;

-- Q192: End-to-end supply chain cost analysis
SELECT r_name AS region,
       n_name AS nation,
       p_type AS part_type,
       COUNT(DISTINCT ps_partkey) AS distinct_parts,
       SUM(ps_availqty) AS total_stock,
       AVG(ps_supplycost) AS avg_cost,
       SUM(ps_supplycost * ps_availqty) AS total_inventory_cost
FROM partsupp
JOIN supplier ON ps_suppkey = s_suppkey
JOIN nation ON s_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
JOIN part ON ps_partkey = p_partkey
GROUP BY r_name, n_name, p_type
ORDER BY total_inventory_cost DESC;

-- Q193: Order fulfillment speed analysis per nation
SELECT n_name,
       AVG(DATEDIFF(l_shipdate, o_orderdate)) AS avg_days_to_ship,
       AVG(DATEDIFF(l_receiptdate, l_shipdate)) AS avg_days_in_transit,
       AVG(DATEDIFF(l_receiptdate, o_orderdate)) AS avg_total_days,
       MIN(DATEDIFF(l_shipdate, o_orderdate)) AS fastest_ship,
       MAX(DATEDIFF(l_shipdate, o_orderdate)) AS slowest_ship
FROM orders
JOIN lineitem ON o_orderkey = l_orderkey
JOIN customer ON o_custkey = c_custkey
JOIN nation ON c_nationkey = n_nationkey
GROUP BY n_name
ORDER BY avg_total_days;

-- Q194: Discount impact analysis per ship mode and year
SELECT l_shipmode,
       YEAR(l_shipdate) AS ship_year,
       COUNT(*) AS item_count,
       SUM(l_extendedprice) AS gross_revenue,
       SUM(l_extendedprice * l_discount) AS total_discount_amount,
       SUM(l_extendedprice * (1 - l_discount)) AS net_revenue,
       AVG(l_discount) * 100 AS avg_discount_pct,
       SUM(l_extendedprice * l_discount) / SUM(l_extendedprice) * 100 AS effective_discount_rate
FROM lineitem
GROUP BY l_shipmode, YEAR(l_shipdate)
ORDER BY l_shipmode, ship_year;

-- Q195: Product type profitability ranking
SELECT p_type,
       COUNT(DISTINCT l_partkey) AS distinct_parts,
       COUNT(*) AS total_orders,
       SUM(l_quantity) AS total_qty,
       SUM(l_extendedprice * (1 - l_discount)) AS net_revenue,
       AVG(l_extendedprice * (1 - l_discount)) AS avg_item_revenue,
       RANK() OVER (ORDER BY SUM(l_extendedprice * (1 - l_discount)) DESC) AS profitability_rank
FROM lineitem
JOIN part ON l_partkey = p_partkey
GROUP BY p_type
ORDER BY profitability_rank;

-- Q196: Cross-nation trade flow analysis
SELECT n1.n_name AS supplier_nation,
       n2.n_name AS customer_nation,
       YEAR(o_orderdate) AS trade_year,
       SUM(l_extendedprice * (1 - l_discount)) AS trade_volume,
       COUNT(DISTINCT l_orderkey) AS transaction_count
FROM lineitem
JOIN orders   ON l_orderkey = o_orderkey
JOIN customer ON o_custkey  = c_custkey
JOIN supplier ON l_suppkey  = s_suppkey
JOIN nation n1 ON s_nationkey = n1.n_nationkey
JOIN nation n2 ON c_nationkey = n2.n_nationkey
WHERE n1.n_nationkey <> n2.n_nationkey
GROUP BY n1.n_name, n2.n_name, YEAR(o_orderdate)
ORDER BY trade_volume DESC
LIMIT 20;

-- Q197: Market share evolution by segment over years
SELECT c_mktsegment,
       order_year,
       segment_revenue,
       segment_revenue / SUM(segment_revenue) OVER (PARTITION BY order_year) * 100 AS market_share_pct,
       segment_revenue / LAG(segment_revenue) OVER (PARTITION BY c_mktsegment ORDER BY order_year) * 100 - 100 AS yoy_growth_pct
FROM (
    SELECT c_mktsegment,
           YEAR(o_orderdate) AS order_year,
           SUM(o_totalprice) AS segment_revenue
    FROM orders
    JOIN customer ON o_custkey = c_custkey
    GROUP BY c_mktsegment, YEAR(o_orderdate)
) AS sub
ORDER BY c_mktsegment, order_year;

-- Q198: Full TPC-H style inventory risk report
SELECT n_name,
       p_brand,
       SUM(ps_availqty) AS total_stock,
       AVG(ps_supplycost) AS avg_unit_cost,
       SUM(ps_availqty * ps_supplycost) AS stock_value,
       SUM(ps_availqty * ps_supplycost) /
           SUM(SUM(ps_availqty * ps_supplycost)) OVER (PARTITION BY n_name) * 100 AS pct_of_nation_stock
FROM partsupp
JOIN supplier ON ps_suppkey = s_suppkey
JOIN nation ON s_nationkey = n_nationkey
JOIN part ON ps_partkey = p_partkey
GROUP BY n_name, p_brand
ORDER BY n_name, stock_value DESC;

-- Q199: Comprehensive order pipeline health check
SELECT o_orderpriority,
       o_orderstatus,
       YEAR(o_orderdate) AS order_year,
       COUNT(*) AS order_count,
       SUM(o_totalprice) AS total_value,
       AVG(o_totalprice) AS avg_value,
       MIN(o_totalprice) AS min_value,
       MAX(o_totalprice) AS max_value,
       STDDEV(o_totalprice) AS stddev_value
FROM orders
GROUP BY o_orderpriority, o_orderstatus, YEAR(o_orderdate)
ORDER BY order_year, o_orderpriority, o_orderstatus;

-- Q200: Ultimate TPC-H aggregation benchmark - full summary
SELECT r_name AS region,
       n_name AS nation,
       c_mktsegment AS market_segment,
       YEAR(o_orderdate) AS order_year,
       COUNT(DISTINCT o_custkey) AS active_customers,
       COUNT(DISTINCT o_orderkey) AS total_orders,
       COUNT(*) AS total_lineitems,
       SUM(l_quantity) AS total_qty,
       SUM(l_extendedprice) AS gross_revenue,
       SUM(l_extendedprice * l_discount) AS total_discounts,
       SUM(l_extendedprice * (1 - l_discount)) AS net_revenue,
       SUM(l_extendedprice * (1 - l_discount) * (1 + l_tax)) AS charged_revenue,
       AVG(l_discount) * 100 AS avg_discount_pct,
       AVG(o_totalprice) AS avg_order_value
FROM orders
JOIN customer ON o_custkey = c_custkey
JOIN lineitem ON o_orderkey = l_orderkey
JOIN nation ON c_nationkey = n_nationkey
JOIN region ON n_regionkey = r_regionkey
GROUP BY r_name, n_name, c_mktsegment, YEAR(o_orderdate)
ORDER BY region, nation, market_segment, order_year;

-- ============================================================
-- END OF AGGREGATION QUERIES (Q001 - Q200)
-- ============================================================
