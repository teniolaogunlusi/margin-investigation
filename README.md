# Gross Margin Decline, Q1 → Q3 2026

**Gross margin fell from 33.3% (Q1) to 19.6% (Q3): gross profit down ₦977M, from ₦1,727M to ₦750M (−57%). 59% of that loss (₦572M) came from six Distributor customers.**
From 1 July these six buy only sweeteners (100% of their kilos, against 18.6% in Q1; 3 of the 20 products), and sweeteners earn them a 3.1% margin, down from 33.3%.
The other ₦405M: six Bakery/Confectionery customers on 10–13% discounts (−₦193M) and all remaining customers (−₦212M, mainly FX raising USD costs by ₦347M while NGN price increases recovered only ₦186M).
Q1 and Q3 reconcile to Finance's control totals (Q1 ₦5,191.2M at 33.3%; Q3 ₦3,825.6M at 19.6%); 13 of 13 validation checks pass.
**Recommendation:** tighten discount approval, set a margin floor on distributor sweeteners, review prices monthly against FX, and find out *why* the distributors changed before committing to a win-back plan (§2).

*v1.0 · Author: Ogunlusi Teniola Elizabeth, Data Analyst · Date: 17 October 2026 · Database: SQLite · Run in DBeaver*

---

## Contents
1. [Findings](#1-findings) · 2. [Decision and recommendation](#2-decision-supported-and-recommendation) · 3. [Definitions and method](#3-definitions-and-method) · 4. [Data cleaning log](#4-data-cleaning-log) · 5. [Reconciliation and validation](#5-reconciliation-and-validation) · 6. [How to rerun](#6-how-to-rerun) · 7. [Limitations and confidence](#7-limitations-and-confidence) · 8. [Open items](#8-open-items-to-close-before-the-committee) · 9. [Files](#9-files)

---

## 1. Findings

All figures come from files 01 to 05 unless marked otherwise (§2 marks the exceptions). Amounts are naira millions (₦M).

### 1.1 Where the ₦977M went (gross profit, Q3 vs Q1) — `04_margin_bridge.sql`, query 4a

| Group | GM Q1 | GM Q3 | Change | Share of drop |
|---|---:|---:|---:|---:|
| **Distributors** (C009, C018, C027, C036, C045, C054) | 602.2 | 30.0 | **−572.2** | **58.6%** |
| **Deep-discount customers** (C007, C019, C033, C061, C062, C063) | 334.7 | 141.5 | −193.2 | 19.8% |
| All other customers | 790.0 | 578.2 | −211.8 | 21.7% |
| **Total** | **1,726.9** | **749.7** | **−977.2** | 100% |

A *deep-discount customer* is any customer with at least one line discounted 10% or more: four Bakery and two Confectionery customers.

### 1.2 Why, by driver — query 4c (each column sums exactly to its change)

| Driver | Distributors | Deep-discount | All other | **Total** |
|---|---:|---:|---:|---:|
| Volume / mix | −514.5 | −89.2 | −112.7 | **−716.4** |
| FX on USD supplier costs | −106.3 | −64.9 | −175.9 | **−347.0** |
| NGN list-price increases | +46.2 | +37.5 | +102.2 | **+185.8** |
| Discounts | +2.4 | −69.8 | −5.6 | **−73.1** |
| Supplier cost increases (P03 and P04, 1 June) | 0.0 | −6.7 | −19.8 | **−26.5** |
| **Change in gross profit** | −572.2 | −193.2 | −211.8 | **−977.2** |

Net of price increases, FX cost ₦161M (−347.0 + 185.8). Volume/mix is dominated by the distributor product-mix collapse (−514.5).

### 1.3 Three findings

1. **Distributor behaviour change (₦572M).** Query 4d: Q1 had 47 orders, 223k kg and 33.3% margin; Q3 has 175 orders (3.7×), 682k kg and 3.1% margin, with sweeteners 100% of kilos. In `margin_model` the distributors bought 20 distinct products in Q1 and 3 in Q3. The three sweeteners are Maltodextrin (P06), Sorbitol 70% (P07) and Dextrose Monohydrate (P08). *The cause of the change is unknown (§7).*
2. **FX is outrunning price.** Of the ₦347M FX cost increase, NGN list-price increases recovered ₦186M. The naira moved from ₦1,480 to ₦1,720 per USD between January and September (query 4b).
3. **Deep discounts began in July.** 350 lines at 10–13%, none before 1 July. The six customers' average discount rose from 3.1% to 11.6% between Q1 and Q3 (query 4c shows discounts cost ₦69.8M of margin). Whether the discounts retained volume is addressed in the supporting figures (§2).

### 1.4 When the margin slipped — query 4b

| Month | Net rev ₦M | GM % | GM % ex-distributors | GM % distributors | Discount % | FX ₦/$ |
|---|---:|---:|---:|---:|---:|---:|
| Jan | 1,760.0 | 33.4 | 33.3 | 33.5 | 2.2 | 1,480 |
| Feb | 1,804.0 | 33.8 | 33.6 | 34.1 | 1.7 | 1,495 |
| Mar | 1,627.2 | 32.5 | 32.8 | 31.7 | 2.4 | 1,520 |
| Apr | 1,643.3 | 31.4 | 31.8 | 30.5 | 2.0 | 1,540 |
| May | 1,669.6 | 31.7 | 31.5 | 32.2 | 1.9 | 1,580 |
| Jun | 1,550.2 | 29.0 | 28.9 | 29.5 | 2.2 | 1,620 |
| **Jul** | 1,404.4 | **21.5** | 26.6 | **4.6** | 4.0 | 1,660 |
| Aug | 1,241.7 | 19.0 | 24.5 | 2.8 | 4.3 | 1,690 |
| Sep | 1,179.5 | 17.9 | 23.8 | 1.9 | 3.9 | 1,720 |

- **Jan–Feb:** stable at 33.3–33.6% (ex-distributors).
- **Mar–May:** a steady drift to 31.5%: FX moving, prices not.
- **Jun:** a step to 28.9%: supplier cost increases plus another FX move.
- **Jul:** the structural break: distributors switch to sweeteners and deep discounts begin.

**Is Q1 a fair reference?** As a budget and board baseline, yes. As a run-rate, no: margin was already easing in March, and Q1 FX (₦1,480–1,520) no longer exists. Jan–Feb is the cleaner "undisturbed" baseline.

---

## 2. Decision supported and recommendation

**Decision:** Commercial committee — what to change in the price list, the discount rules, and which products and segments to push.

| # | Recommendation | Why (evidence) | Indicative impact per quarter* | Main risk |
|---|---|---|---|---|
| B | **Cap discounts at 5% for the six deep-discount accounts, unless approved by name** | Discounts cost ₦69.8M of margin (4c) | +₦54M at a 5% cap if volume holds (+₦30M at 8%); pays off unless they lose more than ~28% of volume | Losing the accounts |
| C | **Set a minimum margin on distributor sweeteners (8% suggested: +5.3% on price)** | 3.1% margin and falling with each FX move (4d) | +₦50M if volume holds; if they leave, margin lost is ₦30M | Gross margin excludes freight and warehousing; 682k kg may be loss-making in reality |
| A | **Raise non-distributor prices +5% to +8%, then review monthly against FX** | FX cost ₦347M vs price recovery ₦186M (4c) | +5%: +₦57M to +₦144M; +8%: +₦135M to +₦230M (volume loss 10% → 0%) | Price elasticity unknown |
| D | **Find out why distributors stopped buying 17 products, before committing to win-back** | Distributor volume/mix −₦514.5M (4c) | Their Q1 margin on these lines was ₦597M/quarter; recovering a quarter ≈ ₦150M (*scenario, not forecast*) | Root cause unknown |

A + B + C ≈ ₦150–250M per quarter, roughly 15–25% of the ₦977M gap (overlapping, so not exactly additive). Closing the remainder depends on D. The FX table ends in September: a further naira move pushes distributor sweeteners below cost.

**\*Supporting figures calculated outside files 01 to 05.** The impact estimates, and these figures, were calculated separately from the same cleaned data and are **not** produced by the SQL files. Treat them as indicative until a script reproduces them:
- For non-distributor customers, like-for-like unit COGS rose 14.1% against a 4.9% rise in NGN prices; restoring Q1 margin on that book at September FX would need about +12.3% on price.
- The six deep-discount customers' volume fell 26.4% between Q1 and Q3; all other non-distributor customers' volume fell 3.4%. This suggests the discounts did not retain volume, but causality cannot be established (they may have been discounted because they were at risk).
- Option sizing is at the Q3 run-rate, in isolation, assuming volume holds or falls 5–10%.

---

## 3. Definitions and method

**Finance definition (confirmed with Finance):**
- `GM % = (Net revenue − COGS) ÷ Net revenue`
- **Net revenue** = kg × unit price (NGN) × (1 − discount%), after discounts and excluding VAT. USD-tagged lines are converted at that month's rate.
- **COGS** = kg × supplier cost (USD/kg) in effect **on the order date** × that **month's** FX rate. Freight, duty and warehousing are **excluded**.
- **Periods** by order date: Q1 = 1 Jan–31 Mar 2026; Q2 = Apr–Jun; Q3 = 1 Jul–30 Sep.
- **Groups:** Distributor = `customers.segment = 'Distributor'`; deep-discount = not a distributor, and at least one line with a discount of 10% or more; all other = the rest.

**Bridge method (04c).** Per product within each group, volume-weighted, with Q1 as baseline (P = gross NGN price/kg, d = discount rate, u = USD cost/kg, f = FX, V = kg):

| Effect | Formula |
|---|---|
| NGN list price | (P₁ − P₀)(1 − d₀) · V₁ |
| Discounts | −(d₁ − d₀) · P₁ · V₁ |
| Supplier cost | −(u₁ − u₀) · f₀ · V₁ |
| FX | −(f₁ − f₀) · u₁ · V₁ |
| Volume / mix | (V₁ − V₀) · baseline unit margin |

The five effects sum exactly to the change in gross profit (check V12). The attribution is sequential: rate effects are measured at Q3 volumes and volume/mix at Q1 unit margins, so interaction terms sit inside the rate effects. A different ordering would shift amounts between rows but not the totals.

---

## 4. Data cleaning log

Raw: six tables (`orders`, `order_lines`, `products`, `customers`, `supplier_costs`, `fx_rates`). The source xlsx and CSVs have identical contents. Profiling (`01_profile.sql`) found no orphan keys.

| Issue | Amount | Treatment | Basis |
|---|---|---|---|
| **`order_lines` loaded twice** | 9,612 raw rows = 2 × 4,806; 4,806 copies removed | Removed by the same de-duplication rule as below | Load defect in my environment; see `01_profile.sql` |
| **Exact duplicate lines (sync bug)** | **94 lines; ₦248.6M of net revenue removed** | Keep the lowest `line_id`; remove the other copies | IT-confirmed sync bug; Finance rule: exact copies only (same order, product, qty, price, discount, currency; only `line_id` differs) |
| Mixed date formats | 177 orders in dd/mm/yyyy | Parsed day-first | Proof: 88 have day > 12, **0** have month > 12 |
| Blank currency | 107 lines | Treated as NGN | Finance: field added later, never mandatory |
| USD-tagged lines | 27 lines | Converted at that month's FX | Finance: genuinely USD-priced |
| Rep names | 4 people, 6 spellings; 88 orders blank | Standardised; blank = "Unassigned" | My decision; no effect on margin totals |
| **Bag-product quantities** (P03 Potassium Sorbate, P16 Sodium Bicarbonate) | 239 lines on or after 1 May | kg = qty × 25 | Proof below; Finance: "prove it from the data" |

After cleaning: 4,712 lines and 1,890 orders.

**Bag-unit proof (`05_validation_checks.sql`, 5b).** Before 1 May the bag products' quantities are all multiples of 25 (25 to 3,000 kg). From 2 May they are 1, 2, 4, 8, 10, 20, 40, 80 and 120, none a multiple of 25, with zero overlap (last kg-style line 28 Apr; first bag-style line 2 May). Without the rule, Q3 net revenue is ₦3,565.3M, which is 6.8% short of Finance's ₦3,825.6M; with it, it ties exactly.

---

## 5. Reconciliation and validation

| Period | Net revenue ₦M | Finance ₦M | Diff | GM % | Finance GM % | Result |
|---|---:|---:|---:|---:|---:|---|
| Q1 | 5,191.2 | 5,191.2 | 0.0% | 33.27 | 33.3 | ✅ |
| Q3 | 3,825.6 | 3,825.6 | 0.0% | 19.60 | 19.6 | ✅ |

Tolerance agreed with Finance: ±0.5% revenue, ±0.2 pts GM. **Q2 has no Finance control total**, so April to June come from the same validated pipeline but are not independently reconciled.

`05_validation_checks.sql` (query 5a) returns 13 checks, each PASS or FAIL, and all must pass:

| Group | Checks |
|---|---|
| Tie-out to Finance | V01 to V04: Q1 and Q3 revenue and GM% |
| Row integrity | V05 model rows = clean lines (4,712); V06 one row per `line_id`; V07 no line lacks a cost or FX rate; V10 no clean line lacks an order |
| Cleaning | V08 no invalid dates; V09 no exact duplicates left; V13 94 sync-bug duplicates removed |
| Rules and maths | V11 bag-unit break is clean (0 ambiguous quantities); V12 bridge total = actual change in gross profit |

**Verification record.**

| Run | Result |
|---|---|
| **My run in DBeaver (SQLite):** 17 Oct 2026 | Files 02 to 05 ran without error |

---

## 6. How to rerun

```
margin_analysis/
├── README.md
├── sql/
│   ├── 01_profile.sql             profile the raw data (read-only)
│   ├── 02_clean.sql               clean_order_lines, clean_orders
│   ├── 03_margin_model.sql        margin_model (one row per clean line, all money in naira)
│   ├── 04_margin_bridge.sql       who, when, why (bridge_prod table + summaries)
│   └── 05_validation_checks.sql   13 PASS/FAIL checks, evidence, cleaning log
└── data/raw/                      the six CSVs from distributor_day1_csvs_2.zip
```

1. Load the six CSVs into tables named `orders`, `order_lines`, `products`, `customers`, `supplier_costs`, `fx_rates`. **Load each table exactly once.**
2. Run the files **in order, 01 to 05**, one script each (DBeaver: **Alt+X** runs a whole script; **Ctrl+Enter** runs one statement).
3. Compare each result with its `EXPECT` comment. The last check is the 13-row summary in 05, where every row must say **PASS**.
4. Each of files 02, 03 and 04 drops and recreates its own tables, so any file can be rerun safely. Raw tables are never modified.

**Dialect notes (the scripts are written for SQLite).** On PostgreSQL or SQL Server: dates need real date types (`date()` and text comparisons of dates are SQLite habits); `SUM(condition)` becomes `SUM(CASE WHEN condition THEN 1 ELSE 0 END)`; a subquery in `FROM` needs an alias; `LIMIT 1` becomes `TOP 1` (SQL Server); `CREATE TABLE … AS SELECT` becomes `SELECT … INTO` (SQL Server). Keep the `1.0*` in 04c on every database (integer division).

---

## 7. Limitations and confidence

| Claim | Confidence | Why not higher |
|---|---:|---|
| Reconciliation, cleaning, bag-unit rule, FX/price/discount figures | ~95% | Q1 and Q3 tie to Finance exactly |
| The distributor shift is real behaviour, not a second data bug | ~85% | Judged from the order pattern; at least 5 of the 6 distributors ordered in every month (all 6 in Jul–Sep); 26 near-duplicate distributor lines in Q3 are unexplained |
| FX lag explains most of the non-distributor slide; deep discounts did not buy volume | ~80% | Observational; discounts may have been defensive |
| *Why* distributors changed behaviour | **<50%** | Not in the data |

Limitations:
1. **Causality.** This analysis shows what changed and when, not why. Price elasticity cannot be estimated from this data, so the option sizing assumes volume holds or falls 5–10%.
2. **Gross margin excludes freight, duty and warehousing** (Finance's definition). Low-margin, high-volume sweeteners may be loss-making on a contribution basis.
3. **The bag-unit change date (1 May) is inferred from the data**, not confirmed by the warehouse.
4. **FX is monthly.** The month's rate applies to every order in that month, and the table ends in September.
5. **Blank currency = NGN** relies on Finance's statement; the prices look NGN-scale, which is consistent with it.
6. **VAT.** The data has no VAT field. Reconciling to Finance's ex-VAT figures to the decimal implies prices are already ex-VAT.
7. **Exact duplicates only.** Lines that share an order and product but are not exact copies are kept, per Finance's rule.
8. **Profiling cannot see meaning.** My table-level checks missed the bag-unit change; it surfaced only when Q3 failed to reconcile.
9. **Value checks are hard-coded for this extract** (Finance totals, the 94 duplicates). A refreshed extract needs new expectations.
10. **Groups are rule-defined** (segment label; any line ≥10% discount), and Q2 is not externally reconciled.
11. **Supporting figures in §2** are not produced by the SQL files.

---

## 8. Open items to close before the committee

1. Sales ops: is there a July contract, promotion or pricing agreement with the six distributors on sweeteners?
2. Account owners: did the distributors move their other 17 products to a competitor?
3. Commercial: who approved the 10–13% discounts, and on what evidence (competitor quote, churn risk)?
4. Finance/logistics: freight and warehousing ₦/kg, to test whether distributor sweeteners are loss-making.
5. Warehouse: confirm that bag products were recorded in bags from 1 May.
6. IT: confirm whether the surge in distributor orders (47 to 175) is genuine.

---

## 9. Files

| File | Purpose |
|---|---|
| `sql/01_profile.sql` | Read-only profiling of the raw data (checks 1a to 1f) |
| `sql/02_clean.sql` | Builds `clean_order_lines` (4,712 lines) and `clean_orders` (1,890 orders) |
| `sql/03_margin_model.sql` | Builds `margin_model`: one row per clean line, all money in naira |
| `sql/04_margin_bridge.sql` | Who (4a), when (4b), why (4c bridge), distributor detail (4d) |
| `sql/05_validation_checks.sql` | 13 PASS/FAIL checks, bag-unit evidence, cleaning log |
| `README.md` | This document |
