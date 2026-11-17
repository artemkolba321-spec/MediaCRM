import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:media_crm/core/config/app_config.dart';
import 'package:media_crm/data/local/local_store.dart';

class CloudSyncResult {
  final bool success;
  final int pushed;
  final int pulled;
  final String? error;

  const CloudSyncResult({
    required this.success,
    this.pushed = 0,
    this.pulled = 0,
    this.error,
  });

  static const notConfigured = CloudSyncResult(
    success: false,
    error: 'Облачный backend не настроен',
  );
}

/// Offline-first bridge to Supabase. Local changes are queued durably and are
/// retried after connectivity or authorization problems.
class CloudService {
  CloudService(this._client, this._store);

  final SupabaseClient? _client;
  final LocalStore _store;

  Future<CloudSyncResult>? _flushing;
  String? lastError;
  DateTime? lastSyncedAt;

  bool get isConfigured => _client != null;
  bool get isSignedIn =>
      _client != null &&
      (_client!.auth.currentUser != null ||
          _client!.auth.currentSession != null);
  String? get userId => _client?.auth.currentUser?.id;
  String? get email => _client?.auth.currentUser?.email;

  SupabaseClient? get client => _client;

  static const Map<String, String> collectionTables = {
    'channels': 'platform_channels',
    'snapshots': 'analytics_snapshots',
    'sync_runs': 'sync_runs',
    'demographics': 'audience_demographics',
    'operations': 'financial_operations',
    'partners': 'partners',
    'partner_events': 'partner_events',
    'contacts': 'contacts',
    'interactions': 'contact_interactions',
    'segments': 'audience_segments',
    'publications': 'publications',
    'publication_stats': 'publication_stats',
    'advertisers': 'advertisers',
    'campaigns': 'ad_campaigns',
    'advertiser_notes': 'advertiser_notes',
    'campaign_documents': 'campaign_documents',
    'funnels': 'funnels',
    'stages': 'funnel_stages',
    'deals': 'funnel_deals',
    'tasks': 'tasks',
    'notifications': 'notifications',
    'activity_log': 'activity_log',
    'currency_rates': 'currency_rates',
  };

  static const Set<String> _mutableCollections = {
    'channels',
    'operations',
    'partners',
    'contacts',
    'segments',
    'publications',
    'advertisers',
    'campaigns',
    'funnels',
    'stages',
    'deals',
    'tasks',
    'notifications',
  };

  Future<CloudSyncResult> pushPending() {
    if (!isConfigured || !isSignedIn) {
      return Future.value(CloudSyncResult.notConfigured);
    }
    return _flushing ??= _pushPending().whenComplete(() => _flushing = null);
  }

  Future<CloudSyncResult> _pushPending() async {
    final client = _client!;
    final queue = _store.readQueue();
    if (queue.isEmpty) {
      return const CloudSyncResult(success: true);
    }
    var pushed = 0;
    final failed = <Map<String, dynamic>>[];
    for (var i = 0; i < queue.length; i++) {
      final item = queue[i];
      final collection = item['collection']?.toString() ?? '';
      final table = collectionTables[collection];
      final id = item['entity_id']?.toString() ?? '';
      if (table == null || id.isEmpty) continue;
      try {
        if (item['operation'] == 'delete') {
          await client.from(table).delete().eq('id', id);
        } else {
          final entity = _store
              .readRaw(collection)
              .where((e) => e['id']?.toString() == id)
              .firstOrNull;
          if (entity != null) {
            final payload = Map<String, dynamic>.from(entity)
              ..['user_id'] = userId;
            if (collection == 'currency_rates') {
              await client
                  .from(table)
                  .upsert(payload, onConflict: 'user_id,code');
            } else if (collection == 'snapshots') {
              await client
                  .from(table)
                  .upsert(payload, onConflict: 'channel_id,metric,date,source');
            } else {
              await client.from(table).upsert(payload, onConflict: 'id');
            }
          }
        }
        pushed++;
      } catch (error) {
        // Access-token errors abort the whole run; we keep the queue intact.
        lastError = _humanize(error);
        failed.addAll(queue.sublist(i));
        break;
      }
    }
    await _rewriteQueue(failed);
    if (failed.isNotEmpty) {
      return CloudSyncResult(success: false, pushed: pushed, error: lastError);
    }
    lastError = null;
    return CloudSyncResult(success: true, pushed: pushed);
  }

  Future<CloudSyncResult> pullAll() async {
    if (!isConfigured || !isSignedIn) {
      return Future.value(CloudSyncResult.notConfigured);
    }
    var pulled = 0;
    try {
      for (final entry in collectionTables.entries) {
        final collection = entry.key;
        final table = entry.value;
        if (collection == 'currency_rates') continue;
        if (collection == 'sync_runs' && _store.readRaw(collection).length > 500) {
          continue;
        }
        final rows = await _fetchAll(table);
        final local = _store.readRaw(collection);
        final byId = {for (final item in local) item['id']?.toString(): item};
        final tombstones = _store.deletedIds(collection);
        var changed = false;
        for (final row in rows) {
          final id = row['id']?.toString();
          if (id == null || tombstones.contains(id)) continue;
          final existing = byId[id];
          if (existing == null) {
            byId[id] = row;
            changed = true;
            pulled++;
          } else if (_isNewerRemote(collection, existing, row)) {
            byId[id] = row;
            changed = true;
            pulled++;
          }
        }
        if (changed) {
          await _store.replaceAll(collection, byId.values.toList());
        }
      }
      lastSyncedAt = DateTime.now();
      lastError = null;
      return CloudSyncResult(success: true, pulled: pulled);
    } catch (error) {
      lastError = _humanize(error);
      return CloudSyncResult(success: false, pulled: pulled, error: lastError);
    }
  }

  Future<CloudSyncResult> synchronize() async {
    if (!isConfigured || !isSignedIn) {
      return CloudSyncResult.notConfigured;
    }
    final push = await pushPending();
    final pull = await pullAll();
    return CloudSyncResult(
      success: push.success && pull.success,
      pushed: push.pushed,
      pulled: pull.pulled,
      error: push.error ?? pull.error,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAll(String table) async {
    const pageSize = 1000;
    final result = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final page = await _client!
          .from(table)
          .select()
          .eq('user_id', userId!)
          .order('id')
          .range(from, from + pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(page);
      result.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
      if (from > 50000) break;
    }
    return result;
  }

  bool _isNewerRemote(
    String collection,
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    if (!_mutableCollections.contains(collection)) return false;
    final localUpdated = DateTime.tryParse(
          local['updated_at']?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final remoteUpdated = DateTime.tryParse(
          remote['updated_at']?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return remoteUpdated.isAfter(localUpdated);
  }

  Future<void> _rewriteQueue(List<Map<String, dynamic>> queue) async {
    await _store.writeQueue(queue);
  }

  String _humanize(Object error) {
    final text = error.toString();
    if (text.contains('JWT') || text.contains('401')) {
      return 'Сессия истекла. Войдите снова.';
    }
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('fetch')) {
      return 'Нет соединения с сервером. Изменения сохранены локально.';
    }
    if (error is PostgrestException) {
      return error.message;
    }
    if (error is FunctionException) {
      return error.details?.toString() ?? error.toString();
    }
    return text.length > 220 ? '${text.substring(0, 220)}…' : text;
  }

  /// Invokes a trusted server-side Edge Function. Tokens/OAuth secrets never
  /// enter the Flutter process.
  ///
  /// Requires cloud to be configured. The Supabase SDK automatically attaches
  /// the current session (JWT) as the Authorization header. If no valid session
  /// exists the call will fail with a 401 — no pre-check needed.
  Future<Map<String, dynamic>> invokeFunction(
    String name, {
    Map<String, dynamic>? body,
  }) async {
    if (!isConfigured) {
      throw StateError('Supabase не настроен. Укажите SUPABASE_URL и '
          'SUPABASE_ANON_KEY при сборке.');
    }
    final response = await _client!.functions.invoke(name, body: body);
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'data': data};
  }

  String get statusLabel {
    if (!AppConfig.isCloudConfigured) return 'Локальный режим';
    if (!isSignedIn) return 'Не выполнен вход';
    return 'Облако подключено';
  }
}
