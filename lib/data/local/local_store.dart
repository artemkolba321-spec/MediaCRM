import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent document store used as the local source of truth.
///
/// The app works fully offline; when Supabase is configured every mutation is
/// also placed into a durable sync queue and pushed to PostgreSQL. Data is
/// namespaced by user id, so switching accounts on one device cannot leak
/// another user's records into the UI.
class LocalStore {
  LocalStore();

  static const int schemaVersion = 2;
  static const String _prefix = 'mcrm.v2';

  static const List<String> collections = [
    'channels',
    'snapshots',
    'sync_runs',
    'demographics',
    'operations',
    'partners',
    'partner_events',
    'contacts',
    'interactions',
    'segments',
    'publications',
    'publication_stats',
    'advertisers',
    'campaigns',
    'advertiser_notes',
    'campaign_documents',
    'funnels',
    'stages',
    'deals',
    'tasks',
    'notifications',
    'activity_log',
    'currency_rates',
  ];

  SharedPreferences? _prefs;
  String? _userId;

  String get userId => _userId ?? 'local-owner';

  Future<void> init() async {
    if (_prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 15));
      if (_prefs != null && _prefs!.get('$_prefix.schema_version') == null) {
        await _prefs!.setInt('$_prefix.schema_version', schemaVersion)
            .timeout(const Duration(seconds: 5), onTimeout: () => true);
      }
    } catch (_) {
      // init failed — _prefs stays null, all operations become no-ops
      _prefs = null;
    }
  }

  void useUser(String userId) {
    _userId = userId;
  }

  String _key(String name) => '$_prefix.$userId.$name';

  Future<void> _ensure() async {
    if (_prefs == null) await init();
  }

  // ---------------------------------------------------------------------------
  // Generic collections
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> readRaw(String collection) {
    final raw = _prefs?.getString(_key(collection));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      // Corrupted local payload: keep the app usable instead of crashing.
    }
    return [];
  }

  List<T> read<T>(String collection, T Function(Map<String, dynamic>) fromJson) {
    return readRaw(collection).map(fromJson).toList();
  }

  Future<void> writeRaw(
    String collection,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      await _ensure();
      final encoded = jsonEncode(items);
      await _prefs!.setString(_key(collection), encoded).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // SharedPreferences can hang on Linux when the JSON payload is
          // too large or the underlying isolate is stuck.  Log and continue
          // so the UI never blocks forever.
          _logWriteError(collection, encoded);
          return true;
        },
      );
    } catch (e) {
      // Never let a write failure block the UI.  The data is already in
      // memory and the caller's Future completes with the item intact.
      _logWriteError(collection, null);
    }
  }

  Future<void> upsert(
    String collection,
    Map<String, dynamic> json, {
    String idField = 'id',
  }) async {
    final items = readRaw(collection);
    final id = json[idField]?.toString();
    final index = items.indexWhere((e) => e[idField]?.toString() == id);
    if (index >= 0) {
      items[index] = json;
    } else {
      items.add(json);
    }
    await writeRaw(collection, items);
  }

  Future<void> deleteById(String collection, String id) async {
    final items = readRaw(collection)
      ..removeWhere((e) => e['id']?.toString() == id);
    await writeRaw(collection, items);
  }

  Future<void> replaceAll(
    String collection,
    List<Map<String, dynamic>> items,
  ) =>
      writeRaw(collection, items);

  // ---------------------------------------------------------------------------
  // Settings / metadata
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? readSettings() {
    final raw = _prefs?.getString(_key('settings'));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> writeSettings(Map<String, dynamic> json) async {
    try {
      await _ensure();
      await _prefs!.setString(
        _key('settings'),
        jsonEncode(json),
      ).timeout(const Duration(seconds: 10), onTimeout: () => true);
    } catch (_) {}
  }

  String? getMeta(String key) => _prefs?.getString(_key('meta.$key'));

  Future<void> setMeta(String key, String? value) async {
    try {
      await _ensure();
      if (value == null) {
        await _prefs!.remove(_key('meta.$key'));
      } else {
        await _prefs!.setString(_key('meta.$key'), value)
            .timeout(const Duration(seconds: 10), onTimeout: () => true);
      }
    } catch (_) {}
  }

  bool getLocalMode() => _prefs?.getBool('$_prefix.local_mode') ?? false;

  Future<void> setLocalMode(bool value) async {
    await _ensure();
    await _prefs!.setBool('$_prefix.local_mode', value);
  }

  Map<String, dynamic>? getLocalProfile() {
    final raw = _prefs?.getString('$_prefix.local_profile');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> saveLocalProfile(Map<String, dynamic> profile) async {
    try {
      await _ensure();
      await _prefs!.setString(
        '$_prefix.local_profile',
        jsonEncode(profile),
      ).timeout(const Duration(seconds: 10), onTimeout: () => true);
    } catch (_) {}
  }

  Future<void> clearLocalSession() async {
    try {
      await _ensure();
      await _prefs!.remove('$_prefix.local_mode');
      await _prefs!.remove('$_prefix.local_profile');
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Deletion tombstones and sync queue
  // ---------------------------------------------------------------------------

  Set<String> deletedIds(String collection) {
    final raw = getMeta('deleted.$collection');
    if (raw == null || raw.isEmpty) return {};
    return raw.split('|').where((e) => e.isNotEmpty).toSet();
  }

  Future<void> markDeleted(String collection, String id) async {
    final ids = deletedIds(collection)..add(id);
    await setMeta('deleted.$collection', ids.join('|'));
  }

  Future<void> unmarkDeleted(String collection, String id) async {
    final ids = deletedIds(collection)..remove(id);
    await setMeta('deleted.$collection', ids.join('|'));
  }

  List<Map<String, dynamic>> readQueue() {
    final raw = _prefs?.getString(_key('sync_queue'));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> writeQueue(List<Map<String, dynamic>> queue) async {
    try {
      await _ensure();
      await _prefs!.setString(
        _key('sync_queue'),
        jsonEncode(queue),
      ).timeout(const Duration(seconds: 10), onTimeout: () => true);
    } catch (_) {}
  }

  Future<void> enqueue({
    required String collection,
    required String entityId,
    required String operation,
  }) async {
    final queue = readQueue();
    queue.removeWhere(
      (e) => e['collection'] == collection && e['entity_id'] == entityId,
    );
    queue.add({
      'collection': collection,
      'entity_id': entityId,
      'operation': operation,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    });
    await writeQueue(queue);
  }

  Future<void> removeQueueItem(String collection, String entityId) async {
    final queue = readQueue()
      ..removeWhere(
        (e) => e['collection'] == collection && e['entity_id'] == entityId,
      );
    await writeQueue(queue);
  }

  int get pendingChanges => readQueue().length;

  // ---------------------------------------------------------------------------
  // Backup / restore
  // ---------------------------------------------------------------------------

  Map<String, dynamic> exportBackup({Map<String, dynamic>? settings}) {
    final data = <String, dynamic>{};
    for (final collection in collections) {
      data[collection] = readRaw(collection);
    }
    return {
      'format': 'mediacrm-backup',
      'version': schemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'user_id': userId,
      'settings': settings ?? readSettings(),
      'data': data,
    };
  }

  Future<void> importBackup(Map<String, dynamic> backup) async {
    final data = backup['data'];
    if (data is! Map) {
      throw const FormatException('Файл не содержит секцию data');
    }
    for (final collection in collections) {
      final items = data[collection];
      if (items is List) {
        await replaceAll(
          collection,
          items
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
    }
    final settings = backup['settings'];
    if (settings is Map) {
      await writeSettings(Map<String, dynamic>.from(settings));
    }
  }

  Future<void> clearAllData() async {
    try {
      for (final collection in collections) {
        await _prefs?.remove(_key(collection));
      }
      await _prefs?.remove(_key('settings'));
      await _prefs?.remove(_key('sync_queue'));
      final keys = _prefs?.getKeys().where((k) => k.startsWith(_key('meta.'))).toList() ?? [];
      for (final key in keys) {
        await _prefs?.remove(key);
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Error logging (silent — no UI impact)
  // ---------------------------------------------------------------------------

  void _logWriteError(String collection, String? data) {
    // Silently log — never throw, never block UI.
    // In production this could route to a logging service.
    // Using toString to avoid import of flutter foundation.
    _silentLog('[LocalStore] write error on "$collection"');
  }

  // ignore: avoid_print
  void _silentLog(String msg) {
    print(msg);
  }
}
