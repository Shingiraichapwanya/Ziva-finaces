import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum AppEnv { live, staging }

/// App Environment Configuration
/// Determines whether the app runs in Live (Production) or Staging (Sandbox) mode.
/// Evaluates compile-time defines (`--dart-define=ENVIRONMENT=staging`) as well
/// as browser URL query parameters (`?env=staging`) when running on Web.
class AppEnvironment {
  static AppEnv? _overrideEnv;

  /// Explicitly set the environment (e.g. for testing)
  static void setOverride(AppEnv? env) {
    _overrideEnv = env;
  }

  /// Current active environment
  static AppEnv get current {
    if (_overrideEnv != null) return _overrideEnv!;

    // 1. Check compile-time environment define
    const definedEnv = String.fromEnvironment('ENVIRONMENT', defaultValue: 'live');
    if (definedEnv.toLowerCase() == 'staging' || definedEnv.toLowerCase() == 'sandbox') {
      return AppEnv.staging;
    }

    // 2. Check browser URL query parameter (?env=staging or ?environment=staging)
    if (kIsWeb) {
      final uri = Uri.base;
      final envParam = uri.queryParameters['env'] ?? uri.queryParameters['environment'];
      if (envParam != null && (envParam.toLowerCase() == 'staging' || envParam.toLowerCase() == 'sandbox')) {
        return AppEnv.staging;
      }
    }

    return AppEnv.live;
  }

  static bool get isLive => current == AppEnv.live;
  static bool get isStaging => current == AppEnv.staging;

  static String get name => isLive ? 'LIVE' : 'STAGING';

  /// Primary environment color accent
  static Color get accentColor => isLive ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

  /// Environment badge background color
  static Color get badgeBgColor => isLive
      ? const Color(0xFF10B981).withValues(alpha: 0.15)
      : const Color(0xFFF59E0B).withValues(alpha: 0.15);

  /// Environment badge border color
  static Color get badgeBorderColor => isLive
      ? const Color(0xFF10B981).withValues(alpha: 0.4)
      : const Color(0xFFF59E0B).withValues(alpha: 0.5);

  /// Environment badge label text
  static String get badgeLabel => isLive ? 'LIVE TERMINAL' : 'STAGING SANDBOX';

  /// Staging banner advisory note
  static String get stagingNotice =>
      'STAGING SANDBOX ENVIRONMENT • MOCK TELEMETRY & EXPERIMENTAL ENGINE ACTIVE';
}
