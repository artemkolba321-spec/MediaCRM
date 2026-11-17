import 'package:uuid/uuid.dart';

import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/notification_item.dart';
import 'package:media_crm/data/models/task.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';
import 'package:media_crm/data/repositories/notification_repository.dart';

class TaskRepository {
  TaskRepository({
    required LocalStore store,
    required CloudService cloud,
    required ActivityService activity,
    required NotificationRepository notifications,
  })  : _notifications = notifications,
        _store = store {
    _tasks = EntityRepository<Task>(
      store: store,
      cloud: cloud,
      collection: 'tasks',
      fromJson: Task.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.updatedAt,
      activity: activity,
    );
  }

  final NotificationRepository _notifications;
  final LocalStore _store;
  late final EntityRepository<Task> _tasks;
  final _uuid = const Uuid();

  List<Task> getTasks({
    TaskStatus? status,
    TaskPriority? priority,
    String? category,
    String? search,
    bool overdueOnly = false,
    bool dueToday = false,
    bool includeDone = true,
  }) {
    var items = _tasks.getAll();
    if (status != null) {
      items = items.where((t) => t.status == status).toList();
    } else if (!includeDone) {
      items = items
          .where((t) => t.status != TaskStatus.done && t.status != TaskStatus.cancelled)
          .toList();
    }
    if (priority != null) {
      items = items.where((t) => t.priority == priority).toList();
    }
    if (category != null && category.isNotEmpty) {
      items = items.where((t) => t.category == category).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      items = items
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.description ?? '').toLowerCase().contains(q))
          .toList();
    }
    if (overdueOnly) items = items.where((t) => t.isOverdue()).toList();
    if (dueToday) items = items.where((t) => t.isDueToday()).toList();
    items.sort((a, b) {
      final dueA = a.dueDate ?? DateTime(2100);
      final dueB = b.dueDate ?? DateTime(2100);
      final byDate = dueA.compareTo(dueB);
      if (byDate != 0) return byDate;
      return a.priority.index.compareTo(b.priority.index);
    });
    return items;
  }

  Task? getTask(String id) => _tasks.getById(id);

  Future<Task> saveTask(Task task) async {
    final isNew = _tasks.getById(task.id) == null;
    return _tasks.save(
      task,
      actionLabel: isNew ? 'created' : 'updated',
      title: isNew ? 'Создана задача «${task.title}»' : 'Обновлена задача «${task.title}»',
    );
  }

  Future<Task> changeStatus(Task task, TaskStatus status) {
    final now = DateTime.now();
    return saveTask(task.copyWith(
      status: status,
      completedAt: status == TaskStatus.done ? now : null,
      clearCompletedAt: status != TaskStatus.done,
      updatedAt: now,
    ));
  }

  Future<void> deleteTask(Task task) => _tasks.delete(
        task.id,
        title: 'Удалена задача «${task.title}»',
      );

  Map<DateTime, List<Task>> calendar(DateTime month) {
    final result = <DateTime, List<Task>>{};
    for (final task in getTasks()) {
      if (task.dueDate == null) continue;
      final date = task.dueDate!.dateOnly;
      if (date.year != month.year || date.month != month.month) continue;
      result.putIfAbsent(date, () => []).add(task);
    }
    return result;
  }

  /// Creates in-app reminders for tasks whose reminder time has passed.
  /// Deduplicated by task id and day.
  Future<int> syncReminders() async {
    var created = 0;
    final settings = _store.readSettings();
    final enabled = settings?['task_notifications'] != false;
    if (!enabled) return 0;
    final now = DateTime.now();
    for (final task in getTasks(includeDone: false)) {
      final reminder = task.reminderDate ?? task.dueDate;
      if (reminder == null) continue;
      if (reminder.isAfter(now)) continue;
      final already = _notifications.hasNotificationFor(
        type: NotificationType.taskReminder,
        relatedId: task.id,
        onDay: now,
      );
      if (already) continue;
      await _notifications.create(
        type: NotificationType.taskReminder,
        title: 'Напоминание: ${task.title}',
        message: task.dueDate == null
            ? 'Задача ожидает выполнения'
            : 'Срок: ${task.dueDate!.formatDateTime()}',
        relatedId: task.id,
        relatedType: 'task',
      );
      created++;
    }
    return created;
  }

  int get overdueCount => getTasks(overdueOnly: true).length;
  int get openCount => getTasks(includeDone: false).length;

  String newTaskId() => _uuid.v4();
}
