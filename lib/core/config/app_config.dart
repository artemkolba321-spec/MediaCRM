import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration loaded from compile-time defines or `.env` file.
///
/// No platform secret is ever compiled into the client.
/// The public Supabase URL and the public anon key are resolved in this order:
///
/// 1. `--dart-define=SUPABASE_URL=…` (release builds — APK, Windows, Linux…)
/// 2. `SUPABASE_URL` from `.env` (debug / dev builds via flutter_dotenv)
///
/// See `.env.example` for the required format.
class AppConfig {
  const AppConfig._();

  static const String appName = 'MediaCRM';
  static const String appVersion = '2.0.0';
  static const String tagline = 'CREATOR WORKSPACE';

  /// Supabase project URL.
  static String? _supabaseUrl;

  /// Supabase anon (public) key.
  static String? _supabaseAnonKey;

  /// Lazy initialization: reads from compile-time defines first,
  /// then from `.env` (must be loaded before first access in debug).
  static void _ensureLoaded() {
    if (_supabaseUrl != null) return; // already resolved
    _supabaseUrl = _resolveEnv('SUPABASE_URL');
    _supabaseAnonKey = _resolveEnv('SUPABASE_ANON_KEY');
  }

  /// Supabase project URL (resolved lazily).
  static String get supabaseUrl {
    _ensureLoaded();
    return _sanitizeUrl(_supabaseUrl!);
  }

  /// Supabase anon (public) key (resolved lazily).
  static String get supabaseAnonKey {
    _ensureLoaded();
    return _supabaseAnonKey!;
  }

  /// OAuth redirect URI for mobile deep-links.
  static const String appRedirectUrl = 'mediacrm://oauth-callback';

  /// Resolve a credential: compile-time `--dart-define` first, then `.env`.
  static String _resolveEnv(String key) {
    // 1. Compile-time define (release builds).
    final define = String.fromEnvironment(key);
    if (define.isNotEmpty) return define;

    // 2. Runtime .env (debug/dev builds).
    try {
      final env = dotenv.env[key]?.trim() ?? '';
      if (env.isNotEmpty) return env;
    } catch (_) {
      // flutter_dotenv not loaded — fall through.
    }
    return '';
  }

  /// Ensure the URL has an http(s) scheme.
  static String _sanitizeUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return 'https://$url';
  }

  /// Returns `true` when both URL and anon key are present and the URL
  /// looks like a valid URI with a scheme.
  static bool get isCloudConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      Uri.tryParse(supabaseUrl)?.hasScheme == true;

  static const String defaultCurrency = 'RUB';
  static const String defaultTimezone = 'Asia/Novosibirsk';

  static const List<String> supportedCurrencies = [
    'RUB',
    'USD',
    'EUR',
    'KZT',
    'BYN',
    'UAH',
  ];

  static const int defaultSyncIntervalMinutes = 180;
  static const int maxSyncRetries = 3;
}
