import 'dart:convert';

class TransactionModel {
  final String transactionId;
  final String transactionDate;
  final String accountId;
  final String categoryId;
  final String categoryName;
  final String transactionType; // 'EXPENSE', 'INCOME', 'ALLOCATION_TRANSFER'
  final double originalAmount;
  final String originalCurrency; // 'ZAR', 'USD', 'ZiG'
  final double reportingAmountZar;
  final double reportingAmountUsd;
  final String merchantOrPayee;
  final String paymentMethod;
  final bool isTaxDeductible;
  final String notes;
  final List<String> tags;
  final bool isSynced; // Local SQLite tracking flag

  TransactionModel({
    required this.transactionId,
    required this.transactionDate,
    required this.accountId,
    required this.categoryId,
    this.categoryName = 'General',
    required this.transactionType,
    required this.originalAmount,
    required this.originalCurrency,
    required this.reportingAmountZar,
    required this.reportingAmountUsd,
    required this.merchantOrPayee,
    this.paymentMethod = 'EFT/Card',
    this.isTaxDeductible = false,
    this.notes = '',
    this.tags = const ['mobile_app'],
    this.isSynced = true,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      transactionId: json['transactionId'] ?? json['transaction_id'] ?? '',
      transactionDate: json['transactionDate'] ?? json['transaction_date'] ?? DateTime.now().toIso8601String().split('T')[0],
      accountId: json['accountId'] ?? json['account_id'] ?? '',
      categoryId: json['categoryId'] ?? json['category_id'] ?? 'CAT_GENERAL',
      categoryName: json['categoryName'] ?? json['category_name'] ?? 'General',
      transactionType: json['transactionType'] ?? json['transaction_type'] ?? 'EXPENSE',
      originalAmount: (json['originalAmount'] ?? json['original_amount'] ?? 0.0).toDouble(),
      originalCurrency: json['originalCurrency'] ?? json['original_currency'] ?? 'ZAR',
      reportingAmountZar: (json['reportingAmountZar'] ?? json['reporting_amount_zar'] ?? 0.0).toDouble(),
      reportingAmountUsd: (json['reportingAmountUsd'] ?? json['reporting_amount_usd'] ?? 0.0).toDouble(),
      merchantOrPayee: json['merchantOrPayee'] ?? json['merchant_or_payee'] ?? 'Direct Entry',
      paymentMethod: json['paymentMethod'] ?? json['payment_method'] ?? 'EFT/Card',
      isTaxDeductible: json['isTaxDeductible'] == 1 || json['isTaxDeductible'] == true || json['is_tax_deductible'] == true,
      notes: json['notes'] ?? '',
      tags: json['tags'] is String
          ? List<String>.from(jsonDecode(json['tags']))
          : (json['tags'] is List ? List<String>.from(json['tags']) : ['mobile_app']),
      isSynced: json['is_synced'] == null ? true : (json['is_synced'] == 1 || json['is_synced'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'transactionDate': transactionDate,
      'accountId': accountId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'transactionType': transactionType,
      'originalAmount': originalAmount,
      'originalCurrency': originalCurrency,
      'reportingAmountZar': reportingAmountZar,
      'reportingAmountUsd': reportingAmountUsd,
      'merchantOrPayee': merchantOrPayee,
      'paymentMethod': paymentMethod,
      'isTaxDeductible': isTaxDeductible,
      'notes': notes,
      'tags': tags,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'transaction_id': transactionId,
      'transaction_date': transactionDate,
      'account_id': accountId,
      'category_id': categoryId,
      'category_name': categoryName,
      'transaction_type': transactionType,
      'original_amount': originalAmount,
      'original_currency': originalCurrency,
      'reporting_amount_zar': reportingAmountZar,
      'reporting_amount_usd': reportingAmountUsd,
      'merchant_or_payee': merchantOrPayee,
      'payment_method': paymentMethod,
      'is_tax_deductible': isTaxDeductible ? 1 : 0,
      'notes': notes,
      'tags': jsonEncode(tags),
      'is_synced': isSynced ? 1 : 0,
    };
  }
}
