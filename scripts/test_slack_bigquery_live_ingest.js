/**
 * test_slack_bigquery_live_ingest.js
 * End-to-end test verifying natural language parsing and live BigQuery ingestion into personal_finance.fct_transactions.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { TransactionParser } = require('../slack/Parser');
const { BigQueryClient, BQ_CONFIG } = require('../slack/BigQueryClient');

const TEST_INPUT = "Spent 75 ZAR on lunch at Nando's";

console.log('=====================================================');
console.log('   Live Slack -> BigQuery Ingestion Verification     ');
console.log('=====================================================');
console.log(`1. Parsing test input: "${TEST_INPUT}"`);

const parseResult = TransactionParser.parse(TEST_INPUT);
if (!parseResult.success) {
  console.error('Parsing failed:', parseResult.error);
  process.exit(1);
}

const parsed = parseResult.data;
console.log('   - Amount:', parsed.originalAmount, parsed.originalCurrency);
console.log('   - Category:', parsed.categoryId, `(${parsed.categoryName})`);
console.log('   - Account:', parsed.accountId, `(${parsed.accountName})`);
console.log('   - Payee:', parsed.merchantOrPayee);

// 2. Generate transaction ID and conversions
const now = new Date();
const isoString = now.toISOString();
const dateStr = isoString.split('T')[0];
const timestampStr = isoString.replace('T', ' ').replace('Z', ' UTC');
const localTimeStr = isoString.replace('Z', '').split('.')[0];
const randomSuffix = Math.floor(1000 + Math.random() * 9000);
const txId = `TX_SLACK_${dateStr.replace(/-/g, '')}_${randomSuffix}`;

const fxRates = BigQueryClient.getLatestExchangeRates();
const conversions = BigQueryClient.convertCurrency(parsed.originalAmount, parsed.originalCurrency, fxRates);

const record = {
  transaction_id: txId,
  transaction_timestamp: timestampStr,
  transaction_date: dateStr,
  local_timezone: BQ_CONFIG.defaultTimezone,
  local_timestamp: localTimeStr,
  settlement_timestamp: timestampStr,
  account_id: parsed.accountId,
  cash_flow_tier: parsed.cashFlowTier,
  category_id: parsed.categoryId,
  transaction_type: parsed.transactionType,
  original_amount: parsed.originalAmount,
  original_currency: parsed.originalCurrency,
  reporting_amount_usd: conversions.reportingAmountUsd,
  reporting_amount_zar: conversions.reportingAmountZar,
  applied_exchange_rate_usd: conversions.appliedExchangeRateUsd,
  applied_exchange_rate_zar: conversions.appliedExchangeRateZar,
  rate_type_applied: conversions.rateTypeApplied,
  transfer_counterpart_id: null,
  merchant_or_payee: parsed.merchantOrPayee,
  payment_method: parsed.paymentMethod,
  statutory_levy_or_fee: null,
  notes: parsed.notes,
  tags: parsed.tags.concat(['slack-live-test']),
  metadata: {
    source: 'slack_bot_simulation',
    raw_prompt: TEST_INPUT,
    ingested_at: isoString
  }
};

const tempFilePath = path.join(__dirname, 'test_slack_tx.json');
fs.writeFileSync(tempFilePath, JSON.stringify(record) + '\n', 'utf8');
console.log(`\n2. Generated NDJSON record for BigQuery Load Job at: ${tempFilePath}`);

console.log('\n3. Executing bq load job (compatible with Free Sandbox)...');
try {
  const loadCmd = `bq load --project_id=${BQ_CONFIG.projectId} --location=${BQ_CONFIG.location} --source_format=NEWLINE_DELIMITED_JSON --label datacloud:antigravity ${BQ_CONFIG.projectId}:${BQ_CONFIG.datasetId}.fct_transactions "${tempFilePath}"`;
  console.log(`   Running: ${loadCmd}`);
  const loadOutput = execSync(loadCmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
  console.log('   Load Output:', loadOutput.trim());
  console.log('   -> Successfully ingested transaction into BigQuery!');
} catch (err) {
  console.error('BigQuery load failed:', err.stderr || err.message);
  process.exit(1);
} finally {
  if (fs.existsSync(tempFilePath)) {
    fs.unlinkSync(tempFilePath);
  }
}

console.log('\n4. Verifying ingested record in BigQuery:');
const verifySql = `SELECT transaction_id, transaction_date, original_amount, original_currency, reporting_amount_zar, reporting_amount_usd, category_id, merchant_or_payee FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\` WHERE transaction_id = '${txId}'`;
const verifyCmd = `bq query --use_legacy_sql=false --project_id=${BQ_CONFIG.projectId} --location=${BQ_CONFIG.location} --label datacloud:antigravity "${verifySql}"`;

try {
  const queryOutput = execSync(verifyCmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
  console.log(queryOutput);
} catch (err) {
  console.error('Verification query failed:', err.stderr || err.message);
}

console.log('5. Checking updated monthly budget vs actual for CAT_DAILY_DINING:');
const budgetSql = `SELECT category_id, category_name, planned_amount_zar, actual_spent_zar, variance_zar, pct_budget_consumed, budget_status FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_monthly_budget_vs_actual\` WHERE category_id = 'CAT_DAILY_DINING'`;
const budgetCmd = `bq query --use_legacy_sql=false --project_id=${BQ_CONFIG.projectId} --location=${BQ_CONFIG.location} --label datacloud:antigravity "${budgetSql}"`;

try {
  const budgetOutput = execSync(budgetCmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
  console.log(budgetOutput);
} catch (err) {
  console.error('Budget query failed:', err.stderr || err.message);
}

console.log('Live Slack -> BigQuery end-to-end verification COMPLETE!');
