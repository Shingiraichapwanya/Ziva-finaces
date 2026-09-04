-- =============================================================================
-- BigQuery Schema: Personal Budget Tracker
-- Script: analytical_queries.sql
-- Description: Production-ready queries demonstrating daily velocity, envelope
--              variance, vault net worth, and multi-currency auditing.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- QUERY 1: Daily Spending Velocity & Burn Rate (By Country and Account)
-- Use this to monitor how fast you are burning cash during the month.
-- -----------------------------------------------------------------------------
SELECT
  transaction_date,
  country_code,
  financial_institution,
  account_name,
  category_name,
  total_spent_original,
  original_currency,
  total_spent_zar,
  total_spent_usd,
  rolling_7d_avg_spend_zar,
  rolling_7d_avg_spend_usd
FROM `personal_finance.v_daily_spending_burn_rate`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY transaction_date DESC, total_spent_zar DESC;

-- -----------------------------------------------------------------------------
-- QUERY 2: Monthly Budget vs Actual Variance (Envelope Health Check)
-- Shows which monthly commitments are under control and which are blowing out.
-- -----------------------------------------------------------------------------
SELECT
  allocation_month,
  cash_flow_tier,
  category_name,
  is_fixed_obligation,
  target_currency,
  planned_amount,
  rollover_from_prior,
  planned_amount_zar,
  actual_spent_zar,
  variance_zar,
  ROUND(pct_budget_consumed, 1) AS pct_consumed,
  budget_status
FROM `personal_finance.v_monthly_budget_vs_actual`
WHERE allocation_month = DATE_TRUNC(CURRENT_DATE(), MONTH)
ORDER BY
  CASE budget_status
    WHEN 'OVER_BUDGET' THEN 1
    WHEN 'NEAR_LIMIT' THEN 2
    ELSE 3
  END,
  actual_spent_zar DESC;

-- -----------------------------------------------------------------------------
-- QUERY 3: Vault Net Worth & Capital Accumulation
-- Measures your long-term wealth assets across South African & Zimbabwean vaults.
-- -----------------------------------------------------------------------------
SELECT
  country_code,
  financial_institution,
  account_name,
  account_type,
  withdrawal_notice_days,
  current_balance_original,
  primary_currency,
  current_balance_zar,
  current_balance_usd,
  total_vault_movements,
  last_movement_date
FROM `personal_finance.v_vault_holdings_and_net_worth`
ORDER BY current_balance_usd DESC;

-- -----------------------------------------------------------------------------
-- QUERY 4: Cross-Tier Transfer Integrity Audit (Double-Entry Verification)
-- Verifies that every transfer leg has a matching counterpart and net sum is 0.
-- -----------------------------------------------------------------------------
WITH transfer_legs AS (
  SELECT
    t.transaction_id,
    t.transfer_counterpart_id,
    t.transaction_date,
    t.account_id,
    t.cash_flow_tier,
    t.original_amount,
    t.original_currency,
    t.reporting_amount_usd
  FROM `personal_finance.fct_transactions` AS t
  WHERE t.transaction_type IN ('INTERNAL_TRANSFER', 'ALLOCATION_TRANSFER', 'VAULT_CONTRIBUTION', 'VAULT_WITHDRAWAL')
)
SELECT
  a.transaction_id AS leg1_id,
  a.cash_flow_tier AS from_tier,
  a.original_amount AS leg1_amount,
  b.transaction_id AS leg2_id,
  b.cash_flow_tier AS to_tier,
  b.original_amount AS leg2_amount,
  (a.reporting_amount_usd + b.reporting_amount_usd) AS transfer_variance_usd,
  CASE
    WHEN (a.reporting_amount_usd + b.reporting_amount_usd) = 0 THEN 'BALANCED'
    ELSE 'UNBALANCED_LEGS'
  END AS reconciliation_status
FROM transfer_legs AS a
LEFT JOIN transfer_legs AS b
  ON a.transfer_counterpart_id = b.transaction_id
WHERE a.original_amount < 0; -- Filter to sending leg to avoid duplication

-- -----------------------------------------------------------------------------
-- QUERY 5: Zimbabwe Dual-Rate Impact Analysis
-- Compares actual expenses recorded under Market/Parallel vs Official RBZ rates.
-- Demonstrates the exact currency distortion on domestic purchasing power.
-- -----------------------------------------------------------------------------
SELECT
  t.transaction_id,
  t.transaction_date,
  t.merchant_or_payee,
  t.original_amount,
  t.original_currency,
  t.rate_type_applied,
  t.applied_exchange_rate_usd,
  t.reporting_amount_usd AS actual_recorded_usd,
  -- Re-evaluate against official rate to quantify parallel spread impact
  ROUND(t.original_amount * r_off.inverse_rate, 4) AS official_benchmark_usd,
  ROUND(ABS(t.reporting_amount_usd - (t.original_amount * r_off.inverse_rate)), 4) AS parallel_rate_distortion_usd
FROM `personal_finance.fct_transactions` AS t
INNER JOIN `personal_finance.dim_accounts` AS a
  ON t.account_id = a.account_id
LEFT JOIN `personal_finance.v_latest_effective_exchange_rates` AS r_off
  ON r_off.base_currency = 'USD'
 AND r_off.quote_currency = t.original_currency
 AND r_off.rate_type = 'OFFICIAL_INTERBANK'
WHERE a.country_code = 'ZW'
  AND t.original_currency = 'ZiG'
  AND t.transaction_type = 'EXPENSE';

-- -----------------------------------------------------------------------------
-- QUERY 6: Quarterly Tax Liability & Provisional Offset Reconciliation
-- Calculates quarterly gross revenue, business productivity write-offs,
-- net taxable income, estimated provisional tax liability (27% rate),
-- actual tax payments, and net outstanding tax or credit surplus.
-- -----------------------------------------------------------------------------
SELECT
  tax_year,
  tax_quarter,
  quarter_start_date,
  quarter_end_date,
  gross_taxable_inflow_zar,
  productivity_expenses_offset_zar,
  total_allowable_deductions_zar,
  net_taxable_income_zar,
  effective_tax_rate,
  estimated_tax_liability_zar,
  actual_tax_paid_zar,
  net_tax_outstanding_zar,
  tax_settlement_status,
  tax_deductible_transaction_count
FROM `personal_finance.v_quarterly_tax_liability_schedule`
ORDER BY tax_year DESC, tax_quarter DESC;

-- -----------------------------------------------------------------------------
-- QUERY 7: Itemized Tax-Deductible Business Expense Schedule
-- Provides an itemized audit schedule of business productivity purchases,
-- software subscriptions, and home office costs with invoice numbers
-- for tax returns (SARS / ZIMRA).
-- -----------------------------------------------------------------------------
SELECT
  transaction_date,
  transaction_id,
  merchant_or_payee,
  category_name,
  tax_line_item,
  original_amount,
  original_currency,
  reporting_amount_zar,
  tax_deductible_amount_zar,
  tax_invoice_number,
  payment_method,
  notes
FROM `personal_finance.v_tax_deductible_expenses_audit`
ORDER BY transaction_date DESC, tax_deductible_amount_zar DESC;
