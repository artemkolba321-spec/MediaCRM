import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/task.dart';
import 'package:media_crm/providers/app_providers.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _search = TextEditingController();
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final created = await ref.read(taskRepositoryProvider).syncReminders();
      if (created > 0 && mounted) {
        bumpData(ref);
        ref.read(syncControllerProvider.notifier).refreshPending();
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(taskRepositoryProvider);
    final filter = ref.watch(taskFilterProvider);
    final colors = context.colors;
    final all = repo.getTasks();
    final tasks = repo.getTasks(
      search: _search.text,
      overdueOnly: filter.overdueOnly,
      includeDone: true,
    );
    final filtered = tasks.where((task) {
      if (filter.statuses.isNotEmpty && !filter.statuses.contains(task.status)) {
        return false;
      }
      if (filter.priorities.isNotEmpty &&
          !filter.priorities.contains(task.priority)) {
        return false;
      }
      return true;
    }).toList();

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Задачи',
            subtitle:
                'Список, Kanban и календарь. Напоминания создаются в приложении '
                'и только пока оно открыто; системные push-уведомления не '
                'настроены.',
            actions: [
              FilledButton.icon(
                onPressed: () => _openTaskForm(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Новая задача'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 720
                      ? 2
                      : 1;
              const gap = 12.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Открытых задач',
                      value: '${repo.openCount}',
                      icon: Icons.task_alt_outlined,
                      color: colors.accent,
                      footnote: 'Всего ${all.length}',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Просрочено',
                      value: '${repo.overdueCount}',
                      icon: Icons.warning_amber_outlined,
                      color: repo.overdueCount > 0 ? colors.red : colors.green,
                      footnote: 'Срок раньше сегодня',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'На сегодня',
                      value: '${repo.getTasks(dueToday: true).length}',
                      icon: Icons.today_outlined,
                      color: colors.blue,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Выполнено',
                      value: '${all.where((t) => t.status == TaskStatus.done).length}',
                      icon: Icons.check_circle_outline_rounded,
                      color: colors.green,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilterBarShell(
            children: [
              SizedBox(
                width: 230,
                child: SearchField(
                  controller: _search,
                  hint: 'Название или описание…',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              _priorityFilter(colors),
              FilterChip(
                label: const Text('Только просроченные'),
                selected: filter.overdueOnly,
                onSelected: (value) => ref
                    .read(taskFilterProvider.notifier)
                    .state = filter.copyWith(overdueOnly: value),
              ),
              const Spacer(),
              SegmentedTabs(
                tabs: const ['Список', 'Kanban', 'Календарь'],
                selected: filter.view.index,
                onChanged: (index) => ref
                    .read(taskFilterProvider.notifier)
                    .state = filter.copyWith(view: TaskView.values[index]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (all.isEmpty)
            EmptyState(
              title: 'Задач пока нет',
              message:
                  'Создайте задачу со сроком и приоритетом. Задачи хранятся '
                  'локально; напоминания появляются в разделе «Уведомления» '
                  'при открытом приложении.',
              icon: Icons.task_alt_outlined,
              action: FilledButton.icon(
                onPressed: () => _openTaskForm(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Создать задачу'),
              ),
            )
          else if (filtered.isEmpty)
            const EmptyState(
              title: 'Ничего не найдено',
              message: 'Измените запрос или фильтры.',
              icon: Icons.search_off_rounded,
              compact: true,
            )
          else
            switch (filter.view) {
              TaskView.list => _TaskList(
                  tasks: filtered,
                  onOpen: (task) => _openTaskForm(task: task),
                  onStatus: (task, status) => _changeStatus(task, status),
                  onDelete: (task) => _deleteTask(task),
                ),
              TaskView.board => _TaskBoard(
                  tasks: filtered,
                  onOpen: (task) => _openTaskForm(task: task),
                  onDrop: (task, status) => _changeStatus(task, status),
                  onAdd: (status) => _openTaskForm(initialStatus: status),
                ),
              TaskView.calendar => _TaskCalendar(
                  month: _month,
                  tasks: filtered,
                  onMonthChanged: (month) => setState(() => _month = month),
                  onOpen: (task) => _openTaskForm(task: task),
                  onAdd: (day) => _openTaskForm(initialDueDate: day),
                ),
            },
          const SizedBox(height: 16),
          const DataSourceNote(
            text:
                'Напоминания создаются внутри приложения при открытии раздела '
                '«Задачи» и дедуплицируются по задаче и дню. Фоновая '
                'синхронизация и системные уведомления в этой версии не '
                'реализованы.',
          ),
        ],
      ),
    );
  }

  Widget _priorityFilter(AppColors colors) {
    final filter = ref.watch(taskFilterProvider);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TaskPriority?>(
          value: filter.priorities.length == 1
              ? filter.priorities.first
              : null,
          hint: Text('Все приоритеты',
              style: TextStyle(fontSize: 11.5, color: colors.muted)),
          isDense: true,
          dropdownColor: colors.panel,
          style: TextStyle(fontSize: 11.5, color: colors.text),
          items: [
            DropdownMenuItem<TaskPriority?>(
              value: null,
              child: Text('Все приоритеты',
                  style: TextStyle(fontSize: 11.5, color: colors.muted)),
            ),
            for (final priority in TaskPriority.values)
              DropdownMenuItem<TaskPriority?>(
                value: priority,
                child: Text(priority.label,
                    style: TextStyle(fontSize: 11.5, color: colors.text)),
              ),
          ],
          onChanged: (value) {
            final next = ref.read(taskFilterProvider);
            ref.read(taskFilterProvider.notifier).state = next.copyWith(
                  priorities: value == null ? {} : {value},
                );
          },
        ),
      ),
    );
  }

  Future<void> _changeStatus(Task task, TaskStatus status) async {
    await ref.read(taskRepositoryProvider).changeStatus(task, status);
    if (!mounted) return;
    bumpData(ref);
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить задачу?',
      message: 'Задача «${task.title}» будет удалена.',
    );
    if (!confirmed) return;
    await ref.read(taskRepositoryProvider).deleteTask(task);
    if (!mounted) return;
    bumpData(ref);
  }

  Future<void> _openTaskForm({
    Task? task,
    TaskStatus? initialStatus,
    DateTime? initialDueDate,
  }) async {
    final title = TextEditingController(text: task?.title ?? '');
    final description = TextEditingController(text: task?.description ?? '');
    final category = TextEditingController(text: task?.category ?? '');
    final channels = ref.read(channelRepositoryProvider).getChannels();
    var priority = task?.priority ?? TaskPriority.medium;
    var status = task?.status ?? initialStatus ?? TaskStatus.todo;
    var dueDate = task?.dueDate ?? initialDueDate;
    var reminder = task?.reminderDate;
    var channelId = task?.channelId;
    final hasReminder = reminder != null;

    try {
      await showFormDialog(
        context,
        title: task == null ? 'Новая задача' : 'Задача',
        description:
            'Срок и напоминание необязательны. Напоминание срабатывает в '
            'приложении, когда наступает указанное время.',
        submitLabel: task == null ? 'Создать' : 'Сохранить',
        wide: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Название',
                child: TextField(controller: title),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Приоритет',
                      child: DropdownButtonFormField<TaskPriority>(
                        value: priority,
                        items: [
                          for (final item in TaskPriority.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) => setDialogState(
                            () => priority = value ?? priority),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Статус',
                      child: DropdownButtonFormField<TaskStatus>(
                        value: status,
                        items: [
                          for (final item in TaskStatus.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => status = value ?? status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Срок',
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await pickDate(
                                  context,
                                  initial: dueDate ?? DateTime.now(),
                                );
                                if (picked != null) {
                                  setDialogState(() => dueDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  suffixIcon: Icon(
                                    Icons.date_range_outlined,
                                    size: 17,
                                  ),
                                ),
                                child: Text(
                                  dueDate == null
                                      ? 'Без срока'
                                      : dueDate!.formatShort(),
                                ),
                              ),
                            ),
                          ),
                          if (dueDate != null)
                            IconButton(
                              tooltip: 'Убрать срок',
                              onPressed: () =>
                                  setDialogState(() => dueDate = null),
                              icon: Icon(Icons.close_rounded,
                                  size: 15, color: context.muted),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Канал',
                      hint: 'необязательно',
                      child: DropdownButtonFormField<String?>(
                        value: channels.any((c) => c.id == channelId)
                            ? channelId
                            : null,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Без привязки'),
                          ),
                          for (final channel in channels)
                            DropdownMenuItem<String?>(
                              value: channel.id,
                              child: Text(
                                channel.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => channelId = value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Напоминание',
                  style: TextStyle(fontSize: 12.5),
                ),
                subtitle: Text(
                  reminder == null
                      ? 'Не задано'
                      : reminder!.formatDateTime(),
                  style: TextStyle(color: context.muted, fontSize: 10.5),
                ),
                value: hasReminder,
                onChanged: (value) => setDialogState(() {
                  if (value) {
                    reminder = (dueDate ?? DateTime.now())
                        .add(const Duration(hours: 9));
                  } else {
                    reminder = null;
                  }
                }),
              ),
              if (hasReminder)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final initial = reminder ?? DateTime.now();
                      final date = await pickDate(context, initial: initial);
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(initial),
                      );
                      if (!context.mounted) return;
                      setDialogState(() {
                        reminder = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time?.hour ?? 9,
                          time?.minute ?? 0,
                        );
                      });
                    },
                    icon: const Icon(Icons.alarm_outlined, size: 15),
                    label: const Text('Изменить время напоминания'),
                  ),
                ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Категория',
                child: TextField(
                  controller: category,
                  decoration: const InputDecoration(
                    hintText: 'Например, монтаж, отчёт, реклама',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Описание',
                child: TextField(
                  controller: description,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Необязательно'),
                ),
              ),
            ],
          ),
        ),
        onSubmit: () async {
          final trimmed = title.text.trim();
          if (trimmed.isEmpty) {
            throw const FormatException('Укажите название задачи');
          }
          final repo = ref.read(taskRepositoryProvider);
          final auth = ref.read(authProvider);
          final now = DateTime.now();
          final entity = task == null
              ? Task(
                  id: const Uuid().v4(),
                  userId: auth.userId,
                  title: trimmed,
                  description: _nullIfEmpty(description.text),
                  priority: priority,
                  status: status,
                  category: _nullIfEmpty(category.text),
                  channelId: channelId,
                  dueDate: dueDate,
                  reminderDate: reminder,
                  createdAt: now,
                  completedAt: status == TaskStatus.done ? now : null,
                  updatedAt: now,
                )
              : Task(
                  id: task.id,
                  userId: task.userId,
                  title: trimmed,
                  description: _nullIfEmpty(description.text),
                  priority: priority,
                  status: status,
                  category: _nullIfEmpty(category.text),
                  channelId: channelId,
                  publicationId: task.publicationId,
                  partnerId: task.partnerId,
                  advertiserId: task.advertiserId,
                  dueDate: dueDate,
                  reminderDate: reminder,
                  createdAt: task.createdAt,
                  completedAt: status == TaskStatus.done
                      ? (task.completedAt ?? now)
                      : null,
                  updatedAt: now,
                );
          await repo.saveTask(entity);
          bumpData(ref);
        },
      );
    } finally {
      title.dispose();
      description.dispose();
      category.dispose();
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.onOpen,
    required this.onStatus,
    required this.onDelete,
  });

  final List<Task> tasks;
  final ValueChanged<Task> onOpen;
  final void Function(Task task, TaskStatus status) onStatus;
  final ValueChanged<Task> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final task in tasks)
            _TaskRow(
              task: task,
              onOpen: () => onOpen(task),
              onStatus: (status) => onStatus(task, status),
              onDelete: () => onDelete(task),
            ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Нет задач по выбранным фильтрам.',
                style: TextStyle(color: colors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onOpen,
    required this.onStatus,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onOpen;
  final ValueChanged<TaskStatus> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final overdue = task.isOverdue();
    final tint = switch (task.priority) {
      TaskPriority.urgent => colors.red,
      TaskPriority.high => colors.yellow,
      TaskPriority.low => colors.muted,
      TaskPriority.medium => colors.accent,
    };
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Row(
          children: [
            Checkbox(
              value: task.status == TaskStatus.done,
              onChanged: (value) => onStatus(
                value == true ? TaskStatus.done : TaskStatus.todo,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      decoration: task.status == TaskStatus.done
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.status == TaskStatus.done
                          ? colors.muted
                          : colors.text,
                    ),
                  ),
                  if (task.description != null)
                    Text(
                      task.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted, fontSize: 10),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (task.category != null)
              Pill(label: task.category!, color: colors.blue),
            const SizedBox(width: 6),
            Pill(label: task.priority.label, color: tint),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: Text(
                task.dueDate == null
                    ? 'Без срока'
                    : task.dueDate!.formatShort(),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: overdue ? colors.red : colors.muted,
                  fontSize: 10.5,
                  fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 118,
              child: Text(
                task.status.label,
                textAlign: TextAlign.right,
                style: TextStyle(color: colors.muted, fontSize: 10.5),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Действия',
              icon: Icon(Icons.more_vert_rounded,
                  size: 16, color: colors.muted),
              onSelected: (value) {
                if (value == 'edit') onOpen();
                if (value == 'delete') onDelete();
                for (final status in TaskStatus.values) {
                  if (value == 'status:${status.name}') onStatus(status);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Открыть')),
                const PopupMenuDivider(),
                for (final status in TaskStatus.values)
                  PopupMenuItem(
                    value: 'status:${status.name}',
                    child: Text('Статус: ${status.label}'),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskBoard extends StatelessWidget {
  const _TaskBoard({
    required this.tasks,
    required this.onOpen,
    required this.onDrop,
    required this.onAdd,
  });

  final List<Task> tasks;
  final ValueChanged<Task> onOpen;
  final void Function(Task task, TaskStatus status) onDrop;
  final ValueChanged<TaskStatus> onAdd;

  static const _columns = [
    TaskStatus.todo,
    TaskStatus.inProgress,
    TaskStatus.done,
    TaskStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 480,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _columns.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final status = _columns[index];
          final items = tasks.where((t) => t.status == status).toList();
          final tint = switch (status) {
            TaskStatus.todo => colors.blue,
            TaskStatus.inProgress => colors.yellow,
            TaskStatus.done => colors.green,
            TaskStatus.cancelled => colors.muted,
          };
          return DragTarget<Task>(
            onAcceptWithDetails: (details) => onDrop(details.data, status),
            builder: (context, candidate, rejected) => Container(
              width: 280,
              decoration: BoxDecoration(
                color: candidate.isNotEmpty
                    ? tint.withValues(alpha: 0.07)
                    : colors.panel,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: candidate.isNotEmpty ? tint : colors.line,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: tint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            status.label,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Pill(label: '${items.length}', color: tint),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              'Перетащите задачу сюда.',
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 11,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 9),
                            itemCount: items.length,
                            itemBuilder: (context, itemIndex) {
                              final task = items[itemIndex];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: LongPressDraggable<Task>(
                                  data: task,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      width: 262,
                                      child: _BoardCard(task: task),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.35,
                                    child: _BoardCard(task: task),
                                  ),
                                  child: InkWell(
                                    onTap: () => onOpen(task),
                                    borderRadius: BorderRadius.circular(11),
                                    child: _BoardCard(task: task),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton.icon(
                      onPressed: () => onAdd(status),
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text('Добавить'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final overdue = task.isOverdue();
    return AppCard(
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              Pill(
                label: task.priority.label,
                color: switch (task.priority) {
                  TaskPriority.urgent => colors.red,
                  TaskPriority.high => colors.yellow,
                  TaskPriority.low => colors.muted,
                  TaskPriority.medium => colors.accent,
                },
              ),
              if (task.category != null)
                Pill(label: task.category!, color: colors.blue),
            ],
          ),
          if (task.dueDate != null) ... [
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 11,
                  color: overdue ? colors.red : colors.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  task.dueDate!.formatShort(),
                  style: TextStyle(
                    color: overdue ? colors.red : colors.muted,
                    fontSize: 9.5,
                    fontWeight:
                        overdue ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskCalendar extends StatelessWidget {
  const _TaskCalendar({
    required this.month,
    required this.tasks,
    required this.onMonthChanged,
    required this.onOpen,
    required this.onAdd,
  });

  final DateTime month;
  final List<Task> tasks;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<Task> onOpen;
  final ValueChanged<DateTime> onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = leading + daysInMonth;
    final rows = ((cells + 6) / 7).floor();
    final byDay = <String, List<Task>>{};
    for (final task in tasks) {
      if (task.dueDate == null) continue;
      final date = task.dueDate!;
      if (date.year != month.year || date.month != month.month) continue;
      final key = '${date.year}-${date.month}-${date.day}';
      byDay.putIfAbsent(key, () => []).add(task);
    }
    final today = DateTime.now();
    return Column(
      children: [
        AppCard(
          child: Row(
            children: [
              IconButton(
                tooltip: 'Предыдущий месяц',
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month - 1)),
                icon: const Icon(Icons.chevron_left_rounded, size: 19),
              ),
              Expanded(
                child: Text(
                  month.formatMonth(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    onMonthChanged(DateTime(today.year, today.month)),
                child: const Text('Сегодня'),
              ),
              IconButton(
                tooltip: 'Следующий месяц',
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month + 1)),
                icon: const Icon(Icons.chevron_right_rounded, size: 19),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  for (final day in const [
                    'Пн',
                    'Вт',
                    'Ср',
                    'Чт',
                    'Пт',
                    'Сб',
                    'Вс',
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              for (var row = 0; row < rows; row++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: _CalendarCell(
                          date: DateTime(
                            month.year,
                            month.month,
                            row * 7 + column - leading + 1,
                          ),
                          inMonth: row * 7 + column - leading + 1 >= 1 &&
                              row * 7 + column - leading + 1 <= daysInMonth,
                          tasks: byDay[
                                  '${month.year}-${month.month}-${row * 7 + column - leading + 1}'] ??
                              const [],
                          onAdd: onAdd,
                          onOpen: onOpen,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Задачи без срока в календарь не попадают.',
          style: TextStyle(color: colors.muted, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.date,
    required this.inMonth,
    required this.tasks,
    required this.onAdd,
    required this.onOpen,
  });

  final DateTime date;
  final bool inMonth;
  final List<Task> tasks;
  final ValueChanged<DateTime> onAdd;
  final ValueChanged<Task> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isToday = inMonth && date.isToday();
    return InkWell(
      onTap: inMonth ? () => onAdd(date) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 78),
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isToday ? colors.accentSoft : colors.panelAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday ? colors.accent : colors.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              inMonth ? '${date.day}' : '',
              style: TextStyle(
                color: isToday ? colors.accent : colors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            for (final task in tasks.take(2))
              InkWell(
                onTap: () => onOpen(task),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  decoration: BoxDecoration(
                    color: switch (task.priority) {
                      TaskPriority.urgent => colors.red,
                      TaskPriority.high => colors.yellow,
                      TaskPriority.medium => colors.accent,
                      TaskPriority.low => colors.blue,
                    }
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (tasks.length > 2)
              Text(
                '+${tasks.length - 2}',
                style: TextStyle(color: colors.muted, fontSize: 8),
              ),
          ],
        ),
      ),
    );
  }
}
