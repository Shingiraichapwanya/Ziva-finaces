-- =============================================================================
-- BigQuery Schema: Personal Budget Tracker
-- Script: 01_dimensions.sql
-- Description: Master dimension tables for Currencies, Accounts, and Categories.
-- =============================================================================

-- Create dataset if not exists (User can customize dataset name e.g. `personal_finance`)
-- CREATE SCHEMA IF NOT EXISTS `personal_finance`
-- OPTIONS(
--   location = 'africa-south1', -- e.g. Google Cloud Johannesburg region, or 'US' / 'EU'
--   description = 'Personal budget tracking data warehouse for Southern African multi-currency cash flows'
-- );

-- -----------------------------------------------------------------------------
-- 1. DIM_CURRENCIES
-- Reference table of ISO 4217 currencies and regional legal tender / mobile units.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `personal_finance.dim_currencies` (
  currency_code       STRING NOT NULL OPTIONS(description="ISO code or regional currency identifier, e.g. ZAR, USD, ZiG"),
  currency_name       STRING NOT NULL OPTIONS(description="Full name of the currency"),
  country_code        STRING NOT NULL OPTIONS(description="ISO Alpha-2 country code primarily associated (e.g. ZA, ZW, US)"),
  symbol              STRING NOT NULL OPTIONS(description="Display symbol (e.g. R, $, ZiG)"),
  decimal_places      INT64 NOT NULL OPTIONS(description="Standard decimal places (usually 2, or 4 for micro-transactions)"),
  is_active           BOOL NOT NULL OPTIONS(description="Whether the currency is currently actively transacted"),
  notes               STRING OPTIONS(description="Contextual notes e.g. Zimbabwe Gold introduced April 2024 replacing ZWL")
)
CLUSTER BY currency_code
OPTIONS(
  description = "Dimension table containing supported currencies for South African and Zimbabwean accounts."
);

-- -----------------------------------------------------------------------------
-- 2. DIM_ACCOUNTS
-- Master register of all financial accounts, split into cash flow tiers.
--
-- Cash Flow Tiers:
--  - 'DAILY_SPENDING': High-velocity operational accounts (cheque/checking, day-to-day debit cards, mobile wallets)
--  - 'MONTHLY_ALLOCATION': Staging/envelope accounts for fixed & scheduled commitments (rent, utilities, medical aid)
--  - 'LONG_TERM_VAULT': Protected capital (emergency reserves, 32-day notices, unit trusts, ETFs, offshore assets)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `personal_finance.dim_accounts` (
  account_id              STRING NOT NULL OPTIONS(description="Unique identifier for the account (e.g. ACC_CAPITEC_DAILY_01)"),
  account_name            STRING NOT NULL OPTIONS(description="User-friendly account label (e.g. Capitec Main Cheque)"),
  financial_institution   STRING NOT NULL OPTIONS(description="Bank or fintech provider (e.g. FNB, Capitec, Stanbic Bank, EcoCash, InnBucks, EasyEquities)"),
  country_code            STRING NOT NULL OPTIONS(description="Country where account is domiciled: 'ZA' or 'ZW'"),
  primary_currency        STRING NOT NULL OPTIONS(description="Base currency for this account (e.g. ZAR, USD, ZiG)"),
  cash_flow_tier          STRING NOT NULL OPTIONS(description="Cash flow designation: 'DAILY_SPENDING', 'MONTHLY_ALLOCATION', or 'LONG_TERM_VAULT'"),
  account_type            STRING NOT NULL OPTIONS(description="Account category: 'CHECKING', 'SAVINGS', 'MOBILE_MONEY', 'INVESTMENT_BROKER', 'RETIREMENT_PRESERVATION', 'PHYSICAL_CASH', 'CREDIT_CARD'"),
  is_vault_locked         BOOL NOT NULL OPTIONS(description="True if account is in the Long-Term Vault with locked/notice terms preventing impulsive daily spending"),
  withdrawal_notice_days  INT64 OPTIONS(description="Notice period required for withdrawals (e.g. 0 for instant, 32 for notice deposits, 999 for locked retirement)"),
  account_number_masked   STRING OPTIONS(description="Last 4 digits or masked identifier for statement reconciliation"),
  is_active               BOOL NOT NULL OPTIONS(description="Active status of the account"),
  created_at              TIMESTAMP NOT NULL OPTIONS(description="Record creation timestamp in UTC")
)
CLUSTER BY cash_flow_tier, country_code, primary_currency
OPTIONS(
  description = "Master accounts dimension with explicit segregation into Daily Spending, Monthly Allocation, and Vault."
);

-- -----------------------------------------------------------------------------
-- 3. DIM_CATEGORIES
-- Hierarchical taxonomy of income, expenses, allocations, and vault capital transfers.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `personal_finance.dim_categories` (
  category_id             STRING NOT NULL OPTIONS(description="Unique category identifier (e.g. CAT_GROCERIES, CAT_RENT, CAT_VAULT_ETF)"),
  category_name           STRING NOT NULL OPTIONS(description="Human-readable category name"),
  parent_category_id      STRING OPTIONS(description="Parent category ID for hierarchical aggregation (e.g. Food & Dining -> Groceries)"),
  category_group          STRING NOT NULL OPTIONS(description="High-level category grouping: 'INCOME', 'LIVING_EXPENSES', 'DEBT_OBLIGATIONS', 'DISCRETIONARY', 'VAULT_INVESTMENTS', 'INTERNAL_TRANSFERS'"),
  cash_flow_tier          STRING NOT NULL OPTIONS(description="Target tier: 'DAILY_SPENDING', 'MONTHLY_ALLOCATION', 'LONG_TERM_VAULT', or 'CROSS_TIER_TRANSFER'"),
  is_essential_need       BOOL NOT NULL OPTIONS(description="True for 50/30/20 'Needs' (e.g. shelter, food, basic electricity, medical aid); False for 'Wants'"),
  is_tax_deductible       BOOL NOT NULL OPTIONS(description="True if expenses in this category qualify for business tax deduction or tax credits"),
  tax_line_item           STRING OPTIONS(description="Tax schedule/return line item classification e.g. 'PRODUCTIVITY_HARDWARE', 'BUSINESS_SOFTWARE', 'PROFESSIONAL_SERVICES', 'STATUTORY_TAX_PAYMENT', 'NON_DEDUCTIBLE'"),
  description             STRING OPTIONS(description="Detailed scope of expenses/flows belonging to this category")
)
CLUSTER BY category_group, cash_flow_tier
OPTIONS(
  description = "Hierarchical budget category dimension classifying expenses into essentials, discretionary, business tax offsets, and capital transfers."
);
