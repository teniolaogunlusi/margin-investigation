-- =====================================================================
-- 02_clean.sql
-- Step 2: CLEAN. Builds two new tables from the raw ones. Raw tables are never touched.
--   clean_order_lines : exact duplicates removed, blank currency = NGN
--   clean_orders      : one date format, a month column, standardised reps
-- Duplicates removed here are of TWO kinds, both caught by the same rule:
--   (a) copies created by loading order_lines twice (identical in every column)
--   (b) the 94 sync-bug duplicates (identical except line_id)
-- Rule (Finance): remove EXACT copies only; keep the lowest line_id; blank currency = NGN.
-- Safe to rerun: each table is dropped and recreated.
-- =====================================================================

-- ---------------------------------------------------------------------
-- PART A. clean_order_lines
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_order_lines;
CREATE TABLE clean_order_lines AS
SELECT line_id,
       order_id,
       product_id,
       qty,
       unit_price,
       discount_pct,
       COALESCE(NULLIF(TRIM(currency),''), 'NGN') AS currency
FROM (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY order_id, product_id, qty, unit_price, discount_pct,
                        COALESCE(NULLIF(TRIM(currency),''),'NGN')
           ORDER BY line_id) AS rn
  FROM order_lines
)
WHERE rn = 1;

-- CHECK 2a. Line count after cleaning
SELECT COUNT(*) AS clean_lines FROM clean_order_lines;
-- EXPECT: 4712   (4806 true lines minus 94 sync-bug duplicates)

-- CHECK 2b. No exact duplicates remain
SELECT COUNT(*) AS duplicate_groups_left FROM (
  SELECT 1 FROM clean_order_lines
  GROUP BY order_id, product_id, qty, unit_price, discount_pct, currency
  HAVING COUNT(*) > 1);
-- EXPECT: 0

-- CHECK 2c. Each line_id appears once, and currency is only NGN or USD
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT line_id) AS distinct_line_ids FROM clean_order_lines;
-- EXPECT: 4712, 4712
SELECT currency, COUNT(*) AS n FROM clean_order_lines GROUP BY currency ORDER BY currency;
-- EXPECT: NGN 4685, USD 27

-- ---------------------------------------------------------------------
-- PART B. clean_orders
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_orders;
CREATE TABLE clean_orders AS
SELECT order_id,
       customer_id,
       order_dt,
       substr(order_dt,1,7)||'-01' AS month,
       rep
FROM (
  SELECT order_id,
         customer_id,
         CASE WHEN order_date LIKE '____-__-__' THEN order_date
              ELSE substr(order_date,7,4)||'-'||substr(order_date,4,2)||'-'||substr(order_date,1,2)
         END AS order_dt,
         CASE LOWER(TRIM(sales_rep))
              WHEN 'tola a.'     THEN 'Tola A.'
              WHEN 'ibrahim m.'  THEN 'Ibrahim M.'
              WHEN 'chika o.'    THEN 'Chika O.'
              WHEN 'funmi b.'    THEN 'Funmi B.'
              ELSE 'Unassigned'
         END AS rep
  FROM orders
);

-- CHECK 2d. Nothing lost, date range right, 4 reps + Unassigned
SELECT COUNT(*) AS orders, MIN(order_dt) AS first_day, MAX(order_dt) AS last_day,
       COUNT(DISTINCT rep) AS reps_incl_unassigned
FROM clean_orders;
-- EXPECT: 1890, 2026-01-01, 2026-09-28, 5

-- CHECK 2e. Every date is a real date (a date like 31/02 would be counted here)
SELECT COUNT(*) AS invalid_dates FROM clean_orders WHERE date(order_dt) IS NULL;
-- EXPECT: 0

-- CHECK 2f. Rep spellings merged (Unassigned must equal the 88 blanks found in Part 1)
SELECT rep, COUNT(*) AS n FROM clean_orders GROUP BY rep ORDER BY rep;
-- EXPECT: Chika O. 322, Funmi B. 300, Ibrahim M. 590, Tola A. 590, Unassigned 88
