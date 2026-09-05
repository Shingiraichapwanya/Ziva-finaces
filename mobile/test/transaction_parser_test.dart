import 'package:flutter_test/flutter_test.dart';
import 'package:ziva_finance/core/utils/transaction_parser.dart';

void main() {
  group('TransactionParser Natural Language Unit Tests', () {
    test('parses standard grocery sentence with currency and merchant', () {
      final res = TransactionParser.parse('Spent 120 ZAR on groceries at Woolworths today');

      expect(res.success, true);
      expect(res.amount, 120.0);
      expect(res.currency, 'ZAR');
      expect(res.merchant, 'Woolworths');
      expect(res.categoryId, 'CAT_GROCERIES');
      expect(res.categoryName, 'Groceries & Household Supplies');
      expect(res.isTaxDeductible, false);
    });

    test('parses work tax-deductible hardware with invoice number', () {
      final res = TransactionParser.parse('Bought 4500 ZAR standing desk for work invoice INV-WORK-771');

      expect(res.success, true);
      expect(res.amount, 4500.0);
      expect(res.currency, 'ZAR');
      expect(res.merchant, 'Standing Desk');
      expect(res.categoryId, 'CAT_TECH_HARDWARE');
      expect(res.isTaxDeductible, true);
      expect(res.invoiceRef, 'INV-WORK-771');
    });

    test('parses USD dining expense with prefix dollar symbol', () {
      final res = TransactionParser.parse('Paid \$45.50 for dinner at Nandos');

      expect(res.success, true);
      expect(res.amount, 45.50);
      expect(res.currency, 'USD');
      expect(res.merchant, 'Nandos');
      expect(res.categoryId, 'CAT_DINING_COFFEE');
      expect(res.isTaxDeductible, false);
    });

    test('parses receipt file name and metadata', () {
      final res = TransactionParser.parseReceipt(
        fileName: 'Woolworths_Invoice_ZAR_345.50.pdf',
        fileContent: 'Woolworths V&A Waterfront Groceries Total ZAR 345.50',
        fileSize: 42500,
      );

      expect(res.success, true);
      expect(res.amount, 345.50);
      expect(res.currency, 'ZAR');
      expect(res.merchant, 'Woolworths');
      expect(res.categoryId, 'CAT_GROCERIES');
    });
  });
}
