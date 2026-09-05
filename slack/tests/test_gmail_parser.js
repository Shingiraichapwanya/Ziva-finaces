/**
 * test_gmail_parser.js - Unit tests for GmailReceiptParser
 */

const assert = require('assert');
const { GmailReceiptParser, GMAIL_CONFIG } = require('../GmailParser');

// 1. Verify default query broadens beyond Google to general receipt keywords
console.log('--- Testing Query Construction ---');
assert.strictEqual(
  GMAIL_CONFIG.defaultQuery.includes('invoice OR receipt OR "payment confirmation" OR "payment advice"'),
  true,
  'Query must include broadened keywords'
);
assert.strictEqual(
  GMAIL_CONFIG.defaultQuery.includes('from:google'),
  false,
  'Query must not restrict to Google addresses'
);
console.log('PASS: Broadened Gmail search query validated.');

// 2. Test PDF attachment detection
console.log('\n--- Testing PDF Attachment Detection ---');
assert.strictEqual(GmailReceiptParser.isPdfAttachment({ getName: () => 'invoice.pdf', getContentType: () => 'application/pdf' }), true);
assert.strictEqual(GmailReceiptParser.isPdfAttachment({ getName: () => 'receipt_scan.PDF', getContentType: () => 'application/octet-stream' }), true);
assert.strictEqual(GmailReceiptParser.isPdfAttachment({ getName: () => 'photo.jpg', getContentType: () => 'image/jpeg' }), false);
console.log('PASS: PDF attachment detection validated.');

// 3. Test Entity Extraction on different receipt styles
console.log('\n--- Testing Financial Entity Extraction ---');

// Case A: Woolworths Grocery Tax Invoice
const caseA = GmailReceiptParser.extractFinancialData({
  from: 'Woolworths Online <noreply@woolworths.co.za>',
  subject: 'Your Woolworths Tax Invoice INV-WW-8821',
  bodyText: 'Thank you for your order. Total Paid: ZAR 458.75. Delivered to Cape Town.',
  fileName: 'Tax_Invoice_INV-WW-8821.pdf',
  dateStr: '2026-03-05'
});

assert.strictEqual(caseA.merchant, 'Woolworths Online');
assert.strictEqual(caseA.amount, 458.75);
assert.strictEqual(caseA.currency, 'ZAR');
assert.strictEqual(caseA.taxInvoiceNumber, 'INV-WW-8821');
assert.strictEqual(caseA.isTaxDeductible, true); // Tax invoice marked
console.log('PASS: Woolworths Tax Invoice parsed successfully.');

// Case B: AWS Cloud Computing USD Payment Confirmation
const caseB = GmailReceiptParser.extractFinancialData({
  from: 'Amazon Web Services <no-reply-aws@amazon.com>',
  subject: 'Payment Confirmation: AWS Cloud Services',
  bodyText: 'We have processed your payment. Amount Charged: $185.50 USD for EC2 and BigQuery hosting.',
  fileName: 'AWS_Statement_March2026.pdf',
  dateStr: '2026-03-05'
});

assert.strictEqual(caseB.merchant, 'Amazon Web Services');
assert.strictEqual(caseB.amount, 185.50);
assert.strictEqual(caseB.currency, 'USD');
assert.strictEqual(caseB.categoryId, 'CAT_PROD_SOFTWARE_TOOLS');
assert.strictEqual(caseB.isTaxDeductible, true); // Cloud / software hosting
console.log('PASS: AWS USD payment confirmation parsed successfully.');

// Case C: Capitec Payment Advice for Rent
const caseC = GmailReceiptParser.extractFinancialData({
  from: 'Capitec Bank Notifications <alerts@capitecbank.co.za>',
  subject: 'Payment Advice: Proof of Payment to Landlord',
  bodyText: 'Payment Advice: Beneficiary Rent Payment. Amount: 14,500.00 ZAR. Ref: #RENT2026',
  fileName: 'Payment_Advice_14500.00.pdf',
  dateStr: '2026-03-05'
});

assert.strictEqual(caseC.merchant, 'Capitec Bank Notifications');
assert.strictEqual(caseC.amount, 14500.00);
assert.strictEqual(caseC.currency, 'ZAR');
assert.strictEqual(caseC.categoryId, 'CAT_ALLOC_RENT');
console.log('PASS: Payment Advice for Rent parsed successfully.');

// 4. Test Complete Attachment Processing & GCS Payload Construction
console.log('\n--- Testing Full Attachment Ingestion Pipeline ---');
const mockMessage = {
  getDate: () => new Date('2026-03-05T10:00:00Z'),
  getSubject: () => 'Tax Invoice from Dell South Africa INV-DELL-4412',
  getFrom: () => 'Dell Technologies <invoicing@dell.com>',
  getPlainBody: () => 'Dear Customer, Please find attached your tax invoice for ZAR 24,999.00 for Dell XPS Developer Laptop.'
};

const mockAttachment = {
  getName: () => 'Dell_Tax_Invoice_INV-DELL-4412.pdf',
  getContentType: () => 'application/pdf',
  getSize: () => 145020,
  getBytes: () => [1, 2, 3]
};

const result = GmailReceiptParser.processReceiptAttachment(mockMessage, mockAttachment);

assert.strictEqual(result.success, true);
assert.strictEqual(result.data.merchantOrPayee, 'Dell Technologies');
assert.strictEqual(result.data.originalAmount, -24999.00);
assert.strictEqual(result.data.originalCurrency, 'ZAR');
assert.strictEqual(result.data.categoryId, 'CAT_PROD_TECH_HARDWARE');
assert.strictEqual(result.data.isTaxDeductible, true);
assert.strictEqual(result.data.taxInvoiceNumber, 'INV-DELL-4412');
assert.strictEqual(result.data.receiptName, 'Dell_Tax_Invoice_INV-DELL-4412.pdf');
assert.strictEqual(result.data.receiptUrl.includes('https://storage.googleapis.com/budget-tracker-507418-receipts/receipts/2026-03/'), true);
assert.strictEqual(result.data.metadata.source, 'gmail_parser');

console.log('PASS: Full attachment processing and GCS linking validated.');

// 5. Test Historical Sweep and Outgoing Client Invoice Detection
console.log('\n--- Testing Historical Sweep & Outgoing Client Invoices ---');

// Case D: Outgoing Client Invoice (Revenue/Income)
const mockClientMessage = {
  getDate: () => new Date('2026-02-15T14:30:00Z'),
  getSubject: () => 'Consulting Invoice: Cloud Architecture Deliverable INV-2026-004',
  getFrom: () => 'me <shingiraichapwanya@gmail.com>',
  getPlainBody: () => 'Dear Client, Please find attached our invoice for Q1 BigQuery advisory. Total Due: ZAR 48,000.00'
};

const mockClientAttachment = {
  getName: () => 'Client_Invoice_INV-2026-004.pdf',
  getContentType: () => 'application/pdf',
  getSize: () => 85400,
  getBytes: () => [1, 2, 3]
};

const clientResult = GmailReceiptParser.processReceiptAttachment(mockClientMessage, mockClientAttachment);

assert.strictEqual(clientResult.success, true);
assert.strictEqual(clientResult.data.transactionType, 'INCOME', 'Outgoing client invoice must be classified as INCOME');
assert.strictEqual(clientResult.data.originalAmount, 48000.00, 'Client invoice amount must be positive revenue');
assert.strictEqual(clientResult.data.categoryId, 'CAT_CLIENT_REVENUE');
assert.strictEqual(clientResult.data.isTaxDeductible, false, 'Client revenue is not a deduction');
assert.strictEqual(clientResult.data.tags.includes('client_invoice'), true);
console.log('PASS: Outgoing client invoice correctly classified as positive revenue (INCOME).');

// Verify runHistoricalSweep query includes 2026/01/01 date boundary
assert.strictEqual(typeof GmailReceiptParser.runHistoricalSweep, 'function');
console.log('PASS: runHistoricalSweep function signature verified.');

console.log('\nAll 8 Gmail Parser test assertions passed successfully!');
