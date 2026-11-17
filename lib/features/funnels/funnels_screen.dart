import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/funnel.dart';
import 'package:media_crm/providers/app_providers.dart';

class FunnelsScreen extends ConsumerStatefulWidget {
  const FunnelsScreen({super.key});

  @override
  ConsumerState<FunnelsScreen> createState() => _FunnelsScreenState();
}

class _FunnelsScreenState extends ConsumerState<FunnelsScreen> {
  String? _funnelId;

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(funnelRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final funnels = repo.getFunnels();
    final selected = _selectedFunnel(funnels);
    final colors = context.colors;

    if (funnels.isNotEmpty && selected == null) {
      _funnelId = funnels.first.id;
      return build(context);
    }

    if (selected == null) {
      return AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Воронки',
              subtitle:
                  'Kanban-воронки для рекламодателей и партнёров. Сделки '
                  'хранятся локально и синхронизируются при наличии аккаунта.',
              actions: [
                FilledButton.icon(
                  onPressed: () => _openFunnelForm(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Создать воронку'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            EmptyState(
              title: 'Воронок пока нет',
              message:
                  'Создайте воронку — приложение добавит базовые этапы '
                  '«Новый лид», «Квалификация», «Предложение», «Сделка». '
                  'Этапы и сделки можно менять.',
              icon: Icons.view_kanban_outlined,
              action: FilledButton.icon(
                onPressed: () => _openFunnelForm(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Создать воронку'),
              ),
            ),
            const SizedBox(height: 16),
            const DataSourceNote(
              text:
                  'Сделки и суммы вводятся вручную. Автоматического создания '
                  'сделок из рекламных кампаний или партнёрских событий нет, '
                  'чтобы не выдумывать данные.',
            ),
          ],
        ),
      );
    }

    final stages = repo.getStages(selected.id);
    final deals = repo.getDeals(selected.id);
    final metrics = repo.metrics(selected.id);
    final totalValue = deals.fold<double>(0, (sum, d) => sum + d.value);
    final wonValue = metrics.isEmpty ? 0.0 : metrics.last.value;
    final wonDeals = metrics.isEmpty ? 0 : metrics.last.deals;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Воронки',
            subtitle:
                'Перетаскивайте сделки между этапами. Конверсия считается по '
                'текущему количеству сделок на этапах.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => _openFunnelForm(funnel: selected),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Изменить'),
              ),
              FilledButton.icon(
                onPressed: () => _openDealForm(selected, stages: stages),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить сделку'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilterBarShell(
            children: [
              SizedBox(
                width: 230,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selected.id,
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: colors.panel,
                    style: TextStyle(fontSize: 12, color: colors.text),
                    items: [
                      for (final funnel in funnels)
                        DropdownMenuItem(
                          value: funnel.id,
                          child: Text(funnel.name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _funnelId = value);
                    },
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openFunnelForm(),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Новая воронка'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openStageForm(selected, order: stages.length),
                icon: const Icon(Icons.view_column_outlined, size: 14),
                label: const Text('Этап'),
              ),
              if (funnels.length > 1)
                TextButton.icon(
                  onPressed: () => _deleteFunnel(selected),
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 14, color: colors.red),
                  label: Text('Удалить воронку',
                      style: TextStyle(color: colors.red)),
                ),
              Text(
                '${deals.length} сделок',
                style: TextStyle(color: colors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 700
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
                      label: 'Сделок в воронке',
                      value: '${deals.length}',
                      icon: Icons.work_outline_rounded,
                      color: colors.accent,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Сумма сделок',
                      value: totalValue.formatMoney(
                        currency: settings.baseCurrency,
                      ),
                      icon: Icons.account_balance_wallet_outlined,
                      color: colors.blue,
                      footnote: 'Сумма по текущим этапам',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'На финальном этапе',
                      value: wonDeals.toString(),
                      icon: Icons.emoji_events_outlined,
                      color: colors.green,
                      footnote: wonValue.formatMoney(
                        currency: settings.baseCurrency,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Конверсия',
                      value: metrics.length < 2
                          ? '—'
                          : metrics.last.conversionFromPrevious
                              .formatPercent(),
                      icon: Icons.filter_alt_outlined,
                      color: colors.yellow,
                      footnote: metrics.length < 2
                          ? 'Недостаточно этапов'
                          : 'С предыдущего этапа',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (stages.isEmpty)
            EmptyState(
              title: 'В воронке нет этапов',
              message:
                  'Добавьте этапы, чтобы создавать и перемещать сделки.',
              icon: Icons.view_column_outlined,
              action: FilledButton.icon(
                onPressed: () =>
                    _openStageForm(selected, order: stages.length),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить этап'),
              ),
            )
          else
            SizedBox(
              height: 470,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stages.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (index == stages.length) {
                    return _AddStageColumn(
                      onTap: () =>
                          _openStageForm(selected, order: stages.length),
                    );
                  }
                  final stage = stages[index];
                  final stageDeals = repo.getDeals(selected.id,
                      stageId: stage.id);
                  final stageMetrics = metrics[index];
                  return _StageColumn(
                    stage: stage,
                    deals: stageDeals,
                    metrics: stageMetrics,
                    currency: settings.baseCurrency,
                    onDropDeal: (dealId) => _moveDeal(dealId, stage, repo),
                    onAddDeal: () => _openDealForm(
                      selected,
                      stages: stages,
                      initialStageId: stage.id,
                    ),
                    onEditStage: () => _openStageForm(
                      selected,
                      stage: stage,
                      order: stage.order,
                    ),
                    onDeleteStage: () => _deleteStage(stage),
                    onOpenDeal: (deal) => _openDealForm(
                      selected,
                      stages: stages,
                      deal: deal,
                    ),
                    onDeleteDeal: (deal) => _deleteDeal(deal),
                    onMoveDeal: (deal, target) =>
                        _moveDealToStage(deal, target, stages, repo),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          const DataSourceNote(
            text:
                'Конверсия рассчитывается от количества сделок на предыдущем '
                'этапе к текущему и не является вероятностным прогнозом. '
                'Суммы указаны в валюте сделки без пересчёта.',
          ),
        ],
      ),
    );
  }

  Funnel? _selectedFunnel(List<Funnel> funnels) {
    if (funnels.isEmpty) return null;
    for (final funnel in funnels) {
      if (funnel.id == _funnelId) return funnel;
    }
    return funnels.first;
  }

  Future<void> _moveDeal(String dealId, FunnelStage stage,
      dynamic repo) async {
    final deal = repo.getDeals(stage.funnelId)
        .where((d) => d.id == dealId)
        .firstOrNull;
    if (deal == null) return;
    await ref.read(funnelRepositoryProvider).moveDeal(deal, stage.id);
    if (!mounted) return;
    bumpData(ref);
  }

  Future<void> _moveDealToStage(
    FunnelDeal deal,
    FunnelStage target,
    List<FunnelStage> stages,
    dynamic repo,
  ) async {
    await repo.moveDeal(deal, target.id);
    if (!mounted) return;
    bumpData(ref);
  }

  Future<void> _deleteDeal(FunnelDeal deal) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить сделку?',
      message: 'Сделка «${deal.contactName}» будет удалена из воронки.',
    );
    if (!confirmed) return;
    await ref.read(funnelRepositoryProvider).deleteDeal(deal);
    if (!mounted) return;
    bumpData(ref);
  }

  Future<void> _deleteStage(FunnelStage stage) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить этап?',
      message:
          'Этап «${stage.name}» и все сделки на нём будут удалены. '
          'Это действие необратимо.',
    );
    if (!confirmed) return;
    await ref.read(funnelRepositoryProvider).deleteStage(stage);
    if (!mounted) return;
    bumpData(ref);
  }

  Future<void> _deleteFunnel(Funnel funnel) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить воронку?',
      message:
          'Воронка «${funnel.name}», её этапы и сделки будут удалены.',
    );
    if (!confirmed) return;
    await ref.read(funnelRepositoryProvider).deleteFunnel(funnel);
    if (!mounted) return;
    _funnelId = null;
    bumpData(ref);
  }

  Future<void> _openFunnelForm({Funnel? funnel}) async {
    final name = TextEditingController(text: funnel?.name ?? '');
    final description = TextEditingController(text: funnel?.description ?? '');
    try {
      await showFormDialog(
        context,
        title: funnel == null ? 'Новая воронка' : 'Воронка',
        description: funnel == null
            ? 'После создания будут добавлены четыре базовых этапа.'
            : 'Переименование не затрагивает этапы и сделки.',
        submitLabel: funnel == null ? 'Создать' : 'Сохранить',
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: 'Название',
              child: TextField(controller: name),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Описание',
              child: TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Необязательно'),
              ),
            ),
          ],
        ),
        onSubmit: () async {
          final trimmed = name.text.trim();
          if (trimmed.isEmpty) {
            throw const FormatException('Укажите название воронки');
          }
          final repo = ref.read(funnelRepositoryProvider);
          final auth = ref.read(authProvider);
          final now = DateTime.now();
          if (funnel == null) {
            final created = Funnel(
              id: const Uuid().v4(),
              userId: auth.userId,
              name: trimmed,
              description: _nullIfEmpty(description.text),
              createdAt: now,
              updatedAt: now,
            );
            await repo.saveFunnel(created);
            const defaults = [
              'Новый лид',
              'Квалификация',
              'Предложение',
              'Сделка',
            ];
            for (var i = 0; i < defaults.length; i++) {
              await repo.saveStage(FunnelStage(
                id: repo.generateStageId(),
                funnelId: created.id,
                userId: created.userId,
                name: defaults[i],
                order: i,
              ));
            }
            _funnelId = created.id;
          } else {
            await repo.saveFunnel(funnel.copyWith(
              name: trimmed,
              description: _nullIfEmpty(description.text),
              updatedAt: now,
            ));
          }
          bumpData(ref);
        },
      );
    } finally {
      name.dispose();
      description.dispose();
    }
  }

  Future<void> _openStageForm(
    Funnel funnel, {
    FunnelStage? stage,
    required int order,
  }) async {
    final name = TextEditingController(text: stage?.name ?? '');
    var color = stage?.color ?? 'accent';
    try {
      await showFormDialog(
        context,
        title: stage == null ? 'Новый этап' : 'Этап',
        submitLabel: stage == null ? 'Добавить' : 'Сохранить',
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Название',
                child: TextField(controller: name),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Цвет',
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in const {
                      'accent': 'Фиолетовый',
                      'blue': 'Синий',
                      'green': 'Зелёный',
                      'yellow': 'Жёлтый',
                      'pink': 'Розовый',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: color == entry.key,
                        onSelected: (_) =>
                            setDialogState(() => color = entry.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        onSubmit: () async {
          final trimmed = name.text.trim();
          if (trimmed.isEmpty) {
            throw const FormatException('Укажите название этапа');
          }
          final repo = ref.read(funnelRepositoryProvider);
          if (stage == null) {
            await repo.saveStage(FunnelStage(
              id: repo.generateStageId(),
              funnelId: funnel.id,
              userId: funnel.userId,
              name: trimmed,
              order: order,
              color: color,
            ));
          } else {
            await repo.saveStage(stage.copyWith(name: trimmed, color: color));
          }
          bumpData(ref);
        },
      );
    } finally {
      name.dispose();
    }
  }

  Future<void> _openDealForm(
    Funnel funnel, {
    required List<FunnelStage> stages,
    FunnelDeal? deal,
    String? initialStageId,
  }) async {
    final contact = TextEditingController(text: deal?.contactName ?? '');
    final email = TextEditingController(text: deal?.contactEmail ?? '');
    final phone = TextEditingController(text: deal?.contactPhone ?? '');
    final source = TextEditingController(text: deal?.source ?? '');
    final value = TextEditingController(
      text: deal == null ? '' : deal.value.toString(),
    );
    final notes = TextEditingController(text: deal?.notes ?? '');
    final settings = ref.read(settingsProvider);
    var stageId = deal?.stageId ??
        (initialStageId ??
            (stages.isEmpty ? '' : stages.first.id));
    var currency = deal?.currency ?? settings.baseCurrency;
    DateTime? closeDate = deal?.expectedCloseDate;

    if (stages.isEmpty) {
      showAppSnack(context, 'Сначала добавьте этап', error: true);
      return;
    }

    try {
      await showFormDialog(
        context,
        title: deal == null ? 'Новая сделка' : 'Сделка',
        description:
            'Сумма и валюта сохраняются как введены. Пересчёт по курсу '
            'не выполняется, чтобы не искажать отчёт.',
        submitLabel: deal == null ? 'Добавить' : 'Сохранить',
        wide: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Контакт',
                      child: TextField(controller: contact),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Этап',
                      child: DropdownButtonFormField<String>(
                        value: stages.any((s) => s.id == stageId)
                            ? stageId
                            : stages.first.id,
                        items: [
                          for (final stage in stages)
                            DropdownMenuItem(
                              value: stage.id,
                              child: Text(stage.name),
                            ),
                        ],
                        onChanged: (value) => setDialogState(
                            () => stageId = value ?? stageId),
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
                      label: 'Email',
                      child: TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Телефон',
                      child: TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: LabeledField(
                      label: 'Сумма',
                      child: TextField(
                        controller: value,
                        keyboardType: numberKeyboard,
                        inputFormatters: decimalFormatters,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Валюта',
                      child: DropdownButtonFormField<String>(
                        value: currency,
                        items: [
                          for (final code in const [
                            'RUB',
                            'USD',
                            'EUR',
                            'KZT',
                            'BYN',
                            'UAH',
                          ])
                            DropdownMenuItem(
                              value: code,
                              child: Text(code),
                            ),
                        ],
                        onChanged: (value) => setDialogState(
                            () => currency = value ?? currency),
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
                      label: 'Источник',
                      child: TextField(
                        controller: source,
                        decoration:
                            const InputDecoration(hintText: 'Например, Instagram'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Ожидаемое закрытие',
                      child: InkWell(
                        onTap: () async {
                          final picked = await pickDate(
                            context,
                            initial: closeDate ?? DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => closeDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            suffixIcon:
                                Icon(Icons.date_range_outlined, size: 17),
                          ),
                          child: Text(
                            closeDate == null
                                ? 'Не задано'
                                : closeDate!.formatShort(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Заметки',
                child: TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Необязательно'),
                ),
              ),
            ],
          ),
        ),
        onSubmit: () async {
          final trimmed = contact.text.trim();
          if (trimmed.isEmpty) {
            throw const FormatException('Укажите контакт сделки');
          }
          final valueNumber =
              double.tryParse(value.text.trim().replaceAll(',', '.')) ?? 0;
          if (valueNumber < 0) {
            throw const FormatException('Сумма не может быть отрицательной');
          }
          final repo = ref.read(funnelRepositoryProvider);
          final auth = ref.read(authProvider);
          final now = DateTime.now();
          final entity = deal == null
              ? FunnelDeal(
                  id: const Uuid().v4(),
                  userId: auth.userId,
                  funnelId: funnel.id,
                  stageId: stageId,
                  contactName: trimmed,
                  contactEmail: _nullIfEmpty(email.text),
                  contactPhone: _nullIfEmpty(phone.text),
                  source: _nullIfEmpty(source.text),
                  notes: _nullIfEmpty(notes.text),
                  value: valueNumber,
                  currency: currency,
                  expectedCloseDate: closeDate,
                  createdAt: now,
                  updatedAt: now,
                )
              : deal.copyWith(
                  stageId: stageId,
                  contactName: trimmed,
                  contactEmail: _nullIfEmpty(email.text),
                  contactPhone: _nullIfEmpty(phone.text),
                  source: _nullIfEmpty(source.text),
                  notes: _nullIfEmpty(notes.text),
                  value: valueNumber,
                  currency: currency,
                  expectedCloseDate: closeDate,
                  updatedAt: now,
                );
          await repo.saveDeal(entity);
          bumpData(ref);
        },
      );
    } finally {
      for (final controller in [contact, email, phone, source, value, notes]) {
        controller.dispose();
      }
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({
    required this.stage,
    required this.deals,
    required this.metrics,
    required this.currency,
    required this.onDropDeal,
    required this.onAddDeal,
    required this.onEditStage,
    required this.onDeleteStage,
    required this.onOpenDeal,
    required this.onDeleteDeal,
    required this.onMoveDeal,
  });

  final FunnelStage stage;
  final List<FunnelDeal> deals;
  final FunnelStageMetrics? metrics;
  final String currency;
  final ValueChanged<String> onDropDeal;
  final VoidCallback onAddDeal;
  final VoidCallback onEditStage;
  final VoidCallback onDeleteStage;
  final ValueChanged<FunnelDeal> onOpenDeal;
  final ValueChanged<FunnelDeal> onDeleteDeal;
  final void Function(FunnelDeal deal, FunnelStage target) onMoveDeal;

  Color _color(AppColors colors) => switch (stage.color) {
        'blue' => colors.blue,
        'green' => colors.green,
        'yellow' => colors.yellow,
        'pink' => colors.pink,
        _ => colors.accent,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = _color(colors);
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDropDeal(details.data),
      builder: (context, candidate, rejected) {
        return Container(
          width: 286,
          decoration: BoxDecoration(
            color: candidate.isNotEmpty
                ? tint.withValues(alpha: 0.08)
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
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: tint, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        stage.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Pill(label: '${deals.length}', color: tint),
                    PopupMenuButton<String>(
                      tooltip: 'Этап',
                      icon: Icon(Icons.more_vert_rounded,
                          size: 16, color: colors.muted),
                      onSelected: (value) {
                        if (value == 'edit') onEditStage();
                        if (value == 'delete') onDeleteStage();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Редактировать этап'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Удалить этап'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  metrics == null
                      ? '—'
                      : '${metrics!.value.formatMoney(currency: currency)} · '
                          'конверсия ${metrics!.conversionFromPrevious.formatPercent()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.muted, fontSize: 10),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: deals.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Перетащите сделку сюда или добавьте новую.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        itemCount: deals.length,
                        itemBuilder: (context, index) {
                          final deal = deals[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: LongPressDraggable<String>(
                              data: deal.id,
                              feedback: Material(
                                color: Colors.transparent,
                                child: SizedBox(
                                  width: 268,
                                  child: _DealCard(
                                    deal: deal,
                                    currency: currency,
                                    onTap: null,
                                    onEdit: null,
                                    onDelete: null,
                                    dragHandle: true,
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.35,
                                child: _DealCard(
                                  deal: deal,
                                  currency: currency,
                                  onTap: null,
                                  onEdit: null,
                                  onDelete: null,
                                ),
                              ),
                              child: _DealCard(
                                deal: deal,
                                currency: currency,
                                onTap: () => onOpenDeal(deal),
                                onEdit: () => onOpenDeal(deal),
                                onDelete: () => onDeleteDeal(deal),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  onPressed: onAddDeal,
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Добавить'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({
    required this.deal,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.dragHandle = false,
  });

  final FunnelDeal deal;
  final String currency;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool dragHandle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  deal.contactName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (dragHandle)
                Icon(Icons.drag_indicator_rounded,
                    size: 15, color: colors.muted)
              else
                PopupMenuButton<String>(
                  tooltip: 'Сделка',
                  icon: Icon(Icons.more_vert_rounded,
                      size: 15, color: colors.muted),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Редактировать'),
                    ),
                    PopupMenuItem(value: 'delete', child: Text('Удалить')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            deal.value.formatMoney(currency: deal.currency),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: colors.green,
            ),
          ),
          if (deal.source != null) ... [
            const SizedBox(height: 3),
            Text(
              deal.source!,
              style: TextStyle(color: colors.muted, fontSize: 9.5),
            ),
          ],
          if (deal.expectedCloseDate != null) ... [
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 11, color: colors.muted),
                const SizedBox(width: 4),
                Text(
                  deal.expectedCloseDate!.formatShort(),
                  style: TextStyle(color: colors.muted, fontSize: 9.5),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddStageColumn extends StatelessWidget {
  const _AddStageColumn({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: colors.line),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: colors.muted, size: 20),
              const SizedBox(height: 6),
              Text(
                'Этап',
                style: TextStyle(color: colors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
