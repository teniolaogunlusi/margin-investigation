-- =====================================================================
-- 06_report_data.sql
-- Step 6: PREPARE THE DATA FOR THE POWER BI REPORT. Run after files 02 to 05.
-- Builds three small tables, one CSV export each:
--   report_lines           one row per clean order line, all money in naira (4,712 rows)
--   report_bridge          the margin bridge, Q1 gross profit to Q3, per customer group
--   report_finance_control Finance's control totals, used for the tie-out on page 1
-- Display names are tidied here (trailing spaces, capitals). No numbers change.
-- Safe to rerun: each table is dropped and recreated.
-- =====================================================================

-- ---------------------------------------------------------------------
-- report_lines
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS report_lines;
CREATE TABLE report_lines AS
SELECT m.line_id, m.order_id, m.order_dt, m.month, m.period,
       m.customer_id, TRIM(c.customer_name) AS customer_name, m.segment, m.grp, m.rep,
       m.product_id,
       CASE m.product_id WHEN 'P06' THEN 'Maltodextrin'
                         WHEN 'P07' THEN 'Sorbitol 70%'
                         ELSE TRIM(p.product_name) END AS product_name,
       m.category, m.unit,
       m.qty, m.kg, m.discount_pct, m.cur, m.fx, m.usd_cost, m.price_ngn,
       m.gross_rev, m.disc_ngn, m.rev, m.cogs, m.gm,
       CASE WHEN m.gm < 0 THEN 1 ELSE 0 END AS below_cost
FROM margin_model m
JOIN customers c ON c.customer_id = m.customer_id
JOIN products p  ON p.product_id  = m.product_id;

-- CHECK 6a. Row count, and the totals still tie to Finance
SELECT COUNT(*) AS rows_in_report_lines FROM report_lines;
-- EXPECT: 4712
SELECT period, ROUND(SUM(rev) / 1e6, 1) AS net_rev_M, ROUND(100.0 * SUM(gm) / SUM(rev), 2) AS gm_pct
FROM report_lines WHERE period IN ('Q1','Q3') GROUP BY period ORDER BY period;
-- EXPECT: Q1 5191.2 / 33.27     Q3 3825.6 / 19.6
SELECT SUM(below_cost) AS below_cost_lines FROM report_lines;
-- EXPECT: 142

-- ---------------------------------------------------------------------
-- report_bridge   (naira millions; one row per group and step)
-- Steps in order: Q1 gross profit, then the five effects. The waterfall chart adds the
-- final "Total" bar by itself, and that bar equals Q3 gross profit.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS report_bridge;
CREATE TABLE report_bridge AS
WITH steps AS (
  SELECT grp, 'Q1 gross profit' AS driver, 1 AS step_order,
         SUM(gm) / 1e6 AS amount_M FROM margin_model WHERE period = 'Q1' GROUP BY grp
  UNION ALL SELECT grp, 'Volume / mix',     2, SUM(dv * m0) / 1e6 FROM bridge_prod GROUP BY grp
  UNION ALL SELECT grp, 'FX on USD costs',  3, SUM(e_fx) / 1e6 FROM bridge_prod GROUP BY grp
  UNION ALL SELECT grp, 'NGN list price',   4, SUM(e_price) / 1e6 FROM bridge_prod GROUP BY grp
  UNION ALL SELECT grp, 'Discounts',        5, SUM(e_disc) / 1e6 FROM bridge_prod GROUP BY grp
  UNION ALL SELECT grp, 'Supplier cost',    6, SUM(e_supplier) / 1e6 FROM bridge_prod GROUP BY grp)
SELECT grp, driver, step_order, ROUND(amount_M, 3) AS amount_M FROM steps
UNION ALL
SELECT 'All groups', driver, step_order, ROUND(SUM(amount_M), 3) FROM steps GROUP BY driver, step_order;

-- CHECK 6b. Each group's steps add up to its Q3 gross profit
SELECT grp, ROUND(SUM(amount_M), 1) AS q3_gross_profit_M FROM report_bridge GROUP BY grp ORDER BY grp;
-- EXPECT: All groups 749.7 | All other 578.2 | Deep-discount 141.5 | Distributor 30.0
SELECT driver, amount_M FROM report_bridge WHERE grp = 'All groups' ORDER BY step_order;
-- EXPECT: Q1 gross profit 1726.9 | Volume / mix -716.4 | FX on USD costs -347.0
--         NGN list price 185.8 | Discounts -73.1 | Supplier cost -26.5

-- ---------------------------------------------------------------------
-- report_finance_control   (Finance's control totals; GM as a decimal, 0.333 = 33.3%)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS report_finance_control;
CREATE TABLE report_finance_control AS
SELECT 'Q1' AS period, 5191.2 AS finance_net_revenue_M, 0.333 AS finance_gm_pct
UNION ALL
SELECT 'Q3', 3825.6, 0.196;
