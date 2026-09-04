-- =============================================================================
-- BigQuery Schema: Personal Budget Tracker
-- Script: 02_exchange_rates.sql
-- Description: Historical and daily exchange rates for multi-currency conversion.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FCT_EXCHANGE_RATES
-- Point-in-time exchange rates with multi-rate regime support (Official vs. Parallel).
--
-- Supported Rate Types:
--  - 'OFFICIAL_INTERBANK': Central Bank / Interbank rate (e.g. SARB for ZAR, RBZ for ZiG/USD)
--  - 'MARKET_PARALLEL': Parallel / Street / Retail market rate (essential for true purchasing power in Zimbabwe)
--  - 'CARD_SETTLEMENT': Commercial bank card clearing rate (including bank margins)
--  - 'BUREAU_DE_CHANGE': Formal bureau de change cash exchange rate
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `personal_finance.fct_exchange_rates` (
  rate_date           DATE NOT NULL OPTIONS(description="Calendar date of the exchange rate quotation"),
  rate_timestamp      TIMESTAMP NOT NULL OPTIONS(description="Exact timestamp when this rate was captured or became effective (UTC)"),
  base_currency       STRING NOT NULL OPTIONS(description="Base currency (e.g. USD, ZAR)"),
  quote_currency      STRING NOT NULL OPTIONS(description="Quote currency (e.g. ZAR, ZiG, USD)"),
  rate_type           STRING NOT NULL OPTIONS(description="Rate regime: 'OFFICIAL_INTERBANK', 'MARKET_PARALLEL', 'CARD_SETTLEMENT', 'BUREAU_DE_CHANGE'"),
  exchange_rate       NUMERIC(18, 6) NOT NULL OPTIONS(description="Rate multiplier: quote_amount = base_amount * exchange_rate"),
  inverse_rate        NUMERIC(18, 6) NOT NULL OPTIONS(description="Inverse rate: base_amount = quote_amount * inverse_rate (1 / exchange_rate)"),
  source_provider     STRING NOT NULL OPTIONS(description="Source of data (e.g. 'Reserve Bank of Zimbabwe', 'South African Reserve Bank', 'OMIR', 'ZimMarketRate', 'Wise')"),
  notes               STRING OPTIONS(description="Additional context regarding rate adjustments, premiums, or statutory fees")
)
PARTITION BY rate_date
CLUSTER BY base_currency, quote_currency, rate_type
OPTIONS(
  description = "Daily and intraday currency exchange rates supporting dual-rate economic reality in Zimbabwe and ZAR cross-rates."
);
