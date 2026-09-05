import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/transaction_model.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_engine.dart';

class QuickEntryBottomSheet extends StatefulWidget {
  final Function(TransactionModel) onTransactionLogged;

  const QuickEntryBottomSheet({super.key, required this.onTransactionLogged});

  @override
  State<QuickEntryBottomSheet> createState() => _QuickEntryBottomSheetState();
}

class _QuickEntryBottomSheetState extends State<QuickEntryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _payeeController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCurrency = 'ZAR';
  String _selectedAccountId = 'ACC_ZA_CAPITEC_DAILY';
  String _selectedCategoryId = 'CAT_GROCERIES';
  String _selectedCategoryName = 'Groceries & Household Supplies';
  String _transactionType = 'EXPENSE';
  bool _isTaxDeductible = false;
  bool _isSubmitting = false;

  final List<Map<String, String>> _accounts = [
    {'id': 'ACC_ZA_CAPITEC_DAILY', 'name': 'Capitec Daily Cheque (ZAR)'},
    {'id': 'ACC_ZA_FNB_MONTHLY', 'name': 'FNB Commercial Monthly (ZAR)'},
    {'id': 'ACC_ZW_ECOCASH_USD', 'name': 'EcoCash USD Wallet (USD)'},
    {'id': 'ACC_ZW_ECOCASH_ZIG', 'name': 'EcoCash ZiG Wallet (ZiG)'},
    {'id': 'ACC_ZA_DISCOVERY_VAULT', 'name': 'Discovery 32-Day Notice (ZAR)'},
  ];

  final List<Map<String, String>> _categories = [
    {'id': 'CAT_GROCERIES', 'name': 'Groceries & Household Supplies', 'tax': '0'},
    {'id': 'CAT_TECH_HARDWARE', 'name': 'Productivity Tech & Work Hardware', 'tax': '1'},
    {'id': 'CAT_SOFTWARE_SAAS', 'name': 'Business Software & Cloud Subscriptions', 'tax': '1'},
    {'id': 'CAT_RENT', 'name': 'Residential Rent & Levies', 'tax': '0'},
    {'id': 'CAT_FIBRE_INTERNET', 'name': 'High-Speed Home Fibre', 'tax': '0'},
    {'id': 'CAT_DINING_COFFEE', 'name': 'Restaurants, Takeaways & Coffee', 'tax': '0'},
    {'id': 'CAT_TAX_STATUTORY', 'name': 'Provisional & Statutory Tax Payments', 'tax': '0'},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _payeeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final rawAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final finalAmount = _transactionType == 'EXPENSE' ? -rawAmount.abs() : rawAmount.abs();

    final now = DateTime.now();
    final dateStr = now.toIso8601String().split('T')[0];
    final txId = 'TX_MOB_${now.millisecondsSinceEpoch}';

    // Calculate reporting amounts
    final zarAmount = CurrencyFormatter.convert(
      amount: finalAmount,
      fromCurrency: _selectedCurrency,
      toCurrency: 'ZAR',
    );
    final usdAmount = CurrencyFormatter.convert(
      amount: finalAmount,
      fromCurrency: _selectedCurrency,
      toCurrency: 'USD',
    );

    final newTx = TransactionModel(
      transactionId: txId,
      transactionDate: dateStr,
      accountId: _selectedAccountId,
      categoryId: _selectedCategoryId,
      categoryName: _selectedCategoryName,
      transactionType: _transactionType,
      originalAmount: finalAmount,
      originalCurrency: _selectedCurrency,
      reportingAmountZar: zarAmount,
      reportingAmountUsd: usdAmount,
      merchantOrPayee: _payeeController.text.trim().isEmpty ? 'Direct Mobile Entry' : _payeeController.text.trim(),
      paymentMethod: 'EFT/Card',
      isTaxDeductible: _isTaxDeductible,
      notes: _notesController.text.trim(),
      tags: ['mobile_offline_entry'],
      isSynced: false, // Initially marked false until background worker syncs
    );

    // 1. Write to local SQLite database cache
    await SqliteService.instance.saveTransaction(newTx);

    // 2. Enqueue in SQLite sync queue with JSON payload
    await SqliteService.instance.enqueueMutation(
      transactionId: txId,
      payloadJson: jsonEncode(newTx.toJson()),
    );

    // 3. Trigger immediate background reconciliation if network is available
    SyncEngine.instance.processQueue();

    if (mounted) {
      widget.onTransactionLogged(newTx);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZivaTheme.bgSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: ZivaTheme.borderCard),
          ),
          content: Row(
            children: [
              const Icon(Icons.cloud_queue_rounded, color: ZivaTheme.gold400, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Transaction logged offline. Queued for BigQuery sync.',
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: ZivaTheme.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: ZivaTheme.borderCard)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Log Transaction (Offline-First)',
                      style: TextStyle(
                        color: ZivaTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: ZivaTheme.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount & Currency Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: ZivaTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.attach_money_rounded, color: ZivaTheme.gold400),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter amount';
                          if (double.tryParse(val) == null) return 'Invalid amount';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: const InputDecoration(labelText: 'Currency'),
                        dropdownColor: ZivaTheme.bgCard,
                        items: ['ZAR', 'USD', 'ZiG'].map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCurrency = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Account Picker
                DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Payment Account',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: ZivaTheme.cyan400),
                  ),
                  dropdownColor: ZivaTheme.bgCard,
                  items: _accounts.map((a) {
                    return DropdownMenuItem(
                      value: a['id'],
                      child: Text(a['name']!, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAccountId = val);
                  },
                ),
                const SizedBox(height: 16),

                // Category Picker
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined, color: ZivaTheme.emerald400),
                  ),
                  dropdownColor: ZivaTheme.bgCard,
                  items: _categories.map((c) {
                    return DropdownMenuItem(
                      value: c['id'],
                      child: Text(c['name']!, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final item = _categories.firstWhere((c) => c['id'] == val);
                      setState(() {
                        _selectedCategoryId = val;
                        _selectedCategoryName = item['name']!;
                        _isTaxDeductible = item['tax'] == '1';
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Merchant / Payee
                TextFormField(
                  controller: _payeeController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant or Payee',
                    hintText: 'e.g. Woolworths, Apple, Retainer',
                    prefixIcon: Icon(Icons.storefront_outlined, color: ZivaTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),

                // Tax Deductible Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: ZivaTheme.gold500,
                  title: const Text(
                    'SARS Tax Deductible (Business Offset)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ZivaTheme.textPrimary),
                  ),
                  subtitle: const Text(
                    'Flags for 27% provisional tax write-off',
                    style: TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                  ),
                  value: _isTaxDeductible,
                  onChanged: (val) => setState(() => _isTaxDeductible = val),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitTransaction,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('Save Offline & Queue Sync'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
