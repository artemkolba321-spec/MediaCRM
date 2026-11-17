import 'package:media_crm/core/utils/json_utils.dart';

enum NotificationType {
  syncError,
  syncComplete,
  financial,
  taskReminder,
  metricChange,
  newSale,
  newRegistration,
  system,
}

extension NotificationTypeInfo on NotificationType {
  String get label => switch (this) {
        NotificationType.syncError => 'Ошибка синхронизации',
        NotificationType.syncComplete => 'Синхронизация завершена',
        NotificationType.financial => 'Финансовое событие',
        NotificationType.taskReminder => 'Напоминание о задаче',
        NotificationType.metricChange => 'Изменение показателей',
        NotificationType.newSale => 'Новая продажа',
        NotificationType.newRegistration => 'Новая регистрация',
        NotificationType.system => 'Системное',
      };
}

class NotificationItem {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final bool read;
  final String? relatedId;
  final String? relatedType;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.read = false,
    this.relatedId,
    this.relatedType,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        type: enumByName(
          NotificationType.values,
          json['type'],
          NotificationType.system,
        ),
        title: parseRequiredString(json['title'], 'Уведомление'),
        message: parseRequiredString(json['message']),
        read: parseBool(json['read']),
        relatedId: parseString(json['related_id']),
        relatedType: parseString(json['related_type']),
        createdAt: parseDateOrNow(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type.name,
        'title': title,
        'message': message,
        'read': read,
        'related_id': relatedId,
        'related_type': relatedType,
        'created_at': isoDateTime(createdAt),
      };

  NotificationItem copyWith({bool? read}) => NotificationItem(
        id: id,
        userId: userId,
        type: type,
        title: title,
        message: message,
        read: read ?? this.read,
        relatedId: relatedId,
        relatedType: relatedType,
        createdAt: createdAt,
      );
}

class ActivityLogEntry {
  final String id;
  final String userId;
  final String entityType;
  final String? entityId;
  final String action; // created, updated, deleted, synced, exported, imported
  final String title;
  final String? details;
  final DateTime createdAt;

  const ActivityLogEntry({
    required this.id,
    required this.userId,
    required this.entityType,
    this.entityId,
    required this.action,
    required this.title,
    this.details,
    required this.createdAt,
  });

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) =>
      ActivityLogEntry(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        entityType: parseRequiredString(json['entity_type']),
        entityId: parseString(json['entity_id']),
        action: parseRequiredString(json['action'], 'updated'),
        title: parseRequiredString(json['title']),
        details: parseString(json['details']),
        createdAt: parseDateOrNow(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'entity_type': entityType,
        'entity_id': entityId,
        'action': action,
        'title': title,
        'details': details,
        'created_at': isoDateTime(createdAt),
      };
}
