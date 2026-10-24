-- =====================================================================
-- 05_validation_checks.sql
-- Step 5: PROVE THE NUMBERS. Run after 02, 03 and 04.
--   5a  SUMMARY : every check returns PASS or FAIL (all must PASS before the report is used)
--   5b  EVIDENCE: bag-unit break, with and without the fix
--   5c  CLEANING LOG: counts and naira value of what was removed
-- Finance control totals: Q1 5,191.2M and 33.3% | Q3 3,825.6M and 19.6%
-- Tolerance agreed with Finance: revenue within 0.5%, GM within 0.2 points.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5a. SUMMARY OF ALL CHECKS   (every row must say PASS)
-- ---------------------------------------------------------------------
WITH t AS (
  SELECT SUM(CASE WHEN period='Q1' THEN rev END) / 1e6 AS rev1,
         SUM(CASE WHEN period='Q3' THEN rev END) / 1e6 AS rev3,
         100.0 * SUM(CASE WHEN period='Q1' THEN gm END) / SUM(CASE WHEN period='Q1' THEN rev END) AS gm1,
         100.0 * SUM(CASE WHEN period='Q3' THEN gm END) / SUM(CASE WHEN period='Q3' THEN rev END) AS gm3
  FROM margin_model),
bag AS (
  SELECT SUM(order_dt >= '2026-05-01' AND qty % 25 = 0) + SUM(order_dt < '2026-05-01' AND qty % 25 <> 0) AS ambiguous
  FROM margin_model WHERE unit = 'bag_25kg'),
br AS (
  SELECT SUM(dv * m0 + e_fx + e_price + e_disc + e_supplier) AS bridge_total FROM bridge_prod),
act AS (
  SELECT SUM(CASE WHEN period='Q3' THEN gm END) - SUM(CASE WHEN period='Q1' THEN gm END) AS actual_change
  FROM margin_model)
SELECT 'V01' AS id, 'Q1 net revenue (M) within 0.5% of Finance' AS check_name, 5191.2 AS expected,
       ROUND(rev1, 1) AS actual,
       CASE WHEN ABS(rev1 / 5191.2 - 1) <= 0.005 THEN 'PASS' ELSE 'FAIL' END AS status FROM t
UNION ALL SELECT 'V02', 'Q1 gross margin % within 0.2 pts of Finance', 33.3, ROUND(gm1, 2),
       CASE WHEN ABS(gm1 - 33.3) <= 0.2 THEN 'PASS' ELSE 'FAIL' END FROM t
UNION ALL SELECT 'V03', 'Q3 net revenue (M) within 0.5% of Finance', 3825.6, ROUND(rev3, 1),
       CASE WHEN ABS(rev3 / 3825.6 - 1) <= 0.005 THEN 'PASS' ELSE 'FAIL' END FROM t
UNION ALL SELECT 'V04', 'Q3 gross margin % within 0.2 pts of Finance', 19.6, ROUND(gm3, 2),
       CASE WHEN ABS(gm3 - 19.6) <= 0.2 THEN 'PASS' ELSE 'FAIL' END FROM t
UNION ALL SELECT 'V05', 'margin_model rows = clean_order_lines rows (no join loss or multiplication)',
       (SELECT COUNT(*) FROM clean_order_lines), (SELECT COUNT(*) FROM margin_model),
       CASE WHEN (SELECT COUNT(*) FROM clean_order_lines) = (SELECT COUNT(*) FROM margin_model) THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'V06', 'one margin_model row per line_id', (SELECT COUNT(*) FROM margin_model),
       (SELECT COUNT(DISTINCT line_id) FROM margin_model),
       CASE WHEN (SELECT COUNT(*) FROM margin_model) = (SELECT COUNT(DISTINCT line_id) FROM margin_model) THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'V07', 'lines with no supplier cost or FX rate', 0,
       (SELECT COUNT(*) FROM margin_model WHERE usd_cost IS NULL OR fx IS NULL),
       CASE WHEN (SELECT COUNT(*) FROM margin_model WHERE usd_cost IS NULL OR fx IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'V08', 'invalid order dates', 0,
       (SELECT COUNT(*) FROM clean_orders WHERE date(order_dt) IS NULL),
       CASE WHEN (SELECT COUNT(*) FROM clean_orders WHERE date(order_dt) IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'V09', 'exact duplicate groups left in clean_order_lines', 0,
       (SELECT COUNT(*) FROM (SELECT 1 FROM clean_order_lines
          GROUP BY order_id, product_id, qty, unit_price, discount_pct, currency HAVING COUNT(*) > 1)),
       CASE WHEN (SELECT COUNT(*) FROM (SELECT 1 FROM clean_order_lines
          GROUP BY order_id, product_id, qty, unit_price, discount_pct, currency HAVING COUNT(*) > 1)) = 0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'V10', 'clean lines whose order is missing', 0,
       (SELECT COUNT(*) FROM clean_order_lines WHERE order_id NOT IN (SELECT order_id FROM clean_orders)),
       CASE WHEN (SELECT COUNT(*) FROM clean_order_lines WHERE order_id NOT IN (SELECT order_id FROM clean_orders)) = 0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'V11', 'bag-unit break is clean (ambiguous quantities)', 0, ambiguous,
       CASE WHEN ambiguous = 0 THEN 'PASS' ELSE 'FAIL' END FROM bag
UNION ALL SELECT 'V12', 'bridge total minus actual change in gross profit (NGN)', 0,
       ROUND(bridge_total - actual_change, 0),
       CASE WHEN ABS(bridge_total - actual_change) < 1 THEN 'PASS' ELSE 'FAIL' END FROM br, act
UNION ALL SELECT 'V13', 'sync-bug duplicates removed (Finance/IT expect about 94)', 94,
       (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM order_lines)) - (SELECT COUNT(*) FROM clean_order_lines),
       CASE WHEN (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM order_lines)) - (SELECT COUNT(*) FROM clean_order_lines) = 94 THEN 'PASS' ELSE 'FAIL' END;
-- EXPECT: 13 rows, all PASS

-- ---------------------------------------------------------------------
-- 5b. EVIDENCE for the bag-unit rule (P03 and P16 are labelled bag_25kg)
-- Finance said quantities for bag products changed at some point and asked us to prove it.
-- ---------------------------------------------------------------------
-- Quantities by month: kg-style (25, 50, 100 ...) before May, bag-style (1, 2, 4, 8 ...) after
SELECT month, MIN(qty) AS smallest_qty, MAX(qty) AS largest_qty, COUNT(*) AS lines
FROM margin_model WHERE unit = 'bag_25kg' GROUP BY month ORDER BY month;
-- EXPECT: Jan-Apr smallest 25 | May-Sep smallest 1, largest 120 at most

-- The exact switch, and proof that there is no overlap
SELECT MAX(CASE WHEN qty % 25 = 0 THEN order_dt END) AS last_kg_style_day,
       MIN(CASE WHEN qty % 25 <> 0 THEN order_dt END) AS first_bag_style_day,
       SUM(order_dt >= '2026-05-01' AND qty % 25 = 0) AS kg_style_after_switch,
       SUM(order_dt <  '2026-05-01' AND qty % 25 <> 0) AS bag_style_before_switch
FROM margin_model WHERE unit = 'bag_25kg';
-- EXPECT: 2026-04-28, 2026-05-02, 0, 0

-- Effect of the rule on Q3 net revenue: without it Q3 is 6.8% short of Finance
SELECT ROUND(SUM(qty * price_ngn * (1 - discount_pct / 100.0)) / 1e6, 1) AS q3_rev_without_fix_M,
       ROUND(SUM(rev) / 1e6, 1) AS q3_rev_with_fix_M,
       3825.6 AS finance_M,
       ROUND(100.0 * (SUM(qty * price_ngn * (1 - discount_pct / 100.0)) / 1e6 / 3825.6 - 1), 1) AS gap_without_fix_pct
FROM margin_model WHERE period = 'Q3';
-- EXPECT: 3565.3, 3825.6, 3825.6, -6.8

-- ---------------------------------------------------------------------
-- 5c. CLEANING LOG: what was removed and fixed (Finance asked for count and value)
-- ---------------------------------------------------------------------
-- Duplicates: counts
SELECT (SELECT COUNT(*) FROM order_lines) AS raw_rows,
       (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM order_lines)) AS distinct_rows,
       (SELECT COUNT(*) FROM clean_order_lines) AS clean_rows,
       (SELECT COUNT(*) FROM order_lines) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM order_lines)) AS load_copies_removed,
       (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM order_lines)) - (SELECT COUNT(*) FROM clean_order_lines) AS sync_bug_duplicates_removed;
-- EXPECT with the doubled load: 9612, 4806, 4712, 4806, 94
-- EXPECT after a single clean load: 4806, 4806, 4712, 0, 94

-- Duplicates: naira value of the sync-bug duplicates removed (net revenue, M)
SELECT ROUND(SUM(
         CASE WHEN p.unit = 'bag_25kg' AND o.order_dt >= '2026-05-01' THEN d.qty * 25 ELSE d.qty END
         * CASE WHEN COALESCE(NULLIF(TRIM(d.currency),''),'NGN') = 'USD' THEN d.unit_price * fx.ngn_per_usd ELSE d.unit_price END
         * (1 - d.discount_pct / 100.0)) / 1e6, 1) AS removed_net_rev_M
FROM (
  SELECT *, ROW_NUMBER() OVER (
           PARTITION BY order_id, product_id, qty, unit_price, discount_pct,
                        COALESCE(NULLIF(TRIM(currency),''),'NGN')
           ORDER BY line_id) AS rn
  FROM (SELECT DISTINCT * FROM order_lines)) d
JOIN clean_orders o ON o.order_id = d.order_id
JOIN products p     ON p.product_id = d.product_id
JOIN fx_rates fx    ON fx.month_start = o.month
WHERE d.rn > 1;
-- EXPECT: 248.6

-- Other fixes applied in 02_clean.sql (counts from Part 1)
SELECT (SELECT COUNT(*) FROM orders WHERE order_date LIKE '__/__/____') AS dates_reformatted_dd_mm_yyyy,
       (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM order_lines) WHERE currency IS NULL OR TRIM(currency) = '') AS blank_currency_set_to_NGN,
       (SELECT COUNT(*) FROM clean_order_lines WHERE currency = 'USD') AS usd_lines_converted,
       (SELECT COUNT(*) FROM clean_orders WHERE rep = 'Unassigned') AS orders_unassigned_rep;
-- EXPECT: 177, 107, 27, 88
