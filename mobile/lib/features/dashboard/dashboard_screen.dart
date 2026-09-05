import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/account_model.dart';
import '../../models/transaction_model.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_engine.dart';
import '../ledger/quick_entry_sheet.dart';
import '../settings/developer_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToLedger;

  const DashboardScreen({super.key, required this.onNavigateToLedger});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedCurrency = 'ZAR';
  List<AccountModel> _accounts = [];
  List<TransactionModel> _recentTransactions = [];
  bool _isLoading = true;
  int _secretTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final accounts = await SqliteService.instance.getLocalAccounts();
    final txs = await SqliteService.instance.getTransactions(limit: 5);

    setState(() {
      _accounts = accounts.isNotEmpty ? accounts : _fallbackAccounts;
      _recentTransactions = txs;
      _isLoading = false;
    });
  }

  // Fallback initial accounts if local SQLite has not yet synced from BigQuery
  List<AccountModel> get _fallbackAccounts => [
        AccountModel(
          accountId: 'ACC_ZA_CAPITEC_DAILY',
          accountName: 'Capitec Daily Cheque',
          financialInstitution: 'Capitec Bank',
          countryCode: 'ZA',
          primaryCurrency: 'ZAR',
          cashFlowTier: 'DAILY_SPENDING',
          accountType: 'CHECKING',
          nativeBalance: 18450.00,
        ),
        AccountModel(
          accountId: 'ACC_ZA_FNB_MONTHLY',
          accountName: 'FNB Commercial Monthly',
          financialInstitution: 'First National Bank',
          countryCode: 'ZA',
          primaryCurrency: 'ZAR',
          cashFlowTier: 'MONTHLY_ALLOCATION',
          accountType: 'CHECKING',
          nativeBalance: 32800.00,
        ),
        AccountModel(
          accountId: 'ACC_ZA_DISCOVERY_VAULT',
          accountName: 'Discovery 32-Day Notice',
          financialInstitution: 'Discovery Bank',
          countryCode: 'ZA',
          primaryCurrency: 'ZAR',
          cashFlowTier: 'LONG_TERM_VAULT',
          accountType: 'SAVINGS',
          nativeBalance: 150000.00,
        ),
        AccountModel(
          accountId: 'ACC_ZA_EE_EQUITIES_VAULT',
          accountName: 'EasyEquities S&P500 & Top40 TFSA',
          financialInstitution: 'EasyEquities',
          countryCode: 'ZA',
          primaryCurrency: 'ZAR',
          cashFlowTier: 'LONG_TERM_VAULT',
          accountType: 'INVESTMENT_BROKER',
          nativeBalance: 680000.00,
        ),
      ];

  double get _totalNetWorthInSelectedCurrency {
    double totalZar = 0;
    for (final acc in _accounts) {
      totalZar += CurrencyFormatter.convert(
        amount: acc.nativeBalance,
        fromCurrency: acc.primaryCurrency,
        toCurrency: 'ZAR',
      );
    }
    return CurrencyFormatter.convert(
      amount: totalZar,
      fromCurrency: 'ZAR',
      toCurrency: _selectedCurrency,
    );
  }

  void _onBrandHeaderTapped() {
    _secretTapCount++;
    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DeveloperSettingsScreen()),
      );
    }
  }

  void _openQuickEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickEntryBottomSheet(
        onTransactionLogged: (newTx) {
          setState(() {
            _recentTransactions.insert(0, newTx);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onBrandHeaderTapped,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ZivaTheme.gold500.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ZivaTheme.gold500.withOpacity(0.4)),
                ),
                child: const Icon(Icons.diamond_outlined, color: ZivaTheme.gold400, size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('ZIVA FINANCE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  Text('COMMAND CENTER', style: TextStyle(fontSize: 9, color: ZivaTheme.textMuted, letterSpacing: 0.5)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: ZivaTheme.textSecondary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeveloperSettingsScreen()),
              );
            },
            tooltip: 'Developer Settings & OTA',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await SyncEngine.instance.processQueue();
          await SyncEngine.instance.refreshFromBigQuery();
          await _loadDashboardData();
        },
        color: ZivaTheme.gold500,
        backgroundColor: ZivaTheme.bgSurface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Offline Sync Status Banner (if pending mutations exist)
              ValueListenableBuilder<int>(
                valueListenable: SyncEngine.instance.pendingCount,
                builder: (context, count, _) {
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: ZivaTheme.gold500.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ZivaTheme.gold500.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_queue_rounded, color: ZivaTheme.gold400, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$count transaction mutation${count == 1 ? '' : 's'} waiting to sync to BigQuery',
                            style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => SyncEngine.instance.processQueue(),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: const Text('SYNC NOW', style: TextStyle(color: ZivaTheme.gold400, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Total Net Worth Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PORTFOLIO NET WORTH',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ZivaTheme.gold400,
                              letterSpacing: 0.8,
                            ),
                          ),
                          // Currency Selector Pills
                          Row(
                            children: ['ZAR', 'USD', 'ZiG'].map((curr) {
                              final isSelected = _selectedCurrency == curr;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedCurrency = curr),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected ? ZivaTheme.gold500 : ZivaTheme.bgSurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    curr,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : ZivaTheme.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        CurrencyFormatter.formatAmount(
                          _totalNetWorthInSelectedCurrency,
                          currency: _selectedCurrency,
                        ),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: ZivaTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 14, color: ZivaTheme.emerald400),
                          const SizedBox(width: 4),
                          Text(
                            'Secured with SQLite Offline Sync & Face ID',
                            style: TextStyle(fontSize: 11, color: ZivaTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Cash Flow Tiers Breakdown Header
              const Text(
                'CASH FLOW TIERS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ZivaTheme.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // Tier 1: Daily Spending
              _buildTierCard(
                tierName: 'Tier 1: Daily Spending',
                description: 'Capitec & EcoCash Instant Liquidity',
                icon: Icons.flash_on_rounded,
                iconColor: ZivaTheme.cyan400,
                filterTier: 'DAILY_SPENDING',
              ),
              const SizedBox(height: 10),

              // Tier 2: Monthly Allocations
              _buildTierCard(
                tierName: 'Tier 2: Monthly Allocations',
                description: 'FNB Commercial & Fixed Commitments',
                icon: Icons.calendar_month_rounded,
                iconColor: ZivaTheme.gold400,
                filterTier: 'MONTHLY_ALLOCATION',
              ),
              const SizedBox(height: 10),

              // Tier 3: Long-Term Vaults
              _buildTierCard(
                tierName: 'Tier 3: Long-Term Vaults',
                description: 'Discovery 32-Day & EasyEquities TFSA',
                icon: Icons.lock_outline_rounded,
                iconColor: ZivaTheme.emerald400,
                filterTier: 'LONG_TERM_VAULT',
              ),

              const SizedBox(height: 24),

              // Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECENT LEDGER ACTIVITY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ZivaTheme.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToLedger,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('VIEW ALL', style: TextStyle(fontSize: 11, color: ZivaTheme.gold400, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_recentTransactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: const Center(
                    child: Text('No recent entries found. Tap + to add an entry.', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                  ),
                )
              else
                ..._recentTransactions.take(3).map((tx) {
                  final isExpense = tx.originalAmount < 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ZivaTheme.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ZivaTheme.borderCard),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          color: isExpense ? ZivaTheme.rose400 : ZivaTheme.emerald400,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tx.merchantOrPayee, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(tx.categoryName, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatAmount(tx.originalAmount, currency: tx.originalCurrency),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: isExpense ? ZivaTheme.textPrimary : ZivaTheme.emerald400,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(tx.transactionDate, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10)),
                                const SizedBox(width: 4),
                                if (tx.isSynced)
                                  const Icon(Icons.check_circle_rounded, size: 10, color: ZivaTheme.emerald400)
                                else
                                  const Icon(Icons.schedule_rounded, size: 10, color: ZivaTheme.gold400),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // Quick Log Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openQuickEntry,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Log Transaction Offline'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required String tierName,
    required String description,
    required IconData icon,
    required Color iconColor,
    required String filterTier,
  }) {
    final tierAccounts = _accounts.where((a) => a.cashFlowTier == filterTier).toList();
    double tierTotalZar = 0;
    for (final acc in tierAccounts) {
      tierTotalZar += CurrencyFormatter.convert(
        amount: acc.nativeBalance,
        fromCurrency: acc.primaryCurrency,
        toCurrency: 'ZAR',
      );
    }
    final tierValConverted = CurrencyFormatter.convert(
      amount: tierTotalZar,
      fromCurrency: 'ZAR',
      toCurrency: _selectedCurrency,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tierName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ZivaTheme.textPrimary)),
                  Text(description, style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.formatAmount(tierValConverted, currency: _selectedCurrency),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: ZivaTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
