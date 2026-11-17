import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/publication.dart';
import 'package:media_crm/providers/app_providers.dart';

class PublicationsScreen extends ConsumerStatefulWidget {
  const PublicationsScreen({super.key});

  @override
  ConsumerState<PublicationsScreen> createState() => _PublicationsScreenState();
}

class _PublicationsScreenState extends ConsumerState<PublicationsScreen> {
  final _search = TextEditingController();
  PlatformType? _platform;
  PublicationType? _type;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(publicationRepositoryProvider);
    final all = repo.getPublications();
    final items = repo.getPublications(
      platform: _platform,
      type: _type,
      search: _search.text,
    );
    final channels = ref.watch(channelRepositoryProvider).getChannels();
    final colors = context.colors;
    final totalViews = all.fold<double>(
      0,
      (sum, p) => sum + (repo.latestStats(p.id)?.views ?? 0),
    );
    final withStats = all.where((p) => repo.latestStats(p.id) != null).length;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Публикации',
            subtitle:
                'Единый архив публикаций всех площадок с сохранённой '
                'историей метрик. Метрики не запрашиваются чаще, чем позволяет API.',
            actions: [
              FilledButton.icon(
                onPressed: () => _openForm(channels: channels),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить публикацию'),
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
                      label: 'Всего публикаций',
                      value: '${all.length}',
                      icon: Icons.article_outlined,
                      color: colors.accent,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Суммарные просмотры',
                      value: totalViews.formatCompact(),
                      icon: Icons.visibility_outlined,
                      color: colors.blue,
                      footnote:
                          'По последним снимкам; заполнено $withStats из ${all.length}',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Площадки',
                      value:
                          '${all.map((p) => p.platform).toSet().length}',
                      icon: Icons.hub_outlined,
                      color: colors.pink,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'За 30 дней',
                      value:
                          '${all.where((p) => p.publishedAt.isAfter(DateTime.now().subtract(const Duration(days: 30)))).length}',
                      icon: Icons.calendar_month_outlined,
                      color: colors.yellow,
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
                width: 260,
                child: SearchField(
                  controller: _search,
                  hint: 'Название или текст…',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              PlatformDropdown(
                value: _platform,
                onChanged: (value) => setState(() => _platform = value),
              ),
              _typeDropdown(colors),
              Text(
                '${items.length} из ${all.length}',
                style: TextStyle(color: colors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (all.isEmpty)
            EmptyState(
              title: 'Публикаций пока нет',
              message:
                  'Добавьте публикацию вручную или подключите площадку с API '
                  'и запустите синхронизацию. Публикации хранятся отдельно от '
                  'снимков метрик.',
              icon: Icons.article_outlined,
              action: FilledButton.icon(
                onPressed: () => _openForm(channels: channels),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить публикацию'),
              ),
            )
          else if (items.isEmpty)
            const EmptyState(
              title: 'Ничего не найдено',
              message: 'Измените запрос или фильтры.',
              icon: Icons.search_off_rounded,
              compact: true,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1200
                    ? 3
                    : constraints.maxWidth >= 740
                        ? 2
                        : 1;
                const gap = 12.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final publication in items)
                      SizedBox(
                        width: width,
                        child: _PublicationCard(
                          publication: publication,
                          stats: repo.latestStats(publication.id),
                          onOpen: () => _openPanel(publication),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          const DataSourceNote(
            text:
                'Просмотры, лайки и комментарии сохраняются как отдельные '
                'снимки с датой и источником. Ручные снимки помечаются '
                'manual и не смешиваются с ответами API.',
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
        child: DropdownButton<PublicationType?>(
          value: _type,
          isDense: true,
          dropdownColor: colors.panel,
          hint: Text('Все типы',
              style: TextStyle(fontSize: 11.5, color: colors.muted)),
          style: TextStyle(fontSize: 11.5, color: colors.text),
          items: [
            DropdownMenuItem<PublicationType?>(
              value: null,
              child: Text('Все типы',
                  style: TextStyle(fontSize: 11.5, color: colors.muted)),
            ),
            for (final type in PublicationType.values)
              DropdownMenuItem<PublicationType?>(
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

  Future<void> _openForm({
    required List<PlatformChannel> channels,
    Publication? publication,
  }) async {
    final title = TextEditingController(text: publication?.title ?? '');
    final url = TextEditingController(text: publication?.url ?? '');
    final image = TextEditingController(text: publication?.imageUrl ?? '');
    final content = TextEditingController(text: publication?.content ?? '');
    final postId =
        TextEditingController(text: publication?.platformPostId ?? '');
    var platform = publication?.platform ?? PlatformType.youtube;
    var type = publication?.type ?? PublicationType.video;
    var channelId = publication?.channelId;
    var publishedAt = publication?.publishedAt ?? DateTime.now();
    final platformChannels =
        channels.where((c) => c.platform == platform).toList();

    try {
      await showFormDialog(
        context,
        title: publication == null ? 'Новая публикация' : 'Публикация',
        description:
            'Название и дата обязательны. ID поста нужен для сопоставления с API.',
        submitLabel: publication == null ? 'Добавить' : 'Сохранить',
        wide: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Площадка',
                      child: DropdownButtonFormField<PlatformType>(
                        value: platform,
                        items: [
                          for (final item in PlatformType.values)
                            DropdownMenuItem(
                              value: item,
                              child: Row(
                                children: [
                                  Icon(platformIcon(item),
                                      size: 14,
                                      color: platformColor(item)),
                                  const SizedBox(width: 6),
                                  Text(item.label),
                                ],
                              ),
                            ),
                        ],
                        onChanged: publication != null
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  platform = value;
                                  channelId = null;
                                });
                              },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Тип',
                      child: DropdownButtonFormField<PublicationType>(
                        value: type,
                        items: [
                          for (final item in PublicationType.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => type = value ?? type),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Канал',
                hint: 'необязательно',
                child: DropdownButtonFormField<String?>(
                  value: platformChannels.any((c) => c.id == channelId)
                      ? channelId
                      : null,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Без привязки'),
                    ),
                    for (final channel in platformChannels)
                      DropdownMenuItem<String?>(
                        value: channel.id,
                        child: Text(channel.name,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => channelId = value),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Название',
                child: TextField(controller: title),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Ссылка',
                child: TextField(
                  controller: url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(hintText: 'https://…'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'ID публикации на площадке',
                      child: TextField(
                        controller: postId,
                        decoration:
                            const InputDecoration(hintText: 'Необязательно'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Дата публикации',
                      child: InkWell(
                        onTap: () async {
                          final picked =
                              await pickDate(context, initial: publishedAt);
                          if (picked != null) {
                            setDialogState(() => publishedAt = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            suffixIcon:
                                Icon(Icons.date_range_outlined, size: 17),
                          ),
                          child: Text(publishedAt.formatShort()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'URL изображения',
                child: TextField(
                  controller: image,
                  keyboardType: TextInputType.url,
                  decoration:
                      const InputDecoration(hintText: 'https://… (необязательно)'),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Текст или описание',
                child: TextField(
                  controller: content,
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
            throw const FormatException('Укажите название публикации');
          }
          final repo = ref.read(publicationRepositoryProvider);
          final auth = ref.read(authProvider);
          final now = DateTime.now();
          final entity = publication == null
              ? Publication(
                  id: const Uuid().v4(),
                  userId: auth.userId,
                  platform: platform,
                  channelId: channelId,
                  platformPostId: _nullIfEmpty(postId.text),
                  title: trimmed,
                  content: _nullIfEmpty(content.text),
                  imageUrl: _nullIfEmpty(image.text),
                  url: _nullIfEmpty(url.text),
                  type: type,
                  publishedAt: publishedAt,
                  createdAt: now,
                  updatedAt: now,
                )
              : publication.copyWith(
                  channelId: channelId,
                  platformPostId: _nullIfEmpty(postId.text),
                  title: trimmed,
                  content: _nullIfEmpty(content.text),
                  imageUrl: _nullIfEmpty(image.text),
                  url: _nullIfEmpty(url.text),
                  type: type,
                  publishedAt: publishedAt,
                  updatedAt: now,
                );
          await repo.savePublication(entity);
          bumpData(ref);
        },
      );
    } finally {
      title.dispose();
      url.dispose();
      image.dispose();
      content.dispose();
      postId.dispose();
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _openPanel(Publication publication) async {
    await showSidePanel<void>(
      context,
      title: publication.title,
      subtitle: '${publication.platform.label} · ${publication.type.label}',
      child: _PublicationPanel(
        publicationId: publication.id,
        onChanged: () => bumpData(ref),
        onDeleted: () => Navigator.of(context).maybePop(),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _PublicationCard extends StatelessWidget {
  const _PublicationCard({
    required this.publication,
    required this.stats,
    required this.onOpen,
  });

  final Publication publication;
  final PublicationStats? stats;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final er = stats == null || stats!.views == 0
        ? 0.0
        : stats!.engagement / stats!.views * 100;
    return AppCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (publication.imageUrl != null && publication.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: Image.network(
                publication.imageUrl!,
                height: 118,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    _placeholder(colors),
              ),
            )
          else
            _placeholder(colors),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PlatformChip(platform: publication.platform, compact: true),
                    const SizedBox(width: 6),
                    Pill(label: publication.type.label, color: colors.muted),
                    const Spacer(),
                    Text(
                      publication.publishedAt.formatDayMonth(),
                      style: TextStyle(color: colors.muted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  publication.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (publication.content != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    publication.content!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _metric(colors, Icons.visibility_outlined,
                        stats?.views.formatCompact() ?? '—'),
                    const SizedBox(width: 10),
                    _metric(colors, Icons.favorite_border_rounded,
                        stats?.likes.formatCompact() ?? '—'),
                    const SizedBox(width: 10),
                    _metric(colors, Icons.chat_bubble_outline_rounded,
                        stats?.comments.formatCompact() ?? '—'),
                    const Spacer(),
                    if (stats != null)
                      Pill(
                        label: 'ER ${er.toStringAsFixed(1)}%',
                        color: colors.accent,
                      )
                    else
                      Pill(label: 'Нет метрик', color: colors.yellow),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(AppColors colors) => Container(
        height: 92,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              platformColor(publication.platform).withValues(alpha: 0.22),
              colors.panelAlt,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(13)),
        ),
        child: Center(
          child: Icon(
            platformIcon(publication.platform),
            size: 28,
            color: platformColor(publication.platform),
          ),
        ),
      );

  Widget _metric(AppColors colors, IconData icon, String value) => Row(
        children: [
          Icon(icon, size: 12, color: colors.muted),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              color: colors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

class _PublicationPanel extends ConsumerStatefulWidget {
  const _PublicationPanel({
    required this.publicationId,
    required this.onChanged,
    required this.onDeleted,
  });

  final String publicationId;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_PublicationPanel> createState() => _PublicationPanelState();
}

class _PublicationPanelState extends ConsumerState<_PublicationPanel> {
  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(publicationRepositoryProvider);
    final publication = repo.getPublication(widget.publicationId);
    final colors = context.colors;
    if (publication == null) {
      return const Center(child: Text('Публикация удалена'));
    }
    final stats = repo.getStats(publication.id);
    final latest = repo.latestStats(publication.id);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PlatformChip(platform: publication.platform),
            Pill(label: publication.type.label, color: colors.blue),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Опубликовано',
                value: publication.publishedAt.formatDateTime(),
                icon: Icons.schedule_rounded,
              ),
              KeyValueRow(
                label: 'Ссылка',
                value: publication.url ?? 'Не указана',
                icon: Icons.link_rounded,
              ),
              KeyValueRow(
                label: 'ID на площадке',
                value: publication.platformPostId ?? 'Не указан',
                icon: Icons.tag_rounded,
              ),
              KeyValueRow(
                label: 'Снимков метрик',
                value: '${stats.length}',
                icon: Icons.query_stats_rounded,
              ),
            ],
          ),
        ),
        if (publication.content != null) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Text(
              publication.content!,
              style: const TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _StatsSummary(latest: latest),
        const SizedBox(height: 14),
        SectionCard(
          title: 'История метрик',
          subtitle: 'Каждый снимок хранится отдельно',
          trailing: SmallIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Добавить снимок',
            onPressed: () => _addStats(publication),
          ),
          child: stats.isEmpty
              ? Text(
                  'Метрик пока нет. Добавьте снимок вручную или синхронизируйте '
                  'площадку с API.',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                )
              : Column(
                  children: [
                    for (final item in stats.take(12))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 88,
                              child: Text(
                                item.recordedAt.formatShort(),
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${item.views.formatCompact()} просм. · '
                                '${item.likes.formatCompact()} ♥ · '
                                '${item.comments.formatCompact()} 💬',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                            Pill(
                              label: item.source,
                              color: item.source == 'api'
                                  ? colors.green
                                  : colors.yellow,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => _delete(publication),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.red,
            side: BorderSide(color: colors.red.withValues(alpha: 0.5)),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('Удалить публикацию'),
        ),
      ],
    );
  }

  Future<void> _addStats(Publication publication) async {
    final views = TextEditingController();
    final likes = TextEditingController();
    final comments = TextEditingController();
    final shares = TextEditingController();
    final reach = TextEditingController();
    var date = DateTime.now();
    try {
      await showFormDialog(
        context,
        title: 'Снимок метрик',
        description:
            'Данные сохраняются с источником manual. Пустые поля считаются нулём.',
        submitLabel: 'Сохранить',
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Дата снимка',
                child: InkWell(
                  onTap: () async {
                    final picked = await pickDate(context, initial: date);
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _field('Просмотры', views),
                  _field('Лайки', likes),
                  _field('Комментарии', comments),
                  _field('Репосты', shares),
                  _field('Охват', reach),
                ],
              ),
            ],
          ),
        ),
        onSubmit: () async {
          await ref.read(publicationRepositoryProvider).addStats(
                publication: publication,
                views: _intOf(views),
                likes: _intOf(likes),
                comments: _intOf(comments),
                shares: _intOf(shares),
                reach: reach.text.trim().isEmpty ? null : _intOf(reach),
                source: 'manual',
                recordedAt: date,
              );
          widget.onChanged();
        },
      );
    } finally {
      views.dispose();
      likes.dispose();
      comments.dispose();
      shares.dispose();
      reach.dispose();
    }
  }

  Widget _field(String label, TextEditingController controller) => SizedBox(
        width: 135,
        child: LabeledField(
          label: label,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '0'),
          ),
        ),
      );

  int _intOf(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  Future<void> _delete(Publication publication) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить публикацию?',
      message:
          'Публикация «${publication.title}» и все её снимки метрик будут '
          'удалены.',
    );
    if (!confirmed) return;
    await ref.read(publicationRepositoryProvider).deletePublication(publication);
    widget.onChanged();
    widget.onDeleted();
  }
}

class _StatsSummary extends StatelessWidget {
  const _StatsSummary({required this.latest});

  final PublicationStats? latest;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Последний снимок',
            style: TextStyle(
              color: colors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (latest == null)
            Text(
              'Метрики ещё не сохранялись.',
              style: TextStyle(color: colors.muted, fontSize: 12),
            )
          else
            Wrap(
              spacing: 22,
              runSpacing: 12,
              children: [
                MiniStat(
                    label: 'Просмотры',
                    value: latest!.views.formatCompact()),
                MiniStat(label: 'Лайки', value: latest!.likes.formatCompact()),
                MiniStat(
                    label: 'Комментарии',
                    value: latest!.comments.formatCompact()),
                MiniStat(
                    label: 'Репосты', value: latest!.shares.formatCompact()),
                MiniStat(
                  label: 'ER',
                  value: latest!.views == 0
                      ? '—'
                      : '${(latest!.engagement / latest!.views * 100).toStringAsFixed(1)}%',
                  color: colors.accent,
                ),
              ],
            ),
          if (latest != null) ...[
            const SizedBox(height: 8),
            Text(
              'Записан ${latest!.recordedAt.formatDateTime()} · '
              'источник ${latest!.source}',
              style: TextStyle(color: colors.muted, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
