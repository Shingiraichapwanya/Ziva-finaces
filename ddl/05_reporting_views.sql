-- =============================================================================
-- BigQuery Schema: Personal Budget Tracker
-- Script: 05_reporting_views.sql
-- Description: Optimized analytical reporting views for Daily Spending, Monthly
--              Budget vs Actuals, Vault Net Worth, and Latest FX Rates.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. V_LATEST_EFFECTIVE_EXCHANGE_RATES
-- Window-ranked view to fetch the latest available exchange rate for any pair.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `personal_finance.v_latest_effective_exchange_rates` AS
WITH ranked_rates AS (
  SELECT
    rate_date,
    rate_timestamp,
    base_currency,
    quote_currency,
    rate_type,
    exchange_rate,
    inverse_rate,
    source_provider,
    ROW_NUMBER() OVER (
      PARTITION BY base_currency, quote_currency, rate_type
      ORDER BY rate_timestamp DESC, rate_date DESC
    ) AS rank_idx
  FROM `personal_finance.fct_exchange_rates`
)
SELECT
  rate_date,
  rate_timestamp,
  base_currency,
  quote_currency,
  rate_type,
  exchange_rate,
  inverse_rate,
  source_provider
FROM ranked_rates
WHERE rank_idx = 1;

-- -----------------------------------------------------------------------------
-- 2. V_DAILY_SPENDING_BURN_RATE
-- Daily spending velocity, 7-day rolling average, and merchant breakdown.
-- Filters strictly to operational daily spending outflows.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `personal_finance.v_daily_spending_burn_rate` AS
WITH daily_aggregates AS (
  -- Early aggregation before joins to optimize execution
  SELECT
    t.transaction_date,
    t.account_id,
    t.category_id,
    -- Invert negative expense amounts into positive spend figures for reporting
    SUM(ABS(t.original_amount)) AS total_spent_original,
    t.original_currency,
    SUM(ABS(t.reporting_amount_usd)) AS total_spent_usd,
    SUM(ABS(t.reporting_amount_zar)) AS total_spent_zar,
    COUNT(1) AS transaction_count
  FROM `personal_finance.fct_transactions` AS t
  WHERE t.cash_flow_tier = 'DAILY_SPENDING'
    AND t.transaction_type IN ('EXPENSE', 'FINANCIAL_FEE')
  GROUP BY
    t.transaction_date,
    t.account_id,
    t.category_id,
    t.original_currency
)
SELECT
  d.transaction_date,
  a.account_name,
  a.financial_institution,
  a.country_code,
  c.category_name,
  c.category_group,
  c.is_essential_need,
  d.total_spent_original,
  d.original_currency,
  d.total_spent_usd,
  d.total_spent_zar,
  d.transaction_count,
  -- 7-Day moving average spend in base currencies
  AVG(d.total_spent_zar) OVER (
    PARTITION BY a.country_code
    ORDER BY d.transaction_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7d_avg_spend_zar,
  AVG(d.total_spent_usd) OVER (
    PARTITION BY a.country_code
    ORDER BY d.transaction_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7d_avg_spend_usd
FROM daily_aggregates AS d
INNER JOIN `personal_finance.dim_accounts` AS a
  ON d.account_id = a.account_id
INNER JOIN `personal_finance.dim_categories` AS c
  ON d.category_id = c.category_id;

-- -----------------------------------------------------------------------------
-- 3. V_MONTHLY_BUDGET_VS_ACTUAL
-- Envelope tracking comparing planned allocations against actual debits.
-- Supports both ZAR and USD reporting.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `personal_finance.v_monthly_budget_vs_actual` AS
WITH monthly_actuals AS (
  -- Early aggregation of expenses and allocation transfers
  SELECT
    DATE_TRUNC(t.transaction_date, MONTH) AS budget_month,
    t.category_id,
    t.cash_flow_tier,
    SUM(ABS(t.reporting_amount_usd)) AS actual_spent_usd,
    SUM(ABS(t.reporting_amount_zar)) AS actual_spent_zar,
    COUNT(1) AS actual_transaction_count
  FROM `personal_finance.fct_transactions` AS t
  WHERE t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER', 'FINANCIAL_FEE')
  GROUP BY
    budget_month,
    t.category_id,
    t.cash_flow_tier
)
SELECT
  b.allocation_month,
  b.category_id,
  b.cash_flow_tier,
  c.category_group,
  c.category_name,
  b.is_fixed_obligation,
  b.target_currency,
  b.planned_amount,
  b.rollover_from_prior,
  b.planned_amount_usd,
  b.planned_amount_zar,
  COALESCE(m.actual_spent_usd, 0.0000) AS actual_spent_usd,
  COALESCE(m.actual_spent_zar, 0.0000) AS actual_spent_zar,
  COALESCE(m.actual_transaction_count, 0) AS actual_transaction_count,
  -- Variance calculation (Positive = Under budget; Negative = Over budget)
  (b.planned_amount_zar + b.rollover_from_prior) - COALESCE(m.actual_spent_zar, 0.0000) AS variance_zar,
  (b.planned_amount_usd + b.rollover_from_prior) - COALESCE(m.actual_spent_usd, 0.0000) AS variance_usd,
  -- Percentage spent
  SAFE_DIVIDE(COALESCE(m.actual_spent_zar, 0.0000), (b.planned_amount_zar + b.rollover_from_prior)) * 100.0 AS pct_budget_consumed,
  CASE
    WHEN COALESCE(m.actual_spent_zar, 0.0000) > (b.planned_amount_zar + b.rollover_from_prior) THEN 'OVER_BUDGET'
    WHEN SAFE_DIVIDE(COALESCE(m.actual_spent_zar, 0.0000), (b.planned_amount_zar + b.rollover_from_prior)) >= 0.90 THEN 'NEAR_LIMIT'
    ELSE 'ON_TRACK'
  END AS budget_status
FROM `personal_finance.fct_budget_allocations` AS b
LEFT JOIN monthly_actuals AS m
  ON b.allocation_month = m.budget_month
 AND b.category_id = m.category_id
 AND b.cash_flow_tier = m.cash_flow_tier
INNER JOIN `personal_finance.dim_categories` AS c
  ON b.category_id = c.category_id;

-- -----------------------------------------------------------------------------
-- 4. V_VAULT_HOLDINGS_AND_NET_WORTH
-- Cumulative capital accumulation in the Long-Term Vault across accounts.
-- Distinguishes emergency liquid runway from invested capital.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `personal_finance.v_vault_holdings_and_net_worth` AS
WITH vault_ledger AS (
  SELECT
    t.account_id,
    SUM(t.original_amount) AS cumulative_balance_original,
    t.original_currency,
    SUM(t.reporting_amount_usd) AS cumulative_balance_usd,
    SUM(t.reporting_amount_zar) AS cumulative_balance_zar,
    MIN(t.transaction_date) AS first_deposit_date,
    MAX(t.transaction_date) AS last_movement_date,
    COUNT(1) AS total_vault_movements
  FROM `personal_finance.fct_transactions` AS t
  WHERE t.cash_flow_tier = 'LONG_TERM_VAULT'
  GROUP BY
    t.account_id,
    t.original_currency
)
SELECT
  a.account_id,
  a.account_name,
  a.financial_institution,
  a.country_code,
  a.primary_currency,
  a.account_type,
  a.is_vault_locked,
  a.withdrawal_notice_days,
  COALESCE(v.cumulative_balance_original, 0.0000) AS current_balance_original,
  COALESCE(v.cumulative_balance_usd, 0.0000) AS current_balance_usd,
  COALESCE(v.cumulative_balance_zar, 0.0000) AS current_balance_zar,
  v.first_deposit_date,
  v.last_movement_date,
  v.total_vault_movements
FROM `personal_finance.dim_accounts` AS a
LEFT JOIN vault_ledger AS v
  ON a.account_id = v.account_id
WHERE a.cash_flow_tier = 'LONG_TERM_VAULT';

-- -----------------------------------------------------------------------------
-- 5. V_CASH_FLOW_WATERFALL_SUMMARY
-- Monthly macro waterfall showing how total income flows into:
-- (1) Daily Spending, (2) Monthly Fixed/Envelopes, and (3) Long-Term Vault.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `personal_finance.v_cash_flow_waterfall_summary` AS
SELECT
  DATE_TRUNC(t.transaction_date, MONTH) AS flow_month,
  t.cash_flow_tier,
  t.transaction_type,
  c.category_group,
  SUM(t.reporting_amount_usd) AS net_flow_usd,
  SUM(t.reporting_amount_zar) AS net_flow_zar
FROM `personal_finance.fct_transactions` AS t
INNER JOIN `personal_finance.dim_categories` AS c
  ON t.category_id = c.category_id
GROUP BY
  flow_month,
  t.cash_flow_tier,
  t.transaction_type,
  c.category_group;

-- -----------------------------------------------------------------------------
-- 6. V_QUARTERLY_TAX_LIABILITY_SCHEDULE
-- Computes quarterly gross taxable inflow, allowable business productivity offsets,
-- estimated provisional tax liabilities (at benchmark rate e.g. 27%), actual statutory
-- tax payments made to SARS/ZIMRA, and net tax outstanding or credit surplus.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `personal_finance.v_quarterly_tax_liability_schedule` AS
WITH quarterly_base AS (
  SELECT
    EXTRACT(YEAR FROM t.transaction_date) AS tax_year,
    CONCAT(CAST(EXTRACT(YEAR FROM t.transaction_date) AS STRING), '-Q', CAST(EXTRACT(QUARTER FROM t.transaction_date) AS STRING)) AS tax_quarter,
    DATE_TRUNC(t.transaction_date, QUARTER) AS quarter_start_date,
    LAST_DAY(t.transaction_date, QUARTER) AS quarter_end_date,

    -- Gross Inflows (Taxable Revenue/Income)
    SUM(CASE WHEN t.transaction_type = 'INCOME' THEN t.reporting_amount_zar ELSE 0 END) AS gross_taxable_inflow_zar,
    SUM(CASE WHEN t.transaction_type = 'INCOME' THEN t.reporting_amount_usd ELSE 0 END) AS gross_taxable_inflow_usd,

    -- Business Productivity Deductions (Hardware, Software, Professional Services)
    SUM(CASE 
      WHEN c.category_group = 'BUSINESS_PRODUCTIVITY' AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN COALESCE(t.tax_deductible_amount_zar, ABS(t.reporting_amount_zar))
      ELSE 0 
    END) AS productivity_expenses_offset_zar,
    SUM(CASE 
      WHEN c.category_group = 'BUSINESS_PRODUCTIVITY' AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN COALESCE(t.tax_deductible_amount_usd, ABS(t.reporting_amount_usd))
      ELSE 0 
    END) AS productivity_expenses_offset_usd,

    -- Total Allowable Tax Deductions (all items flagged is_tax_deductible)
    SUM(CASE 
      WHEN (t.is_tax_deductible OR c.is_tax_deductible) AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN COALESCE(t.tax_deductible_amount_zar, ABS(t.reporting_amount_zar))
      ELSE 0 
    END) AS total_allowable_deductions_zar,
    SUM(CASE 
      WHEN (t.is_tax_deductible OR c.is_tax_deductible) AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN COALESCE(t.tax_deductible_amount_usd, ABS(t.reporting_amount_usd))
      ELSE 0 
    END) AS total_allowable_deductions_usd,

    -- Actual Statutory Tax Payments (Payments made to SARS / ZIMRA)
    SUM(CASE 
      WHEN c.category_id = 'CAT_TAX_STATUTORY_PROVISIONAL' OR c.tax_line_item = 'STATUTORY_TAX_PAYMENT'
      THEN ABS(t.reporting_amount_zar)
      ELSE 0 
    END) AS actual_tax_paid_zar,
    SUM(CASE 
      WHEN c.category_id = 'CAT_TAX_STATUTORY_PROVISIONAL' OR c.tax_line_item = 'STATUTORY_TAX_PAYMENT'
      THEN ABS(t.reporting_amount_usd)
      ELSE 0 
    END) AS actual_tax_paid_usd,

    COUNT(DISTINCT CASE WHEN (t.is_tax_deductible OR c.is_tax_deductible) THEN t.transaction_id END) AS tax_deductible_transaction_count
  FROM `personal_finance.fct_transactions` AS t
  INNER JOIN `personal_finance.dim_categories` AS c
    ON t.category_id = c.category_id
  GROUP BY
    tax_year,
    tax_quarter,
    quarter_start_date,
    quarter_end_date
)
SELECT
  tax_year,
  tax_quarter,
  quarter_start_date,
  quarter_end_date,
  gross_taxable_inflow_zar,
  productivity_expenses_offset_zar,
  total_allowable_deductions_zar,
  
  -- Net Taxable Operating Income after productivity & business deductions
  GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) AS net_taxable_income_zar,
  
  -- Benchmark Provisional Tax Rate (27.00% benchmark for corporate / high bracket provisional)
  0.2700 AS effective_tax_rate,
  
  -- Estimated Tax Liability before tax credits/payments
  ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4) AS estimated_tax_liability_zar,
  
  -- Actual Statutory Tax Payments Made to Date
  actual_tax_paid_zar,
  
  -- Net Outstanding Payable (Positive = Tax Due; Negative = Credit Surplus)
  ROUND(ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4) - actual_tax_paid_zar, 4) AS net_tax_outstanding_zar,
  
  -- Settlement Status Indicator
  CASE
    WHEN actual_tax_paid_zar >= ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4) 
         AND ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4) > 0 
      THEN 'SETTLED'
    WHEN actual_tax_paid_zar > ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4)
      THEN 'CREDIT_SURPLUS'
    WHEN ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4) = 0 
      THEN 'NO_TAX_LIABILITY'
    ELSE 'PAYMENT_PENDING'
  END AS tax_settlement_status,

  -- Dual USD Reporting
  gross_taxable_inflow_usd,
  productivity_expenses_offset_usd,
  total_allowable_deductions_usd,
  GREATEST(0.0000, gross_taxable_inflow_usd - total_allowable_deductions_usd) AS net_taxable_income_usd,
  ROUND(GREATEST(0.0000, gross_taxable_inflow_usd - total_allowable_deductions_usd) * 0.2700, 4) AS estimated_tax_liability_usd,
  actual_tax_paid_usd,
  ROUND(ROUND(GREATEST(0.0000, gross_taxable_inflow_usd - total_allowable_deductions_usd) * 0.2700, 4) - actual_tax_paid_usd, 4) AS net_tax_outstanding_usd,
  tax_deductible_transaction_count
FROM quarterly_base;

-- -----------------------------------------------------------------------------
-- 7. V_TAX_DEDUCTIBLE_EXPENSES_AUDIT
-- Itemized audit trail of every purchase claiming tax deductibility, with merchant,
-- category, invoice reference, and reporting amounts for tax filing.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `personal_finance.v_tax_deductible_expenses_audit` AS
SELECT
  t.transaction_date,
  t.transaction_id,
  t.merchant_or_payee,
  c.category_id,
  c.category_name,
  c.category_group,
  c.tax_line_item,
  t.original_amount,
  t.original_currency,
  t.reporting_amount_zar,
  t.reporting_amount_usd,
  COALESCE(t.tax_deductible_amount_zar, ABS(t.reporting_amount_zar)) AS tax_deductible_amount_zar,
  COALESCE(t.tax_deductible_amount_usd, ABS(t.reporting_amount_usd)) AS tax_deductible_amount_usd,
  t.tax_invoice_number,
  t.payment_method,
  t.notes,
  t.tags
FROM `personal_finance.fct_transactions` AS t
INNER JOIN `personal_finance.dim_categories` AS c
  ON t.category_id = c.category_id
WHERE (t.is_tax_deductible OR c.is_tax_deductible)
  AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER');

