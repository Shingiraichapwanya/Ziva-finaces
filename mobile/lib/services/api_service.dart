import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/account_model.dart';
import '../models/transaction_model.dart';

class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({String? customBaseUrl, http.Client? client})
      : baseUrl = customBaseUrl ?? ApiConstants.defaultBaseUrl,
        _client = client ?? http.Client();

  /// Probe BigQuery backend health
  Future<Map<String, dynamic>> checkHealth() async {
    final uri = Uri.parse('$baseUrl${ApiConstants.healthEndpoint}');
    final res = await _client.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Backend health check returned ${res.statusCode}');
  }

  /// Fetch accounts with live cumulative BigQuery balances
  Future<List<AccountModel>> fetchAccounts() async {
    final uri = Uri.parse('$baseUrl${ApiConstants.accountsEndpoint}');
    final res = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => AccountModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch accounts: ${res.statusCode}');
  }

  /// Fetch primary ledger transactions from BigQuery
  Future<List<TransactionModel>> fetchTransactions({int limit = 100}) async {
    final uri = Uri.parse('$baseUrl${ApiConstants.transactionsEndpoint}?limit=$limit');
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => TransactionModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch transactions: ${res.statusCode}');
  }

  /// Ingest transaction mutation into BigQuery
  Future<Map<String, dynamic>> postTransaction(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl${ApiConstants.transactionsEndpoint}');
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to ingest transaction to BigQuery: ${res.statusCode} ${res.body}');
  }

  /// Fetch performance and analytics summary
  Future<Map<String, dynamic>> fetchAnalyticsSummary() async {
    final uri = Uri.parse('$baseUrl${ApiConstants.analyticsSummaryEndpoint}');
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch analytics summary: ${res.statusCode}');
  }
}
