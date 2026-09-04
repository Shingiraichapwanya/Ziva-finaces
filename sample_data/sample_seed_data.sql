-- =============================================================================
-- BigQuery Schema: Personal Budget Tracker
-- Script: sample_seed_data.sql
-- Description: Realistic test dataset covering South African (ZAR) and
--              Zimbabwean (USD, ZiG) accounts, cross-tier transfers, and FX rates.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. SEED DIM_CURRENCIES
-- -----------------------------------------------------------------------------
INSERT INTO `personal_finance.dim_currencies` (currency_code, currency_name, country_code, symbol, decimal_places, is_active, notes)
VALUES
  ('ZAR', 'South African Rand', 'ZA', 'R', 2, TRUE, 'Legal tender in South Africa and Common Monetary Area'),
  ('USD', 'United States Dollar', 'US', '$', 2, TRUE, 'Dominant currency for pricing and Nostro FCA accounts in Zimbabwe'),
  ('ZiG', 'Zimbabwe Gold', 'ZW', 'ZiG', 2, TRUE, 'Structured currency backed by gold and foreign reserves introduced April 2024'),
  ('ZWL', 'Zimbabwean Dollar (Historical)', 'ZW', 'ZWL$', 2, FALSE, 'Decommissioned predecessor to ZiG');

-- -----------------------------------------------------------------------------
-- 2. SEED DIM_ACCOUNTS
-- -----------------------------------------------------------------------------
INSERT INTO `personal_finance.dim_accounts` (account_id, account_name, financial_institution, country_code, primary_currency, cash_flow_tier, account_type, is_vault_locked, withdrawal_notice_days, account_number_masked, is_active, created_at)
VALUES
  -- South Africa Accounts
  ('ACC_ZA_CAPITEC_DAILY', 'Capitec Primary Cheque', 'Capitec Bank', 'ZA', 'ZAR', 'DAILY_SPENDING', 'CHECKING', FALSE, 0, '...4091', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZA_FNB_MONTHLY', 'FNB Monthly Bills Fusion', 'First National Bank', 'ZA', 'ZAR', 'MONTHLY_ALLOCATION', 'CHECKING', FALSE, 0, '...8812', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZA_DISCOVERY_VAULT', 'Discovery 32-Day Notice Emergency', 'Discovery Bank', 'ZA', 'ZAR', 'LONG_TERM_VAULT', 'SAVINGS', TRUE, 32, '...1940', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZA_EE_EQUITIES_VAULT', 'EasyEquities S&P500 & Top40 TFSA', 'EasyEquities', 'ZA', 'ZAR', 'LONG_TERM_VAULT', 'INVESTMENT_BROKER', TRUE, 999, '...EE77', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),

  -- Zimbabwe Accounts
  ('ACC_ZW_STANBIC_NOSTRO', 'Stanbic Nostro FCA Bills', 'Stanbic Bank Zimbabwe', 'ZW', 'USD', 'MONTHLY_ALLOCATION', 'CHECKING', FALSE, 0, '...5521', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZW_ECOCASH_USD', 'EcoCash USD Wallet', 'EcoCash', 'ZW', 'USD', 'DAILY_SPENDING', 'MOBILE_MONEY', FALSE, 0, '...0772', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZW_ECOCASH_ZIG', 'EcoCash ZiG Wallet', 'EcoCash', 'ZW', 'ZiG', 'DAILY_SPENDING', 'MOBILE_MONEY', FALSE, 0, '...0772', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZW_INNBUCKS_USD', 'InnBucks USD Pocket', 'InnBucks Microfinance', 'ZW', 'USD', 'DAILY_SPENDING', 'MOBILE_MONEY', FALSE, 0, '...4311', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZW_OM_UNITTRUST_VAULT', 'Old Mutual USD Balanced Unit Trust', 'Old Mutual Zimbabwe', 'ZW', 'USD', 'LONG_TERM_VAULT', 'INVESTMENT_BROKER', TRUE, 14, '...OM09', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC');

-- -----------------------------------------------------------------------------
-- 3. SEED DIM_CATEGORIES
-- -----------------------------------------------------------------------------
INSERT INTO `personal_finance.dim_categories` (category_id, category_name, parent_category_id, category_group, cash_flow_tier, is_essential_need, is_tax_deductible, tax_line_item, description)
VALUES
  -- Income
  ('CAT_INC_SALARY', 'Consulting & Employment Income', NULL, 'INCOME', 'MONTHLY_ALLOCATION', FALSE, FALSE, 'TAXABLE_GROSS_INCOME', 'Primary monthly consulting retainer and professional earnings'),
  ('CAT_INC_DIVIDENDS', 'Investment Dividends', NULL, 'INCOME', 'LONG_TERM_VAULT', FALSE, FALSE, 'TAXABLE_INVESTMENT_INCOME', 'Quarterly dividends received on ETF holdings'),

  -- Daily Spending
  ('CAT_DAILY_GROCERIES', 'Groceries & Household Supplies', NULL, 'LIVING_EXPENSES', 'DAILY_SPENDING', TRUE, FALSE, 'NON_DEDUCTIBLE', 'Supermarket food and household consumables'),
  ('CAT_DAILY_DINING', 'Restaurants, Takeaways & Coffee', NULL, 'DISCRETIONARY', 'DAILY_SPENDING', FALSE, FALSE, 'NON_DEDUCTIBLE', 'Eating out, fast food, and barista coffee'),
  ('CAT_DAILY_FUEL_TRANS', 'Fuel, Uber & Commute', NULL, 'LIVING_EXPENSES', 'DAILY_SPENDING', TRUE, FALSE, 'NON_DEDUCTIBLE', 'Petrol purchases, Uber rides, and local travel'),
  ('CAT_DAILY_AIRTIME', 'Mobile Airtime & Bundles', NULL, 'LIVING_EXPENSES', 'DAILY_SPENDING', TRUE, FALSE, 'NON_DEDUCTIBLE', 'Data bundles and voice airtime (Vodacom, MTN, Econet)'),
  ('CAT_DAILY_INCIDENTAL', 'Micro-Cash & Incidentals', NULL, 'DISCRETIONARY', 'DAILY_SPENDING', FALSE, FALSE, 'NON_DEDUCTIBLE', 'Car guard tips, cash petty expenses, minor purchases'),

  -- Business Productivity Purchases (Tax Offsets)
  ('CAT_PROD_TECH_HARDWARE', 'Productivity Tech & Work Hardware', NULL, 'BUSINESS_PRODUCTIVITY', 'DAILY_SPENDING', FALSE, TRUE, 'PRODUCTIVITY_HARDWARE', 'Computers, displays, work desks, UPS/power, and mobile workstations for productivity'),
  ('CAT_PROD_SOFTWARE_TOOLS', 'Business Software, Cloud & AI Subscriptions', NULL, 'BUSINESS_PRODUCTIVITY', 'MONTHLY_ALLOCATION', FALSE, TRUE, 'BUSINESS_SOFTWARE', 'AI subscriptions (ChatGPT, Claude), GitHub, cloud infrastructure (GCP, AWS), IDEs, SaaS'),
  ('CAT_PROD_PROFESSIONAL_SERVICES', 'Professional Services & Compliance', NULL, 'BUSINESS_PRODUCTIVITY', 'MONTHLY_ALLOCATION', FALSE, TRUE, 'PROFESSIONAL_SERVICES', 'Accounting, tax preparation, bookkeeping, legal counsel, and business compliance filings'),

  -- Monthly Allocations & Statutory
  ('CAT_ALLOC_RENT', 'Residential Rent & Levies', NULL, 'LIVING_EXPENSES', 'MONTHLY_ALLOCATION', TRUE, FALSE, 'NON_DEDUCTIBLE', 'Monthly apartment or home rental payment'),
  ('CAT_ALLOC_MEDICAL', 'Medical Aid Scheme', NULL, 'LIVING_EXPENSES', 'MONTHLY_ALLOCATION', TRUE, FALSE, 'MEDICAL_TAX_CREDIT', 'Discovery Health / Cimas healthcare contribution'),
  ('CAT_ALLOC_ELECTRICITY', 'Pre-paid Power & Utility Tokens', NULL, 'LIVING_EXPENSES', 'MONTHLY_ALLOCATION', TRUE, FALSE, 'NON_DEDUCTIBLE', 'Eskom power vouchers and ZESA prepaid electricity tokens'),
  ('CAT_ALLOC_INTERNET', 'High-Speed Home Fibre', NULL, 'LIVING_EXPENSES', 'MONTHLY_ALLOCATION', TRUE, TRUE, 'HOME_OFFICE_DEDUCTION', 'Uncapped home fibre broadband connectivity for remote work'),
  ('CAT_ALLOC_INSURANCE', 'Short-Term Vehicle & Asset Cover', NULL, 'DEBT_OBLIGATIONS', 'MONTHLY_ALLOCATION', TRUE, FALSE, 'NON_DEDUCTIBLE', 'Car and contents insurance premium'),
  ('CAT_ALLOC_SUBSCRIPTIONS', 'Digital Subscriptions', NULL, 'DISCRETIONARY', 'MONTHLY_ALLOCATION', FALSE, FALSE, 'NON_DEDUCTIBLE', 'Streaming media (Netflix, Spotify)'),
  ('CAT_TAX_STATUTORY_PROVISIONAL', 'Provisional & Statutory Tax Payments', NULL, 'STATUTORY_OBLIGATIONS', 'MONTHLY_ALLOCATION', TRUE, FALSE, 'STATUTORY_TAX_PAYMENT', 'Provisional tax payments, PAYE top-ups, and corporate statutory remittances to SARS or ZIMRA'),

  -- Long-Term Vault
  ('CAT_VAULT_EMERGENCY', 'Liquid Emergency Reserve Fund', NULL, 'VAULT_INVESTMENTS', 'LONG_TERM_VAULT', TRUE, FALSE, 'NON_DEDUCTIBLE', 'Capital held for unforeseen financial emergencies (32-day notice)'),
  ('CAT_VAULT_GLOBAL_ETF', 'Offshore S&P 500 Index Equities', NULL, 'VAULT_INVESTMENTS', 'LONG_TERM_VAULT', FALSE, FALSE, 'CAPITAL_INVESTMENT', 'Compounding long-term retirement and passive capital build'),

  -- Internal Cash Flow Transfers
  ('CAT_INTERNAL_SWEEP', 'Cross-Tier Capital Allocation Transfer', NULL, 'INTERNAL_TRANSFERS', 'CROSS_TIER_TRANSFER', FALSE, FALSE, 'INTERNAL_TRANSFER', 'Transfer legs moving money between Daily, Monthly, and Vault');

-- -----------------------------------------------------------------------------
-- 4. SEED FCT_EXCHANGE_RATES
-- Realistic rates for September 2026
-- -----------------------------------------------------------------------------
INSERT INTO `personal_finance.fct_exchange_rates` (rate_date, rate_timestamp, base_currency, quote_currency, rate_type, exchange_rate, inverse_rate, source_provider, notes)
VALUES
  -- USD to ZAR
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'USD', 'ZAR', 'OFFICIAL_INTERBANK', 18.250000, 0.054795, 'SARB', 'South African Reserve Bank daily closing mid-market rate'),
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'USD', 'ZAR', 'CARD_SETTLEMENT', 18.615000, 0.053720, 'Visa / MasterCard', 'Retail commercial card swipe foreign transaction rate with 2% margin'),

  -- USD to ZiG (Official vs Parallel)
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'USD', 'ZiG', 'OFFICIAL_INTERBANK', 13.850000, 0.072202, 'Reserve Bank of Zimbabwe', 'Official interbank weighted exchange rate for ZiG'),
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'USD', 'ZiG', 'MARKET_PARALLEL', 24.500000, 0.040816, 'ZimMarket Index', 'Alternative street cash rate reflecting open retail trading premium'),

  -- ZAR to ZiG
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'ZAR', 'ZiG', 'OFFICIAL_INTERBANK', 0.758900, 1.317697, 'RBZ Cross Rate', 'Cross rate calculated via official USD mid-point'),
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'ZAR', 'ZiG', 'MARKET_PARALLEL', 1.342466, 0.744900, 'ZimMarket Index', 'Border cash trading rate at Beitbridge');

-- -----------------------------------------------------------------------------
-- 5. SEED FCT_BUDGET_ALLOCATIONS (Month of September 2026)
-- -----------------------------------------------------------------------------
INSERT INTO `personal_finance.fct_budget_allocations` (allocation_month, category_id, cash_flow_tier, target_currency, planned_amount, planned_amount_usd, planned_amount_zar, rollover_from_prior, is_fixed_obligation, notes)
VALUES
  -- South African Monthly Fixed Allocations
  (DATE '2026-09-01', 'CAT_ALLOC_RENT', 'MONTHLY_ALLOCATION', 'ZAR', 14500.0000, 794.5205, 14500.0000, 0.0000, TRUE, 'Apartment lease debit order'),
  (DATE '2026-09-01', 'CAT_ALLOC_MEDICAL', 'MONTHLY_ALLOCATION', 'ZAR', 3850.0000, 210.9589, 3850.0000, 0.0000, TRUE, 'Discovery Classic Comprehensive Plan'),
  (DATE '2026-09-01', 'CAT_ALLOC_ELECTRICITY', 'MONTHLY_ALLOCATION', 'ZAR', 1800.0000, 98.6301, 1800.0000, 150.0000, TRUE, 'Eskom prepaid electricity envelope'),
  (DATE '2026-09-01', 'CAT_ALLOC_INTERNET', 'MONTHLY_ALLOCATION', 'ZAR', 999.0000, 54.7397, 999.0000, 0.0000, TRUE, 'Openserve 100/50 Fibre debit order'),
  (DATE '2026-09-01', 'CAT_ALLOC_INSURANCE', 'MONTHLY_ALLOCATION', 'ZAR', 1250.0000, 68.4932, 1250.0000, 0.0000, TRUE, 'Outsurance Comprehensive vehicle cover'),
  (DATE '2026-09-01', 'CAT_ALLOC_SUBSCRIPTIONS', 'MONTHLY_ALLOCATION', 'ZAR', 550.0000, 30.1370, 550.0000, 0.0000, FALSE, 'Netflix & Spotify family plans'),
  (DATE '2026-09-01', 'CAT_PROD_SOFTWARE_TOOLS', 'MONTHLY_ALLOCATION', 'ZAR', 1500.0000, 82.1918, 1500.0000, 0.0000, TRUE, 'ChatGPT Team, Claude Pro, and GitHub developer tools'),
  (DATE '2026-09-01', 'CAT_TAX_STATUTORY_PROVISIONAL', 'MONTHLY_ALLOCATION', 'ZAR', 12000.0000, 657.5342, 12000.0000, 0.0000, TRUE, 'Quarterly provisional tax payment reserve'),

  -- Zimbabwean Monthly Fixed Allocations (Paid from Nostro USD)
  (DATE '2026-09-01', 'CAT_ALLOC_ELECTRICITY', 'MONTHLY_ALLOCATION', 'USD', 120.0000, 120.0000, 2190.0000, 20.0000, TRUE, 'ZESA token purchase via Nostro card'),

  -- Daily Spending Operational Envelopes
  (DATE '2026-09-01', 'CAT_DAILY_GROCERIES', 'DAILY_SPENDING', 'ZAR', 6500.0000, 356.1644, 6500.0000, 450.0000, FALSE, 'Woolworths / Checkers grocery envelope'),
  (DATE '2026-09-01', 'CAT_DAILY_DINING', 'DAILY_SPENDING', 'ZAR', 2500.0000, 136.9863, 2500.0000, 0.0000, FALSE, 'Social dining and takeaways'),
  (DATE '2026-09-01', 'CAT_DAILY_FUEL_TRANS', 'DAILY_SPENDING', 'ZAR', 3000.0000, 164.3836, 3000.0000, 0.0000, FALSE, 'Petrol allowance'),
  (DATE '2026-09-01', 'CAT_DAILY_AIRTIME', 'DAILY_SPENDING', 'USD', 50.0000, 50.0000, 912.5000, 0.0000, FALSE, 'EcoCash data bundles'),

  -- Monthly Long-Term Vault Targets
  (DATE '2026-09-01', 'CAT_VAULT_GLOBAL_ETF', 'LONG_TERM_VAULT', 'ZAR', 8000.0000, 438.3562, 8000.0000, 0.0000, FALSE, 'Target monthly transfer into EasyEquities S&P500'),
  (DATE '2026-09-01', 'CAT_VAULT_EMERGENCY', 'LONG_TERM_VAULT', 'ZAR', 3000.0000, 164.3836, 3000.0000, 0.0000, FALSE, 'Target top-up for 32-day emergency runway');

-- -----------------------------------------------------------------------------
-- 6. SEED FCT_TRANSACTIONS (Ledger Entries across Tiers)
-- -----------------------------------------------------------------------------
INSERT INTO `personal_finance.fct_transactions` (
  transaction_id, transaction_timestamp, transaction_date, local_timezone, local_timestamp, settlement_timestamp,
  account_id, cash_flow_tier, category_id, transaction_type,
  original_amount, original_currency, reporting_amount_usd, reporting_amount_zar,
  applied_exchange_rate_usd, applied_exchange_rate_zar, rate_type_applied,
  transfer_counterpart_id, merchant_or_payee, payment_method, statutory_levy_or_fee,
  is_tax_deductible, tax_deductible_amount_zar, tax_deductible_amount_usd, tax_invoice_number,
  notes, tags, metadata
)
VALUES
  -- 1. Inflow: Monthly Consulting Salary into FNB Monthly Staging Account
  (
    'TX_ZA_20260901_001', TIMESTAMP '2026-09-01 06:15:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 08:15:00', TIMESTAMP '2026-09-01 06:15:00 UTC',
    'ACC_ZA_FNB_MONTHLY', 'MONTHLY_ALLOCATION', 'CAT_INC_SALARY', 'INCOME',
    55000.0000, 'ZAR', 3013.6986, 55000.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    NULL, 'Apex Consulting Client Pty Ltd', 'EFT', NULL,
    FALSE, 0.0000, 0.0000, 'INV-2026-089',
    'Monthly tech consulting retainer fee', ['income', 'salary', 'taxable'], JSON '{"client_ref": "INV-2026-089"}'
  ),

  -- 2. Internal Transfer: Sweep funds from FNB Monthly into Capitec Daily Operational Account (Leg 1: Outflow)
  (
    'TX_ZA_20260901_SWEEP_OUT', TIMESTAMP '2026-09-01 07:00:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 09:00:00', TIMESTAMP '2026-09-01 07:00:00 UTC',
    'ACC_ZA_FNB_MONTHLY', 'MONTHLY_ALLOCATION', 'CAT_INTERNAL_SWEEP', 'INTERNAL_TRANSFER',
    -12000.0000, 'ZAR', -657.5342, -12000.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    'TX_ZA_20260901_SWEEP_IN', 'Capitec Daily Account', 'EFT', 2.5000, 'Monthly operational allowance transfer to Daily Checking', ['transfer', 'daily-allowance'], JSON '{"eft_type": "RTC_PAYSHAP"}'
  ),

  -- 2b. Internal Transfer: Complementary Leg (Leg 2: Inflow into Capitec Daily)
  (
    'TX_ZA_20260901_SWEEP_IN', TIMESTAMP '2026-09-01 07:01:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 09:01:00', TIMESTAMP '2026-09-01 07:01:00 UTC',
    'ACC_ZA_CAPITEC_DAILY', 'DAILY_SPENDING', 'CAT_INTERNAL_SWEEP', 'INTERNAL_TRANSFER',
    12000.0000, 'ZAR', 657.5342, 12000.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    'TX_ZA_20260901_SWEEP_OUT', 'FNB Monthly Account', 'EFT', NULL, 'Monthly operational allowance received', ['transfer', 'daily-allowance'], JSON '{"received_channel": "PAYSHAP"}'
  ),

  -- 3. Capital Injection into Long-Term Vault: EasyEquities Investment Transfer (Leg 1: Outflow from FNB)
  (
    'TX_ZA_20260901_VAULT_OUT', TIMESTAMP '2026-09-01 07:30:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 09:30:00', TIMESTAMP '2026-09-01 07:30:00 UTC',
    'ACC_ZA_FNB_MONTHLY', 'MONTHLY_ALLOCATION', 'CAT_INTERNAL_SWEEP', 'VAULT_CONTRIBUTION',
    -8000.0000, 'ZAR', -438.3562, -8000.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    'TX_ZA_20260901_VAULT_IN', 'EasyEquities Brokerage Vault', 'EFT', NULL, 'Vault contribution towards S&P500 ETF', ['vault', 'investments'], JSON '{"beneficiary_ref": "EE-INVEST-77"}'
  ),

  -- 3b. Long-Term Vault Deposit (Leg 2: Inflow into EasyEquities Vault Account)
  (
    'TX_ZA_20260901_VAULT_IN', TIMESTAMP '2026-09-01 07:35:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 09:35:00', TIMESTAMP '2026-09-01 07:35:00 UTC',
    'ACC_ZA_EE_EQUITIES_VAULT', 'LONG_TERM_VAULT', 'CAT_VAULT_GLOBAL_ETF', 'VAULT_CONTRIBUTION',
    8000.0000, 'ZAR', 438.3562, 8000.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    'TX_ZA_20260901_VAULT_OUT', 'FNB Monthly Transfer', 'EFT', NULL, 'Long-term equity vault deposit: 10x 1nvest S&P500 Info Tech ETF units', ['vault', 'investments'], JSON '{"units_purchased": 10.45}'
  ),

  -- 4. Monthly Fixed Allocation Debit: Rent Payment
  (
    'TX_ZA_20260901_RENT', TIMESTAMP '2026-09-01 08:00:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 10:00:00', TIMESTAMP '2026-09-01 08:00:00 UTC',
    'ACC_ZA_FNB_MONTHLY', 'MONTHLY_ALLOCATION', 'CAT_ALLOC_RENT', 'EXPENSE',
    -14500.0000, 'ZAR', -794.5205, -14500.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    NULL, 'Trafalgar Property Management', 'DIRECT_DEBIT', NULL, 'Cape Town Apartment Rental September 2026', ['fixed-bill', 'rent'], JSON '{"unit": "Apt 402"}'
  ),

  -- 5. Monthly Fixed Allocation Debit: Discovery Health Medical Aid
  (
    'TX_ZA_20260901_MED', TIMESTAMP '2026-09-01 08:05:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 10:05:00', TIMESTAMP '2026-09-01 08:05:00 UTC',
    'ACC_ZA_FNB_MONTHLY', 'MONTHLY_ALLOCATION', 'CAT_ALLOC_MEDICAL', 'EXPENSE',
    -3850.0000, 'ZAR', -210.9589, -3850.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    NULL, 'Discovery Health Scheme', 'DIRECT_DEBIT', NULL, 'Monthly medical aid premium debit', ['medical', 'fixed-bill'], JSON '{"membership_no": "99281726"}'
  ),

  -- 6. Daily Spending Expense (South Africa): Woolworths Food Groceries
  (
    'TX_ZA_20260902_001', TIMESTAMP '2026-09-02 11:30:00 UTC', DATE '2026-09-02', 'Africa/Johannesburg', DATETIME '2026-09-02 13:30:00', TIMESTAMP '2026-09-02 11:30:00 UTC',
    'ACC_ZA_CAPITEC_DAILY', 'DAILY_SPENDING', 'CAT_DAILY_GROCERIES', 'EXPENSE',
    -845.5000, 'ZAR', -46.3288, -845.5000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    NULL, 'Woolworths Food Gardens Centre', 'DEBIT_CARD', NULL, 'Weekly organic groceries and essentials', ['groceries', 'food'], JSON '{"pos_terminal": "W-GARDENS-04"}'
  ),

  -- 7. Daily Spending Expense (South Africa): Vida e Caffe
  (
    'TX_ZA_20260902_002', TIMESTAMP '2026-09-02 13:45:00 UTC', DATE '2026-09-02', 'Africa/Johannesburg', DATETIME '2026-09-02 15:45:00', TIMESTAMP '2026-09-02 13:45:00 UTC',
    'ACC_ZA_CAPITEC_DAILY', 'DAILY_SPENDING', 'CAT_DAILY_DINING', 'EXPENSE',
    -78.0000, 'ZAR', -4.2740, -78.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    NULL, 'Vida e Caffe Kloof St', 'DEBIT_CARD', NULL, 'Cappuccino and croissant', ['coffee', 'discretionary'], NULL
  ),

  -- 8. Daily Spending Expense (Zimbabwe): EcoCash USD Grocery at OK Mart Harare
  (
    'TX_ZW_20260902_001', TIMESTAMP '2026-09-02 14:10:00 UTC', DATE '2026-09-02', 'Africa/Harare', DATETIME '2026-09-02 16:10:00', TIMESTAMP '2026-09-02 14:10:00 UTC',
    'ACC_ZW_ECOCASH_USD', 'DAILY_SPENDING', 'CAT_DAILY_GROCERIES', 'EXPENSE',
    -62.4000, 'USD', -62.4000, -1138.8000, 1.000000, 18.250000, 'OFFICIAL_INTERBANK',
    NULL, 'OK Mart Chitungwiza Junction', 'MOBILE_MONEY_ECOCASH', 1.2500, 'Bulk pantry groceries in Harare', ['groceries', 'zimbabwe'], JSON '{"ecocash_ref": "MP260902.1610.B91823", "merchant_code": "29100"}'
  ),

  -- 9. Daily Spending Expense (Zimbabwe): InnBucks USD Takeaway at Bakers Inn
  (
    'TX_ZW_20260902_002', TIMESTAMP '2026-09-02 16:20:00 UTC', DATE '2026-09-02', 'Africa/Harare', DATETIME '2026-09-02 18:20:00', TIMESTAMP '2026-09-02 16:20:00 UTC',
    'ACC_ZW_INNBUCKS_USD', 'DAILY_SPENDING', 'CAT_DAILY_DINING', 'EXPENSE',
    -9.5000, 'USD', -9.5000, -173.3750, 1.000000, 18.250000, 'OFFICIAL_INTERBANK',
    NULL, 'Simbisa Bakers Inn First St', 'MOBILE_MONEY_INNBUCKS', NULL, 'Family meat pies and juices', ['dining', 'fast-food'], JSON '{"innbucks_qr_auth": "IB-8827-01"}'
  ),

  -- 10. Daily Spending in Local Zimbabwe Gold (ZiG): Econet Airtime via EcoCash ZiG
  -- Converted using the Parallel Market Rate (24.50 ZiG/USD) to reflect genuine economic cost!
  (
    'TX_ZW_20260902_003', TIMESTAMP '2026-09-02 17:00:00 UTC', DATE '2026-09-02', 'Africa/Harare', DATETIME '2026-09-02 19:00:00', TIMESTAMP '2026-09-02 17:00:00 UTC',
    'ACC_ZW_ECOCASH_ZIG', 'DAILY_SPENDING', 'CAT_DAILY_AIRTIME', 'EXPENSE',
    -245.0000, 'ZiG', -10.0000, -182.5000, 0.040816, 0.744898, 'MARKET_PARALLEL',
    NULL, 'Econet Wireless Zimbabwe', 'MOBILE_MONEY_ECOCASH', 4.9000, 'Monthly 15GB SmartBiz WhatsApp and data bundle', ['data', 'airtime'], JSON '{"bundle_type": "SmartBiz_Weekly"}'
  ),

  -- 11. Monthly Allocation Expense (Zimbabwe): ZESA Electricity Prepaid Token via Stanbic Nostro
  (
    'TX_ZW_20260902_004', TIMESTAMP '2026-09-02 18:00:00 UTC', DATE '2026-09-02', 'Africa/Harare', DATETIME '2026-09-02 20:00:00', TIMESTAMP '2026-09-02 18:00:00 UTC',
    'ACC_ZW_STANBIC_NOSTRO', 'MONTHLY_ALLOCATION', 'CAT_ALLOC_ELECTRICITY', 'EXPENSE',
    -100.0000, 'USD', -100.0000, -1825.0000, 1.000000, 18.250000, 'OFFICIAL_INTERBANK',
    NULL, 'ZETDC / ZESA Power Distribution', 'DEBIT_CARD', 2.0000, 'Prepaid power token 350 kWh for Harare residence', ['utilities', 'electricity'], JSON '{"token": "4920-1928-3819-4829-1029", "kwh": 350.2}'
  ),

  -- 12. Long-Term Vault Deposit (Zimbabwe): Old Mutual USD Unit Trust
  (
    'TX_ZW_20260902_005', TIMESTAMP '2026-09-02 18:30:00 UTC', DATE '2026-09-02', 'Africa/Harare', DATETIME '2026-09-02 20:30:00', TIMESTAMP '2026-09-02 18:30:00 UTC',
    'ACC_ZW_OM_UNITTRUST_VAULT', 'LONG_TERM_VAULT', 'CAT_VAULT_GLOBAL_ETF', 'VAULT_CONTRIBUTION',
    250.0000, 'USD', 250.0000, 4562.5000, 1.000000, 18.250000, 'OFFICIAL_INTERBANK',
    NULL, 'Old Mutual Unit Trust Allocation', 'EFT', NULL, 'Offshore balanced fund accumulation deposit', ['vault', 'investments'], JSON '{"nav_per_unit": 1.452, "units_added": 172.17}'
  );
