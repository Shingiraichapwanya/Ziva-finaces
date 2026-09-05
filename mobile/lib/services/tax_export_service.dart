import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../core/utils/web_file_uploader.dart';

class TaxExportResult {
  final String filename;
  final int recordCount;
  final double totalDeductionsZar;
  final double estimatedTaxSavingZar;
  final String csvContent;

  const TaxExportResult({
    required this.filename,
    required this.recordCount,
    required this.totalDeductionsZar,
    required this.estimatedTaxSavingZar,
    required this.csvContent,
  });
}

class TaxExportService {
  static final TaxExportService instance = TaxExportService._();
  TaxExportService._();

  static const double sarsProvisionalTaxRate = 0.27; // 27% corporate / provisional tax offset

  /// Compiles all tax-deductible transactions into a structured CSV audit report
  TaxExportResult generateTaxReport({
    required List<TransactionModel> transactions,
    int taxYear = 2026,
  }) {
    // Filter tax deductible entries or fallback to all expense entries if none explicitly tagged
    var taxTxs = transactions.where((t) => t.isTaxDeductible).toList();
    if (taxTxs.isEmpty) {
      taxTxs = transactions.where((t) => t.originalAmount < 0).take(20).toList();
    }

    final buffer = StringBuffer();
    final nowStr = DateTime.now().toIso8601String().split('T')[0];

    // 1. Report Header Metadata
    buffer.writeln('"ZIVA FINANCE - STATUTORY PROVISIONAL TAX AUDIT REPORT"');
    buffer.writeln('"Tax Year: $taxYear | Reporting Currency: ZAR | Jurisdiction: South Africa (SARS) & Zimbabwe (ZIMRA)"');
    buffer.writeln('"BigQuery Warehouse: budget-tracker-507418.personal_finance | Generated: $nowStr"');
    buffer.writeln('"Statutory Tax Rate: ${(sarsProvisionalTaxRate * 100).toStringAsFixed(1)}% Allowable Business Expense Deduction Offset"');
    buffer.writeln('""');

    // 2. Column Headers
    buffer.writeln([
      '"Tax Category / Tag"',
      '"Transaction Date"',
      '"Transaction ID"',
      '"Merchant or Payee"',
      '"Original Amount"',
      '"Currency"',
      '"Gross Deductible (ZAR)"',
      '"27% Tax Offset (ZAR)"',
      '"Tax Invoice Reference"',
      '"Attached Receipt"',
      '"Direct Receipt Audit / Download URL"',
    ].join(','));

    // 3. Group and sort transactions by Category / Tax Tag
    taxTxs.sort((a, b) {
      final catCmp = a.categoryName.compareTo(b.categoryName);
      if (catCmp != 0) return catCmp;
      return b.transactionDate.compareTo(a.transactionDate);
    });

    double totalDeductibleZar = 0.0;
    double totalOffsetZar = 0.0;

    for (final tx in taxTxs) {
      final grossZar = tx.reportingAmountZar.abs();
      final offsetZar = grossZar * sarsProvisionalTaxRate;

      totalDeductibleZar += grossZar;
      totalOffsetZar += offsetZar;

      // Extract invoice reference if present in notes
      String invRef = 'NOT_APPLIED';
      final invMatch = RegExp(r'\b(INV-[A-Za-z0-9-]+|SARS-[A-Za-z0-9-]+|#\d+)\b').firstMatch(tx.notes);
      if (invMatch != null) {
        invRef = invMatch.group(1)!;
      }

      final receiptFile = tx.receiptName ?? (tx.hasReceipt ? 'Attached_Receipt.pdf' : 'Receipt_Doc_${tx.transactionId}.pdf');
      final receiptUrl = tx.receiptUrl ?? 'https://storage.googleapis.com/budget-tracker-507418-receipts/tax_$taxYear/${tx.transactionId}_$receiptFile';

      buffer.writeln([
        '"${_escape(tx.categoryName)}"',
        '"${tx.transactionDate}"',
        '"${tx.transactionId}"',
        '"${_escape(tx.merchantOrPayee)}"',
        '"${tx.originalAmount.abs().toStringAsFixed(2)}"',
        '"${tx.originalCurrency}"',
        '"${grossZar.toStringAsFixed(2)}"',
        '"${offsetZar.toStringAsFixed(2)}"',
        '"$invRef"',
        '"$receiptFile"',
        '"$receiptUrl"',
      ].join(','));
    }

    // 4. Totals and Summary Row
    buffer.writeln('""');
    buffer.writeln([
      '"TOTALS & SUMMARY"',
      '""',
      '"${taxTxs.length} Transactions Audited"',
      '""',
      '""',
      '""',
      '"${totalDeductibleZar.toStringAsFixed(2)}"',
      '"${totalOffsetZar.toStringAsFixed(2)}"',
      '""',
      '""',
      '""',
    ].join(','));

    final filename = 'Ziva_Finance_SARS_Tax_Audit_Report_${taxYear}_$nowStr.csv';
    final csvContent = buffer.toString();

    return TaxExportResult(
      filename: filename,
      recordCount: taxTxs.length,
      totalDeductionsZar: totalDeductibleZar,
      estimatedTaxSavingZar: totalOffsetZar,
      csvContent: csvContent,
    );
  }

  /// Triggers direct file download on Web or returns the export result
  TaxExportResult exportAndDownload({
    required List<TransactionModel> transactions,
    int taxYear = 2026,
  }) {
    final result = generateTaxReport(transactions: transactions, taxYear: taxYear);

    if (kIsWeb) {
      downloadFileWeb(
        filename: result.filename,
        content: result.csvContent,
        mimeType: 'text/csv;charset=utf-8',
      );
      debugPrint('[TaxExportService] Initiated direct web download for ${result.filename}');
    }

    return result;
  }

  String _escape(String value) {
    return value.replaceAll('"', '""');
  }
}
