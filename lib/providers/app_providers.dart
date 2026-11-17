import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:media_crm/core/analytics/analytics_calculator.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/financial_operation.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/task.dart';
import 'package:media_crm/data/models/user_settings.dart';
import 'package:media_crm/data/repositories/advertiser_repository.dart';
import 'package:media_crm/data/repositories/analytics_repository.dart';
import 'package:media_crm/data/repositories/channel_repository.dart';
import 'package:media_crm/data/repositories/contact_repository.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';
import 'package:media_crm/data/repositories/finance_repository.dart';
import 'package:media_crm/data/repositories/funnel_repository.dart';
import 'package:media_crm/data/repositories/notification_repository.dart';
import 'package:media_crm/data/repositories/partner_repository.dart';
import 'package:media_crm/data/repositories/publication_repository.dart';
import 'package:media_crm/data/repositories/settings_repository.dart';
import 'package:media_crm/data/repositories/task_repository.dart';

// -----------------------------------------------------------------------------
// Infrastructure
// -----------------------------------------------------------------------------

/// Overridden in `main()` with an initialized store.
final localStoreProvider = Provider<LocalStore>((ref) {
  throw StateError('LocalStore не инициализирован');
});

/// Null when Supabase is not configured. The app then works in local mode.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

/// Set by `main()` when Supabase was configured but could not be initialized.
final bootstrapNoticeProvider = Provider<String?>((ref) => null);

final cloudServiceProvider = Provider<CloudService>((ref) {
  return CloudService(
    ref.watch(supabaseClientProvider),
    ref.watch(localStoreProvider),
  );
});

final activityServiceProvider = Provider<ActivityService>((ref) {
  return ActivityService(
    ref.watch(localStoreProvider),
    ref.watch(cloudServiceProvider),
  );
});

/// Incremented after every local mutation. Screens watch it to re-read the
/// synchronous local store without duplicating cache logic per feature.
final dataVersionProvider = StateProvider<int>((ref) => 0);

void bumpData(WidgetRef ref) {
  ref.read(dataVersionProvider.notifier).state++;
}

// -----------------------------------------------------------------------------
// Domain repositories
// -----------------------------------------------------------------------------

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(
    store: ref.watch(localStoreProvider),
    cloud: ref.watch(cloudServiceProvider),
    activity: ref.watch(activityServiceProvider),
  );
});

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return ChannelRepository(
    store: ref.watch(localStoreProvider),
    cloud: ref.watch(cloudServiceProvider),
    activity: ref.watch(activityServiceProvider),
  );
});

final partnerRepositoryProvider = Provider<PartnerRepository>((ref) {
  return PartnerRepository(
    store: ref.watch(localStoreProvider),
    cloud: ref.watch(cloudServiceProvider),
    activity: ref.watch(activityServiceProvider),
    finance: ref.watch(financeRepositoryProvider),
  );
});

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(
    store: ref.watch(localStoreProvider),
    cloud: ref.watch(cloudServiceProvider),
    activity: ref.watch(activityServiceProvider),
  );
});

final publicationRepositoryProvider = Provider<PublicationRepository>((ref) {
  return PublicationRepository(
    store: ref.watch(localStoreProvider),
    cloud: ref.watch(cloudServiceProvider),
    activity: ref.watch(activityServiceProvider),
  );
});

final advertiserRepositoryProvider = Provider<AdvertiserRepository>((ref) {
  return AdvertiserRepository(
    store: ref.watch(localStoreProvider),
    cloud: ref.watch(cloudServiceProvider),
    activity: ref.watch(activityServiceProvider),
    finance: ref.watch(financeRepositoryProvider),
    channels: ref.watch(channelRepositoryProvider),
    publications: ref.watch(publicationRepositoryProvider),
  );
});

final funnelRepositoryProvider = Provider<FunnelRepository>((ref) {
  return FunnelRepository(
    store: ref.watch(localStoreProvider),
    cloud: ref.watch(cloudServiceProvider),
    activity: ref.watch(activityServiceProvider),
  );
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    store: ref.watch(localStoreProvider),
    cloud: ref.watch(cloudServiceProvider),
  );
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    store: ref.watch(localStoreProvider),
    cloud: ref.watch(cloudServiceProvider),
    activity: ref.watch(activityServiceProvider),
    notifications: ref.watch(notificationRepositoryProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    store: ref.watch(localStoreProvider),
    cloud: ref.watch(cloudServiceProvider),
    finance: ref.watch(financeRepositoryProvider),
    activity: ref.watch(activityServiceProvider),
  );
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(
    store: ref.watch(localStoreProvider),
    channels: ref.watch(channelRepositoryProvider),
    finance: ref.watch(financeRepositoryProvider),
    publications: ref.watch(publicationRepositoryProvider),
    advertisers: ref.watch(advertiserRepositoryProvider),
    partners: ref.watch(partnerRepositoryProvider),
    tasks: ref.watch(taskRepositoryProvider),
    notifications: ref.watch(notificationRepositoryProvider),
    contacts: ref.watch(contactRepositoryProvider),
  );
});

// -----------------------------------------------------------------------------
// Auth
// -----------------------------------------------------------------------------

enum AuthStatus { initializing, unauthenticated, authenticated, local }

class AppAuthState {
  final AuthStatus status;
  final String userId;
  final String? email;
  final String displayName;
  final bool busy;
  final bool cloudConfigured;
  final bool isAnonymous;
  final String? notice;

  const AppAuthState({
    this.status = AuthStatus.initializing,
    this.userId = 'local-owner',
    this.email,
    this.displayName = 'Моя медиасеть',
    this.busy = false,
    this.cloudConfigured = false,
    this.isAnonymous = false,
    this.notice,
  });

  bool get isSignedIn =>
      status == AuthStatus.authenticated || status == AuthStatus.local;
  bool get isCloud => status == AuthStatus.authenticated;
  bool get isLocal => status == AuthStatus.local;

  AppAuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? email,
    String? displayName,
    bool? busy,
    bool? cloudConfigured,
    bool? isAnonymous,
    String? notice,
    bool clearNotice = false,
  }) {
    return AppAuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      busy: busy ?? this.busy,
      cloudConfigured: cloudConfigured ?? this.cloudConfigured,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

class AuthController extends StateNotifier<AppAuthState> {
  AuthController(this._store, this._cloud)
      : super(AppAuthState(cloudConfigured: _cloud.isConfigured)) {
    _authSubscription = _cloud.client?.auth.onAuthStateChange.listen((data) {
      final change = data.event;
      final session = data.session;
      final userId = session?.user.id;

      // ── Diagnostic logging (no tokens/secrets) ──────────────────────
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

      // ── Session dropped while authenticated — fall back to local ────
      if (session == null && state.status == AuthStatus.authenticated) {
        debugPrint('[Auth] Session dropped — falling back to local mode');
        _store.useUser('local-owner');
        state = state.copyWith(status: AuthStatus.local);
      }
    });
  }

  final LocalStore _store;
  final CloudService _cloud;
  StreamSubscription<AuthState>? _authSubscription;

  Future<void> initialize() async {
    debugPrint('[Auth] initialize() started, cloudConfigured=${_cloud.isConfigured}');

    if (!_cloud.isConfigured) {
      // No cloud configured — stay in local mode.
      debugPrint('[Auth] Cloud not configured — switching to local mode');
      if (_store.getLocalMode()) {
        final profile = _store.getLocalProfile();
        _store.useUser('local-owner');
        state = state.copyWith(
          userId: 'local-owner',
          displayName: profile?['display_name']?.toString() ?? 'Моя медиасеть',
        );
      }
      return;
    }

    // Cloud is configured. main.dart should have already ensured a session
    // exists (restored from storage or created via anonymous sign-in).
    // Check both currentUser and currentSession for robustness.
    final user = _cloud.client?.auth.currentUser;
    final session = _cloud.client?.auth.currentSession;

    debugPrint('[Auth] initialize() user=${user?.id ?? "null"} '
        'session=${session != null}');

    if (user != null || session != null) {
      // Session exists — apply it.
      // Use currentUser if available (more data), otherwise create from session.
      final targetUser = user ?? session!.user;
      _applyCloudUser(targetUser);
      return;
    }

    // No session at all — this shouldn't happen if main.dart ran correctly,
    // but fall back to local mode to keep the app usable.
    debugPrint('[Auth] initialize() no session — falling back to local mode');
    if (_store.getLocalMode()) {
      final profile = _store.getLocalProfile();
      _store.useUser('local-owner');
      state = state.copyWith(
        userId: 'local-owner',
        displayName: profile?['display_name']?.toString() ?? 'Моя медиасеть',
      );
    }
  }

  void _applyCloudUser(User user) {
    _store.useUser(user.id);
    final meta = user.userMetadata ?? const {};
    final name = (meta['display_name'] ?? meta['name'] ?? user.email ?? '')
        .toString();
    final isAnonymous = user.email == null;
    state = state.copyWith(
      status: AuthStatus.authenticated,
      userId: user.id,
      email: user.email,
      displayName: name.isEmpty ? 'Моя медиасеть' : name,
      busy: false,
      clearNotice: true,
      isAnonymous: isAnonymous,
    );
  }

  Future<void> signIn(String email, String password) async {
    final client = _cloud.client;
    if (client == null) {
      throw StateError('Облачный backend не настроен. Используйте локальный режим.');
    }
    state = state.copyWith(busy: true, clearNotice: true);
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('Не удалось войти');
      }
      _applyCloudUser(user);
    } on AuthException catch (error) {
      state = state.copyWith(
        busy: false,
        notice: _humanizeAuth(error.message),
      );
      rethrow;
    } catch (error) {
      state = state.copyWith(busy: false, notice: _humanizeAuth(error.toString()));
      rethrow;
    }
  }

  Future<void> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    final client = _cloud.client;
    if (client == null) {
      throw StateError('Облачный backend не настроен. Используйте локальный режим.');
    }
    state = state.copyWith(busy: true, clearNotice: true);
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          if (displayName != null && displayName.trim().isNotEmpty)
            'display_name': displayName.trim(),
        },
      );
      final user = response.user;
      if (response.session == null) {
        state = state.copyWith(
          busy: false,
          notice: 'Аккаунт создан. Подтвердите email по ссылке из письма, '
              'затем войдите.',
        );
        return;
      }
      if (user != null) _applyCloudUser(user);
    } on AuthException catch (error) {
      state = state.copyWith(
        busy: false,
        notice: _humanizeAuth(error.message),
      );
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    final client = _cloud.client;
    if (client == null) {
      throw StateError('Облачный backend не настроен.');
    }
    state = state.copyWith(busy: true, clearNotice: true);
    try {
      await client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'mediacrm://reset-password',
      );
      state = state.copyWith(
        busy: false,
        notice: 'Письмо для восстановления доступа отправлено на $email.',
      );
    } on AuthException catch (error) {
      state = state.copyWith(
        busy: false,
        notice: _humanizeAuth(error.message),
      );
      rethrow;
    }
  }

  Future<void> updatePassword(String password) async {
    final client = _cloud.client;
    if (client == null) throw StateError('Облачный backend не настроен.');
    await client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> continueLocally({String displayName = 'Моя медиасеть'}) async {
    await _store.setLocalMode(true);
    await _store.saveLocalProfile({
      'display_name': displayName.trim().isEmpty
          ? 'Моя медиасеть'
          : displayName.trim(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    _store.useUser('local-owner');
    state = state.copyWith(
      status: AuthStatus.local,
      userId: 'local-owner',
      displayName: displayName.trim().isEmpty
          ? 'Моя медиасеть'
          : displayName.trim(),
      email: null,
      isAnonymous: false,
      clearNotice: true,
    );
  }

  /// Upgrades an anonymous session to a permanent account.
  /// The existing data is preserved because it was already stored under
  /// the anonymous user's auth.uid().
  Future<void> upgradeToPermanent(String email, String password,
      {String? displayName}) async {
    final client = _cloud.client;
    if (client == null) {
      throw StateError('Облачный backend не настроен.');
    }
    state = state.copyWith(busy: true, clearNotice: true);
    try {
      final response = await client.auth.updateUser(
        UserAttributes(
          email: email.trim(),
          password: password,
          data: {
            if (displayName != null && displayName.trim().isNotEmpty)
              'display_name': displayName.trim(),
          },
        ),
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('Не удалось создать аккаунт');
      }
      _applyCloudUser(user);
    } on AuthException catch (error) {
      state = state.copyWith(
        busy: false,
        notice: _humanizeAuth(error.message),
      );
      rethrow;
    } catch (error) {
      state = state.copyWith(busy: false, notice: _humanizeAuth(error.toString()));
      rethrow;
    }
  }

  Future<void> signOut() async {
    final client = _cloud.client;
    if (client != null && state.isCloud) {
      // Don't sign out anonymous users — just switch to local mode.
      // Anonymous sessions are tied to device storage and can't be
      // recovered anyway, so signing out would just lose data.
      if (!state.isAnonymous) {
        await client.auth.signOut();
      }
    }
    await _store.setLocalMode(false);
    _store.useUser('local-owner');
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      userId: 'local-owner',
      email: null,
      displayName: 'Моя медиасеть',
      isAnonymous: false,
      clearNotice: true,
    );
  }

  void clearNotice() => state = state.copyWith(clearNotice: true);

  Future<void> refreshProfile(String displayName) async {
    state = state.copyWith(displayName: displayName);
    if (state.isCloud) {
      final client = _cloud.client;
      if (client != null) {
        await client.auth.updateUser(
          UserAttributes(data: {'display_name': displayName}),
        );
      }
    } else {
      final profile = _store.getLocalProfile() ?? {};
      profile['display_name'] = displayName;
      await _store.saveLocalProfile(profile);
    }
  }

  String _humanizeAuth(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
      return 'Неверный email или пароль';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email ещё не подтверждён. Проверьте почту.';
    }
    if (lower.contains('user already registered')) {
      return 'Пользователь с таким email уже зарегистрирован';
    }
    if (lower.contains('password should be')) {
      return 'Пароль должен содержать минимум 6 символов';
    }
    if (lower.contains('rate limit')) {
      return 'Слишком много попыток. Повторите через несколько минут.';
    }
    if (lower.contains('failed host lookup') || lower.contains('socket')) {
      return 'Нет соединения с сервером';
    }
    return text;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthController, AppAuthState>((ref) {
  return AuthController(
    ref.watch(localStoreProvider),
    ref.watch(cloudServiceProvider),
  )..initialize();
});

// -----------------------------------------------------------------------------
// Settings
// -----------------------------------------------------------------------------

class SettingsController extends StateNotifier<UserSettings> {
  SettingsController(this._repo, {required String userId, String? email,
      String? displayName})
      : super(_repo.ensureSettings(
          userId: userId,
          email: email,
          displayName: displayName,
        ));

  final SettingsRepository _repo;

  Future<void> update(UserSettings Function(UserSettings) updater) async {
    state = await _repo.saveSettings(updater(state));
  }

  Future<void> setTheme(String themeMode) =>
      update((settings) => settings.copyWith(themeMode: themeMode));

  Future<void> setCurrency(String currency) => update(
        (settings) => settings.copyWith(
          currency: currency,
          baseCurrency: currency,
        ),
      );

  Future<void> saveRate(String code, double rate) =>
      _repo.saveRate(code, rate);

  Future<String> exportJson() async => _repo.exportBackupJson();

  Future<void> importJson(String raw) async {
    await _repo.importBackupJson(raw);
    state = _repo.getSettings();
  }

  Future<void> clearEverything() async {
    await _repo.clearAllData();
    state = _repo.getSettings();
  }

  void reload() => state = _repo.getSettings();
}

final settingsProvider =
    StateNotifierProvider<SettingsController, UserSettings>((ref) {
  final auth = ref.watch(authProvider);
  return SettingsController(
    ref.watch(settingsRepositoryProvider),
    userId: auth.userId,
    email: auth.email,
    displayName: auth.displayName,
  );
});

// -----------------------------------------------------------------------------
// Sync status
// -----------------------------------------------------------------------------

class GlobalSyncState {
  final bool busy;
  final int pendingChanges;
  final DateTime? lastSyncedAt;
  final String? message;
  final bool error;

  const GlobalSyncState({
    this.busy = false,
    this.pendingChanges = 0,
    this.lastSyncedAt,
    this.message,
    this.error = false,
  });

  GlobalSyncState copyWith({
    bool? busy,
    int? pendingChanges,
    DateTime? lastSyncedAt,
    String? message,
    bool? error,
    bool clearMessage = false,
  }) {
    return GlobalSyncState(
      busy: busy ?? this.busy,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      message: clearMessage ? null : (message ?? this.message),
      error: error ?? this.error,
    );
  }
}

class SyncController extends StateNotifier<GlobalSyncState> {
  SyncController(this._store, this._cloud) : super(const GlobalSyncState()) {
    refreshPending();
  }

  final LocalStore _store;
  final CloudService _cloud;

  void refreshPending() {
    state = state.copyWith(pendingChanges: _store.pendingChanges);
  }

  Future<void> synchronize() async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearMessage: true);
    refreshPending();
    final result = await _cloud.synchronize();
    refreshPending();
    state = state.copyWith(
      busy: false,
      lastSyncedAt: result.success ? DateTime.now() : state.lastSyncedAt,
      message: result.success
          ? 'Синхронизация завершена: отправлено ${result.pushed}, '
              'получено ${result.pulled}.'
          : (result.error ?? 'Не удалось синхронизировать данные'),
      error: !result.success,
    );
  }
}

final syncControllerProvider =
    StateNotifierProvider<SyncController, GlobalSyncState>((ref) {
  return SyncController(
    ref.watch(localStoreProvider),
    ref.watch(cloudServiceProvider),
  );
});

// -----------------------------------------------------------------------------
// Filters
// -----------------------------------------------------------------------------

class DashboardFilter {
  final int days;

  /// 0 means "all time".
  final PlatformType? platform;
  final DateTime? customStart;
  final DateTime? customEnd;

  const DashboardFilter({
    this.days = 30,
    this.platform,
    this.customStart,
    this.customEnd,
  });

  bool get isCustom => customStart != null && customEnd != null;

  DateRange get range {
    if (isCustom) {
      return DateRange(
        start: customStart!,
        end: customEnd!,
        label: '${customStart!.formatShort()} — ${customEnd!.formatShort()}',
      );
    }
    if (days <= 0) return DateRange.all();
    return DateRange.lastDays(days);
  }

  DashboardFilter copyWith({
    int? days,
    PlatformType? platform,
    bool clearPlatform = false,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCustom = false,
  }) {
    return DashboardFilter(
      days: days ?? this.days,
      platform: clearPlatform ? null : (platform ?? this.platform),
      customStart: clearCustom ? null : (customStart ?? this.customStart),
      customEnd: clearCustom ? null : (customEnd ?? this.customEnd),
    );
  }
}

final dashboardFilterProvider =
    StateProvider<DashboardFilter>((ref) => const DashboardFilter());

class FinanceFilterState {
  final DateTime? start;
  final DateTime? end;
  final Set<TransactionType> types;
  final Set<TransactionCategory> categories;
  final PlatformType? platform;
  final String search;

  const FinanceFilterState({
    this.start,
    this.end,
    this.types = const {},
    this.categories = const {},
    this.platform,
    this.search = '',
  });

  FinanceFilterState copyWith({
    DateTime? start,
    DateTime? end,
    Set<TransactionType>? types,
    Set<TransactionCategory>? categories,
    PlatformType? platform,
    bool clearPlatform = false,
    String? search,
    bool clearDates = false,
  }) {
    return FinanceFilterState(
      start: clearDates ? null : (start ?? this.start),
      end: clearDates ? null : (end ?? this.end),
      types: types ?? this.types,
      categories: categories ?? this.categories,
      platform: clearPlatform ? null : (platform ?? this.platform),
      search: search ?? this.search,
    );
  }

  bool get hasFilters =>
      start != null ||
      end != null ||
      types.isNotEmpty ||
      categories.isNotEmpty ||
      platform != null ||
      search.trim().isNotEmpty;
}

final financeFilterProvider = StateProvider<FinanceFilterState>(
  (ref) => const FinanceFilterState(),
);

enum TaskView { list, board, calendar }

class TaskFilterState {
  final String search;
  final Set<TaskStatus> statuses;
  final Set<TaskPriority> priorities;
  final bool overdueOnly;
  final TaskView view;

  const TaskFilterState({
    this.search = '',
    this.statuses = const {},
    this.priorities = const {},
    this.overdueOnly = false,
    this.view = TaskView.list,
  });

  TaskFilterState copyWith({
    String? search,
    Set<TaskStatus>? statuses,
    Set<TaskPriority>? priorities,
    bool? overdueOnly,
    TaskView? view,
  }) {
    return TaskFilterState(
      search: search ?? this.search,
      statuses: statuses ?? this.statuses,
      priorities: priorities ?? this.priorities,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      view: view ?? this.view,
    );
  }
}

final taskFilterProvider =
    StateProvider<TaskFilterState>((ref) => const TaskFilterState());

class AnalyticsFilterState {
  final int days;
  final PlatformType? platform;
  final int tab;

  const AnalyticsFilterState({
    this.days = 30,
    this.platform,
    this.tab = 0,
  });

  DateRange get range => DateRange.lastDays(days);

  AnalyticsFilterState copyWith({
    int? days,
    PlatformType? platform,
    bool clearPlatform = false,
    int? tab,
  }) {
    return AnalyticsFilterState(
      days: days ?? this.days,
      platform: clearPlatform ? null : (platform ?? this.platform),
      tab: tab ?? this.tab,
    );
  }
}

final analyticsFilterProvider = StateProvider<AnalyticsFilterState>(
  (ref) => const AnalyticsFilterState(),
);

// Convenience aggregate: counts used by the shell badges.
final unreadNotificationsProvider = Provider<int>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(notificationRepositoryProvider).unreadCount;
});

/// Currently selected destination in the main shell.
final shellIndexProvider = StateProvider<int>((ref) => 0);
