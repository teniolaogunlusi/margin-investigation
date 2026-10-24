-- 01_profile.sql
-- Part 1: profile the raw data (read-only: nothing is created, changed or deleted)

-- 1a. How big is everything?
SELECT 'orders' AS tbl, COUNT(*) AS n FROM orders
UNION ALL SELECT 'order_lines', COUNT(DISTINCT line_id) FROM order_lines
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'supplier_costs', COUNT(*) FROM supplier_costs
UNION ALL SELECT 'fx_rates', COUNT(*) FROM fx_rates;
-- EXPECT: orders 1890, order_lines 4806, products 20, customers 64, supplier_costs 22, fx_rates 9

-- 1b. Are dates written one way or two? [CHECK]
SELECT CASE WHEN order_date LIKE '____-__-__' THEN 'yyyy-mm-dd'
 WHEN order_date LIKE '__/__/____' THEN 'dd/mm/yyyy'
 ELSE 'OTHER' END AS date_format,
 COUNT(*) AS n_orders
FROM orders GROUP BY 1;
-- EXPECT: yyyy-mm-dd 1713, dd/mm/yyyy 177, no OTHER row
-- Then prove the slash dates are DAY first (a month can never exceed 12):
SELECT SUM(CAST(substr(order_date,1,2) AS INT) > 12) AS day_over_12,
 SUM(CAST(substr(order_date,4,2) AS INT) > 12) AS month_over_12
FROM orders WHERE order_date LIKE '__/__/____';
-- EXPECT: day_over_12 = 88, month_over_12 = 0 (so it is dd/mm/yyyy)

-- 1c. What currencies exist? Any blanks?
SELECT COALESCE(NULLIF(TRIM(currency),''),'(blank)') AS currency, COUNT(*) AS n
FROM (SELECT DISTINCT * FROM order_lines)
GROUP BY 1;
-- EXPECT: NGN 4672, (blank) 107, USD 27

-- 1d. Rep names: how many spellings? [CHECK]
SELECT sales_rep, COUNT(*) AS n FROM orders GROUP BY 1 ORDER BY 1;
-- EXPECT: 6 spellings of 4 people, plus blanks (88)

-- 1e. Do the tables join without orphans? [CHECK]
SELECT (SELECT COUNT(*) FROM order_lines WHERE order_id NOT IN (SELECT order_id FROM orders)) AS lines_without_order,
 (SELECT COUNT(*) FROM order_lines WHERE product_id NOT IN (SELECT product_id FROM products)) AS lines_without_product,
 (SELECT COUNT(*) FROM orders WHERE customer_id NOT IN (SELECT customer_id FROM customers)) AS orders_without_customer;
-- EXPECT: 0, 0, 0

-- 1f. Exact duplicate lines (everything the same except line_id) [CHECK]
SELECT COUNT(*) AS lines_that_are_extra_copies FROM (
 SELECT ROW_NUMBER() OVER (
 PARTITION BY order_id, product_id, qty, unit_price, discount_pct,
 COALESCE(NULLIF(TRIM(currency),''),'NGN')
 ORDER BY line_id) AS rn
 FROM (SELECT DISTINCT * FROM order_lines)
) WHERE rn > 1;
-- EXPECT: 94
