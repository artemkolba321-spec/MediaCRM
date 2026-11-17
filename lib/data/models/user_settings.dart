import 'package:media_crm/core/config/app_config.dart';
import 'package:media_crm/core/utils/json_utils.dart';

class UserSettings {
  final String userId;
  final String displayName;
  final String? email;
  final String themeMode; // dark, light, system
  final String locale;
  final String timezone;
  final String currency;
  final String baseCurrency;
  final bool autoSyncEnabled;
  final int syncIntervalMinutes;
  final bool emailNotifications;
  final bool pushNotifications;
  final bool syncNotifications;
  final bool financialNotifications;
  final bool taskNotifications;
  final bool metricNotifications;
  final String referralBaseUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSettings({
    required this.userId,
    this.displayName = 'Моя медиасеть',
    this.email,
    this.themeMode = 'dark',
    this.locale = 'ru',
    this.timezone = AppConfig.defaultTimezone,
    this.currency = AppConfig.defaultCurrency,
    this.baseCurrency = AppConfig.defaultCurrency,
    this.autoSyncEnabled = true,
    this.syncIntervalMinutes = AppConfig.defaultSyncIntervalMinutes,
    this.emailNotifications = false,
    this.pushNotifications = true,
    this.syncNotifications = true,
    this.financialNotifications = true,
    this.taskNotifications = true,
    this.metricNotifications = false,
    this.referralBaseUrl = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettings.defaults(String userId, {String? displayName, String? email}) {
    final now = DateTime.now();
    return UserSettings(
      userId: userId,
      displayName: displayName ?? 'Моя медиасеть',
      email: email,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return UserSettings(
      userId: parseRequiredString(json['user_id']),
      displayName: parseRequiredString(json['display_name'], 'Моя медиасеть'),
      email: parseString(json['email']),
      themeMode: parseRequiredString(json['theme_mode'], 'dark'),
      locale: parseRequiredString(json['locale'], 'ru'),
      timezone: parseRequiredString(
        json['timezone'],
        AppConfig.defaultTimezone,
      ),
      currency: parseRequiredString(json['currency'], 'RUB'),
      baseCurrency: parseRequiredString(json['base_currency'], 'RUB'),
      autoSyncEnabled: parseBool(json['auto_sync_enabled'], true),
      syncIntervalMinutes: parseInt(
        json['sync_interval_minutes'],
        AppConfig.defaultSyncIntervalMinutes,
      ),
      emailNotifications: parseBool(json['email_notifications']),
      pushNotifications: parseBool(json['push_notifications'], true),
      syncNotifications: parseBool(json['sync_notifications'], true),
      financialNotifications: parseBool(json['financial_notifications'], true),
      taskNotifications: parseBool(json['task_notifications'], true),
      metricNotifications: parseBool(json['metric_notifications']),
      referralBaseUrl: parseRequiredString(json['referral_base_url']),
      createdAt: parseDate(json['created_at']) ?? now,
      updatedAt: parseDate(json['updated_at']) ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'email': email,
        'theme_mode': themeMode,
        'locale': locale,
        'timezone': timezone,
        'currency': currency,
        'base_currency': baseCurrency,
        'auto_sync_enabled': autoSyncEnabled,
        'sync_interval_minutes': syncIntervalMinutes,
        'email_notifications': emailNotifications,
        'push_notifications': pushNotifications,
        'sync_notifications': syncNotifications,
        'financial_notifications': financialNotifications,
        'task_notifications': taskNotifications,
        'metric_notifications': metricNotifications,
        'referral_base_url': referralBaseUrl,
        'created_at': isoDateTime(createdAt),
        'updated_at': isoDateTime(updatedAt),
      };

  UserSettings copyWith({
    String? displayName,
    String? email,
    String? themeMode,
    String? locale,
    String? timezone,
    String? currency,
    String? baseCurrency,
    bool? autoSyncEnabled,
    int? syncIntervalMinutes,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? syncNotifications,
    bool? financialNotifications,
    bool? taskNotifications,
    bool? metricNotifications,
    String? referralBaseUrl,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      userId: userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      currency: currency ?? this.currency,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      syncNotifications: syncNotifications ?? this.syncNotifications,
      financialNotifications:
          financialNotifications ?? this.financialNotifications,
      taskNotifications: taskNotifications ?? this.taskNotifications,
      metricNotifications: metricNotifications ?? this.metricNotifications,
      referralBaseUrl: referralBaseUrl ?? this.referralBaseUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
