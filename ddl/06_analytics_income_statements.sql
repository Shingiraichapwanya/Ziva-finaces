-- =============================================================================
-- BigQuery Schema: Personal Budget Tracker
-- Script: 06_analytics_income_statements.sql
-- Description: Analytical Views for Structured Income Statements (P&L),
--              Operating vs. Personal Margin Segregation, and Non-Operating Gains.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. V_INCOME_STATEMENT_MONTHLY_QUARTERLY
-- Multi-tier P&L isolating Operating Revenue, Business Productivity Deductions,
-- Personal Living Essentials, Discretionary Spend, and Net Savings Rate.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `personal_finance.v_income_statement_monthly_quarterly` AS
WITH monthly_base AS (
  SELECT
    'MONTH' AS period_type,
    FORMAT_DATE('%Y-%m', t.transaction_date) AS statement_period,
    DATE_TRUNC(t.transaction_date, MONTH) AS period_start_date,
    LAST_DAY(t.transaction_date, MONTH) AS period_end_date,

    -- 1. Gross Operating Revenue (Salary, Retainers, Invoiced Inflows)
    SUM(CASE WHEN t.transaction_type = 'INCOME' THEN t.reporting_amount_zar ELSE 0 END) AS gross_operating_revenue_zar,
    SUM(CASE WHEN t.transaction_type = 'INCOME' THEN t.reporting_amount_usd ELSE 0 END) AS gross_operating_revenue_usd,

    -- 2. Operating / Business Productivity Expenses (Hardware, Software, Professional Services)
    SUM(CASE 
      WHEN (c.category_group = 'BUSINESS_PRODUCTIVITY' OR t.is_tax_deductible) 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_zar) 
      ELSE 0 
    END) AS operating_expenses_zar,
    SUM(CASE 
      WHEN (c.category_group = 'BUSINESS_PRODUCTIVITY' OR t.is_tax_deductible) 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_usd) 
      ELSE 0 
    END) AS operating_expenses_usd,

    -- 3. Personal Living Essentials (Rent, Groceries, Electricity, Fuel, Medical)
    SUM(CASE 
      WHEN c.category_group = 'LIVING_EXPENSES' AND NOT t.is_tax_deductible 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_zar) 
      ELSE 0 
    END) AS living_essentials_zar,
    SUM(CASE 
      WHEN c.category_group = 'LIVING_EXPENSES' AND NOT t.is_tax_deductible 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_usd) 
      ELSE 0 
    END) AS living_essentials_usd,

    -- 4. Discretionary Spending (Dining, Coffee, Leisure, Streaming)
    SUM(CASE 
      WHEN c.category_group = 'DISCRETIONARY' 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_zar) 
      ELSE 0 
    END) AS discretionary_expenses_zar,
    SUM(CASE 
      WHEN c.category_group = 'DISCRETIONARY' 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_usd) 
      ELSE 0 
    END) AS discretionary_expenses_usd,

    -- 5. Statutory Taxes & Levies Paid (Provisional Tax remittances, IMTT)
    SUM(CASE 
      WHEN c.category_group IN ('STATUTORY_OBLIGATIONS', 'DEBT_OBLIGATIONS')
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_zar) 
      ELSE 0 
    END) AS statutory_and_debt_zar,
    SUM(CASE 
      WHEN c.category_group IN ('STATUTORY_OBLIGATIONS', 'DEBT_OBLIGATIONS')
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_usd) 
      ELSE 0 
    END) AS statutory_and_debt_usd,

    -- 6. Capital Transfers to Long-Term Vault
    SUM(CASE 
      WHEN t.transaction_type = 'VAULT_CONTRIBUTION' 
      THEN ABS(t.reporting_amount_zar) 
      ELSE 0 
    END) AS vault_contributions_zar,
    SUM(CASE 
      WHEN t.transaction_type = 'VAULT_CONTRIBUTION' 
      THEN ABS(t.reporting_amount_usd) 
      ELSE 0 
    END) AS vault_contributions_usd

  FROM `personal_finance.fct_transactions` AS t
  INNER JOIN `personal_finance.dim_categories` AS c
    ON t.category_id = c.category_id
  GROUP BY 1, 2, 3, 4
),
quarterly_base AS (
  SELECT
    'QUARTER' AS period_type,
    CONCAT(CAST(EXTRACT(YEAR FROM t.transaction_date) AS STRING), '-Q', CAST(EXTRACT(QUARTER FROM t.transaction_date) AS STRING)) AS statement_period,
    DATE_TRUNC(t.transaction_date, QUARTER) AS period_start_date,
    LAST_DAY(t.transaction_date, QUARTER) AS period_end_date,

    SUM(CASE WHEN t.transaction_type = 'INCOME' THEN t.reporting_amount_zar ELSE 0 END) AS gross_operating_revenue_zar,
    SUM(CASE WHEN t.transaction_type = 'INCOME' THEN t.reporting_amount_usd ELSE 0 END) AS gross_operating_revenue_usd,

    SUM(CASE 
      WHEN (c.category_group = 'BUSINESS_PRODUCTIVITY' OR t.is_tax_deductible) 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_zar) 
      ELSE 0 
    END) AS operating_expenses_zar,
    SUM(CASE 
      WHEN (c.category_group = 'BUSINESS_PRODUCTIVITY' OR t.is_tax_deductible) 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_usd) 
      ELSE 0 
    END) AS operating_expenses_usd,

    SUM(CASE 
      WHEN c.category_group = 'LIVING_EXPENSES' AND NOT t.is_tax_deductible 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_zar) 
      ELSE 0 
    END) AS living_essentials_zar,
    SUM(CASE 
      WHEN c.category_group = 'LIVING_EXPENSES' AND NOT t.is_tax_deductible 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_usd) 
      ELSE 0 
    END) AS living_essentials_usd,

    SUM(CASE 
      WHEN c.category_group = 'DISCRETIONARY' 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_zar) 
      ELSE 0 
    END) AS discretionary_expenses_zar,
    SUM(CASE 
      WHEN c.category_group = 'DISCRETIONARY' 
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_usd) 
      ELSE 0 
    END) AS discretionary_expenses_usd,

    SUM(CASE 
      WHEN c.category_group IN ('STATUTORY_OBLIGATIONS', 'DEBT_OBLIGATIONS')
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_zar) 
      ELSE 0 
    END) AS statutory_and_debt_zar,
    SUM(CASE 
      WHEN c.category_group IN ('STATUTORY_OBLIGATIONS', 'DEBT_OBLIGATIONS')
           AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN ABS(t.reporting_amount_usd) 
      ELSE 0 
    END) AS statutory_and_debt_usd,

    SUM(CASE 
      WHEN t.transaction_type = 'VAULT_CONTRIBUTION' 
      THEN ABS(t.reporting_amount_zar) 
      ELSE 0 
    END) AS vault_contributions_zar,
    SUM(CASE 
      WHEN t.transaction_type = 'VAULT_CONTRIBUTION' 
      THEN ABS(t.reporting_amount_usd) 
      ELSE 0 
    END) AS vault_contributions_usd

  FROM `personal_finance.fct_transactions` AS t
  INNER JOIN `personal_finance.dim_categories` AS c
    ON t.category_id = c.category_id
  GROUP BY 1, 2, 3, 4
),
unioned AS (
  SELECT * FROM monthly_base
  UNION ALL
  SELECT * FROM quarterly_base
)
SELECT
  period_type,
  statement_period,
  period_start_date,
  period_end_date,
  
  -- Operating Line Items
  gross_operating_revenue_zar,
  operating_expenses_zar,
  ROUND(gross_operating_revenue_zar - operating_expenses_zar, 4) AS net_operating_income_zar,
  ROUND(SAFE_DIVIDE(gross_operating_revenue_zar - operating_expenses_zar, gross_operating_revenue_zar) * 100, 2) AS operating_margin_pct,

  -- Personal Expenditures & Allocations
  living_essentials_zar,
  discretionary_expenses_zar,
  statutory_and_debt_zar,
  ROUND(operating_expenses_zar + living_essentials_zar + discretionary_expenses_zar + statutory_and_debt_zar, 4) AS total_comprehensive_outflows_zar,

  -- Net Comprehensive Cash Surplus & Savings Rate
  ROUND(gross_operating_revenue_zar - (operating_expenses_zar + living_essentials_zar + discretionary_expenses_zar + statutory_and_debt_zar), 4) AS net_cash_surplus_zar,
  ROUND(SAFE_DIVIDE(
    gross_operating_revenue_zar - (operating_expenses_zar + living_essentials_zar + discretionary_expenses_zar + statutory_and_debt_zar),
    gross_operating_revenue_zar
  ) * 100, 2) AS savings_rate_pct,

  vault_contributions_zar,

  -- USD Equivalents
  gross_operating_revenue_usd,
  operating_expenses_usd,
  ROUND(gross_operating_revenue_usd - operating_expenses_usd, 4) AS net_operating_income_usd,
  living_essentials_usd,
  discretionary_expenses_usd,
  statutory_and_debt_usd,
  ROUND(gross_operating_revenue_usd - (operating_expenses_usd + living_essentials_usd + discretionary_expenses_usd + statutory_and_debt_usd), 4) AS net_cash_surplus_usd,
  vault_contributions_usd

FROM unioned;

-- -----------------------------------------------------------------------------
-- 2. V_NON_OPERATING_GAINS_AND_YIELDS
-- Tracks interest yields from notice accounts, ETF dividend yields, and capital gains.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `personal_finance.v_non_operating_gains_and_yields` AS
WITH vault_positions AS (
  SELECT
    a.account_id,
    a.account_name,
    a.financial_institution,
    a.country_code,
    a.primary_currency,
    a.account_type,
    a.withdrawal_notice_days,
    COALESCE(SUM(t.original_amount), 0.0) AS current_vault_balance_native,
    COALESCE(SUM(t.reporting_amount_zar), 0.0) AS current_vault_balance_zar,
    COALESCE(SUM(t.reporting_amount_usd), 0.0) AS current_vault_balance_usd
  FROM `personal_finance.dim_accounts` AS a
  LEFT JOIN `personal_finance.fct_transactions` AS t
    ON a.account_id = t.account_id
  WHERE a.cash_flow_tier = 'LONG_TERM_VAULT'
  GROUP BY 1, 2, 3, 4, 5, 6, 7
)
SELECT
  v.account_id,
  v.account_name,
  v.financial_institution,
  v.country_code,
  v.primary_currency,
  v.account_type,
  v.withdrawal_notice_days,
  v.current_vault_balance_native,
  v.current_vault_balance_zar,
  v.current_vault_balance_usd,

  -- Modeled Statutory / Benchmark Yield Assumptions
  CASE 
    WHEN v.account_id = 'ACC_ZA_DISCOVERY_VAULT' THEN 'INTEREST_NOTICE_DEPOSIT'
    WHEN v.account_id = 'ACC_ZA_EE_EQUITIES_VAULT' THEN 'DIVIDENDS_AND_CAPITAL_GAINS'
    WHEN v.account_id IN ('ACC_ZW_OM_BALANCED_VAULT', 'ACC_ZW_OM_UNITTRUST_VAULT') THEN 'UNIT_TRUST_DISTRIBUTIONS'
    ELSE 'OTHER_NON_OPERATING_GAIN'
  END AS gain_classification,

  -- Annualized benchmark yields (SARB repo rate + spread, or S&P historical average)
  CASE
    WHEN v.account_id = 'ACC_ZA_DISCOVERY_VAULT' THEN 8.25 -- 8.25% SARB notice rate
    WHEN v.account_id = 'ACC_ZA_EE_EQUITIES_VAULT' THEN 10.50 -- 10.5% S&P 500 / JSE Top 40 expected total return
    WHEN v.account_id IN ('ACC_ZW_OM_BALANCED_VAULT', 'ACC_ZW_OM_UNITTRUST_VAULT') THEN 6.50 -- 6.5% USD balanced fund yield
    ELSE 5.00
  END AS annualized_yield_pct,

  -- Projected 30-day passive non-operating gain
  ROUND(v.current_vault_balance_zar * (
    CASE
      WHEN v.account_id = 'ACC_ZA_DISCOVERY_VAULT' THEN 0.0825
      WHEN v.account_id = 'ACC_ZA_EE_EQUITIES_VAULT' THEN 0.1050
      WHEN v.account_id IN ('ACC_ZW_OM_BALANCED_VAULT', 'ACC_ZW_OM_UNITTRUST_VAULT') THEN 0.0650
      ELSE 0.0500
    END
  ) / 12, 2) AS monthly_projected_gain_zar,

  ROUND(v.current_vault_balance_usd * (
    CASE
      WHEN v.account_id = 'ACC_ZA_DISCOVERY_VAULT' THEN 0.0825
      WHEN v.account_id = 'ACC_ZA_EE_EQUITIES_VAULT' THEN 0.1050
      WHEN v.account_id IN ('ACC_ZW_OM_BALANCED_VAULT', 'ACC_ZW_OM_UNITTRUST_VAULT') THEN 0.0650
      ELSE 0.0500
    END
  ) / 12, 2) AS monthly_projected_gain_usd

FROM vault_positions AS v;
