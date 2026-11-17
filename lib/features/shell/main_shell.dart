import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:media_crm/core/config/app_config.dart';
import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/notification_item.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/sync_run.dart';
import 'package:media_crm/features/advertisers/advertisers_screen.dart';
import 'package:media_crm/features/analytics/analytics_screen.dart';
import 'package:media_crm/features/audience/audience_screen.dart';
import 'package:media_crm/features/channels/channels_screen.dart';
import 'package:media_crm/features/dashboard/dashboard_screen.dart';
import 'package:media_crm/features/finance/finance_screen.dart';
import 'package:media_crm/features/funnels/funnels_screen.dart';
import 'package:media_crm/features/notifications/notifications_screen.dart';
import 'package:media_crm/features/partners/partners_screen.dart';
import 'package:media_crm/features/publications/publications_screen.dart';
import 'package:media_crm/features/settings/settings_screen.dart';
import 'package:media_crm/features/tasks/tasks_screen.dart';
import 'package:media_crm/providers/app_providers.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _syncTimer;
  bool _syncTickRunning = false;

  @override
  void initState() {
    super.initState();
    // Cheap in-process scheduler: one tick per minute. Network calls happen
    // only for channels whose user-configured interval has actually elapsed.
    _syncTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _autoSyncTick(),
    );
    Future<void>.delayed(const Duration(seconds: 3), _autoSyncTick);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _autoSyncTick() async {
    if (_syncTickRunning || !mounted) return;
    final auth = ref.read(authProvider);
    final settings = ref.read(settingsProvider);
    final cloud = ref.read(cloudServiceProvider);
    if (!auth.isCloud || !cloud.isConfigured || !settings.autoSyncEnabled) {
      return;
    }
    final repo = ref.read(channelRepositoryProvider);
    final now = DateTime.now();
    final due = repo.getChannels().where((channel) {
      if (!channel.isConnected || !channel.autoSync) return false;
      if (!channel.platform.supportsAutomaticSync) return false;
      final interval = Duration(
        minutes: channel.syncIntervalMinutes ?? settings.syncIntervalMinutes,
      );
      final last = channel.lastSyncAt;
      return last == null || now.difference(last) >= interval;
    }).toList();
    if (due.isEmpty) return;

    _syncTickRunning = true;
    try {
      final notifications = ref.read(notificationRepositoryProvider);
      for (final channel in due) {
        if (!mounted) break;
        final result = await repo.syncChannel(
          channel,
          trigger: SyncTrigger.scheduled,
        );
        if (!settings.syncNotifications) continue;
        await notifications.create(
          type: result.success
              ? NotificationType.syncComplete
              : NotificationType.syncError,
          title: result.success
              ? 'Синхронизация: ${channel.name}'
              : 'Ошибка синхронизации: ${channel.name}',
          message: result.message,
          relatedId: channel.id,
          relatedType: 'channel',
        );
      }
      if (!mounted) return;
      bumpData(ref);
      ref.read(syncControllerProvider.notifier).refreshPending();
    } finally {
      _syncTickRunning = false;
    }
  }

  static const _destinations = <_Destination>[
    _Destination(0, 'Дашборд', Icons.dashboard_outlined, Icons.dashboard_rounded, 'Обзор'),
    _Destination(1, 'Аналитика', Icons.insights_outlined, Icons.insights_rounded, 'Обзор'),
    _Destination(2, 'Мои каналы', Icons.hub_outlined, Icons.hub_rounded, 'Сеть'),
    _Destination(3, 'Аудитория', Icons.people_outline_rounded, Icons.people_rounded, 'Сеть'),
    _Destination(4, 'Публикации', Icons.article_outlined, Icons.article_rounded, 'Сеть'),
    _Destination(5, 'Финансы', Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded, 'Бизнес'),
    _Destination(6, 'Рекламодатели', Icons.campaign_outlined, Icons.campaign_rounded, 'Бизнес'),
    _Destination(7, 'Партнёры', Icons.handshake_outlined, Icons.handshake_rounded, 'Бизнес'),
    _Destination(8, 'Воронки', Icons.view_kanban_outlined, Icons.view_kanban_rounded, 'Бизнес'),
    _Destination(9, 'Задачи', Icons.task_alt_outlined, Icons.task_alt_rounded, 'Работа'),
    _Destination(10, 'Уведомления', Icons.notifications_none_rounded,
        Icons.notifications_rounded, 'Работа'),
    _Destination(11, 'Настройки', Icons.settings_outlined, Icons.settings_rounded, 'Система'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(shellIndexProvider);
    final auth = ref.watch(authProvider);
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < kMobileBreakpoint;
    final expanded = width >= 1180;

    final content = Column(
      children: [
        _TopBar(
          title: _destinations[index].label,
          mobile: mobile,
          onMenu: mobile ? () => _scaffoldKey.currentState?.openDrawer() : null,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey(index),
              child: _screenFor(index),
            ),
          ),
        ),
      ],
    );

    if (mobile) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          width: 280,
          backgroundColor: context.panel,
          child: SafeArea(
            child: _Sidebar(
              destinations: _destinations,
              selected: index,
              expanded: true,
              onSelect: (value) {
                ref.read(shellIndexProvider.notifier).state = value;
                Navigator.of(context).maybePop();
              },
              footer: _SidebarFooter(
                displayName: auth.displayName,
                isCloud: auth.isCloud,
                onSettings: () {
                  ref.read(shellIndexProvider.notifier).state = 11;
                  Navigator.of(context).maybePop();
                },
              ),
            ),
          ),
        ),
        body: SafeArea(child: content),
        bottomNavigationBar: NavigationBar(
          height: 64,
          backgroundColor: context.panel,
          surfaceTintColor: Colors.transparent,
          indicatorColor: context.colors.accentSoft,
          selectedIndex: index <= 5 ? index.clamp(0, 3) : 4,
          onDestinationSelected: (value) {
            if (value == 4) {
              _scaffoldKey.currentState?.openDrawer();
              return;
            }
            ref.read(shellIndexProvider.notifier).state = value;
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Обзор',
            ),
            const NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Аналитика',
            ),
            const NavigationDestination(
              icon: Icon(Icons.hub_outlined),
              selectedIcon: Icon(Icons.hub_rounded),
              label: 'Каналы',
            ),
            const NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Финансы',
            ),
            const NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Ещё',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              destinations: _destinations,
              selected: index,
              expanded: expanded,
              onSelect: (value) =>
                  ref.read(shellIndexProvider.notifier).state = value,
              footer: _SidebarFooter(
                displayName: auth.displayName,
                isCloud: auth.isCloud,
                onSettings: () =>
                    ref.read(shellIndexProvider.notifier).state = 11,
                compact: !expanded,
              ),
              compact: !expanded,
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _screenFor(int index) => switch (index) {
        0 => const DashboardScreen(),
        1 => const AnalyticsScreen(),
        2 => const ChannelsScreen(),
        3 => const AudienceScreen(),
        4 => const PublicationsScreen(),
        5 => const FinanceScreen(),
        6 => const AdvertisersScreen(),
        7 => const PartnersScreen(),
        8 => const FunnelsScreen(),
        9 => const TasksScreen(),
        10 => const NotificationsScreen(),
        _ => const SettingsScreen(),
      };
}

class _Destination {
  const _Destination(
    this.index,
    this.label,
    this.icon,
    this.activeIcon,
    this.group,
  );

  final int index;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String group;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selected,
    required this.expanded,
    required this.onSelect,
    required this.footer,
    this.compact = false,
  });

  final List<_Destination> destinations;
  final int selected;
  final bool expanded;
  final ValueChanged<int> onSelect;
  final Widget footer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final groups = <String, List<_Destination>>{};
    for (final destination in destinations) {
      groups.putIfAbsent(destination.group, () => []).add(destination);
    }
    return Container(
      width: expanded ? 232 : 74,
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(right: BorderSide(color: colors.line)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              expanded ? 16 : 0,
              16,
              expanded ? 12 : 0,
              14,
            ),
            child: expanded
                ? const Row(
                    children: [
                      _Logo(size: 32),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConfig.appName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              AppConfig.tagline,
                              style: TextStyle(
                                fontSize: 7.5,
                                letterSpacing: 1.6,
                                color: Color(0xFF9AA5B8),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const Center(child: _Logo(size: 34)),
          ),
          Divider(height: 1, color: colors.line),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              children: [
                for (final entry in groups.entries) ...[
                  if (expanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 5),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    )
                  else if (entry.key != groups.keys.first)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Divider(color: colors.line),
                    ),
                  for (final destination in entry.value)
                    _SidebarItem(
                      destination: destination,
                      selected: selected == destination.index,
                      expanded: expanded,
                      onTap: () => onSelect(destination.index),
                    ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: colors.line),
          footer,
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final child = Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 10 : 0,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: selected ? colors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment:
            expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(
            selected ? destination.activeIcon : destination.icon,
            size: 18,
            color: selected ? colors.accent : colors.muted,
          ),
          if (expanded) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.text : colors.muted,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ],
      ),
    );

    final tappable = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: colors.accent.withValues(alpha: 0.05),
        child: child,
      ),
    );
    if (expanded) return tappable;
    return Tooltip(message: destination.label, child: tappable);
  }
}

class _SidebarFooter extends ConsumerWidget {
  const _SidebarFooter({
    required this.displayName,
    required this.isCloud,
    required this.onSettings,
    this.compact = false,
  });

  final String displayName;
  final bool isCloud;
  final VoidCallback onSettings;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sync = ref.watch(syncControllerProvider);
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            IconButton(
              tooltip: 'Синхронизация',
              onPressed: () => ref.read(syncControllerProvider.notifier).synchronize(),
              icon: sync.busy
                  ? const Spinner(size: 16)
                  : Icon(
                      Icons.cloud_sync_outlined,
                      color: sync.pendingChanges > 0
                          ? colors.yellow
                          : colors.muted,
                    ),
            ),
            const SizedBox(height: 4),
            IconButton(
              tooltip: 'Настройки',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          InkWell(
            onTap: () => ref.read(syncControllerProvider.notifier).synchronize(),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.panelAlt,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: colors.line),
              ),
              child: Row(
                children: [
                  if (sync.busy)
                    const Spinner(size: 14)
                  else
                    Icon(
                      isCloud ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      size: 15,
                      color: isCloud ? colors.green : colors.muted,
                    ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sync.busy
                              ? 'Синхронизация…'
                              : isCloud
                                  ? 'Облако подключено'
                                  : 'Локальный режим',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isCloud ? colors.text : colors.muted,
                          ),
                        ),
                        if (isCloud)
                          Text(
                            sync.pendingChanges > 0
                                ? '${sync.pendingChanges} в очереди'
                                : 'Все изменения сохранены',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: sync.pendingChanges > 0
                                  ? colors.yellow
                                  : colors.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.sync_rounded, size: 13, color: colors.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onSettings,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Text(
                        displayName.trim().isEmpty
                            ? 'M'
                            : displayName.trim().characters.first.toUpperCase(),
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.settings_outlined, size: 14, color: colors.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accent, colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(Icons.hub_rounded, color: Colors.white, size: size * 0.54),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.title,
    required this.mobile,
    this.onMenu,
  });

  final String title;
  final bool mobile;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final auth = ref.watch(authProvider);
    final sync = ref.watch(syncControllerProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    return Container(
      height: 58,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 18),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          if (mobile)
            IconButton(
              tooltip: 'Меню',
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded, size: 20),
            )
          else ...[
            const _Logo(size: 22),
            const SizedBox(width: 9),
          ],
          Text(
            mobile ? title : AppConfig.appName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
          if (!mobile) ...[
            const SizedBox(width: 8),
            Text('/', style: TextStyle(color: colors.line, fontSize: 15)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                color: colors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),
          if (!mobile) ...[
            _SyncChip(
              isCloud: auth.isCloud,
              busy: sync.busy,
              pending: sync.pendingChanges,
              onTap: () {
                ref.read(syncControllerProvider.notifier).synchronize();
              },
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: 'Уведомления',
            onPressed: () => ref.read(shellIndexProvider.notifier).state = 10,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, size: 20),
                if (unread > 0)
                  Positioned(
                    right: -4,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 14),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          PopupMenuButton<String>(
            tooltip: 'Аккаунт',
            offset: const Offset(0, 44),
            onSelected: (value) async {
              if (value == 'settings') {
                ref.read(shellIndexProvider.notifier).state = 11;
              } else if (value == 'sync') {
                await ref.read(syncControllerProvider.notifier).synchronize();
              } else if (value == 'logout') {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Выйти из аккаунта?',
                  message: auth.isCloud
                      ? 'Локальные данные останутся на устройстве. '
                          'Для доступа к ним снова войдите в аккаунт.'
                      : 'Вы вернётесь на экран входа. Локальные данные '
                          'сохранятся на устройстве.',
                  confirmLabel: 'Выйти',
                  danger: false,
                );
                if (confirmed) {
                  await ref.read(authProvider.notifier).signOut();
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.displayName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      auth.email ?? 'Локальный режим',
                      style: TextStyle(fontSize: 10.5, color: colors.muted),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: _MenuRow(icon: Icons.settings_outlined, label: 'Настройки'),
              ),
              const PopupMenuItem(
                value: 'sync',
                child: _MenuRow(icon: Icons.sync_rounded, label: 'Синхронизировать'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: _MenuRow(
                  icon: Icons.logout_rounded,
                  label: 'Выйти',
                  color: Color(0xFFFF5F6D),
                ),
              ),
            ],
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  auth.displayName.trim().isEmpty
                      ? 'M'
                      : auth.displayName.trim().characters.first.toUpperCase(),
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({
    required this.isCloud,
    required this.busy,
    required this.pending,
    required this.onTap,
  });

  final bool isCloud;
  final bool busy;
  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (busy)
              const Spinner(size: 12)
            else
              Icon(
                isCloud ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                size: 13,
                color: isCloud ? colors.green : colors.muted,
              ),
            const SizedBox(width: 5),
            Text(
              busy
                  ? 'Синхронизация'
                  : isCloud
                      ? (pending > 0 ? 'Очередь: $pending' : 'Сохранено')
                      : 'Локально',
              style: TextStyle(
                fontSize: 10.5,
                color: isCloud ? colors.muted : colors.yellow,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? context.muted),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12.5, color: color)),
      ],
    );
  }
}
