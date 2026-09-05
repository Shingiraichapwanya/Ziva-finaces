import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../models/sync_queue_item.dart';

class SqliteService {
  static final SqliteService instance = SqliteService._internal();
  static Database? _database;

  SqliteService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'ziva_finance.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 1. Local Transactions Cache
        await db.execute('''
          CREATE TABLE local_transactions (
            transaction_id TEXT PRIMARY KEY,
            transaction_date TEXT NOT NULL,
            account_id TEXT NOT NULL,
            category_id TEXT NOT NULL,
            category_name TEXT,
            transaction_type TEXT NOT NULL,
            original_amount REAL NOT NULL,
            original_currency TEXT NOT NULL,
            reporting_amount_zar REAL NOT NULL,
            reporting_amount_usd REAL NOT NULL,
            merchant_or_payee TEXT,
            payment_method TEXT,
            is_tax_deductible INTEGER NOT NULL DEFAULT 0,
            notes TEXT,
            tags TEXT,
            is_synced INTEGER NOT NULL DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // 2. Offline Sync Mutation Queue
        await db.execute('''
          CREATE TABLE sync_queue (
            queue_id TEXT PRIMARY KEY,
            transaction_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'PENDING',
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');

        // 3. Local Accounts Cache
        await db.execute('''
          CREATE TABLE local_accounts (
            account_id TEXT PRIMARY KEY,
            account_name TEXT NOT NULL,
            financial_institution TEXT,
            country_code TEXT,
            primary_currency TEXT,
            cash_flow_tier TEXT,
            account_type TEXT,
            is_vault_locked INTEGER DEFAULT 0,
            withdrawal_notice_days INTEGER DEFAULT 0,
            account_number_masked TEXT,
            native_balance REAL NOT NULL,
            is_active INTEGER DEFAULT 1
          )
        ''');

        await db.execute('CREATE INDEX idx_tx_date ON local_transactions(transaction_date DESC)');
        await db.execute('CREATE INDEX idx_sync_status ON sync_queue(sync_status)');
      },
    );
  }

  // --- Transactions ---

  Future<void> saveTransaction(TransactionModel tx) async {
    final db = await database;
    await db.insert(
      'local_transactions',
      tx.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveTransactionsBatch(List<TransactionModel> list) async {
    final db = await database;
    final batch = db.batch();
    for (final tx in list) {
      batch.insert(
        'local_transactions',
        tx.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<TransactionModel>> getTransactions({int limit = 100}) async {
    final db = await database;
    final result = await db.query(
      'local_transactions',
      orderBy: 'transaction_date DESC, created_at DESC',
      limit: limit,
    );
    return result.map((map) => TransactionModel.fromJson(map)).toList();
  }

  Future<void> markTransactionSynced(String transactionId) async {
    final db = await database;
    await db.update(
      'local_transactions',
      {'is_synced': 1},
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  // --- Sync Queue ---

  Future<SyncQueueItem> enqueueMutation({
    required String transactionId,
    required String payloadJson,
  }) async {
    final db = await database;
    final queueItem = SyncQueueItem(
      queueId: const Uuid().v4(),
      transactionId: transactionId,
      payloadJson: payloadJson,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      syncStatus: SyncStatus.pending,
      retryCount: 0,
    );

    await db.insert(
      'sync_queue',
      queueItem.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return queueItem;
  }

  Future<List<SyncQueueItem>> getPendingQueue() async {
    final db = await database;
    final result = await db.query(
      'sync_queue',
      where: "sync_status IN ('PENDING', 'FAILED')",
      orderBy: 'created_at ASC',
    );
    return result.map((map) => SyncQueueItem.fromSqlite(map)).toList();
  }

  Future<List<SyncQueueItem>> getAllQueueItems() async {
    final db = await database;
    final result = await db.query(
      'sync_queue',
      orderBy: 'created_at DESC',
    );
    return result.map((map) => SyncQueueItem.fromSqlite(map)).toList();
  }

  Future<void> updateQueueItem(SyncQueueItem item) async {
    final db = await database;
    await db.update(
      'sync_queue',
      item.toSqliteMap(),
      where: 'queue_id = ?',
      whereArgs: [item.queueId],
    );
  }

  Future<int> getPendingQueueCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(1) FROM sync_queue WHERE sync_status IN ('PENDING', 'FAILED')",
    ));
    return count ?? 0;
  }

  Future<void> clearCompletedQueue() async {
    final db = await database;
    await db.delete('sync_queue', where: "sync_status = 'SYNCED'");
  }

  // --- Accounts ---

  Future<void> saveAccountsBatch(List<AccountModel> accounts) async {
    final db = await database;
    final batch = db.batch();
    for (final acc in accounts) {
      batch.insert(
        'local_accounts',
        acc.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<AccountModel>> getLocalAccounts() async {
    final db = await database;
    final result = await db.query('local_accounts', where: 'is_active = 1');
    return result.map((m) => AccountModel.fromJson(m)).toList();
  }
}
