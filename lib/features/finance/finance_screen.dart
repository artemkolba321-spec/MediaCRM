import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:media_crm/core/analytics/analytics_calculator.dart';
import 'package:media_crm/core/analytics/finance_calculator.dart';
import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/export_utils.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/charts.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/financial_operation.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/repositories/finance_repository.dart';
import 'package:media_crm/providers/app_providers.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final filter = ref.watch(financeFilterProvider);
    final settings = ref.watch(settingsProvider);
    final repo = ref.watch(financeRepositoryProvider);
    final channels = ref.watch(channelRepositoryProvider).getChannels();
    final allOps = repo.getOperations();
    final ops = repo.getOperations(FinanceFilter(
      start: filter.start,
      end: filter.end,
      types: filter.types.isEmpty ? null : filter.types,
      categories: filter.categories.isEmpty ? null : filter.categories,
      search: _search.text,
    ));
    final platformOps = filter.platform == null
        ? ops
        : _byPlatform(ops, filter.platform!, channels);
    final summary = calculateFinanceSummary(platformOps, channels: channels);
    final colors = context.colors;
    final currency = settings.baseCurrency;
    final rangeLabel = _rangeLabel(filter);

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Финансы',
            subtitle:
                'P&L по проведённым операциям. Выводы и переводы учитываются '
                'отдельно как движение средств; приложение не выполняет '
                'банковских платежей.',
            actions: [
              OutlinedButton.icon(
                onPressed: _openRates,
                icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                label: const Text('Курсы валют'),
              ),
              OutlinedButton.icon(
                onPressed: allOps.isEmpty ? null : () => _exportCsv(ops),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Экспорт CSV'),
              ),
              FilledButton.icon(
                onPressed: () => _openOperationForm(channels: channels),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить операцию'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilterBarShell(
            children: [
              _PresetButton(
                label: '30 дн.',
                selected: _isLastDays(filter, 30),
                onTap: () => _setLastDays(30),
              ),
              _PresetButton(
                label: '90 дн.',
                selected: _isLastDays(filter, 90),
                onTap: () => _setLastDays(90),
              ),
              _PresetButton(
                label: 'Год',
                selected: _isLastDays(filter, 365),
                onTap: () => _setLastDays(365),
              ),
              _PresetButton(
                label: 'Всё время',
                selected: filter.start == null && filter.end == null,
                onTap: () => ref
                    .read(financeFilterProvider.notifier)
                    .state = filter.copyWith(clearDates: true),
              ),
              _PresetButton(
                label: filter.start == null ? 'Период…' : rangeLabel,
                selected: filter.start != null,
                icon: Icons.date_range_outlined,
                onTap: () => _pickRange(filter),
              ),
              SizedBox(
                width: 220,
                child: SearchField(
                  controller: _search,
                  hint: 'Описание или контрагент…',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              PlatformDropdown(
                value: filter.platform,
                onChanged: (value) => ref
                    .read(financeFilterProvider.notifier)
                    .state = filter.copyWith(
                  platform: value,
                  clearPlatform: value == null,
                ),
              ),
              if (filter.hasFilters)
                TextButton.icon(
                  onPressed: () {
                    _search.clear();
                    ref.read(financeFilterProvider.notifier).state =
                        const FinanceFilterState();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded, size: 13),
                  label: const Text('Сбросить'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1240
                  ? 4
                  : constraints.maxWidth >= 760
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
                      label: 'Выручка',
                      value: summary.income.formatMoney(currency: currency),
                      icon: Icons.payments_outlined,
                      color: colors.green,
                      footnote: '${summary.count} операций в выборке',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Расходы',
                      value: summary.expenses.formatMoney(currency: currency),
                      icon: Icons.receipt_long_outlined,
                      color: colors.pink,
                      footnote: summary.refunds > 0
                          ? 'Возвраты: ${summary.refunds.formatMoney(currency: currency)}'
                          : 'Возвратов нет',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Чистая прибыль',
                      value: summary.netProfit.formatMoney(currency: currency),
                      icon: Icons.savings_outlined,
                      color: summary.netProfit >= 0
                          ? colors.green
                          : colors.red,
                      footnote:
                          'Маржа ${summary.margin.toStringAsFixed(1)}%',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Cash balance',
                      value:
                          summary.cashBalance.formatMoney(currency: currency),
                      icon: Icons.account_balance_wallet_outlined,
                      color: colors.accent,
                      footnote:
                          'За вычетом выводов ${summary.withdrawn.formatMoney(currency: currency)}',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final chart = SectionCard(
                title: 'Динамика денежного потока',
                subtitle: 'Проведённые операции в $currency',
                trailing: ChartLegend(
                  items: [
                    (label: 'Доход', color: colors.green),
                    (label: 'Расход', color: colors.pink),
                  ],
                ),
                child: TimeSeriesChart(
                  series: [
                    ChartSeries(
                      label: 'Доход',
                      color: colors.green,
                      points: _series(ops, TransactionType.income, filter),
                      filled: true,
                    ),
                    ChartSeries(
                      label: 'Расход',
                      color: colors.pink,
                      points: _series(ops, TransactionType.expense, filter),
                    ),
                  ],
                  showLegend: false,
                  height: 250,
                  valueFormatter: (value) =>
                      value.formatMoney(currency: currency),
                ),
              );
              final categories = SectionCard(
                title: 'Категории',
                subtitle: 'Прибыль и убытки по категориям',
                child: HBarChart(
                  items: [
                    for (final entry in summary.byCategory.entries)
                      if (entry.value != 0)
                        (
                          label: entry.key.label,
                          value: entry.value,
                          color: entry.value >= 0 ? colors.green : colors.pink,
                        ),
                  ],
                  valueFormatter: (value) =>
                      value.formatMoney(currency: currency),
                ),
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: chart),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: categories),
                  ],
                );
              }
              return Column(
                children: [chart, const SizedBox(height: 14), categories],
              );
            },
          ),
          const SizedBox(height: 14),
          _Breakdown(summary: summary, currency: currency),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Операции',
            subtitle: '${ops.length} записей; ожидаемые и отменённые не входят '
                'в прибыль',
            trailing: allOps.isEmpty
                ? null
                : TextButton(
                    onPressed: () => _openOperationForm(
                      channels: channels,
                    ),
                    child: const Text('Добавить'),
                  ),
            child: ops.isEmpty
                ? EmptyState(
                    title: allOps.isEmpty
                        ? 'Финансовых операций пока нет'
                        : 'Ничего не найдено',
                    message: allOps.isEmpty
                        ? 'Добавьте первый доход или расход. Операции хранятся '
                            'локально и синхронизируются при наличии аккаунта.'
                        : 'Измените фильтры или поисковый запрос.',
                    icon: Icons.receipt_long_outlined,
                    compact: true,
                    action: allOps.isEmpty
                        ? FilledButton.icon(
                            onPressed: () =>
                                _openOperationForm(channels: channels),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Добавить операцию'),
                          )
                        : null,
                  )
                : Column(
                    children: [
                      for (final op in ops)
                        _OperationTile(
                          operation: op,
                          channels: channels,
                          onEdit: () =>
                              _openOperationForm(channels: channels, operation: op),
                          onDelete: () => _deleteOperation(op),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          const DataSourceNote(
            text:
                'Суммы в разных валютах приводятся к базовой валюте по курсу, '
                'указанному в операции. По умолчанию курсы равны 1, пока вы их '
                'не зададите; вымышленные курсы не подставляются. Выплаты '
                'партнёрам и рекламные оплаты создают учётные операции.',
          ),
        ],
      ),
    );
  }

  List<FinancialOperation> _byPlatform(
    List<FinancialOperation> ops,
    PlatformType platform,
    List<PlatformChannel> channels,
  ) {
    final ids = channels
        .where((c) => c.platform == platform)
        .map((c) => c.id)
        .toSet();
    return ops
        .where((op) => op.channelId != null && ids.contains(op.channelId))
        .toList();
  }

  bool _isLastDays(FinanceFilterState filter, int days) {
    if (filter.start == null || filter.end == null) return false;
    final expectedStart = DateTime.now().dateOnly.subtract(Duration(days: days - 1));
    return filter.start!.dateOnly == expectedStart &&
        filter.end!.dateOnly == DateTime.now().dateOnly;
  }

  void _setLastDays(int days) {
    final now = DateTime.now();
    final filter = ref.read(financeFilterProvider);
    ref.read(financeFilterProvider.notifier).state = filter.copyWith(
      start: now.subtract(Duration(days: days - 1)),
      end: now,
    );
  }

  Future<void> _pickRange(FinanceFilterState filter) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: filter.start != null && filter.end != null
          ? DateTimeRange(start: filter.start!, end: filter.end!)
          : null,
      locale: const Locale('ru'),
    );
    if (picked == null) return;
    ref.read(financeFilterProvider.notifier).state = filter.copyWith(
      start: picked.start,
      end: picked.end,
    );
  }

  String _rangeLabel(FinanceFilterState filter) {
    if (filter.start == null || filter.end == null) return 'Всё время';
    return '${filter.start!.formatShort()} — ${filter.end!.formatShort()}';
  }

  List<MetricPoint> _series(
    List<FinancialOperation> ops,
    TransactionType type,
    FinanceFilterState filter,
  ) {
    final start = filter.start ?? DateTime(2000);
    final end = filter.end ?? DateTime.now();
    final byDay = <String, double>{};
    for (final op in ops) {
      if (op.type != type || !op.isCompleted) continue;
      final key = op.date.toIso8601String().substring(0, 10);
      byDay.update(key, (value) => value + op.baseAmount,
          ifAbsent: () => op.baseAmount);
    }
    final points = <MetricPoint>[];
    if (end.difference(start).inDays > 730) {
      // Avoid building thousands of points for "all time"; aggregate by month.
      final byMonth = <String, double>{};
      for (final entry in byDay.entries) {
        final month = entry.key.substring(0, 7);
        byMonth.update(month, (value) => value + entry.value,
            ifAbsent: () => entry.value);
      }
      final keys = byMonth.keys.toList()..sort();
      for (final key in keys) {
        points.add(MetricPoint(DateTime.parse('$key-01'), byMonth[key]!));
      }
      return points;
    }
    for (var day = start.dateOnly;
        !day.isAfter(end.dateOnly);
        day = day.add(const Duration(days: 1))) {
      final key = day.toIso8601String().substring(0, 10);
      points.add(MetricPoint(day, byDay[key] ?? 0));
    }
    return points;
  }

  Future<void> _exportCsv(List<FinancialOperation> ops) async {
    final rows = <List<Object?>>[
      [
        'date',
        'type',
        'status',
        'category',
        'amount',
        'currency',
        'exchange_rate',
        'base_amount',
        'base_currency',
        'counterparty',
        'description',
      ],
      for (final op in ops)
        [
          op.date.toIso8601String().substring(0, 10),
          op.type.name,
          op.status.name,
          op.category.name,
          op.amount,
          op.currency,
          op.exchangeRate,
          op.baseAmount,
          op.baseCurrency,
          op.counterparty ?? '',
          op.description ?? '',
        ],
    ];
    final result = await exportTextFile(
      fileName: 'mediacrm-finance.csv',
      content: buildCsv(rows),
    );
    if (!mounted) return;
    showAppSnack(context, result.message, error: !result.ok);
  }

  Future<void> _openOperationForm({
    required List<PlatformChannel> channels,
    FinancialOperation? operation,
  }) async {
    final settings = ref.read(settingsProvider);
    final repo = ref.read(financeRepositoryProvider);
    final amount = TextEditingController(
      text: operation == null ? '' : operation.amount.toString(),
    );
    final rate = TextEditingController(
      text: operation == null
          ? '1'
          : operation.exchangeRate.toString(),
    );
    final description =
        TextEditingController(text: operation?.description ?? '');
    final counterparty =
        TextEditingController(text: operation?.counterparty ?? '');
    var type = operation?.type ?? TransactionType.income;
    var status = operation?.status ?? TransactionStatus.completed;
    var category = operation?.category ?? TransactionCategory.adRevenue;
    var currency = operation?.currency ?? settings.baseCurrency;
    var channelId = operation?.channelId;
    var date = operation?.date ?? DateTime.now();

    try {
      await showFormDialog(
        context,
        title: operation == null ? 'Новая операция' : 'Операция',
        description:
            'Приложение только учитывает деньги. Переводы и выплаты — '
            'учётные записи, реальные платежи не выполняются.',
        submitLabel: operation == null ? 'Добавить' : 'Сохранить',
        wide: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final amountValue =
                double.tryParse(amount.text.trim().replaceAll(',', '.')) ?? 0;
            final rateValue =
                double.tryParse(rate.text.trim().replaceAll(',', '.')) ?? 1;
            final base = amountValue * rateValue;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'Тип',
                        child: DropdownButtonFormField<TransactionType>(
                          value: type,
                          items: [
                            for (final item in TransactionType.values)
                              DropdownMenuItem(
                                value: item,
                                child: Text(item.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              type = value;
                              if (value == TransactionType.expense &&
                                  !category.isIncome) {
                                category = TransactionCategory.other;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LabeledField(
                        label: 'Статус',
                        child: DropdownButtonFormField<TransactionStatus>(
                          value: status,
                          items: [
                            for (final item in TransactionStatus.values)
                              DropdownMenuItem(
                                value: item,
                                child: Text(item.label),
                              ),
                          ],
                          onChanged: (value) => setDialogState(
                              () => status = value ?? status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  type.hint,
                  style: TextStyle(
                    color: context.muted,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Категория',
                  child: DropdownButtonFormField<TransactionCategory>(
                    value: category,
                    items: [
                      for (final item in TransactionCategory.values)
                        DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => category = value ?? category),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: LabeledField(
                        label: 'Сумма',
                        child: TextField(
                          controller: amount,
                          keyboardType: numberKeyboard,
                          inputFormatters: decimalFormatters,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(hintText: '0'),
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
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              currency = value;
                              rate.text = value == settings.baseCurrency
                                  ? '1'
                                  : (repo.ratesToBase()[value] ?? 1)
                                      .toString();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LabeledField(
                        label: 'Курс к ${settings.baseCurrency}',
                        child: TextField(
                          controller: rate,
                          keyboardType: numberKeyboard,
                          inputFormatters: decimalFormatters,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(hintText: '1'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'В базовой валюте: ${base.formatMoney(currency: settings.baseCurrency)}',
                  style: TextStyle(
                    color: context.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'Дата',
                        child: InkWell(
                          onTap: () async {
                            final picked =
                                await pickDate(context, initial: date);
                            if (picked != null) {
                              setDialogState(() => date = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              suffixIcon: Icon(Icons.date_range_outlined,
                                  size: 17),
                            ),
                            child: Text(date.formatShort()),
                          ),
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
                LabeledField(
                  label: 'Контрагент',
                  child: TextField(
                    controller: counterparty,
                    decoration:
                        const InputDecoration(hintText: 'Необязательно'),
                  ),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Описание',
                  child: TextField(
                    controller: description,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(hintText: 'Необязательно'),
                  ),
                ),
              ],
            );
          },
        ),
        onSubmit: () async {
          final amountValue =
              double.tryParse(amount.text.trim().replaceAll(',', '.'));
          final rateValue =
              double.tryParse(rate.text.trim().replaceAll(',', '.'));
          if (amountValue == null || amountValue <= 0) {
            throw const FormatException('Укажите сумму больше нуля');
          }
          if (rateValue == null || rateValue <= 0) {
            throw const FormatException('Курс должен быть больше нуля');
          }
          final auth = ref.read(authProvider);
          final now = DateTime.now();
          final baseAmount = repo.baseAmountFor(
            amount: amountValue,
            currency: currency,
            baseCurrency: settings.baseCurrency,
            exchangeRate: rateValue,
          );
          final entity = operation == null
              ? FinancialOperation(
                  id: const Uuid().v4(),
                  userId: auth.userId,
                  type: type,
                  status: status,
                  amount: amountValue,
                  currency: currency,
                  exchangeRate: rateValue,
                  baseAmount: baseAmount,
                  baseCurrency: settings.baseCurrency,
                  category: category,
                  description: _nullIfEmpty(description.text),
                  counterparty: _nullIfEmpty(counterparty.text),
                  channelId: channelId,
                  date: date,
                  createdAt: now,
                  updatedAt: now,
                )
              : operation.copyWith(
                  type: type,
                  status: status,
                  amount: amountValue,
                  currency: currency,
                  exchangeRate: rateValue,
                  baseAmount: baseAmount,
                  baseCurrency: settings.baseCurrency,
                  category: category,
                  description: _nullIfEmpty(description.text),
                  counterparty: _nullIfEmpty(counterparty.text),
                  channelId: channelId,
                  date: date,
                  updatedAt: now,
                );
          await repo.saveOperation(entity);
          bumpData(ref);
        },
      );
    } finally {
      amount.dispose();
      rate.dispose();
      description.dispose();
      counterparty.dispose();
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _deleteOperation(FinancialOperation operation) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить операцию?',
      message:
          'Операция «${operation.description ?? operation.category.label}» на '
          '${operation.amount.formatMoney(currency: operation.currency)} будет '
          'удалена из P&L. Это не влияет на реальные деньги.',
    );
    if (!confirmed) return;
    await ref.read(financeRepositoryProvider).deleteOperation(operation);
    if (!mounted) return;
    bumpData(ref);
    showAppSnack(context, 'Операция удалена');
  }

  Future<void> _openRates() async {
    final settings = ref.read(settingsProvider);
    final repo = ref.read(financeRepositoryProvider);
    final rates = repo.getCurrencyRates();
    final colors = context.colors;
    final controllers = <String, TextEditingController>{
      for (final rate in rates)
        rate.code: TextEditingController(text: rate.rateToBase.toString()),
    };
    try {
      await showFormDialog(
        context,
        title: 'Курсы валют',
        description:
            'Курс показывает, сколько единиц ${settings.baseCurrency} содержится '
            'в одной единице валюты. Значения по умолчанию равны 1 — задайте '
            'реальные курсы вручную.',
        submitLabel: 'Сохранить',
        builder: (dialogContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final code in controllers.keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controllers[code],
                        keyboardType: numberKeyboard,
                        inputFormatters: decimalFormatters,
                        decoration: InputDecoration(
                          hintText: '1',
                          helperText: '1 $code = ? ${settings.baseCurrency}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            InfoNotice(
              message:
                  'Курсы хранятся локально и синхронизируются. Автоматического '
                  'получения курсов от банка нет: значения не выдумываются.',
              color: colors.blue,
            ),
          ],
        ),
        onSubmit: () async {
          for (final entry in controllers.entries) {
            final value = double.tryParse(
              entry.value.text.trim().replaceAll(',', '.'),
            );
            if (value == null || value <= 0) {
              throw FormatException('Некорректный курс для ${entry.key}');
            }
            await repo.saveCurrencyRate(entry.key, value);
          }
          bumpData(ref);
        },
      );
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color:
                selected ? colors.accent.withValues(alpha: 0.5) : colors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 12,
                  color: selected ? colors.accent : colors.muted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? colors.accent : colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({
    required this.operation,
    required this.channels,
    required this.onEdit,
    required this.onDelete,
  });

  final FinancialOperation operation;
  final List<PlatformChannel> channels;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final positive = operation.type == TransactionType.income;
    final neutral = operation.type == TransactionType.transfer ||
        operation.type == TransactionType.pending ||
        operation.type == TransactionType.withdrawal;
    final tint = positive
        ? colors.green
        : neutral
            ? colors.muted
            : colors.pink;
    final channel = channels
        .where((c) => c.id == operation.channelId)
        .firstOrNull;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          IconSquare(
            icon: switch (operation.type) {
              TransactionType.income => Icons.arrow_downward_rounded,
              TransactionType.expense => Icons.arrow_upward_rounded,
              TransactionType.refund => Icons.undo_rounded,
              TransactionType.pending => Icons.hourglass_bottom_rounded,
              TransactionType.transfer => Icons.swap_horiz_rounded,
              TransactionType.withdrawal => Icons.account_balance_outlined,
            },
            color: tint,
            size: 30,
          ),
          const SizedBox(width: 9),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  operation.description ?? operation.category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${operation.date.formatShort()} · ${operation.category.label}'
                  '${channel == null ? '' : ' · ${channel.name}'}'
                  '${operation.counterparty == null ? '' : ' · ${operation.counterparty}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pill(
            label: operation.status.label,
            color: operation.status == TransactionStatus.completed
                ? colors.green
                : operation.status == TransactionStatus.pending
                    ? colors.yellow
                    : colors.red,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${positive ? '+' : operation.type == TransactionType.expense || operation.type == TransactionType.refund ? '−' : ''}'
                  '${operation.amount.formatMoney(currency: operation.currency)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
                if (operation.currency != operation.baseCurrency)
                  Text(
                    operation.baseAmount.formatMoney(currency: operation.baseCurrency),
                    style:
                        TextStyle(color: colors.muted, fontSize: 9.5),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Действия',
            icon: Icon(Icons.more_vert_rounded, size: 17, color: colors.muted),
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
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.summary, required this.currency});

  final FinanceSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final items = <Widget>[
            _BreakdownItem(
              label: 'Ожидаемые поступления',
              value: summary.pendingIncome.formatMoney(currency: currency),
              color: colors.yellow,
              note: 'Не входят в P&L до проведения',
            ),
            _BreakdownItem(
              label: 'Выведено средств',
              value: summary.withdrawn.formatMoney(currency: currency),
              color: colors.muted,
              note: 'Движение денег, не расход',
            ),
            _BreakdownItem(
              label: 'Переводы',
              value: summary.transfers.formatMoney(currency: currency),
              color: colors.muted,
              note: 'Учётные перемещения',
            ),
            _BreakdownItem(
              label: 'Возвраты',
              value: summary.refunds.formatMoney(currency: currency),
              color: colors.pink,
              note: 'Уменьшают прибыль',
            ),
          ];
          if (wide) {
            return Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 42,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: colors.line,
                    ),
                  Expanded(child: items[i]),
                ],
              ],
            );
          }
          return Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [for (final item in items) item],
          );
        },
      ),
    );
  }
}

class _BreakdownItem extends StatelessWidget {
  const _BreakdownItem({
    required this.label,
    required this.value,
    required this.color,
    required this.note,
  });

  final String label;
  final String value;
  final Color color;
  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(note,
            style: TextStyle(color: colors.muted, fontSize: 9.5)),
      ],
    );
  }
}
