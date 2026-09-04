/**
 * test_slack_tax_ingest.js
 * End-to-end live test verifying natural language parsing of tax-deductible purchases
 * and live ingestion into personal_finance.fct_transactions with updated tax liability schedule.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { TransactionParser } = require('../slack/Parser');
const { BigQueryClient, BQ_CONFIG } = require('../slack/BigQueryClient');

const TEST_INPUT = 'Bought 4500 ZAR standing desk for work invoice INV-WORK-771';

console.log('===================================================================');
console.log('   Live Slack -> BigQuery Tax Offset Ingestion Verification       ');
console.log('===================================================================');
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
console.log('   - Tax Deductible:', parsed.isTaxDeductible);
console.log('   - Tax Line Item:', parsed.taxLineItem);
console.log('   - Invoice Ref:', parsed.taxInvoiceNumber);

// 2. Generate transaction ID and conversions
const now = new Date();
const isoString = now.toISOString();
const dateStr = isoString.split('T')[0];
const timestampStr = isoString.replace('T', ' ').replace('Z', ' UTC');
const localTimeStr = isoString.replace('Z', '').split('.')[0];
const randomSuffix = Math.floor(1000 + Math.random() * 9000);
const txId = `TX_TAX_TEST_${dateStr.replace(/-/g, '')}_${randomSuffix}`;

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
  is_tax_deductible: parsed.isTaxDeductible,
  tax_deductible_amount_zar: Math.abs(conversions.reportingAmountZar),
  tax_deductible_amount_usd: Math.abs(conversions.reportingAmountUsd),
  tax_invoice_number: parsed.taxInvoiceNumber,
  notes: parsed.notes,
  tags: parsed.tags.concat(['slack-tax-test']),
  metadata: {
    source: 'slack_bot_tax_simulation',
    raw_prompt: TEST_INPUT,
    ingested_at: isoString
  }
};

const tempFilePath = path.join(__dirname, 'test_tax_tx.json');
fs.writeFileSync(tempFilePath, JSON.stringify(record) + '\n', 'utf8');
console.log(`\n2. Generated NDJSON record at: ${tempFilePath}`);

console.log('\n3. Executing bq load job into BigQuery...');
try {
  const loadCmd = `bq load --project_id=${BQ_CONFIG.projectId} --location=${BQ_CONFIG.location} --source_format=NEWLINE_DELIMITED_JSON --label datacloud:antigravity ${BQ_CONFIG.projectId}:${BQ_CONFIG.datasetId}.fct_transactions "${tempFilePath}"`;
  execSync(loadCmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
  console.log('   -> Successfully loaded tax-deductible transaction!');
} catch (err) {
  console.error('BigQuery load failed:', err.stderr || err.message);
  process.exit(1);
} finally {
  if (fs.existsSync(tempFilePath)) {
    fs.unlinkSync(tempFilePath);
  }
}

console.log('\n4. Querying Updated Quarterly Tax Liability Schedule:');
const taxSql = `SELECT tax_year, tax_quarter, gross_taxable_inflow_zar, productivity_expenses_offset_zar, total_allowable_deductions_zar, net_taxable_income_zar, estimated_tax_liability_zar, actual_tax_paid_zar, net_tax_outstanding_zar, tax_settlement_status FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_quarterly_tax_liability_schedule\` WHERE tax_year = 2026`;
const taxSqlFile = path.join(__dirname, 'temp_query.sql');
fs.writeFileSync(taxSqlFile, taxSql, 'utf8');

try {
  const queryCmd = `cmd.exe /c "bq query --use_legacy_sql=false --project_id=${BQ_CONFIG.projectId} --location=${BQ_CONFIG.location} --label datacloud:antigravity < \\"${taxSqlFile}\\""`;
  const queryOutput = execSync(queryCmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
  console.log(queryOutput);
} catch (err) {
  console.error('Tax query failed:', err.stderr || err.message);
} finally {
  if (fs.existsSync(taxSqlFile)) {
    fs.unlinkSync(taxSqlFile);
  }
}

console.log('5. Querying Itemized Tax-Deductible Audit Schedule:');
const auditSql = `SELECT transaction_date, merchant_or_payee, tax_line_item, reporting_amount_zar, tax_deductible_amount_zar, tax_invoice_number FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_tax_deductible_expenses_audit\` ORDER BY transaction_date DESC, tax_deductible_amount_zar DESC LIMIT 5`;
fs.writeFileSync(taxSqlFile, auditSql, 'utf8');

try {
  const auditCmd = `cmd.exe /c "bq query --use_legacy_sql=false --project_id=${BQ_CONFIG.projectId} --location=${BQ_CONFIG.location} --label datacloud:antigravity < \\"${taxSqlFile}\\""`;
  const auditOutput = execSync(auditCmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
  console.log(auditOutput);
} catch (err) {
  console.error('Audit query failed:', err.stderr || err.message);
} finally {
  if (fs.existsSync(taxSqlFile)) {
    fs.unlinkSync(taxSqlFile);
  }
}

console.log('Live tax offset ingestion test COMPLETE!');
