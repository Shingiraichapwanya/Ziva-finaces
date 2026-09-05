import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'sqlite_service.dart';
import '../models/sync_queue_item.dart';

class SyncEngine {
  static final SyncEngine instance = SyncEngine._internal();

  final SqliteService _sqlite = SqliteService.instance;
  final ApiService _api = ApiService();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> lastSyncTime = ValueNotifier<DateTime?>(null);

  SyncEngine._internal();

  /// Initialize background network listener and queue counter
  Future<void> initialize() async {
    await updatePendingCount();

    // Listen for network restoration
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        debugPrint('[SyncEngine] Network connection established. Processing sync queue...');
        processQueue();
      }
    });

    // Initial check
    final initial = await _connectivity.checkConnectivity();
    if (initial.any((r) => r != ConnectivityResult.none)) {
      unawaited(processQueue());
    }
  }

  /// Update reactive count of offline items waiting to sync
  Future<int> updatePendingCount() async {
    final count = await _sqlite.getPendingQueueCount();
    pendingCount.value = count;
    return count;
  }

  /// Process all pending and failed mutations in SQLite queue
  Future<void> processQueue() async {
    if (isSyncing.value) return;

    final pending = await _sqlite.getPendingQueue();
    if (pending.isEmpty) {
      pendingCount.value = 0;
      return;
    }

    isSyncing.value = true;
    debugPrint('[SyncEngine] Found ${pending.length} mutations to sync to BigQuery.');

    for (final item in pending) {
      try {
        // Mark status as SYNCING
        await _sqlite.updateQueueItem(item.copyWith(syncStatus: SyncStatus.syncing));

        // Transmit mutation payload to BigQuery backend
        final result = await _api.postTransaction(item.payload);

        if (result['success'] == true) {
          // Success: Mark queue item SYNCED and update local ledger record
          await _sqlite.updateQueueItem(item.copyWith(syncStatus: SyncStatus.synced));
          await _sqlite.markTransactionSynced(item.transactionId);
          debugPrint('[SyncEngine] Successfully synced mutation ${item.transactionId} to BigQuery.');
        } else {
          throw Exception(result['error'] ?? 'BigQuery insertion failed');
        }
      } catch (err) {
        debugPrint('[SyncEngine] Error syncing mutation ${item.transactionId}: $err');
        await _sqlite.updateQueueItem(
          item.copyWith(
            syncStatus: SyncStatus.failed,
            retryCount: item.retryCount + 1,
            lastError: err.toString(),
          ),
        );
      }
    }

    lastSyncTime.value = DateTime.now();
    isSyncing.value = false;
    await updatePendingCount();
  }

  /// Pull fresh accounts and transactions from BigQuery to synchronize SQLite cache
  Future<void> refreshFromBigQuery() async {
    try {
      final accounts = await _api.fetchAccounts();
      final transactions = await _api.fetchTransactions(limit: 100);

      await _sqlite.saveAccountsBatch(accounts);
      await _sqlite.saveTransactionsBatch(transactions);

      debugPrint('[SyncEngine] Cache refreshed from BigQuery: ${accounts.length} accounts, ${transactions.length} transactions.');
    } catch (e) {
      debugPrint('[SyncEngine] Failed to refresh from BigQuery: $e');
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
