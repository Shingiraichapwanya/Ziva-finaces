import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../models/sync_queue_item.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/shorebird_service.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_engine.dart';

class DeveloperSettingsScreen extends StatefulWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  State<DeveloperSettingsScreen> createState() => _DeveloperSettingsScreenState();
}

class _DeveloperSettingsScreenState extends State<DeveloperSettingsScreen> {
  final ShorebirdService _shorebird = ShorebirdService.instance;
  final SqliteService _sqlite = SqliteService.instance;
  final ApiService _api = ApiService();

  int? _currentPatch;
  bool _isCheckingShorebird = false;
  String _shorebirdStatusMessage = 'Idle';

  List<SyncQueueItem> _queueItems = [];
  bool _isLoadingQueue = true;

  Map<String, dynamic>? _backendHealth;
  bool _isProbingBackend = false;

  @override
  void initState() {
    super.initState();
    _loadDeveloperData();
  }

  Future<void> _loadDeveloperData() async {
    // 1. Shorebird patch info
    final patch = await _shorebird.getCurrentPatchNumber();
    // 2. Local queue items
    final items = await _sqlite.getAllQueueItems();

    if (mounted) {
      setState(() {
        _currentPatch = patch;
        _queueItems = items;
        _isLoadingQueue = false;
      });
    }
  }

  Future<void> _checkForShorebirdUpdates() async {
    setState(() {
      _isCheckingShorebird = true;
      _shorebirdStatusMessage = 'Contacting Shorebird Code Push servers...';
    });

    try {
      final hasUpdate = await _shorebird.checkForUpdates();
      if (mounted) {
        setState(() {
          _isCheckingShorebird = false;
          _shorebirdStatusMessage = hasUpdate
              ? 'New OTA patch detected! Tap Update to download.'
              : 'App is up to date (No new OTA patches).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingShorebird = false;
          _shorebirdStatusMessage = 'Update check failed: $e';
        });
      }
    }
  }

  Future<void> _triggerForceSync() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting manual sync to BigQuery...')),
    );
    await SyncEngine.instance.processQueue();
    await _loadDeveloperData();
  }

  Future<void> _probeBackendHealth() async {
    setState(() => _isProbingBackend = true);
    try {
      final health = await _api.checkHealth();
      if (mounted) {
        setState(() {
          _backendHealth = health;
          _isProbingBackend = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _backendHealth = {'status': 'OFFLINE', 'error': e.toString()};
          _isProbingBackend = false;
        });
      }
    }
  }

  Future<void> _testBiometrics() async {
    final success = await BiometricService.instance.authenticate(
      reason: 'Developer Settings biometric verification test',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Biometric check PASSED' : 'Biometric check FAILED'),
          backgroundColor: success ? ZivaTheme.emeraldBg : ZivaTheme.roseBg,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      appBar: AppBar(
        title: const Text('Developer Settings & OTA Engine'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Shorebird OTA Code Push Panel
            _buildSectionHeader('SHOREBIRD OVER-THE-AIR (OTA) UPDATES'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Code Push Engine', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _shorebird.isShorebirdAvailable ? ZivaTheme.emeraldBg : ZivaTheme.gold500.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _shorebird.isShorebirdAvailable ? 'ACTIVE' : 'DEV SIMULATION',
                            style: TextStyle(
                              color: _shorebird.isShorebirdAvailable ? ZivaTheme.emerald400 : ZivaTheme.gold400,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Current Patch: ${_currentPatch != null ? 'Patch #$_currentPatch' : 'Base Binary (No patches)'}',
                      style: const TextStyle(fontSize: 12, color: ZivaTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Status: $_shorebirdStatusMessage',
                      style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isCheckingShorebird ? null : _checkForShorebirdUpdates,
                        icon: _isCheckingShorebird
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.system_update_alt_rounded, size: 16),
                        label: const Text('Check for OTA Patches'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 2. Offline SQLite Sync Queue Inspector
            _buildSectionHeader('OFFLINE SQLITE SYNC QUEUE INSPECTOR'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Local Database: ziva_finance.db', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('${_queueItems.length} total mutations logged in queue', style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20, color: ZivaTheme.textSecondary),
                          onPressed: _loadDeveloperData,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _triggerForceSync,
                            icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: ZivaTheme.gold400),
                            label: const Text('Force Sync to BigQuery', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            await _sqlite.clearCompletedQueue();
                            await _loadDeveloperData();
                          },
                          child: const Text('Clear Synced', style: TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_isLoadingQueue)
                      const Center(child: CircularProgressIndicator(color: ZivaTheme.gold500))
                    else if (_queueItems.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Text('Queue is completely clean. 0 pending items.', style: TextStyle(color: ZivaTheme.emerald400, fontSize: 12)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _queueItems.length,
                        separatorBuilder: (_, __) => const Divider(color: ZivaTheme.borderSubtle, height: 12),
                        itemBuilder: (context, idx) {
                          final item = _queueItems[idx];
                          final isSynced = item.syncStatus == SyncStatus.synced;
                          final isFailed = item.syncStatus == SyncStatus.failed;

                          return Row(
                            children: [
                              Icon(
                                isSynced ? Icons.check_circle_rounded : (isFailed ? Icons.error_outline_rounded : Icons.schedule_rounded),
                                color: isSynced ? ZivaTheme.emerald400 : (isFailed ? ZivaTheme.rose400 : ZivaTheme.gold400),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.transactionId, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
                                    Text(
                                      'Created: ${item.createdAt.split('.').first} • Retries: ${item.retryCount}',
                                      style: const TextStyle(fontSize: 10, color: ZivaTheme.textMuted),
                                    ),
                                    if (item.lastError != null)
                                      Text('Error: ${item.lastError}', style: const TextStyle(fontSize: 10, color: ZivaTheme.rose400)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSynced ? ZivaTheme.emeraldBg : (isFailed ? ZivaTheme.roseBg : ZivaTheme.gold500.withOpacity(0.15)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.syncStatus.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSynced ? ZivaTheme.emerald400 : (isFailed ? ZivaTheme.rose400 : ZivaTheme.gold400),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. BigQuery Backend Health Probe
            _buildSectionHeader('BIGQUERY WAREHOUSE CONNECTION PROBE'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Express REST API Backend', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ElevatedButton(
                          onPressed: _isProbingBackend ? null : _probeBackendHealth,
                          style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: _isProbingBackend
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Probe /api/health', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_backendHealth != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ZivaTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ZivaTheme.borderCard),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${_backendHealth!['status']}', style: const TextStyle(fontFamily: 'monospace', color: ZivaTheme.emerald400, fontWeight: FontWeight.bold)),
                            Text('Project: ${_backendHealth!['project'] ?? 'N/A'}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                            Text('Dataset: ${_backendHealth!['dataset'] ?? 'N/A'} (${_backendHealth!['location'] ?? ''})', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                            Text('Server Timestamp: ${_backendHealth!['timestamp'] ?? ''}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: ZivaTheme.textMuted)),
                          ],
                        ),
                      ),
                    ] else
                      const Text('Tap "Probe" to test connection to BigQuery express server', style: TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 4. Biometric Security Test
            _buildSectionHeader('BIOMETRIC SECURITY VALIDATION'),
            Card(
              child: ListTile(
                title: const Text('Test Face ID / Touch ID Prompt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Verify local_auth iOS/Android security gate', style: TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                trailing: const Icon(Icons.fingerprint_rounded, color: ZivaTheme.gold400),
                onTap: _testBiometrics,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ZivaTheme.gold400,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
