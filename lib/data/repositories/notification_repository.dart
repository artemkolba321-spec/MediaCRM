import 'package:uuid/uuid.dart';

import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/notification_item.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';

class NotificationRepository {
  NotificationRepository({
    required LocalStore store,
    required CloudService cloud,
  }) : _store = store {
    _notifications = EntityRepository<NotificationItem>(
      store: store,
      cloud: cloud,
      collection: 'notifications',
      fromJson: NotificationItem.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.createdAt,
    );
  }

  final LocalStore _store;
  late final EntityRepository<NotificationItem> _notifications;
  final _uuid = const Uuid();

  List<NotificationItem> getNotifications({
    bool? read,
    NotificationType? type,
    int limit = 200,
  }) {
    var items = _notifications.getAll();
    if (read != null) items = items.where((n) => n.read == read).toList();
    if (type != null) items = items.where((n) => n.type == type).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(limit).toList();
  }

  int get unreadCount =>
      _notifications.getAll().where((n) => !n.read).length;

  Future<NotificationItem> create({
    required NotificationType type,
    required String title,
    required String message,
    String? relatedId,
    String? relatedType,
  }) async {
    final item = NotificationItem(
      id: _uuid.v4(),
      userId: _store.userId,
      type: type,
      title: title,
      message: message,
      relatedId: relatedId,
      relatedType: relatedType,
      createdAt: DateTime.now(),
    );
    await _notifications.append(item);
    return item;
  }

  Future<void> markAsRead(NotificationItem item) async {
    final current = _notifications.getById(item.id);
    if (current == null) return;
    await _notifications.save(current.copyWith(read: true));
  }

  Future<void> markAllAsRead() async {
    for (final item in getNotifications(read: false)) {
      await _notifications.save(item.copyWith(read: true));
    }
  }

  Future<void> delete(NotificationItem item) => _notifications.delete(item.id);

  bool hasNotificationFor({
    required NotificationType type,
    String? relatedId,
    DateTime? onDay,
  }) {
    final day = (onDay ?? DateTime.now()).dateOnly;
    return _notifications.getAll().any((n) =>
        n.type == type &&
        n.relatedId == relatedId &&
        n.createdAt.dateOnly == day);
  }
}
