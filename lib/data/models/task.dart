import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/utils/json_utils.dart';

enum TaskPriority { low, medium, high, urgent }

extension TaskPriorityInfo on TaskPriority {
  String get label => switch (this) {
        TaskPriority.low => 'Низкий',
        TaskPriority.medium => 'Средний',
        TaskPriority.high => 'Высокий',
        TaskPriority.urgent => 'Срочный',
      };
}

enum TaskStatus { todo, inProgress, done, cancelled }

extension TaskStatusInfo on TaskStatus {
  String get label => switch (this) {
        TaskStatus.todo => 'К выполнению',
        TaskStatus.inProgress => 'В работе',
        TaskStatus.done => 'Выполнено',
        TaskStatus.cancelled => 'Отменено',
      };
}

class Task {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskStatus status;
  final String? category;
  final String? channelId;
  final String? publicationId;
  final String? partnerId;
  final String? advertiserId;
  final DateTime? dueDate;
  final DateTime? reminderDate;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.category,
    this.channelId,
    this.publicationId,
    this.partnerId,
    this.advertiserId,
    this.dueDate,
    this.reminderDate,
    required this.createdAt,
    this.completedAt,
    required this.updatedAt,
  });

  bool get isOpen =>
      status == TaskStatus.todo || status == TaskStatus.inProgress;

  bool isOverdue([DateTime? now]) =>
      isOpen &&
      dueDate != null &&
      dueDate!.dateOnly.isBefore((now ?? DateTime.now()).dateOnly);

  bool isDueToday([DateTime? now]) =>
      isOpen && dueDate != null && dueDate!.isSameDay(now ?? DateTime.now());

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        title: parseRequiredString(json['title'], 'Без названия'),
        description: parseString(json['description']),
        priority: enumByName(
          TaskPriority.values,
          json['priority'],
          TaskPriority.medium,
        ),
        status: enumByName(
          TaskStatus.values,
          json['status'],
          TaskStatus.todo,
        ),
        category: parseString(json['category']),
        channelId: parseString(json['channel_id']),
        publicationId: parseString(json['publication_id']),
        partnerId: parseString(json['partner_id']),
        advertiserId: parseString(json['advertiser_id']),
        dueDate: parseDate(json['due_date']),
        reminderDate: parseDate(json['reminder_date']),
        createdAt: parseDateOrNow(json['created_at']),
        completedAt: parseDate(json['completed_at']),
        updatedAt: parseDateOrNow(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'priority': priority.name,
        'status': status.name,
        'category': category,
        'channel_id': channelId,
        'publication_id': publicationId,
        'partner_id': partnerId,
        'advertiser_id': advertiserId,
        'due_date': isoDateOrNull(dueDate),
        'reminder_date': isoDateTimeOrNull(reminderDate),
        'created_at': isoDateTime(createdAt),
        'completed_at': isoDateTimeOrNull(completedAt),
        'updated_at': isoDateTime(updatedAt),
      };

  Task copyWith({
    String? title,
    String? description,
    TaskPriority? priority,
    TaskStatus? status,
    String? category,
    String? channelId,
    String? publicationId,
    String? partnerId,
    String? advertiserId,
    DateTime? dueDate,
    DateTime? reminderDate,
    DateTime? completedAt,
    DateTime? updatedAt,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      channelId: channelId ?? this.channelId,
      publicationId: publicationId ?? this.publicationId,
      partnerId: partnerId ?? this.partnerId,
      advertiserId: advertiserId ?? this.advertiserId,
      dueDate: dueDate ?? this.dueDate,
      reminderDate: reminderDate ?? this.reminderDate,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
