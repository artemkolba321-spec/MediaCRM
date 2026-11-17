import 'dart:async';

import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/analytics_snapshot.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/sync_run.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';
import 'package:uuid/uuid.dart';

class SyncActionResult {
  final bool success;
  final String message;
  final int metrics;
  final int publications;
  final bool manualOnly;

  const SyncActionResult({
    required this.success,
    required this.message,
    this.metrics = 0,
    this.publications = 0,
    this.manualOnly = false,
  });
}

class ChannelRepository {
  ChannelRepository({
    required LocalStore store,
    required CloudService cloud,
    required ActivityService activity,
  })  : _cloud = cloud,
        _activity = activity {
    _channels = EntityRepository<PlatformChannel>(
      store: store,
      cloud: cloud,
      collection: 'channels',
      fromJson: PlatformChannel.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.updatedAt,
      activity: activity,
    );
    _snapshots = EntityRepository<AnalyticsSnapshot>(
      store: store,
      cloud: cloud,
      collection: 'snapshots',
      fromJson: AnalyticsSnapshot.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.recordedAt,
    );
    _syncRuns = EntityRepository<SyncRun>(
      store: store,
      cloud: cloud,
      collection: 'sync_runs',
      fromJson: SyncRun.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.startedAt,
    );
  }

  final CloudService _cloud;
  final ActivityService _activity;
  late final EntityRepository<PlatformChannel> _channels;
  late final EntityRepository<AnalyticsSnapshot> _snapshots;
  late final EntityRepository<SyncRun> _syncRuns;
  final _uuid = const Uuid();

  List<PlatformChannel> getChannels() {
    final items = _channels.getAll()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  PlatformChannel? getChannel(String id) => _channels.getById(id);

  Future<PlatformChannel> saveChannel(PlatformChannel channel) async {
    final isNew = _channels.getById(channel.id) == null;
    final saved = await _channels.save(
      channel,
      actionLabel: isNew ? 'created' : 'updated',
      title: isNew
          ? 'Добавлена площадка «${channel.name}»'
          : 'Обновлена площадка «${channel.name}»',
    );
    return saved;
  }

  Future<void> deleteChannel(PlatformChannel channel) async {
    final snaps = _snapshots
        .getAll()
        .where((s) => s.channelId == channel.id)
        .toList();
    for (final snap in snaps) {
      await _snapshots.delete(snap.id);
    }
    await _channels.delete(
      channel.id,
      title: 'Удалена площадка «${channel.name}»',
    );
  }

  List<AnalyticsSnapshot> getSnapshots({
    String? channelId,
    String? metric,
    DateTime? start,
    DateTime? end,
    PlatformType? platform,
    Set<SnapshotSource>? sources,
  }) {
    var items = _snapshots.getAll();
    if (channelId != null) {
      items = items.where((e) => e.channelId == channelId).toList();
    }
    if (metric != null) {
      items = items.where((e) => e.metric == metric).toList();
    }
    if (start != null) {
      items = items
          .where((e) => !e.date.dateOnly.isBefore(start.dateOnly))
          .toList();
    }
    if (end != null) {
      items = items
          .where((e) => !e.date.dateOnly.isAfter(end.dateOnly))
          .toList();
    }
    if (platform != null) {
      items = items.where((e) => e.platform == platform).toList();
    }
    if (sources != null) {
      items = items.where((e) => sources.contains(e.source)).toList();
    }
    items.sort((a, b) => a.date.compareTo(b.date));
    return dedupeSnapshots(items);
  }

  List<AnalyticsSnapshot> dedupeSnapshots(List<AnalyticsSnapshot> input) {
    final byKey = <String, AnalyticsSnapshot>{};
    for (final snapshot in input) {
      final existing = byKey[snapshot.uniqueKey];
      if (existing == null ||
          snapshot.recordedAt.isAfter(existing.recordedAt)) {
        byKey[snapshot.uniqueKey] = snapshot;
      }
    }
    final result = byKey.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  Future<AnalyticsSnapshot> addManualSnapshot({
    required PlatformChannel channel,
    required DateTime date,
    required Map<String, double> metrics,
    String? note,
  }) async {
    AnalyticsSnapshot? last;
    for (final entry in metrics.entries) {
      if (entry.value.isNaN || entry.value < 0) continue;
      final snapshot = AnalyticsSnapshot(
        id: _uuid.v4(),
        userId: channel.userId,
        channelId: channel.id,
        platform: channel.platform,
        metric: entry.key,
        value: entry.value,
        date: date,
        source: SnapshotSource.manual,
        reliability: SnapshotReliability.manual,
        recordedAt: DateTime.now(),
      );
      last = snapshot;
      final existing = _snapshots.getAll().where(
            (s) => s.uniqueKey == snapshot.uniqueKey,
          );
      for (final old in existing) {
        await _snapshots.delete(old.id);
      }
      await _snapshots.append(snapshot);
    }
    if (metrics[AnalyticsMetric.followers] != null) {
      final followers = metrics[AnalyticsMetric.followers]!.round();
      await _channels.save(
        channel.copyWith(
          subscriberCount: followers,
          lastSyncAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ChannelStatus.connected,
        ),
      );
    }
    await _activity.log(
      entityType: 'snapshots',
      entityId: last?.id,
      action: 'imported',
      title: 'Ручной снимок метрик «${channel.name}»',
      details: note ?? 'Введён вручную, помечен как manual',
    );
    return last!;
  }

  List<SyncRun> getSyncRuns({String? channelId, int limit = 50}) {
    var runs = _syncRuns.getAll();
    if (channelId != null) {
      runs = runs.where((e) => e.channelId == channelId).toList();
    }
    runs.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return runs.take(limit).toList();
  }

  Future<void> recordSyncRun(SyncRun run) => _syncRuns.append(run);

  Future<SyncActionResult> syncChannel(
    PlatformChannel channel, {
    SyncTrigger trigger = SyncTrigger.manual,
  }) async {
    if (!_cloud.isConfigured) {
      return const SyncActionResult(
        success: false,
        manualOnly: true,
        message: 'Сервер не настроен. Настройте Supabase и Edge Functions '
            'для автоматического сбора статистики. Пока доступен ручной снимок '
            'метрик — он сохраняется как источник «manual».',
      );
    }
    if (!_cloud.isSignedIn) {
      return const SyncActionResult(
        success: false,
        manualOnly: true,
        message: 'Для серверной синхронизации войдите в облачный аккаунт.',
      );
    }
    if (channel.platform == PlatformType.boosty) {
      return const SyncActionResult(
        success: false,
        manualOnly: true,
        message: 'У Boosty нет публичного API. Используйте ручной импорт '
            'или загрузите CSV из личного кабинета Boosty.',
      );
    }
    final run = SyncRun(
      id: _uuid.v4(),
      userId: channel.userId,
      channelId: channel.id,
      platform: channel.platform,
      status: SyncRunStatus.running,
      trigger: trigger,
      startedAt: DateTime.now(),
    );
    await recordSyncRun(run);
    await _channels.save(
      channel.copyWith(
        status: ChannelStatus.syncing,
        clearError: true,
        updatedAt: DateTime.now(),
      ),
    );
    try {
      final response = await _cloud.invokeFunction(
        'platform-sync',
        body: {'channel_id': channel.id},
      );
      final ok = response['ok'] == true;
      final message = response['message']?.toString() ??
          (ok ? 'Синхронизация завершена' : 'Не удалось синхронизировать');
      final metrics = (response['metrics_written'] as num?)?.toInt() ?? 0;
      final publications =
          (response['publications_written'] as num?)?.toInt() ?? 0;
      final finished = SyncRun(
        id: run.id,
        userId: run.userId,
        channelId: run.channelId,
        platform: run.platform,
        status: ok ? SyncRunStatus.success : SyncRunStatus.error,
        trigger: trigger,
        startedAt: run.startedAt,
        finishedAt: DateTime.now(),
        message: message,
        metricsWritten: metrics,
        publicationsWritten: publications,
      );
      await _syncRuns.delete(run.id);
      await recordSyncRun(finished);
      final current = getChannel(channel.id) ?? channel;
      await _channels.save(
        current.copyWith(
          status: ok
              ? (current.hasCredentials
                  ? ChannelStatus.connected
                  : ChannelStatus.disconnected)
              : ChannelStatus.error,
          lastSyncAt: ok ? DateTime.now() : current.lastSyncAt,
          error: ok ? null : message,
          clearError: ok,
          updatedAt: DateTime.now(),
        ),
      );
      return SyncActionResult(
        success: ok,
        message: message,
        metrics: metrics,
        publications: publications,
      );
    } catch (error) {
      final message = _friendlyError(error);
      await _syncRuns.delete(run.id);
      await recordSyncRun(SyncRun(
        id: run.id,
        userId: run.userId,
        channelId: run.channelId,
        platform: run.platform,
        status: SyncRunStatus.error,
        trigger: trigger,
        startedAt: run.startedAt,
        finishedAt: DateTime.now(),
        message: message,
      ));
      final current = getChannel(channel.id) ?? channel;
      await _channels.save(
        current.copyWith(
          status: ChannelStatus.error,
          error: message,
          updatedAt: DateTime.now(),
        ),
      );
      return SyncActionResult(success: false, message: message);
    }
  }

  Future<SyncActionResult> syncAll({SyncTrigger trigger = SyncTrigger.manual}) async {
    final channels = getChannels();
    if (channels.isEmpty) {
      return const SyncActionResult(
        success: false,
        message: 'Сначала добавьте площадку',
      );
    }
    var success = 0;
    var failed = 0;
    var metrics = 0;
    var publications = 0;
    String? lastMessage;
    for (final channel in channels.where((c) => c.platform.supportsAutomaticSync)) {
      final result = await syncChannel(channel, trigger: trigger);
      lastMessage = result.message;
      if (result.success) {
        success++;
        metrics += result.metrics;
        publications += result.publications;
      } else if (!result.manualOnly) {
        failed++;
      }
    }
    return SyncActionResult(
      success: failed == 0,
      message: success == 0 && failed == 0
          ? (lastMessage ?? 'Нет площадок с поддержкой автоматической синхронизации')
          : 'Синхронизировано: $success, ошибок: $failed. '
              'Метрик: $metrics, публикаций: $publications.${lastMessage != null ? ' $lastMessage' : ''}',
      metrics: metrics,
      publications: publications,
    );
  }

  /// Returns true when OAuth is available: cloud configured and user signed in.
  bool get isOAuthAvailable => _cloud.isConfigured && _cloud.isSignedIn;

  Future<String> startOAuth(PlatformChannel channel) async {
    if (!isOAuthAvailable) {
      throw StateError(
        'Для OAuth необходим вход в облачный аккаунт Supabase. '
        'Войдите через меню настроек или используйте ручной ввод токена.',
      );
    }

    // Ensure the channel record is synced to Supabase before requesting OAuth.
    // EntityRepository.save() fires pushPending() asynchronously (unawaited),
    // so a freshly created channel may not exist in the cloud yet.
    // We must wait for the push AND verify the record is actually visible.
    final pushResult = await _cloud.pushPending();
    if (!pushResult.success) {
      throw StateError(
        'Не удалось синхронизировать площадку с облаком: '
        '${pushResult.error ?? 'неизвестная ошибка'}',
      );
    }

    // Verify the channel actually exists in the cloud before calling OAuth.
    // This catches the case where pushPending() returned success but the
    // upsert was not yet visible to Edge Functions (propagation delay).
    await _ensureChannelInCloud(channel);

    final response = await _cloud.invokeFunction(
      'platform-oauth-start',
      body: {
        'channel_id': channel.id,
        'user_id': channel.userId,
        'platform': channel.platform.name,
      },
    );
    final url = response['auth_url']?.toString();
    if (url == null || url.isEmpty) {
      throw StateError('Сервер не вернул OAuth URL');
    }
    return url;
  }

  /// Verifies that the channel record exists in the Supabase cloud.
  /// Retries once after a short delay if not found (propagation delay).
  Future<void> _ensureChannelInCloud(PlatformChannel channel) async {
    if (!_cloud.isConfigured || !_cloud.isSignedIn) return;

    final client = _cloud.client;
    if (client == null) return;

    final table = CloudService.collectionTables['channels'] ?? 'platform_channels';
    final userId = _cloud.userId;
    if (userId == null) return;

    // Try to find the channel in the cloud
    var found = false;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(milliseconds: 500));

      try {
        final result = await client
            .from(table)
            .select('id')
            .eq('id', channel.id)
            .eq('user_id', userId)
            .maybeSingle();

        if (result != null) {
          found = true;
          break;
        }
      } catch (_) {
        // Propagation delay — retry once
      }
    }

    if (!found) {
      throw StateError(
        'Площадка «${channel.name}» не найдена в облаке. '
        'Повторите попытку подключения.',
      );
    }
  }

  Future<void> saveServerCredential({
    required PlatformChannel channel,
    required String credential,
    required AuthMethod method,
    Map<String, dynamic> extra = const {},
  }) async {
    await _cloud.invokeFunction(
      'platform-connect',
      body: {
        'channel_id': channel.id,
        'platform': channel.platform.name,
        'credential': credential,
        'auth_method': method.name,
        'extra': extra,
      },
    );
    await _channels.save(
      channel.copyWith(
        authMethod: method,
        hasCredentials: true,
        status: ChannelStatus.connected,
        clearError: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> disconnectServerCredential(PlatformChannel channel) async {
    if (_cloud.isConfigured && _cloud.isSignedIn) {
      await _cloud.invokeFunction(
        'platform-disconnect',
        body: {'channel_id': channel.id},
      );
    }
    await _channels.save(
      channel.copyWith(
        hasCredentials: false,
        authMethod: AuthMethod.none,
        status: ChannelStatus.disconnected,
        clearError: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('FunctionException')) {
      return 'Ошибка Edge Function. Проверьте журнал Supabase и настройки '
          'токенов площадки.';
    }
    return text.length > 240 ? '${text.substring(0, 240)}…' : text;
  }
}
