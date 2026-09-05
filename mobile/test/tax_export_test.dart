import 'package:flutter_test/flutter_test.dart';
import 'package:ziva_finance/models/transaction_model.dart';
import 'package:ziva_finance/services/tax_export_service.dart';

void main() {
  group('TaxExportService Unit Tests', () {
    test('groups transactions by tax category and computes 27% SARS deduction', () {
      final transactions = [
        TransactionModel(
          transactionId: 'tx-1',
          transactionDate: '2026-03-01',
          accountId: 'acc-1',
          categoryId: 'CAT_TECH_HARDWARE',
          categoryName: 'Hardware & Tech',
          transactionType: 'EXPENSE',
          originalAmount: -20000.0,
          originalCurrency: 'ZAR',
          reportingAmountZar: -20000.0,
          reportingAmountUsd: -1080.0,
          merchantOrPayee: 'Dell South Africa',
          isTaxDeductible: true,
          notes: 'Office laptop for dev INV-WORK-990',
          tags: ['hardware', 'tax_deductible', 'office'],
          receiptName: 'Dell_Invoice_20000.pdf',
          receiptUrl: 'https://storage.googleapis.com/ziva-finance-receipts/Dell_Invoice_20000.pdf',
        ),
        TransactionModel(
          transactionId: 'tx-2',
          transactionDate: '2026-03-02',
          accountId: 'acc-1',
          categoryId: 'CAT_GROCERIES',
          categoryName: 'Groceries',
          transactionType: 'EXPENSE',
          originalAmount: -500.0,
          originalCurrency: 'ZAR',
          reportingAmountZar: -500.0,
          reportingAmountUsd: -27.0,
          merchantOrPayee: 'Woolworths',
          isTaxDeductible: false,
          notes: 'Personal groceries',
          tags: ['groceries'],
        ),
        TransactionModel(
          transactionId: 'tx-3',
          transactionDate: '2026-03-03',
          accountId: 'acc-1',
          categoryId: 'CAT_CLOUD',
          categoryName: 'Cloud Infrastructure',
          transactionType: 'EXPENSE',
          originalAmount: -1000.0,
          originalCurrency: 'USD',
          reportingAmountZar: -18500.0,
          reportingAmountUsd: -1000.0,
          merchantOrPayee: 'Amazon Web Services',
          isTaxDeductible: true,
          notes: 'Production BigQuery & hosting INV-AWS-2026',
          tags: ['cloud', 'sars_deductible'],
          receiptName: 'AWS_Tax_Invoice.pdf',
          receiptUrl: 'https://storage.googleapis.com/ziva-finance-receipts/AWS_Tax_Invoice.pdf',
        ),
      ];

      final result = TaxExportService.instance.generateTaxReport(
        transactions: transactions,
        taxYear: 2026,
      );

      // Verify records and totals
      expect(result.recordCount, 2);
      expect(result.totalDeductionsZar, 38500.0);
      expect(result.estimatedTaxSavingZar, 38500.0 * 0.27); // 10395.00 ZAR

      final csvContent = result.csvContent;

      // Verify header sections
      expect(csvContent.contains('ZIVA FINANCE - STATUTORY PROVISIONAL TAX AUDIT REPORT'), true);
      expect(csvContent.contains('Statutory Tax Rate: 27.0% Allowable Business Expense Deduction Offset'), true);
      expect(csvContent.contains('Direct Receipt Audit / Download URL'), true);

      // Verify invoice references parsed from notes
      expect(csvContent.contains('INV-WORK-990'), true);
      expect(csvContent.contains('INV-AWS-2026'), true);

      // Verify embedded receipt links
      expect(csvContent.contains('https://storage.googleapis.com/ziva-finance-receipts/Dell_Invoice_20000.pdf'), true);
      expect(csvContent.contains('https://storage.googleapis.com/ziva-finance-receipts/AWS_Tax_Invoice.pdf'), true);
      expect(csvContent.contains('Dell_Invoice_20000.pdf'), true);
    });

    test('handles transactions without explicit tax tags by taking expense subset', () {
      final nonTaxTx = [
        TransactionModel(
          transactionId: 'tx-4',
          transactionDate: '2026-03-04',
          accountId: 'acc-2',
          categoryId: 'CAT_ENTERTAINMENT',
          categoryName: 'Entertainment',
          transactionType: 'EXPENSE',
          originalAmount: -250.0,
          originalCurrency: 'ZAR',
          reportingAmountZar: -250.0,
          reportingAmountUsd: -13.5,
          merchantOrPayee: 'Cinema',
          isTaxDeductible: false,
        ),
      ];

      final result = TaxExportService.instance.generateTaxReport(
        transactions: nonTaxTx,
        taxYear: 2026,
      );

      expect(result.recordCount, 1);
      expect(result.totalDeductionsZar, 250.0);
      expect(result.csvContent.contains('Cinema'), true);
      expect(result.csvContent.contains('250.00'), true);
    });
  });
}
