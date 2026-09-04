# BigQuery Personal Budget Tracker (Multi-Tier & Southern African Multi-Currency)

A production-grade Google BigQuery data warehouse schema and analytics suite designed for personal financial management. It cleanly segregates **Daily Spending**, **Monthly Allocations**, and a **Long-Term Vault**, with native handling for multi-currency cash flows across **South Africa (ZAR)** and **Zimbabwe (USD, ZiG, dual exchange rates)**.

---

## Architecture Overview

```
                                  ┌────────────────────────┐
                                  │ Monthly Income Inflows │
                                  │ (Salary, Retainers)    │
                                  └───────────┬────────────┘
                                              │
                      ┌───────────────────────┼───────────────────────┐
                      ▼                       ▼                       ▼
           ┌──────────────────────┐┌──────────────────────┐┌──────────────────────┐
           │ Tier 1: Daily Spend  ││ Tier 2: Monthly Alloc││ Tier 3: Vault        │
           ├──────────────────────┤├──────────────────────┤├──────────────────────┤
           │ • Capitec Cheque     ││ • Fixed Rent/Bond    ││ • EasyEquities ETF   │
           │ • EcoCash USD/ZiG    ││ • Medical Aid        ││ • 32-Day Notice Fund │
           │ • InnBucks Pocket    ││ • Prepaid Power      ││ • Old Mutual Units   │
           │ • Cash Petty Wallet  ││ • Subscriptions      ││ • Offshore Reserves  │
           └──────────────────────┘└──────────────────────┘└──────────────────────┘
```

### Three-Tier Cash Flow Segregation

| Tier | Purpose | Velocity | Accounts Supported |
| :--- | :--- | :--- | :--- |
| **`DAILY_SPENDING`** | High-frequency operational expenses (groceries, dining, coffee, fuel, mobile data). | Daily / Multiple per day | Capitec Cheque, EcoCash USD/ZiG, InnBucks, Cash |
| **`MONTHLY_ALLOCATION`** | Staging accounts and budget envelopes for fixed contractual bills and planned sinking funds (rent, medical aid, WiFi, power tokens). | Month-end / Scheduled | FNB Fusion, Stanbic Nostro FCA, Dedicated Bill Accounts |
| **`LONG_TERM_VAULT`** | Wealth preservation, emergency reserves, and compounding investments. Protected from impulsive day-to-day spending. | Inflows: Monthly; Outflows: Rare | EasyEquities TFSA/USD, Discovery 32-Day Notice, Old Mutual Balanced Unit Trusts |

---

## Southern African Multi-Currency Engine

### 1. South Africa Context
- **Base Currency**: `ZAR` (South African Rand).
- **Institutions**: Capitec, FNB, Discovery Bank, Standard Bank, Nedbank, EasyEquities.
- **FX Needs**: Automated cross-currency conversion from ZAR to USD for offshore investments (S&P 500 ETFs) and digital subscriptions (Netflix, GitHub).

### 2. Zimbabwe Context
- **Multi-Currency Environment**: Zimbabwe operates a multi-currency system dominated by **USD** (cash, Nostro accounts, InnBucks, EcoCash USD) alongside **ZiG** (Zimbabwe Gold, introduced in 2024 to replace ZWL).
- **Dual Exchange Rate Regimes**:
  - `OFFICIAL_INTERBANK`: The Reserve Bank of Zimbabwe (RBZ) official interbank weighted average.
  - `MARKET_PARALLEL`: The retail/street market rate, which reflects genuine economic purchasing power and cash premiums.
  - `CARD_SETTLEMENT`: Commercial swipe POS clearing rates with statutory 2% Intermediated Money Transfer Tax (`statutory_levy_or_fee`).
- **Traceability**: The `fct_transactions` table records both `original_amount` + `original_currency` and pre-computed conversions into **both USD and ZAR**, explicitly storing `applied_exchange_rate_usd`, `applied_exchange_rate_zar`, and `rate_type_applied`.

---

## Schema Files & Directory Structure

```
personal-budget-tracker-bigquery/
├── ddl/
│   ├── 01_dimensions.sql        # dim_currencies, dim_accounts, dim_categories
│   ├── 02_exchange_rates.sql     # fct_exchange_rates (Partitioned & Clustered)
│   ├── 03_transactions.sql       # fct_transactions (Primary ledger, Partitioned & Clustered)
│   ├── 04_monthly_allocations.sql# fct_budget_allocations (Monthly envelope targets)
│   └── 05_reporting_views.sql    # Analytical views (Daily burn rate, Budget vs Actual, Vault)
├── sample_data/
│   └── sample_seed_data.sql      # Seed dataset with realistic ZA & ZW financial events
├── queries/
│   └── analytical_queries.sql    # Ready-to-run queries for daily burn, budget variance, and audits
└── README.md                     # Architecture guide and usage documentation
```

---

## BigQuery Optimization Best Practices Applied

1. **Partitioning**:
   - `fct_transactions` is `PARTITION BY transaction_date`. When querying specific date ranges (e.g. current month or last 30 days), BigQuery prunes unneeded partitions, reducing query costs and query runtime.
   - `fct_exchange_rates` is `PARTITION BY rate_date`.
   - `fct_budget_allocations` is `PARTITION BY allocation_month`.
2. **Clustering**:
   - `fct_transactions` is `CLUSTER BY cash_flow_tier, account_id, category_id`. Queries filtering on a specific tier (e.g., `WHERE cash_flow_tier = 'DAILY_SPENDING'`) skip non-relevant storage blocks.
3. **Data Type Precision**:
   - Financial amounts use `NUMERIC(18, 4)` and exchange rates use `NUMERIC(18, 6)`. Floating-point (`FLOAT64`) is prohibited to prevent binary floating-point representation errors in accounting reconciliations.
4. **Early Aggregation in Views**:
   - Views (`v_daily_spending_burn_rate`, `v_monthly_budget_vs_actual`) perform `SUM(...)` and `GROUP BY` on the transaction table *before* joining dimension tables to minimize shuffle and memory usage.
5. **Transfer Integrity**:
   - Internal transfers (e.g., funding Daily Checking from Monthly Staging, or sending funds to the Vault) record complementary legs linked by `transfer_counterpart_id` to ensure double-entry balance verification.

---

## Quickstart: Deploying to BigQuery

### Step 1: Create the Dataset
In Google Cloud BigQuery Studio or using the `bq` CLI:
```bash
bq mk --location=africa-south1 --dataset personal_finance
```
*(You can use `africa-south1` for Johannesburg, or `US` / `EU` as preferred).*

### Step 2: Run DDL Scripts in Order
Execute the scripts sequentially:
1. `ddl/01_dimensions.sql`
2. `ddl/02_exchange_rates.sql`
3. `ddl/03_transactions.sql`
4. `ddl/04_monthly_allocations.sql`
5. `ddl/05_reporting_views.sql`

### Step 3: Load Seed Data
Run `sample_data/sample_seed_data.sql` to populate initial accounts, categories, FX rates, and test transactions.

### Step 4: Run Analytical Queries
Run queries from `queries/analytical_queries.sql` to view:
- **Daily spending velocity** and 7-day rolling average spend.
- **Budget vs. Actual envelope variance** with automated `OVER_BUDGET` / `NEAR_LIMIT` warning flags.
- **Vault net worth accumulation** across accounts.
- **Zimbabwe parallel rate distortion analysis**.
