import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/transaction_model.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_engine.dart';
import 'quick_entry_sheet.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String _activeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadLocalLedger();
  }

  Future<void> _loadLocalLedger() async {
    setState(() => _isLoading = true);
    final txs = await SqliteService.instance.getTransactions(limit: 100);
    setState(() {
      _transactions = txs;
      _isLoading = false;
    });
  }

  Future<void> _onRefresh() async {
    // 1. Process any pending offline mutations
    await SyncEngine.instance.processQueue();
    // 2. Fetch fresh ledger items from BigQuery
    await SyncEngine.instance.refreshFromBigQuery();
    // 3. Reload local SQLite view
    await _loadLocalLedger();
  }

  void _openQuickEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickEntryBottomSheet(
        onTransactionLogged: (newTx) {
          setState(() {
            _transactions.insert(0, newTx);
          });
        },
      ),
    );
  }

  List<TransactionModel> get _filteredTransactions {
    if (_activeFilter == 'EXPENSES') {
      return _transactions.where((t) => t.originalAmount < 0).toList();
    } else if (_activeFilter == 'INCOME') {
      return _transactions.where((t) => t.originalAmount > 0).toList();
    } else if (_activeFilter == 'TAX') {
      return _transactions.where((t) => t.isTaxDeductible).toList();
    }
    return _transactions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      appBar: AppBar(
        title: const Text('Ledger & Sync Queue'),
        actions: [
          // Live Sync Status Icon with badge count
          ValueListenableBuilder<int>(
            valueListenable: SyncEngine.instance.pendingCount,
            builder: (context, count, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: SyncEngine.instance.isSyncing,
                builder: (context, isSyncing, _) {
                  return IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          isSyncing ? Icons.sync_rounded : (count > 0 ? Icons.cloud_queue_rounded : Icons.cloud_done_rounded),
                          color: count > 0 ? ZivaTheme.gold400 : ZivaTheme.emerald400,
                        ),
                        if (count > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: ZivaTheme.rose500,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: _onRefresh,
                    tooltip: count > 0 ? '$count items queued offline. Tap to sync.' : 'All synced to BigQuery',
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openQuickEntry,
        backgroundColor: ZivaTheme.gold500,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Entry', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All Entries'),
                  const SizedBox(width: 8),
                  _buildFilterChip('EXPENSES', 'Expenses'),
                  const SizedBox(width: 8),
                  _buildFilterChip('INCOME', 'Inflows'),
                  const SizedBox(width: 8),
                  _buildFilterChip('TAX', 'Tax Deductible'),
                ],
              ),
            ),
          ),

          // Ledger Feed
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: ZivaTheme.gold500,
              backgroundColor: ZivaTheme.bgSurface,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: ZivaTheme.gold500))
                  : _filteredTransactions.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
                          itemCount: _filteredTransactions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tx = _filteredTransactions[index];
                            final isExpense = tx.originalAmount < 0;

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Row(
                                  children: [
                                    // Direction Icon
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isExpense ? ZivaTheme.roseBg : ZivaTheme.emeraldBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                        color: isExpense ? ZivaTheme.rose400 : ZivaTheme.emerald400,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Payee & Category
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.merchantOrPayee,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: ZivaTheme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                tx.categoryName,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: ZivaTheme.textMuted,
                                                ),
                                              ),
                                              if (tx.isTaxDeductible) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: ZivaTheme.gold500.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'TAX SHIELD',
                                                    style: TextStyle(
                                                      color: ZivaTheme.gold400,
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Amount & Sync Badge
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.formatAmount(
                                            tx.originalAmount,
                                            currency: tx.originalCurrency,
                                          ),
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: isExpense ? ZivaTheme.textPrimary : ZivaTheme.emerald400,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              tx.transactionDate,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: ZivaTheme.textMuted,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Sync Status Tag
                                            if (tx.isSynced)
                                              const Icon(Icons.check_circle_rounded, size: 13, color: ZivaTheme.emerald400)
                                            else
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Icons.schedule_rounded, size: 12, color: ZivaTheme.gold400),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'QUEUED',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: ZivaTheme.gold400,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isActive = _activeFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? ZivaTheme.gold500.withOpacity(0.18) : ZivaTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? ZivaTheme.gold500 : ZivaTheme.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? ZivaTheme.gold300 : ZivaTheme.textSecondary,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: ZivaTheme.textMuted.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text(
            'No transactions recorded yet',
            style: TextStyle(color: ZivaTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap "Add Entry" to log offline or online',
            style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
