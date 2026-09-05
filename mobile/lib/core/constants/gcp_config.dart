/// Google Cloud Platform & BigQuery Configuration for Ziva Finance
class GcpConfig {
  /// GCP Project ID hosting the financial data warehouse
  static const String projectId = 'budget-tracker-507418';

  /// Primary BigQuery dataset
  static const String datasetId = 'personal_finance';

  /// Default BigQuery compute/storage region
  static const String location = 'africa-south1';

  /// Dedicated service account for mobile BigQuery operations
  static const String serviceAccountEmail =
      'mobile-bigquery-client@budget-tracker-507418.iam.gserviceaccount.com';

  /// IAM Roles assigned:
  /// - roles/bigquery.dataEditor (Dataset & table read/write)
  /// - roles/bigquery.jobUser (Query job submission)
  static const List<String> assignedRoles = [
    'roles/bigquery.dataEditor',
    'roles/bigquery.jobUser',
  ];

  /// Relative asset path for service account JSON credentials if injected
  static const String serviceAccountAssetPath =
      'assets/credentials/mobile-bigquery-client.json';
}
