import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/transaction_model.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_engine.dart';
import '../../services/tax_export_service.dart';
import 'quick_entry_sheet.dart';
import 'receipt_viewer_sheet.dart';

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
    showModalBottomSheet<void>(
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

  void _showReceiptViewer(TransactionModel tx) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiptViewerSheet(transaction: tx),
    );
  }

  void _exportTaxReport() {
    final result = TaxExportService.instance.exportAndDownload(
      transactions: _transactions,
      taxYear: 2026,
    );

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
            const Icon(Icons.file_download_done_rounded, color: ZivaTheme.gold400, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tax Audit Report Downloaded: ${result.filename} (${result.recordCount} items, R ${result.estimatedTaxSavingZar.toStringAsFixed(2)} allowable offset)',
                style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(TransactionModel tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZivaTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ZivaTheme.borderCard),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ZivaTheme.roseBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: ZivaTheme.rose400, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Delete Transaction',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete this transaction?',
              style: TextStyle(color: ZivaTheme.textMuted.withValues(alpha: 0.9), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZivaTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ZivaTheme.borderCard),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.merchantOrPayee,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary, fontSize: 13),
                        ),
                        Text(
                          '${tx.categoryName} • ${tx.transactionDate}',
                          style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatAmount(tx.originalAmount, currency: tx.originalCurrency),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: ZivaTheme.rose400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This action will immediately remove the entry from your ledger and execute a hard DELETE query on the BigQuery warehouse.',
              style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: ZivaTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZivaTheme.rose400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteTransaction(TransactionModel tx) async {
    final deletedId = tx.transactionId;
    setState(() {
      _transactions.removeWhere((t) => t.transactionId == deletedId);
    });

    try {
      await SqliteService.instance.deleteTransaction(deletedId);
      if (mounted) {
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
                const Icon(Icons.delete_sweep_rounded, color: ZivaTheme.rose400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Deleted ${tx.merchantOrPayee} from ledger & BigQuery.',
                    style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to delete transaction: $e');
    }
  }

  Future<void> _confirmDeleteTransaction(TransactionModel tx) async {
    final confirmed = await _showDeleteConfirmationDialog(tx);
    if (confirmed) {
      await _deleteTransaction(tx);
    }
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

  double get _totalTaxDeductibleZar {
    return _transactions
        .where((t) => t.isTaxDeductible)
        .fold<double>(0.0, (sum, t) => sum + t.reportingAmountZar.abs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      appBar: AppBar(
        title: const Text('Ledger & Sync Queue'),
        actions: [
          // Download Tax Report Action
          IconButton(
            icon: const Icon(Icons.description_outlined, color: ZivaTheme.gold400),
            tooltip: 'Download SARS Tax Audit Report (CSV & Receipts)',
            onPressed: _exportTaxReport,
          ),

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

          // Tax Audit Report Banner (Active when viewing TAX tab)
          if (_activeFilter == 'TAX')
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZivaTheme.gold500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: ZivaTheme.gold400, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SARS Provisional Tax Deductions',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary),
                        ),
                        Text(
                          'R ${(_totalTaxDeductibleZar * 0.27).toStringAsFixed(2)} estimated 27% cashflow offset (R ${_totalTaxDeductibleZar.toStringAsFixed(2)} allowable gross)',
                          style: const TextStyle(fontSize: 11, color: ZivaTheme.gold300),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: _exportTaxReport,
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Export Tax Report', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZivaTheme.gold500,
                      foregroundColor: Colors.black,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
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

                            return Dismissible(
                              key: Key(tx.transactionId),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                return await _showDeleteConfirmationDialog(tx);
                              },
                              onDismissed: (direction) {
                                _deleteTransaction(tx);
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                margin: const EdgeInsets.symmetric(vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: ZivaTheme.roseBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: ZivaTheme.rose400.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_forever_rounded, color: ZivaTheme.rose400, size: 22),
                                    SizedBox(width: 6),
                                    Text(
                                      'DELETE',
                                      style: TextStyle(
                                        color: ZivaTheme.rose400,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              child: Card(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _showReceiptViewer(tx),
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
                                                        color: ZivaTheme.gold500.withValues(alpha: 0.15),
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
                                                  if (tx.hasReceipt) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: ZivaTheme.emerald400.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.receipt_rounded, size: 8, color: ZivaTheme.emerald400),
                                                          SizedBox(width: 2),
                                                          Text(
                                                            'RECEIPT',
                                                            style: TextStyle(
                                                              color: ZivaTheme.emerald400,
                                                              fontSize: 8,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
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
                                                  const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
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

                                        // Delete Trash Icon Button
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: ZivaTheme.rose400),
                                          tooltip: 'Delete Transaction',
                                          splashRadius: 18,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                          onPressed: () => _confirmDeleteTransaction(tx),
                                        ),
                                      ],
                                    ),
                                  ),
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
          color: isActive ? ZivaTheme.gold500.withValues(alpha: 0.18) : ZivaTheme.bgSurface,
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
          Icon(Icons.receipt_long_outlined, size: 48, color: ZivaTheme.textMuted.withValues(alpha: 0.5)),
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
