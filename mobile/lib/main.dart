import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/ziva_theme.dart';
import 'features/auth/biometric_lock_screen.dart';
import 'features/auth/privacy_shield.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/ledger/ledger_screen.dart';
import 'features/settings/developer_settings_screen.dart';
import 'services/biometric_service.dart';
import 'services/sync_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce dark system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ZivaTheme.bgCore,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize SQLite sync engine
  await SyncEngine.instance.initialize();

  runApp(const ZivaFinanceMobileApp());
}

class ZivaFinanceMobileApp extends StatelessWidget {
  const ZivaFinanceMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ziva Finance',
      debugShowCheckedModeBanner: false,
      theme: ZivaTheme.darkTheme,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _isBackgroundMasked = false;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Monitor iOS/Android app lifecycle transitions
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[LifecycleObserver] AppLifecycleState changed to: $state');

    // 1. When app is backgrounded or becoming inactive (user swipes up for App Switcher)
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      setState(() {
        // Instantly mask the app UI with the privacy blur shield
        _isBackgroundMasked = true;
      });
    }

    // 2. When app resumes to foreground from background
    if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  Future<void> _handleAppResume() async {
    // If the app was unlocked, lock it and prompt for Face ID re-authentication
    if (_isUnlocked) {
      final authenticated = await BiometricService.instance.authenticate(
        reason: 'Re-authenticate with Face ID to resume your Ziva Finance session',
      );

      if (mounted) {
        setState(() {
          if (authenticated) {
            _isBackgroundMasked = false;
            _isUnlocked = true;
          } else {
            // Keep locked and show biometric lock screen
            _isBackgroundMasked = false;
            _isUnlocked = false;
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isBackgroundMasked = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main App Shell or Startup Biometric Lock Screen
        if (!_isUnlocked)
          BiometricLockScreen(
            onAuthenticated: () {
              setState(() {
                _isUnlocked = true;
                _isBackgroundMasked = false;
              });
            },
          )
        else
          Scaffold(
            body: IndexedStack(
              index: _currentTabIndex,
              children: [
                DashboardScreen(
                  onNavigateToLedger: () => setState(() => _currentTabIndex = 1),
                ),
                const LedgerScreen(),
                const DeveloperSettingsScreen(),
              ],
            ),
            bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                color: ZivaTheme.bgSurface,
                border: Border(top: BorderSide(color: ZivaTheme.borderCard)),
              ),
              child: NavigationBar(
                selectedIndex: _currentTabIndex,
                backgroundColor: ZivaTheme.bgSurface,
                indicatorColor: ZivaTheme.gold500.withOpacity(0.2),
                onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined, color: ZivaTheme.textMuted),
                    selectedIcon: Icon(Icons.dashboard_rounded, color: ZivaTheme.gold400),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: ValueListenableBuilder<int>(
                      valueListenable: SyncEngine.instance.pendingCount,
                      builder: (context, count, _) {
                        return Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: ZivaTheme.gold500,
                          textColor: Colors.black,
                          child: const Icon(Icons.receipt_long_outlined, color: ZivaTheme.textMuted),
                        );
                      },
                    ),
                    selectedIcon: const Icon(Icons.receipt_long_rounded, color: ZivaTheme.gold400),
                    label: 'Ledger',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.tune_outlined, color: ZivaTheme.textMuted),
                    selectedIcon: Icon(Icons.tune_rounded, color: ZivaTheme.gold400),
                    label: 'Dev & OTA',
                  ),
                ],
              ),
            ),
          ),

        // iOS Multitasking App Switcher Privacy Masking Shield
        if (_isBackgroundMasked)
          const PrivacyShield(),
      ],
    );
  }
}
