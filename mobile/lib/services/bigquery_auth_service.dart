import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/constants/gcp_config.dart';

/// BigQuery Authentication Service
/// Manages authentication configuration, service account credentials loading from
/// assets and .env / dart-define, and telemetry for BigQuery queries.
class BigQueryAuthService {
  static final BigQueryAuthService instance = BigQueryAuthService._();
  BigQueryAuthService._();

  Map<String, dynamic>? _serviceAccountKey;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  bool get isKeyLoaded => _serviceAccountKey != null;

  String get serviceAccountEmail =>
      (_serviceAccountKey?['client_email'] as String?) ??
      const String.fromEnvironment('BIGQUERY_SERVICE_ACCOUNT', defaultValue: GcpConfig.serviceAccountEmail);

  String get projectId =>
      (_serviceAccountKey?['project_id'] as String?) ??
      const String.fromEnvironment('GCP_PROJECT_ID', defaultValue: GcpConfig.projectId);

  String get datasetId =>
      (_serviceAccountKey?['dataset_id'] as String?) ??
      const String.fromEnvironment('BIGQUERY_DATASET', defaultValue: GcpConfig.datasetId);

  String get location =>
      (_serviceAccountKey?['location'] as String?) ??
      const String.fromEnvironment('BIGQUERY_LOCATION', defaultValue: GcpConfig.location);

  List<String> get assignedRoles {
    final roles = _serviceAccountKey?['roles'];
    if (roles is List) {
      return roles.map((e) => e.toString()).toList();
    }
    return GcpConfig.assignedRoles;
  }

  /// Loads service account JSON key from assets/credentials/ or fallback
  Future<bool> loadCredentialsFromAssets() async {
    try {
      final jsonString =
          await rootBundle.loadString(GcpConfig.serviceAccountAssetPath);

      if (jsonString.trim().isEmpty) {
        _serviceAccountKey = null;
        _isLoaded = true;
        debugPrint('[BigQueryAuthService] Asset file is empty. Using default GCP configuration.');
        return false;
      }

      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic> && decoded.containsKey('client_email')) {
        _serviceAccountKey = decoded;
        _isLoaded = true;
        debugPrint('[BigQueryAuthService] Successfully loaded service account credentials for: $serviceAccountEmail');
        return true;
      }

      _serviceAccountKey = null;
      _isLoaded = true;
      return false;
    } catch (e) {
      debugPrint('[BigQueryAuthService] Note: Service account JSON not loaded from assets: $e');
      _serviceAccountKey = null;
      _isLoaded = true;
      return false;
    }
  }

  /// Diagnostics telemetry map
  Map<String, dynamic> getAuthDiagnostics() {
    return {
      'serviceAccountEmail': serviceAccountEmail,
      'projectId': projectId,
      'datasetId': datasetId,
      'location': location,
      'assignedRoles': assignedRoles,
      'assetKeyConfiguredPath': GcpConfig.serviceAccountAssetPath,
      'isKeyLoadedFromAssets': isKeyLoaded,
      'authMode': isKeyLoaded
          ? 'SERVICE_ACCOUNT_CREDENTIALS_JSON'
          : 'SECURE_AUTHENTICATED_PROXY_GATEWAY',
    };
  }
}
