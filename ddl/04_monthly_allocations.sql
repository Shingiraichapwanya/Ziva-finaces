-- =============================================================================
-- BigQuery Schema: Personal Budget Tracker
-- Script: 04_monthly_allocations.sql
-- Description: Budget allocation targets, monthly envelopes, and sinking funds.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FCT_BUDGET_ALLOCATIONS
-- Monthly budgeted capital allocation per category and cash flow tier.
-- Enables Zero-Based Budgeting (ZBB) and envelope comparison against actuals.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `personal_finance.fct_budget_allocations` (
  allocation_month        DATE NOT NULL OPTIONS(description="First day of the budget month, e.g. 2026-09-01"),
  category_id             STRING NOT NULL OPTIONS(description="Foreign key to dim_categories"),
  cash_flow_tier          STRING NOT NULL OPTIONS(description="Cash flow designation: 'DAILY_SPENDING', 'MONTHLY_ALLOCATION', or 'LONG_TERM_VAULT'"),
  target_currency         STRING NOT NULL OPTIONS(description="Budgeted currency code (e.g. ZAR, USD)"),
  
  -- Budget Amounts
  planned_amount          NUMERIC(18, 4) NOT NULL OPTIONS(description="Planned allocation amount in target_currency"),
  planned_amount_usd      NUMERIC(18, 4) NOT NULL OPTIONS(description="Planned allocation converted to USD for unified reporting"),
  planned_amount_zar      NUMERIC(18, 4) NOT NULL OPTIONS(description="Planned allocation converted to ZAR for unified reporting"),
  rollover_from_prior     NUMERIC(18, 4) DEFAULT 0.0000 NOT NULL OPTIONS(description="Unspent surplus or deficit carried over from the prior month envelope"),
  
  -- Commitment Profile
  is_fixed_obligation     BOOL NOT NULL OPTIONS(description="True for non-negotiable monthly expenses (Rent, Medical Aid, Fixed Insurance); False for flexible sinking funds"),
  notes                   STRING OPTIONS(description="Notes regarding seasonal adjustments, price hikes, or targets")
)
PARTITION BY allocation_month
CLUSTER BY cash_flow_tier, category_id
OPTIONS(
  description = "Monthly budget targets across envelopes, operational daily spending allocations, and long-term vault contributions."
);
