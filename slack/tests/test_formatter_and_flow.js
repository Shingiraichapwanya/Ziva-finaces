/**
 * test_formatter_and_flow.js - Test suite for SlackFormatter and processTransaction logic
 */

const { Parser } = require('../Parser');
const { BigQueryClient } = require('../BigQueryClient');
const { SlackFormatter } = require('../SlackFormatter');
const { processTransaction } = require('../Code');

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`PASS: ${message}`);
    passed++;
  } else {
    console.error(`FAIL: ${message}`);
    failed++;
  }
}

console.log('--- Testing SlackFormatter ---');

// Test 1: Help message
const help = SlackFormatter.formatHelpMessage();
assert(help.response_type === 'ephemeral', 'Help message is ephemeral');
assert(help.blocks.length >= 4, 'Help message has multiple blocks');

// Test 2: Error message
const errorMsg = SlackFormatter.formatErrorMessage('Invalid amount', 'lunch yesterday');
assert(errorMsg.response_type === 'ephemeral', 'Error message is ephemeral');
assert(errorMsg.blocks[1].text.text.includes('Invalid amount'), 'Error text contains message');

// Test 3: Success message formatting
const parseResult = Parser.parse('Spent 50 ZAR on lunch at Vida');
const parsed = parseResult.data;
const result = BigQueryClient.insertTransaction(parsed);
const budgetStatus = {
  categoryName: 'Restaurants, Takeaways & Coffee',
  targetCurrency: 'ZAR',
  plannedAmountZar: 3500.0,
  actualSpentZar: 1580.0,
  varianceZar: 1920.0,
  pctConsumed: 45.1,
  budgetStatus: 'ON_TRACK'
};

const successMsg = SlackFormatter.formatSuccessMessage(parsed, result, budgetStatus);
assert(successMsg.response_type === 'in_channel', 'Success message is in_channel');
assert(successMsg.blocks[0].text.text.includes('Expense Logged: -50.00 ZAR'), 'Header contains correct expense amount');
assert(successMsg.blocks[1].fields.some(f => f.text.includes('CAT_DAILY_DINING')), 'Fields include category');
assert(successMsg.blocks[3].text.text.includes('🟢 *On Track* (45.1% consumed)'), 'Budget block shows On Track status');

// Test 4: Success message with OVER_BUDGET
const overBudgetStatus = {
  categoryName: 'Restaurants, Takeaways & Coffee',
  targetCurrency: 'ZAR',
  plannedAmountZar: 1000.0,
  actualSpentZar: 1250.0,
  varianceZar: -250.0,
  pctConsumed: 125.0,
  budgetStatus: 'OVER_BUDGET'
};
const overBudgetMsg = SlackFormatter.formatSuccessMessage(parsed, result, overBudgetStatus);
assert(overBudgetMsg.blocks[3].text.text.includes('🔴 *OVER BUDGET* (125% consumed)'), 'Budget block shows OVER BUDGET');

console.log('\n--- Testing processTransaction Workflow ---');

// Test 5: End-to-end slash command flow for standard expense
const flowResult1 = processTransaction('Spent 50 ZAR on lunch at Vida', {
  source: 'slash_command',
  userName: 'shingi'
});
assert(flowResult1.response_type === 'in_channel', 'Slash command returns in_channel response');
assert(flowResult1.blocks[0].text.text.includes('50.00 ZAR'), 'Response contains original amount');

// Test 6: End-to-end USD grocery transaction
const flowResult2 = processTransaction('Paid 120 USD for OK Mart groceries', {
  source: 'slash_command',
  userName: 'shingi'
});
assert(flowResult2.response_type === 'in_channel', 'USD transaction returns in_channel response');
assert(flowResult2.blocks[0].text.text.includes('120.00 USD'), 'USD amount formatted');

// Test 7: Handling invalid / unparseable input gracefully
const errorFlow = processTransaction('completely unparseable words without numbers', {
  source: 'slash_command',
  userName: 'shingi'
});
assert(errorFlow.response_type === 'ephemeral', 'Error flow returns ephemeral response');
assert(errorFlow.blocks[0].text.text.includes('Could Not Log Transaction'), 'Error header displayed');

// Test 8: Tax-deductible productivity purchase flow
const taxFlow = processTransaction('Bought 7500 ZAR Dell 4K monitor for work invoice INV-DELL-9921', {
  source: 'slash_command',
  userName: 'shingi'
});
assert(taxFlow.response_type === 'in_channel', 'Tax flow returns in_channel response');
assert(taxFlow.blocks[1].fields.some(f => f.text.includes('Tax-Deductible Business Expense')), 'Shows tax-deductible badge');
assert(taxFlow.blocks[1].fields.some(f => f.text.includes('INV-DELL-9921')), 'Shows invoice number in fields');

// Test 9: Statutory tax remittance payment flow
const taxPaymentFlow = processTransaction('Paid 12000 ZAR provisional tax SARS ref SARS-2026-Q1', {
  source: 'slash_command',
  userName: 'shingi'
});
assert(taxPaymentFlow.response_type === 'in_channel', 'Tax payment returns in_channel response');
assert(taxPaymentFlow.blocks[1].fields.some(f => f.text.includes('Statutory Tax Remittance')), 'Shows statutory tax remittance badge');
assert(taxPaymentFlow.blocks[1].fields.some(f => f.text.includes('SARS-2026-Q1')), 'Shows SARS reference in fields');

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) {
  process.exit(1);
}
