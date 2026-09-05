import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/ziva_theme.dart';

/// Screen-obscuring shield displayed in the iOS App Switcher to prevent sensitive balance leaks
class PrivacyShield extends StatelessWidget {
  const PrivacyShield({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          color: ZivaTheme.bgCore.withValues(alpha: 0.92),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: ZivaTheme.gold500.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: ZivaTheme.gold500,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ZIVA FINANCE',
                  style: TextStyle(
                    color: ZivaTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZivaTheme.gold500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'FINANCIAL PRIVACY ACTIVE',
                    style: TextStyle(
                      color: ZivaTheme.gold300,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
