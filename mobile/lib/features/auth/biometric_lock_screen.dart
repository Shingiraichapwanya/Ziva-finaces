import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';
import '../../services/biometric_service.dart';

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const BiometricLockScreen({super.key, required this.onAuthenticated});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> with SingleTickerProviderStateMixin {
  bool _isAuthenticating = false;
  String? _errorMessage;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Prompt for biometrics immediately upon display
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometrics();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometrics() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final success = await BiometricService.instance.authenticate(
      reason: 'Verify your identity to access Ziva Finance portfolios and ledgers',
    );

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
      });

      if (success) {
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorMessage = 'Authentication failed or canceled. Tap to retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Brand Emblem
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x40F59E0B), Color(0x1AD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ZivaTheme.gold500.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: ZivaTheme.gold500.withOpacity(0.2),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.diamond_outlined, color: ZivaTheme.gold400, size: 32),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'ZIVA FINANCE',
                style: TextStyle(
                  color: ZivaTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'PORTFOLIO ENCRYPTION ACTIVE',
                style: TextStyle(
                  color: ZivaTheme.textMuted,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),

              const Spacer(flex: 3),

              // Pulse Biometric Icon Button
              ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.05).animate(_pulseController),
                child: GestureDetector(
                  onTap: _triggerBiometrics,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ZivaTheme.bgSurface,
                      border: Border.all(color: ZivaTheme.gold500.withOpacity(0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: ZivaTheme.gold500.withOpacity(0.25),
                          blurRadius: 25,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.fingerprint_rounded,
                        color: _errorMessage != null ? ZivaTheme.rose400 : ZivaTheme.gold400,
                        size: 52,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                _isAuthenticating ? 'Scanning Face ID...' : 'Touch sensor or glance to unlock',
                style: const TextStyle(
                  color: ZivaTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: ZivaTheme.roseBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ZivaTheme.rose500.withOpacity(0.4)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: ZivaTheme.rose400, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const Spacer(flex: 3),

              // Manual Retry Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _triggerBiometrics,
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Unlock with Face ID / Passcode'),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
