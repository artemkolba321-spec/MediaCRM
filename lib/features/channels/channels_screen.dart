import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:media_crm/core/platform/platform_limits.dart';
import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/analytics_snapshot.dart';
import 'package:media_crm/data/models/notification_item.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/sync_run.dart';
import 'package:media_crm/providers/app_providers.dart';

class ChannelsScreen extends ConsumerStatefulWidget {
  const ChannelsScreen({super.key});

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends ConsumerState<ChannelsScreen> {
  final _search = TextEditingController();
  PlatformType? _platformFilter;
  bool _syncingAll = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PlatformChannel> _channels() {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(channelRepositoryProvider);
    var items = repo.getChannels();
    if (_platformFilter != null) {
      items = items.where((c) => c.platform == _platformFilter).toList();
    }
    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items
          .where((c) =>
              c.name.toLowerCase().contains(query) ||
              (c.url ?? '').toLowerCase().contains(query) ||
              (c.platformId ?? '').toLowerCase().contains(query))
          .toList();
    }
    return items;
  }

  Future<void> _syncAll() async {
    if (_syncingAll) return;
    setState(() => _syncingAll = true);
    try {
      final result = await ref.read(channelRepositoryProvider).syncAll();
      if (!mounted) return;
      bumpData(ref);
      showAppSnack(context, result.message,
          error: !result.success && !result.manualOnly);
      if (!result.success && !result.manualOnly) {
        await ref.read(notificationRepositoryProvider).create(
              type: NotificationType.syncError,
              title: 'Ошибка синхронизации',
              message: result.message,
            );
        bumpData(ref);
      }
    } finally {
      if (mounted) setState(() => _syncingAll = false);
    }
  }

  Future<void> _openAddDialog() async {
    final channel = await _showChannelForm(context);
    // После добавления новой YouTube-площадки — предложить подключение
    if (!mounted) return;
    if (channel != null &&
        channel.platform == PlatformType.youtube &&
        !channel.hasCredentials) {
      bumpData(ref);
      await _showConnectPrompt(context, channel);
    } else {
      bumpData(ref);
    }
  }

  /// Диалог «Подключить YouTube-канал сейчас?» после создания площадки.
  Future<void> _showConnectPrompt(
    BuildContext context,
    PlatformChannel channel,
  ) async {
    final chosen = await showConfirmDialog(
      context,
      title: 'Подключить YouTube-канал?',
      message:
          'Площадка «${channel.name}» добавлена. Для сбора статистики '
          'необходимо подключить YouTube-канал через OAuth 2.0 Google. '
          'Токены будут сохранены только на сервере.',
      confirmLabel: 'Подключить',
    );
    if (!chosen) return;
    // Открываем панель подключения для этой площадки
    await _openPanel(context, channel, connect: true);
  }

  /// Returns the saved channel, or null if the dialog was cancelled.
  Future<PlatformChannel?> _showChannelForm(
    BuildContext context, {
    PlatformChannel? channel,
  }) async {
    final name = TextEditingController(text: channel?.name ?? '');
    final url = TextEditingController(text: channel?.url ?? '');
    final platformId = TextEditingController(text: channel?.platformId ?? '');
    final description =
        TextEditingController(text: channel?.description ?? '');
    final avatar = TextEditingController(text: channel?.avatarUrl ?? '');
    var platform = channel?.platform ?? PlatformType.youtube;
    var autoSync = channel?.autoSync ?? true;
    var interval = channel?.syncIntervalMinutes;

    final result = await showFormDialog<PlatformChannel?>(
      context,
      title: channel == null ? 'Новая площадка' : 'Настройки площадки',
      description:
          'Название и ссылка обязательны. ID используется для API, если он известен.',
      submitLabel: channel == null ? 'Добавить' : 'Сохранить',
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: 'Платформа',
              child: DropdownButtonFormField<PlatformType>(
                value: platform,
                itemHeight: 48,
                items: [
                  for (final item in PlatformType.values)
                    DropdownMenuItem(
                      value: item,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlatformChip(platform: item),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              item.apiNote,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: context.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: channel == null
                    ? (value) {
                        if (value != null) {
                          setDialogState(() => platform = value);
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Название',
              child: TextField(
                controller: name,
                decoration: const InputDecoration(hintText: 'Например, Основной канал'),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Ссылка',
              child: TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration:
                    const InputDecoration(hintText: 'https://…'),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'ID площадки',
              hint: 'канал, сообщество или репозиторий',
              child: TextField(
                controller: platformId,
                decoration: const InputDecoration(
                  hintText: 'UC… / @channel / owner/repo',
                ),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Описание',
              child: TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Необязательно'),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'URL аватара',
              child: TextField(
                controller: avatar,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://… (необязательно)',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Автоматическая синхронизация',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Выполняется, пока приложение открыто и есть облачный аккаунт',
                style: TextStyle(fontSize: 10.5, color: context.muted),
              ),
              value: autoSync,
              onChanged: (value) => setDialogState(() => autoSync = value),
            ),
            if (autoSync) ...[
              const SizedBox(height: 6),
              LabeledField(
                label: 'Интервал',
                child: DropdownButtonFormField<int>(
                  value: interval ?? 180,
                  items: const [
                    DropdownMenuItem(value: 60, child: Text('Каждый час')),
                    DropdownMenuItem(value: 180, child: Text('Каждые 3 часа')),
                    DropdownMenuItem(value: 360, child: Text('Каждые 6 часов')),
                    DropdownMenuItem(value: 720, child: Text('Каждые 12 часов')),
                    DropdownMenuItem(value: 1440, child: Text('Раз в день')),
                  ],
                  onChanged: (value) => setDialogState(() => interval = value),
                ),
              ),
            ],
            const SizedBox(height: 12),
            InfoNotice(
              message:
                  'Платформа: ${platform.apiNote}. ${platformCapabilities[platform]?.limitations ?? ''}',
              color: context.colors.blue,
            ),
          ],
        ),
      ),
      onSubmit: () async {
        final trimmed = name.text.trim();
        if (trimmed.isEmpty) {
          throw const FormatException('Укажите название площадки');
        }
        final auth = ref.read(authProvider);
        final now = DateTime.now();
        final repo = ref.read(channelRepositoryProvider);
        final entity = channel == null
            ? PlatformChannel(
                id: const Uuid().v4(),
                userId: auth.userId,
                platform: platform,
                name: trimmed,
                url: _emptyToNull(url.text),
                platformId: _emptyToNull(platformId.text),
                description: _emptyToNull(description.text),
                avatarUrl: _emptyToNull(avatar.text),
                autoSync: autoSync,
                syncIntervalMinutes: interval,
                createdAt: now,
                updatedAt: now,
              )
            : channel.copyWith(
                name: trimmed,
                url: _emptyToNull(url.text),
                platformId: _emptyToNull(platformId.text),
                description: _emptyToNull(description.text),
                avatarUrl: _emptyToNull(avatar.text),
                autoSync: autoSync,
                syncIntervalMinutes: interval,
                updatedAt: now,
              );
        await repo.saveChannel(entity);
        return entity;
      },
    );

    name.dispose();
    url.dispose();
    platformId.dispose();
    description.dispose();
    avatar.dispose();
    return result;
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _syncOne(PlatformChannel channel) async {
    if (channel.platform == PlatformType.boosty) {
      final snapshots = ref
          .read(channelRepositoryProvider)
          .getSnapshots(channelId: channel.id);
      if (snapshots.isEmpty && mounted) {
        showAppSnack(
          context,
          'Boosty не предоставляет публичный API. Откройте карточку канала и '
          'добавьте метрики вручную — они сохранятся с источником manual.',
        );
      }
      return;
    }
    final result = await ref.read(channelRepositoryProvider).syncChannel(channel);
    if (!mounted) return;
    bumpData(ref);
    showAppSnack(context, result.message,
        error: !result.success && !result.manualOnly);
    if (!result.success && !result.manualOnly) {
      await ref.read(notificationRepositoryProvider).create(
            type: NotificationType.syncError,
            title: 'Ошибка синхронизации: ${channel.name}',
            message: result.message,
            relatedId: channel.id,
            relatedType: 'channel',
          );
      bumpData(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels();
    final all = ref.watch(channelRepositoryProvider).getChannels();
    final colors = context.colors;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Мои каналы',
            subtitle:
                'Подключение официальных API, ручные снимки метрик и история '
                'синхронизаций. Секреты площадок хранятся только на сервере.',
            actions: [
              OutlinedButton.icon(
                onPressed: all.isEmpty || _syncingAll ? null : _syncAll,
                icon: _syncingAll
                    ? const Spinner(size: 14)
                    : const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Синхронизировать все'),
              ),
              FilledButton.icon(
                onPressed: _openAddDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить площадку'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilterBarShell(
            children: [
              SizedBox(
                width: 260,
                child: SearchField(
                  controller: _search,
                  hint: 'Название, URL или ID…',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              PlatformDropdown(
                value: _platformFilter,
                onChanged: (value) => setState(() => _platformFilter = value),
              ),
              Text(
                '${channels.length} из ${all.length}',
                style: TextStyle(color: colors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (all.isEmpty)
            EmptyState(
              title: 'Пока нет ни одной площадки',
              message:
                  'Добавьте YouTube, Telegram, Boosty, ВКонтакте или GitHub. '
                  'Для площадок с официальным API можно подключить доступ, '
                  'для остальных — вводить метрики вручную.',
              icon: Icons.hub_outlined,
              action: FilledButton.icon(
                onPressed: _openAddDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить площадку'),
              ),
            )
          else if (channels.isEmpty)
            const EmptyState(
              title: 'Ничего не найдено',
              message: 'Измените поисковый запрос или фильтр платформы.',
              icon: Icons.search_off_rounded,
              compact: true,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final columns = constraints.maxWidth >= 1200
                    ? 3
                    : constraints.maxWidth >= 760
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final channel in channels)
                      SizedBox(
                        width: width,
                        child: _ChannelCard(
                          channel: channel,
                          onOpen: () => _openPanel(context, channel),
                          onSync: () => _syncOne(channel),
                          onEdit: () =>
                              _showChannelForm(context, channel: channel),
                          onDelete: () => _deleteChannel(channel),
                          onConnect: () =>
                              _openPanel(context, channel, connect: true),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          const DataSourceNote(
            text:
                'YouTube, Telegram, ВКонтакте и GitHub используют официальные '
                'API. Boosty публичного API не имеет — только ручной ввод. '
                'Метрики, введённые вручную, помечаются источником manual и '
                'не смешиваются с данными API.',
          ),
        ],
      ),
    );
  }

  Future<void> _openPanel(
    BuildContext context,
    PlatformChannel channel, {
    bool connect = false,
  }) async {
    await showSidePanel<void>(
      context,
      title: channel.name,
      subtitle: channel.platform.apiNote,
      child: _ChannelPanel(
        channelId: channel.id,
        openConnect: connect,
        onChanged: () => bumpData(ref),
        onEdit: () => _showChannelForm(context, channel: channel),
        onDeleted: () => Navigator.of(context).maybePop(),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _deleteChannel(PlatformChannel channel) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить площадку?',
      message:
          'Будут удалены карточка «${channel.name}» и все сохранённые снимки '
          'метрик этой площадки. Финансовые операции и публикации останутся, '
          'но потеряют привязку к каналу.',
    );
    if (!confirmed) return;
    await ref.read(channelRepositoryProvider).deleteChannel(channel);
    if (!mounted) return;
    bumpData(ref);
    showAppSnack(context, 'Площадка удалена');
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.channel,
    required this.onOpen,
    required this.onSync,
    required this.onEdit,
    required this.onDelete,
    required this.onConnect,
  });

  final PlatformChannel channel;
  final VoidCallback onOpen;
  final VoidCallback onSync;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = switch (channel.status) {
      ChannelStatus.connected => channel.hasCredentials ? colors.green : colors.blue,
      ChannelStatus.disconnected => colors.muted,
      ChannelStatus.error => colors.red,
      ChannelStatus.syncing => colors.accent,
    };
    final statusLabel = switch (channel.status) {
      ChannelStatus.connected =>
        channel.hasCredentials ? 'Подключено' : 'Ручные данные',
      ChannelStatus.disconnected => 'Не подключено',
      ChannelStatus.error => 'Ошибка',
      ChannelStatus.syncing => 'Синхронизация',
    };
    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(channel: channel),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            channel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Pill(label: statusLabel, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        PlatformChip(platform: channel.platform, compact: true),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            channel.url ?? channel.platformId ?? 'Ссылка не указана',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Действия',
                icon: Icon(Icons.more_vert_rounded,
                    size: 17, color: colors.muted),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
            ],
          ),
          if (channel.description != null && channel.description!.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              channel.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.muted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  label: 'Аудитория',
                  value: channel.subscriberCount > 0
                      ? channel.subscriberCount.formatCompact()
                      : '—',
                ),
              ),
              Expanded(
                child: MiniStat(
                  label: 'Последняя синхронизация',
                  value: channel.lastSyncAt == null
                      ? '—'
                      : channel.lastSyncAt!.formatRelative(),
                ),
              ),
            ],
          ),
          if (channel.error != null) ...[
            const SizedBox(height: 10),
            ErrorNotice(message: channel.error!, compact: true),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: channel.platform == PlatformType.boosty
                    ? OutlinedButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.edit_note_rounded, size: 15),
                        label: const Text('Ввести метрики'),
                      )
                    : channel.hasCredentials
                        ? OutlinedButton.icon(
                            onPressed: onSync,
                            icon: const Icon(Icons.sync_rounded, size: 15),
                            label: const Text('Синхронизировать'),
                          )
                        : OutlinedButton.icon(
                            onPressed: onConnect,
                            icon: const Icon(Icons.link_rounded, size: 15),
                            label: const Text('Подключить'),
                          ),
              ),
              const SizedBox(width: 8),
              SmallIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Настройки',
                onPressed: onEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.channel});

  final PlatformChannel channel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (channel.avatarUrl != null && channel.avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          channel.avatarUrl!,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              _letterAvatar(context, colors),
        ),
      );
    }
    return _letterAvatar(context, colors);
  }

  Widget _letterAvatar(BuildContext context, AppColors colors) {
    final color = platformColor(channel.platform);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: channel.name.trim().isEmpty
            ? Icon(platformIcon(channel.platform), size: 19, color: color)
            : Text(
                channel.name.trim().characters.first.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _ChannelPanel extends ConsumerStatefulWidget {
  const _ChannelPanel({
    required this.channelId,
    required this.openConnect,
    required this.onChanged,
    required this.onEdit,
    required this.onDeleted,
  });

  final String channelId;
  final bool openConnect;
  final VoidCallback onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ChannelPanel> createState() => _ChannelPanelState();
}

class _ChannelPanelState extends ConsumerState<_ChannelPanel> {
  bool _openedConnect = false;
  bool _syncing = false;
  bool _oAuthInProgress = false;

  @override
  void initState() {
    super.initState();
    if (widget.openConnect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openConnectDialog();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(channelRepositoryProvider);
    final channel = repo.getChannel(widget.channelId);
    final colors = context.colors;
    if (channel == null) {
      return const Center(child: Text('Площадка удалена'));
    }
    final snapshots = repo.getSnapshots(channelId: channel.id);
    final recentSnapshots = snapshots.reversed.take(8).toList();
    final runs = repo.getSyncRuns(channelId: channel.id);
    final capability = platformCapabilities[channel.platform]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            PlatformChip(platform: channel.platform),
            const SizedBox(width: 7),
            Pill(
              label: channel.status.label,
              color: switch (channel.status) {
                ChannelStatus.connected => colors.green,
                ChannelStatus.disconnected => colors.muted,
                ChannelStatus.error => colors.red,
                ChannelStatus.syncing => colors.accent,
              },
            ),
            const Spacer(),
            Pill(
              label: authMethodHint(channel.platform, channel.authMethod),
              color: channel.hasCredentials ? colors.green : colors.muted,
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              KeyValueRow(
                label: 'ID площадки',
                value: channel.platformId ?? 'Не указан',
                icon: Icons.tag_rounded,
              ),
              KeyValueRow(
                label: 'Ссылка',
                value: channel.url ?? 'Не указана',
                icon: Icons.link_rounded,
              ),
              KeyValueRow(
                label: 'Аудитория',
                value: channel.subscriberCount > 0
                    ? channel.subscriberCount.formatCompact()
                    : 'Нет данных',
                icon: Icons.people_outline_rounded,
              ),
              KeyValueRow(
                label: 'Последняя синхронизация',
                value: channel.lastSyncAt == null
                    ? 'Ещё не было'
                    : channel.lastSyncAt!.formatDateTime(),
                icon: Icons.schedule_rounded,
              ),
              KeyValueRow(
                label: 'Снимков метрик',
                value: '${snapshots.length}',
                icon: Icons.query_stats_rounded,
              ),
            ],
          ),
        ),
        if (channel.error != null) ...[
          const SizedBox(height: 12),
          ErrorNotice(message: channel.error!),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: 'Подключение',
          subtitle: capability.auth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (channel.platform == PlatformType.boosty)
                InfoNotice(
                  message:
                      'У Boosty нет публичного API. Добавляйте метрики вручную '
                      'или импортируйте данные из личного кабинета. Такие '
                      'значения помечаются как manual.',
                  color: colors.yellow,
                  icon: Icons.workspace_premium_outlined,
                )
              else if (channel.hasCredentials) ...[
                InfoNotice(
                  message:
                      'Доступ подключён и хранится на сервере. Клиент не '
                      'содержит токенов.',
                  color: colors.green,
                  icon: Icons.verified_user_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _syncing ? null : _sync,
                        icon: _syncing
                            ? const Spinner(size: 14)
                            : const Icon(Icons.sync_rounded, size: 16),
                        label: const Text('Синхронизировать'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _disconnect,
                      child: const Text('Отключить'),
                    ),
                  ],
                ),
              ] else ...[
                InfoNotice(
                  message: _connectHint(channel.platform),
                  color: colors.blue,
                  icon: Icons.vpn_key_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _openConnectDialog,
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: Text(
                          channel.platform == PlatformType.youtube ||
                                  channel.platform == PlatformType.github
                              ? 'Подключить через OAuth'
                              : 'Ввести токен',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _addManualSnapshot,
                      icon: const Icon(Icons.edit_note_rounded, size: 15),
                      label: const Text('Вручную'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Доступные метрики: ${capability.availableMetrics.join(', ')}.',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 10.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Недоступно: ${capability.unavailableMetrics.join(', ')}.',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 10.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                capability.limitations,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 10.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Сбор данных',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Автоматическая синхронизация',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  channel.platform == PlatformType.boosty
                      ? 'Недоступна для Boosty'
                      : 'Пока приложение открыто; интервал '
                          '${channel.syncIntervalMinutes ?? 180} мин.',
                  style: TextStyle(fontSize: 10.5, color: colors.muted),
                ),
                value: channel.autoSync,
                onChanged: channel.platform == PlatformType.boosty
                    ? null
                    : (value) async {
                        await repo.saveChannel(
                          channel.copyWith(
                            autoSync: value,
                            updatedAt: DateTime.now(),
                          ),
                        );
                        widget.onChanged();
                      },
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addManualSnapshot,
                      icon: const Icon(Icons.edit_note_rounded, size: 15),
                      label: const Text('Добавить снимок метрик'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SmallIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Изменить площадку',
                    onPressed: widget.onEdit,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Последние снимки',
          subtitle: 'История сохраняется отдельно и не перезаписывается',
          trailing: Text(
            '${snapshots.length}',
            style: TextStyle(color: colors.muted, fontSize: 11),
          ),
          child: recentSnapshots.isEmpty
              ? const EmptyState(
                  title: 'Снимков пока нет',
                  message:
                      'Подключите API или добавьте метрики вручную. Графики '
                      'строятся только по сохранённым значениям.',
                  icon: Icons.query_stats_rounded,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final snapshot in recentSnapshots)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              child: Text(
                                snapshot.date.formatDayMonth(),
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                AnalyticsMetric.label(snapshot.metric),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              AnalyticsMetric.isMoney(snapshot.metric)
                                  ? snapshot.value.formatMoney()
                                  : snapshot.value.formatCompact(),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Pill(
                              label: snapshot.source.name,
                              color: snapshot.source == SnapshotSource.api
                                  ? colors.green
                                  : colors.yellow,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'История синхронизаций',
          trailing: IconButton(
            tooltip: 'Обновить',
            onPressed: _syncing ? null : _sync,
            icon: const Icon(Icons.sync_rounded, size: 16),
          ),
          child: runs.isEmpty
              ? Text(
                  'Синхронизаций ещё не было.',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                )
              : Column(
                  children: [
                    for (final run in runs.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: run.status == SyncRunStatus.success
                                    ? colors.green
                                    : run.status == SyncRunStatus.error
                                        ? colors.red
                                        : colors.muted,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    run.message ??
                                        (run.status == SyncRunStatus.running
                                            ? 'Выполняется…'
                                            : run.status.name),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                  Text(
                                    '${run.startedAt.formatDateTime()} · '
                                    '${run.trigger.name}'
                                    '${run.duration == null ? '' : ' · ${run.duration!.inSeconds} с'}',
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (run.metricsWritten > 0)
                              Pill(
                                label: '${run.metricsWritten} метрик',
                                color: colors.accent,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _delete,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.red,
            side: BorderSide(color: colors.red.withValues(alpha: 0.5)),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('Удалить площадку'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _connectHint(PlatformType platform) => switch (platform) {
        PlatformType.youtube =>
          'Подключение выполняется через OAuth 2.0 Google. После входа '
              'сервер сохранит токены и будет обновлять их автоматически.',
        PlatformType.telegram =>
          'Создайте бота у @BotFather, добавьте его администратором канала и '
              'вставьте токен. Токен будет сохранён в Supabase Edge Function.',
        PlatformType.boosty =>
          'Публичного API нет — доступен только ручной ввод.',
        PlatformType.vk =>
          'Введите access token сообщества с правами на чтение стены и '
              'статистики. Токен сохраняется только на сервере.',
        PlatformType.github =>
          'Можно использовать OAuth GitHub или fine-grained token с доступом '
              'к репозиториям. Для трафика нужны права администратора репозитория.',
      };

  Future<void> _openConnectDialog() async {
    if (_openedConnect) return;
    _openedConnect = true;
    final repo = ref.read(channelRepositoryProvider);
    final channel = repo.getChannel(widget.channelId);
    if (channel == null) return;
    final cloud = ref.read(cloudServiceProvider);
    final colors = context.colors;
    final credential = TextEditingController();
    final extra = TextEditingController();
    var method = channel.platform == PlatformType.telegram
        ? AuthMethod.botToken
        : AuthMethod.accessToken;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Подключение ${channel.platform.label}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InfoNotice(
                    message: platformCapabilities[channel.platform]!.auth,
                    color: colors.blue,
                    icon: Icons.vpn_key_outlined,
                  ),
                  if (!cloud.isConfigured) ...[
                    const SizedBox(height: 10),
                    const ErrorNotice(
                      message:
                          'Supabase не настроен. Добавьте SUPABASE_URL и '
                          'SUPABASE_ANON_KEY при сборке, разверните Edge '
                          'Functions и войдите в облачный аккаунт. Сейчас '
                          'доступен только ручной ввод метрик.',
                    ),
                  ],
                  if (channel.platform == PlatformType.youtube) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Для YouTube используется только OAuth: сервер '
                      'сформирует ссылку, вы войдёте в Google и вернётесь в '
                      'приложение.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ] else if (channel.platform == PlatformType.github) ...[
                    const SizedBox(height: 12),
                    SegmentedTabs(
                      tabs: const ['OAuth', 'Токен'],
                      selected: method == AuthMethod.oauth ? 0 : 1,
                      onChanged: (value) => setDialogState(
                        () => method = value == 0
                            ? AuthMethod.oauth
                            : AuthMethod.accessToken,
                      ),
                    ),
                    if (method == AuthMethod.accessToken) ...[
                      const SizedBox(height: 10),
                      LabeledField(
                        label: 'Personal access token',
                        child: TextField(
                          controller: credential,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'github_pat_… или ghp_…',
                          ),
                        ),
                      ),
                    ],
                  ] else if (channel.platform != PlatformType.boosty &&
                      channel.platform != PlatformType.youtube) ...[
                    const SizedBox(height: 12),
                    LabeledField(
                      label: channel.platform == PlatformType.telegram
                          ? 'Токен бота'
                          : 'Access token',
                      child: TextField(
                        controller: credential,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: channel.platform == PlatformType.telegram
                              ? '123456:ABC-DEF…'
                              : 'vk1.a.…',
                        ),
                      ),
                    ),
                    if (channel.platform == PlatformType.telegram) ...[
                      const SizedBox(height: 10),
                      LabeledField(
                        label: 'ID канала (необязательно)',
                        child: TextField(
                          controller: extra,
                          decoration: const InputDecoration(
                            hintText: '@channel или -100…',
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (channel.platform == PlatformType.boosty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Подключение невозможно: у Boosty нет публичного API. '
                      'Используйте ручные снимки метрик.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            if (channel.platform != PlatformType.boosty)
              FilledButton(
                onPressed: _oAuthInProgress
                    ? null
                    : () async {
                        // ── YouTube / GitHub OAuth flow ────────────────────────
                        if (channel.platform == PlatformType.youtube ||
                            (channel.platform == PlatformType.github &&
                                method == AuthMethod.oauth)) {
                          // ── Check OAuth availability (cloud + auth) ────────
                          if (!repo.isOAuthAvailable) {
                            debugPrint(
                              '[OAuth] ❌ OAuth недоступен: '
                              'cloud=${ref.read(cloudServiceProvider).isConfigured}, '
                              'signedIn=${ref.read(cloudServiceProvider).isSignedIn}',
                            );
                            // Show sign-in dialog directly from the connect dialog
                            await _showSignInDialog(dialogContext, channel);
                            // After sign-in, retry the OAuth flow
                            if (dialogContext.mounted && context.mounted) {
                              // Refresh the channel and retry
                              final refreshedRepo =
                                  ref.read(channelRepositoryProvider);
                              if (!refreshedRepo.isOAuthAvailable) {
                                showAppSnack(
                                  context,
                                  'Вход не выполнен. Попробуйте ещё раз или '
                                  'введите токен вручную.',
                                  error: true,
                                );
                                return;
                              }
                              await _doOAuthFlow(dialogContext, channel);
                            }
                            return; // Prevent falling through to the second _doOAuthFlow call
                          }

                          await _doOAuthFlow(dialogContext, channel);
                          return;
                        }

                  // ── Non-OAuth flow (token entry) ───────────────────────────
                  try {
                    final token = credential.text.trim();
                    if (token.isEmpty) {
                      throw StateError('Введите токен доступа');
                    }
                    await repo.saveServerCredential(
                      channel: channel,
                      credential: token,
                      method: method,
                      extra: {
                        if (extra.text.trim().isNotEmpty)
                          'chat_id': extra.text.trim(),
                      },
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    widget.onChanged();
                    if (context.mounted) {
                      showAppSnack(context, 'Доступ сохранён на сервере');
                    }
                  } catch (error) {
                    if (context.mounted) {
                      showAppSnack(context, error.toString(), error: true);
                    }
                  }
                },
                child: const Text('Подключить'),
              ),
          ],
        ),
      ),
    );
    credential.dispose();
    extra.dispose();
    _openedConnect = false;
  }

  Future<void> _addManualSnapshot() async {
    final repo = ref.read(channelRepositoryProvider);
    final channel = repo.getChannel(widget.channelId);
    if (channel == null) return;
    var date = DateTime.now();
    final followers = TextEditingController(
      text: channel.subscriberCount > 0 ? '${channel.subscriberCount}' : '',
    );
    final views = TextEditingController();
    final likes = TextEditingController();
    final comments = TextEditingController();
    final shares = TextEditingController();
    final paid = TextEditingController();
    final revenue = TextEditingController();
    final posts = TextEditingController();

    Map<String, TextEditingController> fields() => {
          AnalyticsMetric.followers: followers,
          AnalyticsMetric.views: views,
          AnalyticsMetric.likes: likes,
          AnalyticsMetric.comments: comments,
          AnalyticsMetric.shares: shares,
          AnalyticsMetric.paidSubscribers: paid,
          AnalyticsMetric.revenue: revenue,
          AnalyticsMetric.posts: posts,
        };

    try {
      await showFormDialog(
        context,
        title: 'Снимок метрик',
        description:
            'Значения сохраняются с источником manual и датой снимка. '
            'Пустые поля пропускаются.',
        submitLabel: 'Сохранить снимок',
        wide: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoNotice(
                message:
                    'Для Boosty это основной способ учёта. Для площадок с API '
                    'ручные снимки не перезаписывают данные API: они хранятся '
                    'отдельно с тем же периодом.',
                color: context.colors.yellow,
                icon: Icons.edit_note_rounded,
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Дата снимка',
                child: InkWell(
                  onTap: () async {
                    final picked = await pickDate(
                      context,
                      initial: date,
                      last: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      suffixIcon: Icon(Icons.date_range_outlined, size: 17),
                    ),
                    child: Text(date.formatShort()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final two = constraints.maxWidth > 480;
                  final width = two
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;
                  final entries = fields().entries.toList();
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final entry in entries)
                        SizedBox(
                          width: width,
                          child: LabeledField(
                            label: AnalyticsMetric.label(entry.key),
                            child: TextField(
                              controller: entry.value,
                              keyboardType: numberKeyboard,
                              inputFormatters: decimalFormatters,
                              decoration: InputDecoration(
                                hintText: AnalyticsMetric.isMoney(entry.key)
                                    ? 'в базовой валюте'
                                    : '0',
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        onSubmit: () async {
          final metrics = <String, double>{};
          for (final entry in fields().entries) {
            final raw = entry.value.text.trim().replaceAll(',', '.');
            if (raw.isEmpty) continue;
            final value = double.tryParse(raw);
            if (value == null) {
              throw FormatException(
                'Некорректное значение для «${AnalyticsMetric.label(entry.key)}»',
              );
            }
            if (value < 0) {
              throw FormatException(
                'Значение «${AnalyticsMetric.label(entry.key)}» не может быть отрицательным',
              );
            }
            metrics[entry.key] = value;
          }
          if (metrics.isEmpty) {
            throw const FormatException('Заполните хотя бы одну метрику');
          }
          await repo.addManualSnapshot(
            channel: channel,
            date: date,
            metrics: metrics,
            note: 'Площадка ${channel.platform.label}',
          );
          widget.onChanged();
        },
      );
    } finally {
      for (final controller in fields().values) {
        controller.dispose();
      }
    }
  }

  Future<void> _sync() async {
    final repo = ref.read(channelRepositoryProvider);
    final channel = repo.getChannel(widget.channelId);
    if (channel == null || _syncing) return;
    setState(() => _syncing = true);
    try {
      final result = await repo.syncChannel(channel);
      widget.onChanged();
      if (mounted) {
        showAppSnack(context, result.message,
            error: !result.success && !result.manualOnly);
      }
      if (!result.success && !result.manualOnly) {
        await ref.read(notificationRepositoryProvider).create(
              type: NotificationType.syncError,
              title: 'Ошибка синхронизации: ${channel.name}',
              message: result.message,
              relatedId: channel.id,
              relatedType: 'channel',
            );
        widget.onChanged();
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _disconnect() async {
    final repo = ref.read(channelRepositoryProvider);
    final channel = repo.getChannel(widget.channelId);
    if (channel == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Отключить доступ?',
      message:
          'Сервер удалит сохранённые токены площадки. История метрик и '
          'публикаций останется.',
      confirmLabel: 'Отключить',
    );
    if (!confirmed) return;
    try {
      await repo.disconnectServerCredential(channel);
      widget.onChanged();
      if (mounted) showAppSnack(context, 'Доступ отключён');
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  Future<void> _delete() async {
    final repo = ref.read(channelRepositoryProvider);
    final channel = repo.getChannel(widget.channelId);
    if (channel == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить площадку?',
      message:
          'Будут удалены карточка и все снимки метрик. Это действие нельзя '
          'отменить.',
    );
    if (!confirmed) return;
    await repo.deleteChannel(channel);
    widget.onChanged();
    widget.onDeleted();
  }

  /// Shows a sign-in dialog when OAuth is requested but the user is not
  /// authenticated with Supabase cloud.
  Future<void> _showSignInDialog(
    BuildContext dialogContext,
    PlatformChannel channel,
  ) async {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final auth = ref.read(authProvider.notifier);
    var busy = false;

    await showDialog<void>(
      context: dialogContext,
      builder: (innerContext) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: const Text('Вход в облако'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Для подключения YouTube через OAuth необходим вход в '
                  'облачный аккаунт Supabase. Токены хранятся только на '
                  'сервере и не покидают его.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      final password = passwordCtrl.text;
                      if (email.isEmpty || password.isEmpty) return;
                      setInnerState(() => busy = true);
                      try {
                        await auth.signIn(email, password);
                        if (ctx.mounted) Navigator.pop(ctx);
                        // Refresh the channel panel after sign-in
                        if (!mounted) return;
                        ref.read(dataVersionProvider.notifier).state++;
                        showAppSnack(
                          context,
                          'Вы вошли. Повторите подключение.',
                        );
                      } catch (error) {
                        if (ctx.mounted) {
                          final msg = error.toString().replaceAll(
                                'Exception: ', '',
                              );
                          showAppSnack(ctx, msg, error: true);
                        }
                      } finally {
                        if (ctx.mounted) {
                          setInnerState(() => busy = false);
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Войти'),
            ),
          ],
        ),
      ),
    );

    emailCtrl.dispose();
    passwordCtrl.dispose();
  }

  /// Executes the full OAuth flow: calls startOAuth, validates the URL,
  /// launches the browser, and handles the result.
  Future<void> _doOAuthFlow(
    BuildContext dialogContext,
    PlatformChannel channel,
  ) async {
    // Guard against re-entrant calls (double-tap, nested navigation, etc.)
    if (_oAuthInProgress) {
      debugPrint('[OAuth] ⚠️ Пропуск: OAuth уже выполняется');
      return;
    }

    debugPrint('[OAuth] FLOW ENTER');
    debugPrint('[OAuth] IN_PROGRESS BEFORE CHECK: $_oAuthInProgress');

    // Set the flag ONLY after passing the guard — this is the single
    // source of truth that guarantees exactly one flow runs at a time.
    _oAuthInProgress = true;
    debugPrint('[OAuth] FLOW STARTED');

    try {
      debugPrint(
        '[OAuth] >>> Нажата кнопка "Подключить" для '
        '${channel.platform.label} (channel=${channel.id})',
      );

      // ── Этап 1: Вызов Edge Function platform-oauth-start ──────────
      debugPrint('[OAuth] CALLING EDGE FUNCTION');
      late String url;
      try {
        url = await ref.read(channelRepositoryProvider).startOAuth(channel);
      } on StateError catch (e) {
        debugPrint('[OAuth] ❌ Этап 1: StateError: ${e.message}');
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (context.mounted) {
          showAppSnack(
            context,
            'Невозможно начать OAuth: ${e.message}',
            error: true,
          );
        }
        _openedConnect = false;
        return;
      } catch (error, stackTrace) {
        debugPrint('[OAuth] ❌ Этап 1: Exception при вызове Edge Function:');
        debugPrint('[OAuth]   type: ${error.runtimeType}');
        debugPrint('[OAuth]   message: $error');
        debugPrint('[OAuth]   stack: $stackTrace');
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (context.mounted) {
          final text = error.toString();
          final message = text.contains('FunctionException')
              ? 'Ошибка Edge Function platform-oauth-start. '
                  'Проверьте журнал Supabase и настройки OAuth приложения.'
              : 'Не удалось запросить OAuth URL: $text';
          showAppSnack(context, message, error: true);
        }
        _openedConnect = false;
        return;
      }
      debugPrint('[OAuth] EDGE FUNCTION RESPONSE: ${url.isNotEmpty}');

      // ── Этап 2: Проверка ответа сервера ───────────────────────────
      if (url.isEmpty) {
        debugPrint('[OAuth] ❌ Этап 2: сервер вернул пустой URL');
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (context.mounted) {
          showAppSnack(
            context,
            'Сервер не вернул OAuth URL. Повторите попытку или введите '
            'токен вручную.',
            error: true,
          );
        }
        _openedConnect = false;
        return;
      }
      debugPrint('[OAuth] ✅ Этап 2: OAuth URL получен (${url.length} символов)');

      // ── Этап 3: Валидация URL ────────────────────────────────────
      late Uri parsedUrl;
      try {
        parsedUrl = Uri.parse(url);
      } on FormatException catch (e) {
        debugPrint('[OAuth] ❌ Этап 3: Uri.parse не смог распознать URL: $e');
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (context.mounted) {
          showAppSnack(
            context,
            'Сервер вернул некорректный OAuth URL. Повторите попытку.',
            error: true,
          );
        }
        _openedConnect = false;
        return;
      }

      if (parsedUrl.scheme != 'https') {
        debugPrint('[OAuth] ❌ Этап 3: Схема URL не https: ${parsedUrl.scheme}');
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (context.mounted) {
          showAppSnack(
            context,
            'OAuth URL должен начинаться с https:// (получено: ${parsedUrl.scheme})',
            error: true,
          );
        }
        _openedConnect = false;
        return;
      }

      if (channel.platform == PlatformType.youtube &&
          parsedUrl.host != 'accounts.google.com') {
        debugPrint(
          '[OAuth] ❌ Этап 3: Хост URL не accounts.google.com: '
          '${parsedUrl.host}',
        );
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (context.mounted) {
          showAppSnack(
            context,
            'OAuth URL должен вести на accounts.google.com '
            '(получено: ${parsedUrl.host}). Повторите попытку.',
            error: true,
          );
        }
        _openedConnect = false;
        return;
      }

      debugPrint('[OAuth] ✅ Этап 3: URL валиден: scheme=${parsedUrl.scheme}, host=${parsedUrl.host}');

      // ── Этап 4: Запуск внешнего браузера ─────────────────────────
      debugPrint('[OAuth] OPENING EXTERNAL BROWSER');
      final launched = await launchUrl(
        parsedUrl,
        mode: LaunchMode.externalApplication,
      );

      debugPrint('[OAuth] BROWSER LAUNCH RESULT: $launched');

      if (!launched) {
        debugPrint('[OAuth] ❌ Этап 4: Браузер НЕ открылся (launched=false)');
        if (context.mounted) {
          showAppSnack(
            context,
            'Не удалось открыть браузер для авторизации. '
            'Проверьте настройки системы или попробуйте '
            'ввести токен вручную.',
            error: true,
          );
        }
        _openedConnect = false;
        return;
      }

      debugPrint('[OAuth] ✅ Этап 4: Браузер открыт успешно.');
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      if (context.mounted) {
        showAppSnack(
          context,
          'OAuth открыт в браузере. После входа вернитесь в '
          'приложение и запустите синхронизацию.',
        );
      }
      _openedConnect = false;
    } finally {
      debugPrint('[OAuth] FLOW FINISHED');
      _oAuthInProgress = false;
      debugPrint('[OAuth] IN_PROGRESS RESET: false');
    }
  }
}
