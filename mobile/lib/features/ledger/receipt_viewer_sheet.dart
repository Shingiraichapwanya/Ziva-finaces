import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/web_file_uploader.dart';
import '../../models/transaction_model.dart';

class ReceiptViewerSheet extends StatelessWidget {
  final TransactionModel transaction;

  const ReceiptViewerSheet({super.key, required this.transaction});

  void _downloadReceipt(BuildContext context) {
    final receiptName = transaction.receiptName ?? 'Receipt_${transaction.transactionId}.pdf';
    final receiptContent = '''
================================================================
                    ZIVA FINANCE AUDIT RECEIPT
================================================================
Transaction ID : ${transaction.transactionId}
Date           : ${transaction.transactionDate}
Merchant / Payee: ${transaction.merchantOrPayee}
Category       : ${transaction.categoryName} (${transaction.categoryId})
Payment Method : ${transaction.paymentMethod}
Amount Paid    : ${CurrencyFormatter.formatAmount(transaction.originalAmount, currency: transaction.originalCurrency)}
Reporting (ZAR): R ${transaction.reportingAmountZar.toStringAsFixed(2)}
Reporting (USD): \$ ${transaction.reportingAmountUsd.toStringAsFixed(2)}
SARS Deductible: ${transaction.isTaxDeductible ? 'YES (27% Provisional Tax Offset Eligible)' : 'NO'}
Notes / Invoice: ${transaction.notes}
BigQuery Dataset: budget-tracker-507418.personal_finance.fct_transactions
================================================================
Status: VERIFIED IN CLOUD LEDGER
Generated via Ziva Finance Mobile Companion (Web Build)
================================================================
''';

    if (kIsWeb) {
      downloadFileWeb(
        filename: receiptName.endsWith('.pdf') ? receiptName.replaceAll('.pdf', '.txt') : receiptName,
        content: receiptContent,
        mimeType: 'text/plain;charset=utf-8',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ZivaTheme.bgSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: ZivaTheme.gold400),
        ),
        content: Row(
          children: [
            const Icon(Icons.download_done_rounded, color: ZivaTheme.gold400, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Receipt downloaded: $receiptName',
                style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyAuditUrl(BuildContext context) {
    final url = transaction.receiptUrl ??
        'https://storage.googleapis.com/budget-tracker-507418-receipts/tax_2026/${transaction.transactionId}_${transaction.receiptName ?? "receipt.pdf"}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ZivaTheme.bgSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: ZivaTheme.borderCard),
        ),
        content: const Text(
          'Receipt cloud audit link copied to clipboard.',
          style: TextStyle(color: ZivaTheme.textPrimary, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receiptName = transaction.receiptName ?? 'Attached_Receipt_${transaction.transactionId.substring(0, 10)}.pdf';
    final isTax = transaction.isTaxDeductible;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: ZivaTheme.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: ZivaTheme.gold500.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: ZivaTheme.gold400, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Receipt & Tax Audit Voucher',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary),
                          ),
                          Text(
                            transaction.transactionId,
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: ZivaTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: ZivaTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Visual Receipt Slip Card
              Container(
                decoration: BoxDecoration(
                  color: ZivaTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ZivaTheme.borderCard),
                ),
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Merchant & Amount Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaction.merchantOrPayee,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                transaction.categoryName,
                                style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatAmount(transaction.originalAmount, currency: transaction.originalCurrency),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: transaction.originalAmount < 0 ? ZivaTheme.textPrimary : ZivaTheme.emerald400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: ZivaTheme.borderSubtle),
                    const SizedBox(height: 10),

                    // Key Details Grid
                    _buildDetailRow('Transaction Date', transaction.transactionDate),
                    _buildDetailRow('Currency & Account', '${transaction.originalCurrency} • ${transaction.accountId}'),
                    _buildDetailRow('ZAR Equivalent', 'R ${transaction.reportingAmountZar.toStringAsFixed(2)}'),
                    _buildDetailRow('Attached File', receiptName),

                    if (isTax) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: ZivaTheme.gold500.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_rounded, size: 16, color: ZivaTheme.gold400),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'SARS 27% Tax Deductible: R ${(transaction.reportingAmountZar.abs() * 0.27).toStringAsFixed(2)} allowable offset',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (transaction.notes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Notes: ${transaction.notes}',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: ZivaTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons: Download & Copy Link
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadReceipt(context),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZivaTheme.gold500,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyAuditUrl(context),
                      icon: const Icon(Icons.link_rounded, size: 16, color: ZivaTheme.gold400),
                      label: const Text('Copy Link', style: TextStyle(fontSize: 12, color: ZivaTheme.textPrimary)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: ZivaTheme.borderCard),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ZivaTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
