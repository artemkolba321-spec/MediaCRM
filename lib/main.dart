import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:media_crm/app.dart';
import 'package:media_crm/core/config/app_config.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/providers/app_providers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Result of the Supabase initialization + anonymous sign-in flow.
class AuthInitResult {
  final SupabaseClient? client;
  final String? errorMessage;
  final bool sessionCreated;

  const AuthInitResult({
    this.client,
    this.errorMessage,
    required this.sessionCreated,
  });

  bool get success => errorMessage == null && sessionCreated;
}

/// Initializes Supabase and ensures an anonymous session exists.
///
/// Returns [AuthInitResult] with the client, any error message, and whether
/// a session was successfully created. The caller must await this before
/// showing any screens that depend on cloud operations.
Future<AuthInitResult> initSupabase() async {
  // 1. Load configuration from .env (or dart-define for release builds).
  await dotenv.load(fileName: '.env');

  if (!AppConfig.isCloudConfigured) {
    debugPrint('[Auth] Supabase URL or anon key not set — skipping cloud.');
    return const AuthInitResult(
      sessionCreated: false,
    );
  }

  debugPrint('[Auth] Supabase URL: ${AppConfig.supabaseUrl}');

  SupabaseClient? client;
  try {
    // 2. Initialize the Supabase client.
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      debug: false,
    );
    client = Supabase.instance.client;
    debugPrint('[Auth] Supabase initialized');

    // 3. Set up auth state change listener for diagnostic logging.
    //    This runs BEFORE checking/restoring session so we capture
    //    the initial SDK session restore event (if any).
    client.auth.onAuthStateChange.listen((data) {
      final change = data.event;
      final session = data.session;
      final userId = session?.user.id;
      switch (change) {
        case AuthChangeEvent.initialSession:
          debugPrint('[Auth] authStateChanges: INITIAL_SESSION '
              'userId=${userId ?? "null"}');
          break;
        case AuthChangeEvent.signedIn:
          debugPrint('[Auth] authStateChanges: SIGNED_IN '
              'userId=${userId ?? "null"}');
          break;
        case AuthChangeEvent.signedOut:
          debugPrint('[Auth] authStateChanges: SIGNED_OUT');
          break;
        case AuthChangeEvent.tokenRefreshed:
          debugPrint('[Auth] authStateChanges: TOKEN_REFRESHED '
              'userId=${userId ?? "null"}');
          break;
        case AuthChangeEvent.userUpdated:
          debugPrint('[Auth] authStateChanges: USER_UPDATED '
              'userId=${userId ?? "null"}');
          break;
        case AuthChangeEvent.mfaChallengeVerified:
          debugPrint('[Auth] authStateChanges: MFA_CHALLENGE_VERIFIED '
              'userId=${userId ?? "null"}');
          break;
        case AuthChangeEvent.passwordRecovery:
          debugPrint('[Auth] authStateChanges: PASSWORD_RECOVERY');
          break;
        default:
          debugPrint('[Auth] authStateChanges: $change');
      }
    });

    // 4. Check for an existing persisted session.
    //    The Flutter SDK stores sessions in SharedPreferences under the key
    //    'supabase.auth.token' and restores them automatically on init.
    final existingSession = client.auth.currentSession;
    if (existingSession != null) {
      debugPrint('[Auth] Existing session: true');
      debugPrint('[Auth] Session user ID: ${existingSession.user.id}');
      debugPrint('[Auth] Session expires at: ${existingSession.expiresAt}');
      // Session already exists — nothing to do.
      return AuthInitResult(
        client: client,
        sessionCreated: true,
      );
    }

    debugPrint('[Auth] Existing session: false — creating anonymous session');

    // 5. Create an anonymous session.
    late final String? userId;
    late final bool responseSession;
    late final bool currentSessionAfter;

    try {
      final response = await client.auth.signInAnonymously();
      userId = response.user?.id;
      responseSession = response.session != null;
      currentSessionAfter = client.auth.currentSession != null;
    } on AuthException catch (e) {
      debugPrint('[Auth] signInAnonymously AuthException: ${e.message} '
          '(code=${e.statusCode})');
      userId = null;
      responseSession = false;
      currentSessionAfter = false;
    } catch (e, stack) {
      debugPrint('[Auth] signInAnonymously error: $e');
      debugPrint('[Auth] $stack');
      userId = null;
      responseSession = false;
      currentSessionAfter = false;
    }

    debugPrint('[Auth] signInAnonymously result: '
        'userId=$userId responseSession=$responseSession '
        'currentSessionAfter=$currentSessionAfter');

    if (userId == null || !responseSession || !currentSessionAfter) {
      debugPrint('[Auth] Anonymous sign-in failed: userId=$userId '
          'session=$responseSession sdkSession=$currentSessionAfter');
      return const AuthInitResult(
        client: null,
        errorMessage:
            'Не удалось создать сессию. '
            'Возможно, в Supabase Dashboard отключён '
            '"Anonymous sign-in". Приложение запущено в локальном режиме.',
        sessionCreated: false,
      );
    }

    debugPrint('[Auth] Anonymous sign-in successful');
    debugPrint('[Auth] Current session: true');
    debugPrint('[Auth] Current user ID: $userId');

    return AuthInitResult(
      client: client,
      sessionCreated: true,
    );
  } catch (error, stackTrace) {
    debugPrint('[Auth] Supabase init error: $error');
    debugPrint('[Auth] $stackTrace');

    // Extract useful info from AuthException if available.
    if (error is AuthException) {
      debugPrint('[Auth] AuthException statusCode: ${error.statusCode}');
      debugPrint('[Auth] AuthException message: ${error.message}');
    }

    // CRITICAL: null out the client so CloudService.isConfigured returns false.
    // Otherwise cloud=true / signedIn=false creates the confusing
    // "requires cloud account" error path.
    return AuthInitResult(
      client: null,
      errorMessage:
          'Ошибка инициализации Supabase: $error. '
          'Приложение запущено в локальном режиме.',
      sessionCreated: false,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local store first (needed before runApp).
  final store = LocalStore();
  await store.init();

  // Initialize Supabase with anonymous auth.
  final result = await initSupabase();

  debugPrint('[Auth] === initSupabase result ===');
  debugPrint('[Auth] client=${result.client != null} '
      'sessionCreated=${result.sessionCreated} '
      'error=${result.errorMessage ?? "none"}');
  if (result.client != null) {
    final sess = result.client!.auth.currentSession;
    debugPrint('[Auth] currentSession after init: ${sess != null} '
        'userId=${sess?.user.id ?? "null"}');
  }
  debugPrint('[Auth] ==============================');

  runApp(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        supabaseClientProvider.overrideWithValue(result.client),
        bootstrapNoticeProvider.overrideWithValue(result.errorMessage),
      ],
      child: const MediaCrmApp(),
    ),
  );
}
