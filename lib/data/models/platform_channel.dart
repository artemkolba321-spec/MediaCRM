import 'package:media_crm/core/utils/json_utils.dart';

enum PlatformType { youtube, telegram, boosty, vk, github }

extension PlatformTypeInfo on PlatformType {
  String get label => switch (this) {
        PlatformType.youtube => 'YouTube',
        PlatformType.telegram => 'Telegram',
        PlatformType.boosty => 'Boosty',
        PlatformType.vk => 'ВКонтакте',
        PlatformType.github => 'GitHub',
      };

  String get shortLabel => switch (this) {
        PlatformType.youtube => 'YT',
        PlatformType.telegram => 'TG',
        PlatformType.boosty => 'BO',
        PlatformType.vk => 'VK',
        PlatformType.github => 'GH',
      };

  String get apiNote => switch (this) {
        PlatformType.youtube =>
          'YouTube Data API + YouTube Analytics API (OAuth 2.0)',
        PlatformType.telegram => 'Telegram Bot API (бот-администратор канала)',
        PlatformType.boosty =>
          'Публичного API нет — доступен только ручной импорт',
        PlatformType.vk => 'VK API (токен с правами администратора сообщества)',
        PlatformType.github => 'GitHub REST API (OAuth или fine-grained token)',
      };

  bool get supportsAutomaticSync => this != PlatformType.boosty;
}

enum ChannelStatus { connected, disconnected, error, syncing }

extension ChannelStatusInfo on ChannelStatus {
  String get label => switch (this) {
        ChannelStatus.connected => 'Подключено',
        ChannelStatus.disconnected => 'Не подключено',
        ChannelStatus.error => 'Ошибка доступа',
        ChannelStatus.syncing => 'Синхронизация',
      };
}

enum AuthMethod { none, oauth, botToken, accessToken, manual }

extension AuthMethodInfo on AuthMethod {
  String get label => switch (this) {
        AuthMethod.none => 'Не настроено',
        AuthMethod.oauth => 'OAuth 2.0',
        AuthMethod.botToken => 'Токен бота',
        AuthMethod.accessToken => 'Access token',
        AuthMethod.manual => 'Ручной ввод',
      };
}

class PlatformChannel {
  final String id;
  final String userId;
  final PlatformType platform;
  final String name;
  final String? url;
  final String? description;
  final String? avatarUrl;
  final String? platformId;
  final ChannelStatus status;
  final DateTime? lastSyncAt;
  final int subscriberCount;
  final bool autoSync;
  final int? syncIntervalMinutes;
  final String? error;
  final Map<String, dynamic> settings;
  final AuthMethod authMethod;
  final bool hasCredentials;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlatformChannel({
    required this.id,
    required this.userId,
    required this.platform,
    required this.name,
    this.url,
    this.description,
    this.avatarUrl,
    this.platformId,
    this.status = ChannelStatus.disconnected,
    this.lastSyncAt,
    this.subscriberCount = 0,
    this.autoSync = true,
    this.syncIntervalMinutes,
    this.error,
    this.settings = const {},
    this.authMethod = AuthMethod.none,
    this.hasCredentials = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isConnected =>
      status == ChannelStatus.connected && hasCredentials;

  factory PlatformChannel.fromJson(Map<String, dynamic> json) {
    return PlatformChannel(
      id: parseRequiredString(json['id']),
      userId: parseRequiredString(json['user_id']),
      platform: enumByName(
        PlatformType.values,
        json['platform'],
        PlatformType.youtube,
      ),
      name: parseRequiredString(json['name'], 'Без названия'),
      url: parseString(json['url']),
      description: parseString(json['description']),
      avatarUrl: parseString(json['avatar_url']),
      platformId: parseString(json['platform_id']),
      status: enumByName(
        ChannelStatus.values,
        json['status'],
        ChannelStatus.disconnected,
      ),
      lastSyncAt: parseDate(json['last_sync_at']),
      subscriberCount: parseInt(json['subscriber_count']),
      autoSync: parseBool(json['auto_sync'], true),
      syncIntervalMinutes: parseIntOrNull(json['sync_interval_minutes']),
      error: parseString(json['error']),
      settings: parseMap(json['settings']),
      authMethod: enumByName(
        AuthMethod.values,
        json['auth_method'],
        AuthMethod.none,
      ),
      hasCredentials: parseBool(json['has_credentials']),
      createdAt: parseDateOrNow(json['created_at']),
      updatedAt: parseDateOrNow(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'platform': platform.name,
        'name': name,
        'url': url,
        'description': description,
        'avatar_url': avatarUrl,
        'platform_id': platformId,
        'status': status.name,
        'last_sync_at': isoDateTimeOrNull(lastSyncAt),
        'subscriber_count': subscriberCount,
        'auto_sync': autoSync,
        'sync_interval_minutes': syncIntervalMinutes,
        'error': error,
        'settings': settings,
      'auth_method': authMethod.name,
      'has_credentials': hasCredentials,
      'created_at': isoDateTime(createdAt),
      'updated_at': isoDateTime(updatedAt),
      };

  PlatformChannel copyWith({
    String? id,
    String? userId,
    PlatformType? platform,
    String? name,
    String? url,
    String? description,
    String? avatarUrl,
    String? platformId,
    ChannelStatus? status,
    DateTime? lastSyncAt,
    int? subscriberCount,
    bool? autoSync,
    int? syncIntervalMinutes,
    String? error,
    bool clearError = false,
    Map<String, dynamic>? settings,
    AuthMethod? authMethod,
    bool? hasCredentials,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlatformChannel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      platform: platform ?? this.platform,
      name: name ?? this.name,
      url: url ?? this.url,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      platformId: platformId ?? this.platformId,
      status: status ?? this.status,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      autoSync: autoSync ?? this.autoSync,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      error: clearError ? null : (error ?? this.error),
      settings: settings ?? this.settings,
      authMethod: authMethod ?? this.authMethod,
      hasCredentials: hasCredentials ?? this.hasCredentials,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
