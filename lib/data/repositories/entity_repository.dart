import 'dart:async';

import 'package:uuid/uuid.dart';

import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';

/// Generic offline-first CRUD repository. Domain repositories add calculations
/// and aggregate queries on top of this class.
class EntityRepository<T> {
  EntityRepository({
    required this.store,
    required this.cloud,
    required this.collection,
    required this.fromJson,
    required this.toJson,
    required this.idOf,
    required this.userIdOf,
    required this.updatedAtOf,
    this.activity,
  });

  final LocalStore store;
  final CloudService cloud;
  final String collection;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;
  final String Function(T) idOf;
  final String Function(T) userIdOf;
  final DateTime Function(T) updatedAtOf;
  final ActivityService? activity;

  String get _table => CloudService.collectionTables[collection] ?? collection;

  List<T> getAll() {
    final tombstones = store.deletedIds(collection);
    return store
        .readRaw(collection)
        .where((json) => !tombstones.contains(json['id']?.toString()))
        .map(fromJson)
        .toList();
  }

  T? getById(String id) {
    final tombstones = store.deletedIds(collection);
    if (tombstones.contains(id)) return null;
    final raw = store
        .readRaw(collection)
        .where((json) => json['id']?.toString() == id)
        .firstOrNull;
    return raw == null ? null : fromJson(raw);
  }

  Future<T> save(T item, {String? actionLabel, String? title}) async {
    final id = idOf(item);
    await store.unmarkDeleted(collection, id);
    await store.upsert(collection, toJson(item));
    await _queueUpsert(id);
    if (actionLabel != null) {
      await activity?.log(
        entityType: collection,
        entityId: id,
        action: actionLabel,
        title: title ?? actionLabel,
      );
    }
    unawaited(cloud.pushPending());
    return item;
  }

  /// Used by the server sync to persist already-final records without adding
  /// them to the outgoing queue.
  Future<void> saveFromRemote(T item) async {
    await store.upsert(collection, toJson(item));
  }

  Future<void> saveMany(List<T> items, {bool queue = false}) async {
    for (final item in items) {
      await store.upsert(collection, toJson(item));
      if (queue) await _queueUpsert(idOf(item));
    }
    if (queue) unawaited(cloud.pushPending());
  }

  Future<void> delete(String id, {String? title}) async {
    await store.deleteById(collection, id);
    await store.markDeleted(collection, id);
    await store.enqueue(
      collection: collection,
      entityId: id,
      operation: 'delete',
    );
    if (title != null) {
      await activity?.log(
        entityType: collection,
        entityId: id,
        action: 'deleted',
        title: title,
      );
    }
    unawaited(cloud.pushPending());
  }

  Future<void> _queueUpsert(String id) async {
    await store.enqueue(
      collection: collection,
      entityId: id,
      operation: 'upsert',
    );
    await store.setMeta('last_write.$collection', DateTime.now().toIso8601String());
  }

  /// A direct upsert for immutable history tables where `updated_at` is not
  /// meaningful.
  Future<void> append(T item) async {
    final id = idOf(item);
    if (getById(id) != null) return;
    await store.upsert(collection, toJson(item));
    await _queueUpsert(id);
    unawaited(cloud.pushPending());
  }

  String get remoteTable => _table;

  bool get isCloudAvailable => cloud.isConfigured && cloud.isSignedIn;

  String newId() => const Uuid().v4();
}

class ActivityService {
  ActivityService(this.store, this.cloud);

  final LocalStore store;
  final CloudService cloud;
  final _uuid = const Uuid();

  Future<void> log({
    required String entityType,
    String? entityId,
    required String action,
    required String title,
    String? details,
  }) async {
    final entry = {
      'id': _uuid.v4(),
      'user_id': store.userId,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'title': title,
      'details': details,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await store.upsert('activity_log', entry);
    await store.enqueue(
      collection: 'activity_log',
      entityId: entry['id']!,
      operation: 'upsert',
    );
    unawaited(cloud.pushPending());
  }
}
