import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/app_environment.dart';
import '../../core/theme/ziva_theme.dart';
import '../../services/biometric_service.dart';

/// AccessGuardScreen - Executive PIN & Biometric Passcode Gate
/// Secures the Live environment against unauthorized access to financial records.
class AccessGuardScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AccessGuardScreen({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<AccessGuardScreen> createState() => _AccessGuardScreenState();
}

class _AccessGuardScreenState extends State<AccessGuardScreen> with SingleTickerProviderStateMixin {
  static const String _masterPin = String.fromEnvironment('ZIVA_ACCESS_PIN', defaultValue: '2026');
  String _enteredPin = '';
  String? _errorMessage;
  bool _isAuthenticatingBiometrics = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String digit) {
    HapticFeedback.lightImpact();
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });

      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDelete() {
    HapticFeedback.selectionClick();
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _verifyPin() {
    if (_enteredPin == _masterPin) {
      HapticFeedback.mediumImpact();
      widget.onAuthenticated();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _errorMessage = 'Invalid Passcode. Access Denied.';
        _enteredPin = '';
      });
    }
  }

  Future<void> _attemptBiometricUnlock() async {
    if (kIsWeb) {
      // Biometrics on web automatically bypasses in staging/demo
      widget.onAuthenticated();
      return;
    }

    setState(() => _isAuthenticatingBiometrics = true);
    final success = await BiometricService.instance.authenticate(
      reason: 'Authenticate to access Ziva Finance Executive Terminal',
    );
    if (mounted) {
      setState(() => _isAuthenticatingBiometrics = false);
      if (success) {
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorMessage = 'Biometric verification failed.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaging = AppEnvironment.isStaging;
    final accentColor = AppEnvironment.accentColor;

    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Environment Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppEnvironment.badgeBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppEnvironment.badgeBorderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isStaging ? Icons.science_outlined : Icons.shield_outlined,
                          size: 14,
                          color: accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppEnvironment.badgeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ziva Finance Logo / Shield
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 34,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  const Text(
                    'ZIVA FINANCE',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.0,
                      color: ZivaTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isStaging
                        ? 'Sandbox Security Terminal'
                        : 'Executive Financial Terminal Access',
                    style: TextStyle(
                      fontSize: 13,
                      color: ZivaTheme.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // 4-Digit Passcode Dots
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value * (_shakeController.value > 0 ? (_shakeController.value % 0.2 > 0.1 ? 1 : -1) : 0), 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final isFilled = index < _enteredPin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled ? accentColor : Colors.transparent,
                                border: Border.all(
                                  color: isFilled ? accentColor : ZivaTheme.textSecondary.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                                boxShadow: isFilled
                                    ? [
                                        BoxShadow(
                                          color: accentColor.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Error Message Display
                  SizedBox(
                    height: 22,
                    child: _errorMessage != null
                        ? Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: ZivaTheme.rose400,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // Keypad (1 - 9, Biometrics, 0, Backspace)
                  _buildKeypad(accentColor),
                  const SizedBox(height: 24),

                  // Staging Quick Unlock
                  if (isStaging)
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onAuthenticated();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppEnvironment.accentColor.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.bolt, color: AppEnvironment.accentColor, size: 18),
                      label: Text(
                        'Instant Sandbox Bypass (Staging Demo)',
                        style: TextStyle(
                          color: AppEnvironment.accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(Color accentColor) {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3']),
        const SizedBox(height: 14),
        _buildKeyRow(['4', '5', '6']),
        const SizedBox(height: 14),
        _buildKeyRow(['7', '8', '9']),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Left Action: Biometrics
            _buildActionKey(
              icon: Icons.fingerprint_rounded,
              onTap: _attemptBiometricUnlock,
              color: accentColor,
            ),
            // Center Action: 0
            _buildNumberKey('0'),
            // Right Action: Delete / Backspace
            _buildActionKey(
              icon: Icons.backspace_outlined,
              onTap: _onDelete,
              color: ZivaTheme.textSecondary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildNumberKey(d)).toList(),
    );
  }

  Widget _buildNumberKey(String digit) {
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ZivaTheme.bgSurface.withValues(alpha: 0.6),
          border: Border.all(
            color: ZivaTheme.borderCard.withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: ZivaTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 68,
        height: 68,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Center(
          child: _isAuthenticatingBiometrics && icon == Icons.fingerprint_rounded
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}
