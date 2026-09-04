const { execSync } = require('child_process');
const path = require('path');

const projectId = 'budget-tracker-507418';
const datasetId = 'personal_finance';
const location = 'africa-south1';
const ndjsonDir = path.join(__dirname, '..', 'sample_data', 'ndjson');

const tables = [
  'dim_currencies',
  'dim_accounts',
  'dim_categories',
  'fct_exchange_rates',
  'fct_budget_allocations',
  'fct_transactions'
];

for (const table of tables) {
  const filePath = path.join(ndjsonDir, `${table}.json`);
  const cmd = `bq load --project_id=${projectId} --location=${location} --replace --source_format=NEWLINE_DELIMITED_JSON --label datacloud:antigravity ${projectId}:${datasetId}.${table} "${filePath}"`;
  console.log(`Loading ${table}...`);
  try {
    const out = execSync(cmd, { encoding: 'utf8' });
    console.log(`  -> ${table} loaded successfully.`);
  } catch (err) {
    console.error(`  ERROR loading ${table}:`, err.stderr || err.message);
    process.exit(1);
  }
}

console.log('All tables loaded successfully!');
