-- =====================================================================
-- 03_margin_model.sql
-- Step 3: MARGIN MODEL. One table, one row per clean order line, all money in naira.
-- Reads ONLY the clean tables (clean_order_lines, clean_orders) plus the reference tables.
-- Finance definitions:
--   gross_rev = kg x price_ngn                      (USD-priced lines x that month's FX rate)
--   rev       = gross_rev x (1 - discount%)         (NET revenue: after discounts, excl. VAT)
--   cogs      = kg x supplier USD cost per kg (in force ON THE ORDER DATE) x that month's FX
--   gm        = rev - cogs                          (freight, duty, warehousing NOT included)
-- Bag products (unit = bag_25kg): from 2026-05-01 qty is recorded in BAGS, so kg = qty x 25.
--   Before that date qty is already kg. Evidence for the break: 05_validation_checks.sql
-- Customer groups: Distributor (segment) | Deep-discount (any customer with a line >= 10%
--   discount) | All other.  Periods: Q1 = Jan-Mar, Q3 = Jul-Sep, Q2 = Apr-Jun.
-- =====================================================================

DROP TABLE IF EXISTS margin_model;
CREATE TABLE margin_model AS
WITH deep AS (
  SELECT DISTINCT o.customer_id
  FROM clean_order_lines l
  JOIN clean_orders o ON o.order_id = l.order_id
  WHERE l.discount_pct >= 10
),
base AS (
  SELECT l.line_id, l.order_id, o.order_dt, o.month, o.rep,
         o.customer_id, c.segment,
         l.product_id, p.category, p.unit,
         l.qty, l.discount_pct, l.currency AS cur,
         fx.ngn_per_usd AS fx,
         (SELECT sc.unit_cost_usd_per_kg
            FROM supplier_costs sc
           WHERE sc.product_id = l.product_id AND sc.effective_date <= o.order_dt
           ORDER BY sc.effective_date DESC LIMIT 1) AS usd_cost,
         CASE WHEN p.unit = 'bag_25kg' AND o.order_dt >= '2026-05-01'
              THEN l.qty * 25 ELSE l.qty END AS kg,
         CASE WHEN l.currency = 'USD' THEN l.unit_price * fx.ngn_per_usd
              ELSE l.unit_price END AS price_ngn,
         CASE WHEN c.segment = 'Distributor' THEN 'Distributor'
              WHEN o.customer_id IN (SELECT customer_id FROM deep) THEN 'Deep-discount'
              ELSE 'All other' END AS grp,
         CASE WHEN o.order_dt BETWEEN '2026-01-01' AND '2026-03-31' THEN 'Q1'
              WHEN o.order_dt BETWEEN '2026-07-01' AND '2026-09-30' THEN 'Q3'
              ELSE 'Q2' END AS period
  FROM clean_order_lines l
  JOIN clean_orders o ON o.order_id   = l.order_id
  JOIN products p     ON p.product_id = l.product_id
  JOIN customers c    ON c.customer_id = o.customer_id
  JOIN fx_rates fx    ON fx.month_start = o.month
)
SELECT line_id, order_id, order_dt, month, period, customer_id, segment, grp, rep,
       product_id, category, unit, qty, kg, discount_pct, cur, fx, usd_cost, price_ngn,
       kg * price_ngn                                           AS gross_rev,
       kg * price_ngn * discount_pct / 100.0                    AS disc_ngn,
       kg * price_ngn * (1 - discount_pct / 100.0)              AS rev,
       kg * usd_cost * fx                                       AS cogs,
       kg * price_ngn * (1 - discount_pct / 100.0) - kg * usd_cost * fx AS gm
FROM base;

-- CHECK 3a. One model row per clean line; no cost or FX rate missing
SELECT COUNT(*) AS model_rows,
       SUM(usd_cost IS NULL) AS missing_cost,
       SUM(fx IS NULL) AS missing_fx
FROM margin_model;
-- EXPECT: 4712, 0, 0

-- CHECK 3b. Quick look (the formal tie-out to Finance is in 05_validation_checks.sql)
SELECT period,
       ROUND(SUM(rev) / 1e6, 1) AS net_rev_M,
       ROUND(100.0 * SUM(gm) / SUM(rev), 2) AS gm_pct
FROM margin_model WHERE period IN ('Q1','Q3') GROUP BY period ORDER BY period;
-- EXPECT: Q1 5191.2 / 33.27     Q3 3825.6 / 19.6
