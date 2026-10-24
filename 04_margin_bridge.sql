-- =====================================================================
-- 04_margin_bridge.sql
-- Step 4: EXPLAIN THE DROP. Reads only margin_model.
--   4a WHO    : gross profit by customer group, Q1 vs Q3
--   4b WHEN   : month-by-month trend
--   4c WHY    : margin bridge in naira (volume/mix, FX, price, discounts, supplier cost)
--   4d DETAIL : what the distributors buy now
-- All amounts in naira millions (M).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4a. WHO: gross profit by customer group
-- ---------------------------------------------------------------------
SELECT grp,
       ROUND(SUM(CASE WHEN period='Q1' THEN gm END) / 1e6, 1) AS gm_q1_M,
       ROUND(SUM(CASE WHEN period='Q3' THEN gm END) / 1e6, 1) AS gm_q3_M,
       ROUND((SUM(CASE WHEN period='Q3' THEN gm END) - SUM(CASE WHEN period='Q1' THEN gm END)) / 1e6, 1) AS change_M
FROM margin_model WHERE period IN ('Q1','Q3')
GROUP BY grp ORDER BY change_M;
-- EXPECT: Distributor 602.2 -> 30.0 (-572.2) | Deep-discount 334.7 -> 141.5 (-193.2)
--         All other 790.0 -> 578.2 (-211.8)   Total 1726.9 -> 749.7 (-977.2)

-- ---------------------------------------------------------------------
-- 4b. WHEN: month by month (timing is the clue to the cause)
-- ---------------------------------------------------------------------
SELECT month,
       ROUND(SUM(rev) / 1e6, 1) AS net_rev_M,
       ROUND(100.0 * SUM(gm) / SUM(rev), 1) AS gm_pct_all,
       ROUND(100.0 * SUM(CASE WHEN grp <> 'Distributor' THEN gm END)
                   / SUM(CASE WHEN grp <> 'Distributor' THEN rev END), 1) AS gm_pct_ex_distributors,
       ROUND(100.0 * SUM(CASE WHEN grp = 'Distributor' THEN gm END)
                   / SUM(CASE WHEN grp = 'Distributor' THEN rev END), 1) AS gm_pct_distributors,
       ROUND(100.0 * SUM(disc_ngn) / SUM(gross_rev), 1) AS discount_pct,
       MAX(fx) AS fx
FROM margin_model GROUP BY month ORDER BY month;
-- EXPECT: gm_pct_all 33.4, 33.8, 32.5, 31.4, 31.7, 29.0, 21.5, 19.0, 17.9
--         distributors fall from 29.5 (Jun) to 4.6 (Jul), 2.8, 1.9

-- ---------------------------------------------------------------------
-- 4c. WHY: the margin bridge, Q1 -> Q3, per customer group
-- For each product within a group, Q1 is the baseline:
--   p = gross price per kg   d = discount rate   u = USD cost per kg   f = FX   V = kg
--   volume/mix = (V3 - V1) x Q1 unit margin          list price = V3 x (p3 - p1) x (1 - d1)
--   discounts  = -V3 x p3 x (d3 - d1)                supplier   = -V3 x (u3 - u1) x f1
--   FX         = -V3 x u3 x (f3 - f1)
-- The five effects add up exactly to the change in gross profit.
-- NOTE the 1.0* in the rates: kg and FX are whole numbers and SQL would otherwise
-- chop the decimals off the division (integer division).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS bridge_prod;
CREATE TABLE bridge_prod AS
WITH agg AS (
  SELECT grp, product_id, period,
         SUM(kg) AS v, SUM(gross_rev) AS gr, SUM(disc_ngn) AS dc,
         SUM(kg * usd_cost) AS wu, SUM(kg * fx) AS wf
  FROM margin_model WHERE period IN ('Q1','Q3')
  GROUP BY grp, product_id, period),
rates AS (
  SELECT grp, product_id, period, v,
         1.0 * gr / v AS p, 1.0 * dc / gr AS d, 1.0 * wu / v AS u, 1.0 * wf / v AS f
  FROM agg),
keys AS (SELECT DISTINCT grp, product_id FROM rates),
j AS (
  SELECT k.grp, k.product_id,
         a.v AS v0, a.p AS p0, a.d AS d0, a.u AS u0, a.f AS f0,
         b.v AS v1, b.p AS p1, b.d AS d1, b.u AS u1, b.f AS f1
  FROM keys k
  LEFT JOIN rates a ON a.grp = k.grp AND a.product_id = k.product_id AND a.period = 'Q1'
  LEFT JOIN rates b ON b.grp = k.grp AND b.product_id = k.product_id AND b.period = 'Q3')
SELECT grp, product_id,
       COALESCE(v1,0) - COALESCE(v0,0) AS dv,
       -- baseline unit margin: Q1 rates (Q3 rates if the product is new in Q3)
       COALESCE(p0,p1) * (1 - COALESCE(d0,d1)) - COALESCE(u0,u1) * COALESCE(f0,f1) AS m0,
       CASE WHEN v1 IS NULL THEN 0 ELSE  v1 * (p1 - COALESCE(p0,p1)) * (1 - COALESCE(d0,d1)) END AS e_price,
       CASE WHEN v1 IS NULL THEN 0 ELSE -v1 * p1 * (d1 - COALESCE(d0,d1)) END                  AS e_disc,
       CASE WHEN v1 IS NULL THEN 0 ELSE -v1 * (u1 - COALESCE(u0,u1)) * COALESCE(f0,f1) END     AS e_supplier,
       CASE WHEN v1 IS NULL THEN 0 ELSE -v1 * u1 * (f1 - COALESCE(f0,f1)) END                  AS e_fx
FROM j;

SELECT grp,
       ROUND(SUM(dv * m0) / 1e6, 1)      AS volume_mix_M,
       ROUND(SUM(e_fx) / 1e6, 1)         AS fx_M,
       ROUND(SUM(e_price) / 1e6, 1)      AS list_price_M,
       ROUND(SUM(e_disc) / 1e6, 1)       AS discounts_M,
       ROUND(SUM(e_supplier) / 1e6, 1)   AS supplier_cost_M,
       ROUND(SUM(dv * m0 + e_fx + e_price + e_disc + e_supplier) / 1e6, 1) AS total_change_M
FROM bridge_prod GROUP BY grp
UNION ALL
SELECT 'TOTAL',
       ROUND(SUM(dv * m0) / 1e6, 1), ROUND(SUM(e_fx) / 1e6, 1), ROUND(SUM(e_price) / 1e6, 1),
       ROUND(SUM(e_disc) / 1e6, 1), ROUND(SUM(e_supplier) / 1e6, 1),
       ROUND(SUM(dv * m0 + e_fx + e_price + e_disc + e_supplier) / 1e6, 1)
FROM bridge_prod;
-- EXPECT (naira millions):
--   All other      vol/mix -112.7  FX -175.9  price +102.2  disc  -5.6  supplier -19.8  total -211.8
--   Deep-discount  vol/mix  -89.2  FX  -64.9  price  +37.5  disc -69.8  supplier  -6.7  total -193.2
--   Distributor    vol/mix -514.5  FX -106.3  price  +46.2  disc  +2.4  supplier   0.0  total -572.2
--   TOTAL          vol/mix -716.4  FX -347.0  price +185.8  disc -73.1  supplier -26.5  total -977.2

-- ---------------------------------------------------------------------
-- 4d. DETAIL: what do the distributors buy now?
-- ---------------------------------------------------------------------
SELECT period,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(kg) / 1e3, 0) AS kg_thousand,
       ROUND(100.0 * SUM(CASE WHEN category = 'Sweeteners' THEN kg END) / SUM(kg), 1) AS sweetener_share_pct,
       ROUND(100.0 * SUM(gm) / SUM(rev), 1) AS gm_pct
FROM margin_model WHERE grp = 'Distributor' AND period IN ('Q1','Q3')
GROUP BY period ORDER BY period;
-- EXPECT: Q1 47 orders, 223k kg, 18.6 pct sweeteners, 33.3 pct GM
--         Q3 175 orders, 682k kg, 100.0 pct sweeteners, 3.1 pct GM
