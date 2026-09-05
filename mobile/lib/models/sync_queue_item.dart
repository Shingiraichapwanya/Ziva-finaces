import 'dart:convert';

enum SyncStatus { pending, syncing, synced, failed }

class SyncQueueItem {
  final String queueId;
  final String transactionId;
  final String payloadJson;
  final String createdAt;
  final SyncStatus syncStatus;
  final int retryCount;
  final String? lastError;

  SyncQueueItem({
    required this.queueId,
    required this.transactionId,
    required this.payloadJson,
    required this.createdAt,
    this.syncStatus = SyncStatus.pending,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> get payload {
    try {
      return jsonDecode(payloadJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  factory SyncQueueItem.fromSqlite(Map<String, dynamic> map) {
    SyncStatus status = SyncStatus.pending;
    switch ((map['sync_status'] as String?)?.toUpperCase()) {
      case 'SYNCING':
        status = SyncStatus.syncing;
        break;
      case 'SYNCED':
        status = SyncStatus.synced;
        break;
      case 'FAILED':
        status = SyncStatus.failed;
        break;
      default:
        status = SyncStatus.pending;
    }

    return SyncQueueItem(
      queueId: map['queue_id'] as String,
      transactionId: map['transaction_id'] as String,
      payloadJson: map['payload_json'] as String,
      createdAt: map['created_at'] as String,
      syncStatus: status,
      retryCount: (map['retry_count'] as int?) ?? 0,
      lastError: map['last_error'] as String?,
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'queue_id': queueId,
      'transaction_id': transactionId,
      'payload_json': payloadJson,
      'created_at': createdAt,
      'sync_status': syncStatus.name.toUpperCase(),
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  SyncQueueItem copyWith({
    SyncStatus? syncStatus,
    int? retryCount,
    String? lastError,
  }) {
    return SyncQueueItem(
      queueId: queueId,
      transactionId: transactionId,
      payloadJson: payloadJson,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
