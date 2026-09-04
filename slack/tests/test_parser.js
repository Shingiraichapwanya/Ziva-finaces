/**
 * test_parser.js - Unit tests for TransactionParser
 */

const assert = require('assert');
const { TransactionParser } = require('../Parser');

const testCases = [
  {
    input: 'Spent 50 ZAR on lunch',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 50,
      originalAmount: -50,
      originalCurrency: 'ZAR',
      categoryId: 'CAT_DAILY_DINING',
      cashFlowTier: 'DAILY_SPENDING',
      accountId: 'ACC_ZA_CAPITEC_DAILY'
    }
  },
  {
    input: 'Paid 120 USD for OK Mart groceries',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 120,
      originalAmount: -120,
      originalCurrency: 'USD',
      categoryId: 'CAT_DAILY_GROCERIES',
      cashFlowTier: 'DAILY_SPENDING',
      accountId: 'ACC_ZW_ECOCASH_USD'
    }
  },
  {
    input: 'Coffee R45 at Vida e Caffe',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 45,
      originalAmount: -45,
      originalCurrency: 'ZAR',
      categoryId: 'CAT_DAILY_DINING',
      cashFlowTier: 'DAILY_SPENDING',
      accountId: 'ACC_ZA_CAPITEC_DAILY'
    }
  },
  {
    input: 'Bought 245 ZiG airtime Econet',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 245,
      originalAmount: -245,
      originalCurrency: 'ZiG',
      categoryId: 'CAT_DAILY_AIRTIME',
      cashFlowTier: 'DAILY_SPENDING',
      accountId: 'ACC_ZW_ECOCASH_ZIG'
    }
  },
  {
    input: 'Rent 14500 ZAR apartment lease',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 14500,
      originalAmount: -14500,
      originalCurrency: 'ZAR',
      categoryId: 'CAT_ALLOC_RENT',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      accountId: 'ACC_ZA_FNB_MONTHLY'
    }
  },
  {
    input: 'Salary received 55000 ZAR client retainer',
    expected: {
      success: true,
      transactionType: 'INCOME',
      absoluteAmount: 55000,
      originalAmount: 55000,
      originalCurrency: 'ZAR',
      categoryId: 'CAT_INC_SALARY',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      accountId: 'ACC_ZA_FNB_MONTHLY'
    }
  },
  {
    input: 'Uber ride 125 ZAR to airport',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 125,
      originalAmount: -125,
      originalCurrency: 'ZAR',
      categoryId: 'CAT_DAILY_FUEL_TRANS',
      cashFlowTier: 'DAILY_SPENDING',
      accountId: 'ACC_ZA_CAPITEC_DAILY'
    }
  },
  {
    input: 'Paid 100 USD for ZESA power token',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 100,
      originalAmount: -100,
      originalCurrency: 'USD',
      categoryId: 'CAT_ALLOC_ELECTRICITY',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      accountId: 'ACC_ZW_STANBIC_NOSTRO'
    }
  },
  {
    input: 'Invested 8000 ZAR in S&P500 ETF',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 8000,
      originalAmount: -8000,
      originalCurrency: 'ZAR',
      categoryId: 'CAT_VAULT_GLOBAL_ETF',
      cashFlowTier: 'LONG_TERM_VAULT',
      accountId: 'ACC_ZA_EE_EQUITIES_VAULT',
      isTaxDeductible: false
    }
  },
  {
    input: 'Bought 7500 ZAR Dell 4K monitor for work invoice INV-DELL-9921',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 7500,
      originalAmount: -7500,
      originalCurrency: 'ZAR',
      categoryId: 'CAT_PROD_TECH_HARDWARE',
      cashFlowTier: 'DAILY_SPENDING',
      accountId: 'ACC_ZA_CAPITEC_DAILY',
      isTaxDeductible: true,
      taxInvoiceNumber: 'INV-DELL-9921'
    }
  },
  {
    input: 'Paid 40 USD for Claude and ChatGPT team',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 40,
      originalAmount: -40,
      originalCurrency: 'USD',
      categoryId: 'CAT_PROD_SOFTWARE_TOOLS',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      accountId: 'ACC_ZW_STANBIC_NOSTRO',
      isTaxDeductible: true
    }
  },
  {
    input: 'Paid 12000 ZAR provisional tax SARS ref SARS-2026-Q1',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 12000,
      originalAmount: -12000,
      originalCurrency: 'ZAR',
      categoryId: 'CAT_TAX_STATUTORY_PROVISIONAL',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      accountId: 'ACC_ZA_FNB_MONTHLY',
      isTaxDeductible: false,
      taxInvoiceNumber: 'SARS-2026-Q1'
    }
  },
  {
    input: 'Paid 1500 ZAR to accountant for tax preparation',
    expected: {
      success: true,
      transactionType: 'EXPENSE',
      absoluteAmount: 1500,
      originalAmount: -1500,
      originalCurrency: 'ZAR',
      categoryId: 'CAT_PROD_PROFESSIONAL_SERVICES',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      accountId: 'ACC_ZA_FNB_MONTHLY',
      isTaxDeductible: true
    }
  }
];

let passed = 0;
let failed = 0;

for (const tc of testCases) {
  const result = TransactionParser.parse(tc.input);
  try {
    assert.strictEqual(result.success, tc.expected.success, `Expected success=${tc.expected.success}`);
    assert.strictEqual(result.data.transactionType, tc.expected.transactionType, `Transaction type mismatch on "${tc.input}"`);
    assert.strictEqual(result.data.absoluteAmount, tc.expected.absoluteAmount, `Amount mismatch on "${tc.input}"`);
    assert.strictEqual(result.data.originalAmount, tc.expected.originalAmount, `Signed amount mismatch on "${tc.input}"`);
    assert.strictEqual(result.data.originalCurrency, tc.expected.originalCurrency, `Currency mismatch on "${tc.input}"`);
    assert.strictEqual(result.data.categoryId, tc.expected.categoryId, `Category mismatch on "${tc.input}" (got ${result.data.categoryId}, expected ${tc.expected.categoryId})`);
    assert.strictEqual(result.data.cashFlowTier, tc.expected.cashFlowTier, `Tier mismatch on "${tc.input}"`);
    assert.strictEqual(result.data.accountId, tc.expected.accountId, `Account mismatch on "${tc.input}"`);
    if (tc.expected.isTaxDeductible !== undefined) {
      assert.strictEqual(result.data.isTaxDeductible, tc.expected.isTaxDeductible, `Tax deductible mismatch on "${tc.input}"`);
    }
    if (tc.expected.taxInvoiceNumber !== undefined) {
      assert.strictEqual(result.data.taxInvoiceNumber, tc.expected.taxInvoiceNumber, `Invoice number mismatch on "${tc.input}"`);
    }
    console.log(`PASS: "${tc.input}" -> ${result.data.originalCurrency} ${result.data.absoluteAmount} [${result.data.categoryId}] (TaxDeductible=${result.data.isTaxDeductible})`);
    passed++;
  } catch (err) {
    console.error(`FAIL: "${tc.input}":`, err.message);
    failed++;
  }
}

console.log(`\nResults: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
