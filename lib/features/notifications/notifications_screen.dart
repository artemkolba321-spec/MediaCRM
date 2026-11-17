import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/notification_item.dart';
import 'package:media_crm/providers/app_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _tab = 0;
  NotificationType? _type;

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(notificationRepositoryProvider);
    final all = repo.getNotifications();
    final unread = repo.getNotifications(read: false);
    final items = (switch (_tab) {
      1 => unread,
      2 => repo.getNotifications(read: true),
      _ => all,
    })
        .where((item) => _type == null || item.type == _type)
        .toList();
    final colors = context.colors;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Уведомления',
            subtitle:
                'Внутренние события приложения: напоминания о задачах, '
                'синхронизация, финансовые записи и изменения показателей. '
                'Email и push не отправляются.',
            actions: [
              OutlinedButton.icon(
                onPressed: unread.isEmpty
                    ? null
                    : () async {
                        await repo.markAllAsRead();
                        if (!context.mounted) return;
                        bumpData(ref);
                        showAppSnack(context, 'Все уведомления прочитаны');
                      },
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('Прочитать все'),
              ),
              OutlinedButton.icon(
                onPressed: all.any((n) => n.read)
                    ? () => _clearRead(repo)
                    : null,
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Очистить прочитанные'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : 1;
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
                      label: 'Всего',
                      value: '${all.length}',
                      icon: Icons.notifications_none_rounded,
                      color: colors.accent,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Непрочитанные',
                      value: '${unread.length}',
                      icon: Icons.mark_email_unread_outlined,
                      color: unread.isEmpty ? colors.green : colors.yellow,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'За 7 дней',
                      value:
                          '${all.where((n) => n.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length}',
                      icon: Icons.calendar_month_outlined,
                      color: colors.blue,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilterBarShell(
            children: [
              SegmentedTabs(
                tabs: [
                  'Все (${all.length})',
                  'Непрочитанные (${unread.length})',
                  'Прочитанные',
                ],
                selected: _tab,
                onChanged: (index) => setState(() => _tab = index),
              ),
              _typeDropdown(colors),
              const Spacer(),
              Text(
                '${items.length} записей',
                style: TextStyle(color: colors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (all.isEmpty)
            const EmptyState(
              title: 'Уведомлений пока нет',
              message:
                  'Здесь появятся события: напоминания о задачах, результаты '
                  'синхронизации и финансовые записи. Уведомления не '
                  'создаются автоматически без реального события.',
              icon: Icons.notifications_none_rounded,
            )
          else if (items.isEmpty)
            const EmptyState(
              title: 'Ничего не найдено',
              message: 'Смените вкладку или фильтр типа.',
              icon: Icons.search_off_rounded,
              compact: true,
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final item in items)
                    _NotificationRow(
                      item: item,
                      onOpen: () => _openNotification(item),
                      onRead: () => _markRead(item),
                      onDelete: () => _delete(item),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const DataSourceNote(
            text:
                'Уведомления хранятся локально и синхронизируются как часть '
                'коллекции notifications. Системные push-уведомления, email и '
                'фоновая доставка в этой версии отсутствуют.',
          ),
        ],
      ),
    );
  }

  Widget _typeDropdown(AppColors colors) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<NotificationType?>(
          value: _type,
          isDense: true,
          dropdownColor: colors.panel,
          hint: Text('Все типы',
              style: TextStyle(fontSize: 11.5, color: colors.muted)),
          style: TextStyle(fontSize: 11.5, color: colors.text),
          items: [
            DropdownMenuItem<NotificationType?>(
              value: null,
              child: Text('Все типы',
                  style: TextStyle(fontSize: 11.5, color: colors.muted)),
            ),
            for (final type in NotificationType.values)
              DropdownMenuItem<NotificationType?>(
                value: type,
                child: Text(type.label,
                    style: TextStyle(fontSize: 11.5, color: colors.text)),
              ),
          ],
          onChanged: (value) => setState(() => _type = value),
        ),
      ),
    );
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.read) return;
    await ref.read(notificationRepositoryProvider).markAsRead(item);
    if (!mounted) return;
    bumpData(ref);
  }

  Future<void> _delete(NotificationItem item) async {
    await ref.read(notificationRepositoryProvider).delete(item);
    if (!mounted) return;
    bumpData(ref);
  }

  Future<void> _openNotification(NotificationItem item) async {
    await _markRead(item);
    if (!mounted) return;
    final index = switch (item.relatedType) {
      'task' => 9,
      'operation' => 5,
      'partner' => 7,
      'advertiser' => 6,
      'channel' => 2,
      _ => null,
    };
    if (index != null) {
      ref.read(shellIndexProvider.notifier).state = index;
    } else {
      await showSidePanel<void>(
        context,
        title: item.title,
        subtitle: item.type.label,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            AppCard(
              child: Text(
                item.message,
                style: const TextStyle(fontSize: 12.5, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            KeyValueRow(
              label: 'Создано',
              value: item.createdAt.formatDateTime(),
              icon: Icons.schedule_rounded,
            ),
            if (item.relatedType != null)
              KeyValueRow(
                label: 'Связанная запись',
                value: '${item.relatedType} · ${item.relatedId ?? '—'}',
                icon: Icons.link_rounded,
              ),
          ],
        ),
      );
    }
  }

  Future<void> _clearRead(dynamic repo) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Очистить прочитанные?',
      message:
          'Все прочитанные уведомления будут удалены. Непрочитанные останутся.',
      confirmLabel: 'Очистить',
    );
    if (!confirmed) return;
    final read = ref
        .read(notificationRepositoryProvider)
        .getNotifications(read: true);
    for (final item in read) {
      await ref.read(notificationRepositoryProvider).delete(item);
    }
    if (!mounted) return;
    bumpData(ref);
    showAppSnack(context, 'Прочитанные уведомления удалены');
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.onOpen,
    required this.onRead,
    required this.onDelete,
  });

  final NotificationItem item;
  final VoidCallback onOpen;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = switch (item.type) {
      NotificationType.syncError => colors.red,
      NotificationType.syncComplete => colors.green,
      NotificationType.financial => colors.green,
      NotificationType.taskReminder => colors.yellow,
      NotificationType.metricChange => colors.blue,
      NotificationType.newSale => colors.green,
      NotificationType.newRegistration => colors.accent,
      NotificationType.system => colors.muted,
    };
    final icon = switch (item.type) {
      NotificationType.syncError => Icons.sync_problem_rounded,
      NotificationType.syncComplete => Icons.sync_rounded,
      NotificationType.financial => Icons.payments_outlined,
      NotificationType.taskReminder => Icons.alarm_outlined,
      NotificationType.metricChange => Icons.trending_up_rounded,
      NotificationType.newSale => Icons.shopping_bag_outlined,
      NotificationType.newRegistration => Icons.person_add_alt_1_outlined,
      NotificationType.system => Icons.info_outline_rounded,
    };
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: item.read ? Colors.transparent : colors.accentSoft,
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconSquare(icon: icon, color: tint, size: 30),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: item.read
                                ? FontWeight.w600
                                : FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!item.read)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.type.label} · ${item.createdAt.formatRelative()}',
                    style: TextStyle(color: colors.muted, fontSize: 9.5),
                  ),
                ],
              ),
            ),
            if (!item.read)
              IconButton(
                tooltip: 'Отметить прочитанным',
                onPressed: onRead,
                icon: Icon(Icons.done_rounded,
                    size: 15, color: colors.muted),
              ),
            IconButton(
              tooltip: 'Удалить',
              onPressed: onDelete,
              icon: Icon(Icons.close_rounded, size: 15, color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
