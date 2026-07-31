-- ============================================================
-- AUTO-GENERATED INDEX RECOMMENDATIONS
-- System: Workload-Driven ML Index Recommendation
-- Database: TPC-H SF-1, MySQL 8.0.40
-- Queries analyzed: 911 across 5 categories
-- Methodology: SQL parsing + EXPLAIN analysis + ML scoring
-- ============================================================

USE tpch;

-- HIGH PRIORITY (9 indexes)
-- --------------------------------------------------
-- Rank   1 | Score   564.5 | Queries   41 | FullScans  45 | JOIN_ON,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_nation_n_nationkey ON nation (n_nationkey);

-- Rank   2 | Score   560.8 | Queries   24 | FullScans  60 | GROUP_BY,JOIN_ON,ORDER_BY,SELECT,WHERE
CREATE INDEX auto_idx_region_r_name ON region (r_name);

-- Rank   3 | Score   502.2 | Queries   24 | FullScans  54 | GROUP_BY,ORDER_BY,SELECT,WHERE
CREATE INDEX auto_idx_nation_n_name ON nation (n_name);

-- Rank   4 | Score   411.5 | Queries   18 | FullScans  45 | GROUP_BY,ORDER_BY,SELECT,WHERE
CREATE INDEX auto_idx_lineitem_l_shipmode ON lineitem (l_shipmode);

-- Rank   5 | Score   410.0 | Queries   23 | FullScans  41 | GROUP_BY,JOIN_ON,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_orders_o_custkey ON orders (o_custkey);

-- Rank   6 | Score   390.5 | Queries   30 | FullScans  37 | HAVING,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_lineitem_l_discount ON lineitem (l_discount);

-- Rank   7 | Score   383.0 | Queries   26 | FullScans  38 | HAVING,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_orders_o_totalprice ON orders (o_totalprice);

-- Rank   8 | Score   372.5 | Queries   23 | FullScans  35 | GROUP_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_lineitem_l_shipdate ON lineitem (l_shipdate);

-- Rank   9 | Score   339.5 | Queries   24 | FullScans  27 | JOIN_ON,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_region_r_regionkey ON region (r_regionkey);

-- MEDIUM PRIORITY (12 indexes)
-- --------------------------------------------------
-- Rank  10 | Score   333.7 | Queries   21 | FullScans  34 | GROUP_BY,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_orders_o_orderdate ON orders (o_orderdate);

-- Rank  11 | Score   330.5 | Queries   15 | FullScans  35 | GROUP_BY,ORDER_BY,SELECT,WHERE
CREATE INDEX auto_idx_orders_o_orderpriority ON orders (o_orderpriority);

-- Rank  12 | Score   308.0 | Queries   26 | FullScans  30 | ORDER_BY,SELECT,WHERE
CREATE INDEX auto_idx_lineitem_l_extendedprice ON lineitem (l_extendedprice);

-- Rank  13 | Score   302.8 | Queries   22 | FullScans  24 | JOIN_ON,WHERE
CREATE INDEX auto_idx_nation_n_regionkey ON nation (n_regionkey);

-- Rank  14 | Score   252.5 | Queries   12 | FullScans  25 | GROUP_BY,JOIN_ON,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_customer_c_custkey ON customer (c_custkey);

-- Rank  15 | Score   245.0 | Queries   16 | FullScans  23 | GROUP_BY,JOIN_ON,SELECT
-- ALREADY COVERED: CREATE INDEX auto_idx_orders_o_orderkey ON orders (o_orderkey);

-- Rank  16 | Score   240.5 | Queries   19 | FullScans  21 | HAVING,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_lineitem_l_quantity ON lineitem (l_quantity);

-- Rank  17 | Score   230.7 | Queries   15 | FullScans  20 | GROUP_BY,JOIN_ON,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_part_p_partkey ON part (p_partkey);

-- Rank  18 | Score   229.0 | Queries   13 | FullScans  22 | GROUP_BY,JOIN_ON,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_supplier_s_suppkey ON supplier (s_suppkey);

-- Rank  19 | Score   218.7 | Queries   11 | FullScans  23 | GROUP_BY,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_part_p_brand ON part (p_brand);

-- Rank  20 | Score   187.2 | Queries    9 | FullScans  20 | GROUP_BY,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_part_p_type ON part (p_type);

-- Rank  21 | Score   173.3 | Queries   12 | FullScans  18 | GROUP_BY,SELECT
CREATE INDEX auto_idx_supplier_s_name ON supplier (s_name);

-- LOW PRIORITY (29 indexes)
-- --------------------------------------------------
-- Rank  22 | Score   166.4 | Queries    8 | FullScans  17 | GROUP_BY,HAVING,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_part_p_size ON part (p_size);

-- Rank  23 | Score   152.8 | Queries    8 | FullScans  16 | GROUP_BY,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_lineitem_l_returnflag ON lineitem (l_returnflag);

-- Rank  24 | Score   152.8 | Queries   11 | FullScans  15 | GROUP_BY,SELECT,WHERE
CREATE INDEX auto_idx_customer_c_name ON customer (c_name);

-- Rank  25 | Score   150.5 | Queries   10 | FullScans  13 | HAVING,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_customer_c_acctbal ON customer (c_acctbal);

-- Rank  26 | Score   145.2 | Queries    7 | FullScans  15 | GROUP_BY,ORDER_BY,SELECT,WHERE
CREATE INDEX auto_idx_part_p_container ON part (p_container);

-- Rank  27 | Score   115.2 | Queries    8 | FullScans   9 | JOIN_ON,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_supplier_s_nationkey ON supplier (s_nationkey);

-- Rank  28 | Score   113.0 | Queries    7 | FullScans  11 | GROUP_BY,ORDER_BY,SELECT,WHERE
CREATE INDEX auto_idx_part_p_name ON part (p_name);

-- Rank  29 | Score   105.5 | Queries    7 | FullScans   9 | GROUP_BY,JOIN_ON,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_customer_c_nationkey ON customer (c_nationkey);

-- Rank  30 | Score   101.8 | Queries    4 | FullScans  11 | GROUP_BY,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_lineitem_l_suppkey ON lineitem (l_suppkey);

-- Rank  31 | Score    87.5 | Queries    5 | FullScans   9 | GROUP_BY,SELECT
-- ALREADY COVERED: CREATE INDEX auto_idx_customer_c_mktsegment ON customer (c_mktsegment);

-- Rank  32 | Score    83.0 | Queries    6 | FullScans   8 | ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_lineitem_l_orderkey ON lineitem (l_orderkey);

-- Rank  33 | Score    74.8 | Queries    4 | FullScans   7 | GROUP_BY,JOIN_ON,ORDER_BY,SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_lineitem_l_partkey ON lineitem (l_partkey);

-- Rank  34 | Score    73.2 | Queries    3 | FullScans   8 | GROUP_BY,ORDER_BY,SELECT
CREATE INDEX auto_idx_lineitem_l_linestatus ON lineitem (l_linestatus);

-- Rank  35 | Score    69.5 | Queries    4 | FullScans   7 | ORDER_BY,SELECT,WHERE
CREATE INDEX auto_idx_partsupp_ps_availqty ON partsupp (ps_availqty);

-- Rank  36 | Score    66.5 | Queries    5 | FullScans   5 | SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_supplier_s_acctbal ON supplier (s_acctbal);

-- Rank  37 | Score    65.8 | Queries    3 | FullScans   7 | GROUP_BY,ORDER_BY,SELECT
CREATE INDEX auto_idx_orders_o_clerk ON orders (o_clerk);

-- Rank  38 | Score    65.8 | Queries    3 | FullScans   7 | GROUP_BY,ORDER_BY,SELECT
CREATE INDEX auto_idx_part_p_mfgr ON part (p_mfgr);

-- Rank  39 | Score    63.5 | Queries    5 | FullScans   5 | SELECT,WHERE
-- ALREADY COVERED: CREATE INDEX auto_idx_part_p_retailprice ON part (p_retailprice);

-- Rank  40 | Score    62.0 | Queries    4 | FullScans   6 | ORDER_BY,SELECT,WHERE
CREATE INDEX auto_idx_lineitem_l_tax ON lineitem (l_tax);

-- Rank  41 | Score    51.5 | Queries    4 | FullScans   5 | ORDER_BY,SELECT
-- ALREADY COVERED: CREATE INDEX auto_idx_lineitem_l_linenumber ON lineitem (l_linenumber);

-- Rank  42 | Score    43.2 | Queries    3 | FullScans   4 | JOIN_ON,ORDER_BY,SELECT
-- ALREADY COVERED: CREATE INDEX auto_idx_partsupp_ps_partkey ON partsupp (ps_partkey);

-- Rank  43 | Score    35.8 | Queries    3 | FullScans   3 | JOIN_ON,SELECT
-- ALREADY COVERED: CREATE INDEX auto_idx_partsupp_ps_suppkey ON partsupp (ps_suppkey);

-- Rank  44 | Score    29.0 | Queries    2 | FullScans   2 | WHERE
CREATE INDEX auto_idx_lineitem_l_commitdate ON lineitem (l_commitdate);

-- Rank  45 | Score    28.2 | Queries    1 | FullScans   3 | GROUP_BY,ORDER_BY,SELECT
-- ALREADY COVERED: CREATE INDEX auto_idx_orders_o_orderstatus ON orders (o_orderstatus);

-- Rank  46 | Score    26.0 | Queries    2 | FullScans   2 | SELECT,WHERE
CREATE INDEX auto_idx_lineitem_l_receiptdate ON lineitem (l_receiptdate);

-- Rank  47 | Score    15.5 | Queries    1 | FullScans   1 | WHERE
CREATE INDEX auto_idx_lineitem_l_shipinstruct ON lineitem (l_shipinstruct);

-- Rank  48 | Score    15.4 | Queries    1 | FullScans   1 | WHERE
CREATE INDEX auto_idx_supplier_s_comment ON supplier (s_comment);

-- Rank  49 | Score    12.5 | Queries    1 | FullScans   1 | SELECT
-- ALREADY COVERED: CREATE INDEX auto_idx_partsupp_ps_supplycost ON partsupp (ps_supplycost);

-- Rank  50 | Score    12.5 | Queries    1 | FullScans   1 | SELECT
CREATE INDEX auto_idx_supplier_s_phone ON supplier (s_phone);

