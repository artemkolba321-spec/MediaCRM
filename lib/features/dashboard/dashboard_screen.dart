import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:media_crm/core/analytics/analytics_calculator.dart';
import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/charts.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/repositories/analytics_repository.dart';
import 'package:media_crm/data/models/sync_run.dart';
import 'package:media_crm/data/models/notification_item.dart';
import 'package:media_crm/providers/app_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _syncing = false;

  Future<void> _syncAll() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final result = await ref.read(channelRepositoryProvider).syncAll();
      if (mounted) {
        bumpData(ref);
        showAppSnack(
          context,
          result.message,
          error: !result.success && !result.manualOnly,
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _pickCustomRange() async {
    final filter = ref.read(dashboardFilterProvider);
    final initial = filter.isCustom
        ? DateTimeRange(start: filter.customStart!, end: filter.customEnd!)
        : DateTimeRange(
            start: filter.range.start,
            end: filter.range.end,
          );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initial,
      locale: const Locale('ru'),
    );
    if (picked == null) return;
    ref.read(dashboardFilterProvider.notifier).state = filter.copyWith(
      customStart: picked.start,
      customEnd: picked.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(dashboardFilterProvider);
    ref.watch(dataVersionProvider);
    final settings = ref.watch(settingsProvider);
    final analytics = ref.watch(analyticsRepositoryProvider);
    final channels = ref.watch(channelRepositoryProvider).getChannels();
    final data = analytics.dashboard(
      range: filter.range,
      platform: filter.platform,
    );
    final currency = settings.baseCurrency;
    final colors = context.colors;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Дашборд',
            subtitle:
                'Сводка по медиасети за период «${filter.range.label}». '
                'Данные рассчитываются из сохранённых снимков метрик и финансовых операций.',
            actions: [
              OutlinedButton.icon(
                onPressed: _syncing ? null : _syncAll,
                icon: _syncing
                    ? const Spinner(size: 14)
                    : const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Синхронизировать'),
              ),
              FilledButton.icon(
                onPressed: () => ref.read(shellIndexProvider.notifier).state = 2,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить площадку'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilterBarShell(
            children: [
              PeriodSelector(
                days: filter.days,
                customLabel: filter.isCustom ? filter.range.label : null,
                onChanged: (days) => ref
                    .read(dashboardFilterProvider.notifier)
                    .state = filter.copyWith(days: days, clearCustom: true),
                onCustom: _pickCustomRange,
              ),
              SizedBox(height: 20, child: VerticalDivider(color: colors.line)),
              PlatformDropdown(
                value: filter.platform,
                onChanged: (platform) => ref
                    .read(dashboardFilterProvider.notifier)
                    .state = filter.copyWith(
                  platform: platform,
                  clearPlatform: platform == null,
                ),
              ),
              if (filter.isCustom)
                TextButton.icon(
                  onPressed: () => ref
                      .read(dashboardFilterProvider.notifier)
                      .state = filter.copyWith(clearCustom: true),
                  icon: const Icon(Icons.close_rounded, size: 13),
                  label: const Text('Сбросить период'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (channels.isEmpty) ...[
            _EmptyOnboarding(
              onAdd: () =>
                  ref.read(shellIndexProvider.notifier).state = 2,
              onRestore: () =>
                  ref.read(shellIndexProvider.notifier).state = 11,
            ),
          ] else ...[
            if (!data.hasAnalytics)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InfoNotice(
                  message:
                      'За выбранный период нет сохранённых снимков метрик. '
                      'Показатели аудитории ниже взяты из карточек площадок, '
                      'остальные графики пусты. Подключите API или добавьте '
                      'ручной снимок в разделе «Мои каналы».',
                  color: colors.yellow,
                  icon: Icons.query_stats_rounded,
                  action: TextButton(
                    onPressed: () =>
                        ref.read(shellIndexProvider.notifier).state = 2,
                    child: const Text('К каналам'),
                  ),
                ),
              ),
            _StatsGrid(
              children: [
                StatTile(
                  label: 'Общая аудитория',
                  value: data.audience.formatCompact(),
                  icon: Icons.people_alt_outlined,
                  color: colors.accent,
                  delta: data.audienceChangePercent,
                  deltaLabel: 'за период',
                  footnote:
                      '${data.channelsWithData} из ${channels.length} площадок '
                      'с историей метрик',
                ),
                StatTile(
                  label: 'Прирост аудитории',
                  value:
                      '${data.audienceChange >= 0 ? '+' : ''}${data.audienceChange.formatCompact()}',
                  icon: Icons.trending_up_rounded,
                  color: data.audienceChange >= 0 ? colors.green : colors.red,
                  footnote: 'Чистое изменение за «${filter.range.label}»',
                ),
                StatTile(
                  label: 'Просмотры',
                  value: data.views.formatCompact(),
                  icon: Icons.visibility_outlined,
                  color: colors.blue,
                  footnote: data.views == 0
                      ? 'Нет данных API за период'
                      : 'Сумма по снимкам платформ',
                ),
                StatTile(
                  label: 'Выручка',
                  value: data.finance.income.formatCompact(),
                  icon: Icons.payments_outlined,
                  color: colors.green,
                  delta: percentChange(
                    data.finance.income,
                    data.previousFinance.income,
                  ),
                  deltaLabel: 'к предыдущему периоду',
                  footnote: 'Реальные проведённые операции, $currency',
                ),
                StatTile(
                  label: 'Чистая прибыль',
                  value: data.finance.netProfit.formatCompact(),
                  icon: Icons.account_balance_wallet_outlined,
                  color: data.finance.netProfit >= 0 ? colors.green : colors.red,
                  footnote:
                      'Доходы − расходы − возвраты. Маржа ${data.finance.margin.toStringAsFixed(1)}%',
                ),
                StatTile(
                  label: 'Публикации',
                  value: data.publications.formatCompact(),
                  icon: Icons.article_outlined,
                  color: colors.pink,
                  footnote: 'Записей за период во всех базах',
                ),
                StatTile(
                  label: 'Платные подписчики',
                  value: data.paidSubscribers.formatCompact(),
                  icon: Icons.workspace_premium_outlined,
                  color: colors.yellow,
                  footnote: data.paidSubscribers == 0
                      ? 'Нет снимков paid_subscribers'
                      : 'Последнее известное значение',
                ),
                StatTile(
                  label: 'Активные кампании',
                  value: '${data.activeCampaigns}',
                  icon: Icons.campaign_outlined,
                  color: colors.accent,
                  footnote: data.campaignDebt > 0
                      ? 'Задолженность ${data.campaignDebt.formatCompact()} $currency'
                      : 'Задолженности по кампаниям нет',
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final audienceCard = SectionCard(
                  title: 'Динамика аудитории',
                  subtitle: 'История сохранённых снимков; пропуски заполняются '
                      'последним известным значением',
                  trailing: PlatformChip(
                    platform: filter.platform ?? PlatformType.youtube,
                    compact: true,
                  ),
                  child: TimeSeriesChart(
                    series: [
                      ChartSeries(
                        label: 'Аудитория',
                        color: colors.accent,
                        points: data.audienceSeries,
                        filled: true,
                      ),
                    ],
                    height: wide ? 260 : 220,
                  ),
                );
                final donutCard = SectionCard(
                  title: 'Структура аудитории',
                  subtitle: 'Доля площадок в общей аудитории',
                  child: DonutChartView(
                    segments: [
                      for (final row in data.platformRows)
                        if (row.audience > 0)
                          DonutSegment(
                            label: row.platform.label,
                            value: row.audience,
                            color: platformColor(row.platform),
                          ),
                    ],
                    centerValue: data.audience.formatCompact(),
                    centerLabel: 'аудитория',
                    legendOnRight: wide,
                    size: wide ? 150 : 168,
                  ),
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: audienceCard),
                      const SizedBox(width: 14),
                      Expanded(flex: 4, child: donutCard),
                    ],
                  );
                }
                return Column(
                  children: [
                    audienceCard,
                    const SizedBox(height: 14),
                    donutCard,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final revenue = SectionCard(
                  title: 'Доходы и расходы',
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
                        points: data.revenueSeries,
                        filled: true,
                      ),
                      ChartSeries(
                        label: 'Расход',
                        color: colors.pink,
                        points: data.expenseSeries,
                      ),
                    ],
                    showLegend: false,
                    height: 235,
                    valueFormatter: (value) =>
                        '${value.formatCompact()} $currency',
                  ),
                );
                final views = SectionCard(
                  title: 'Просмотры по дням',
                  subtitle: 'Только данные, полученные из API или вручную',
                  child: TimeSeriesChart(
                    series: [
                      ChartSeries(
                        label: 'Просмотры',
                        color: colors.blue,
                        points: data.viewsSeries,
                        filled: true,
                      ),
                    ],
                    height: 235,
                  ),
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: revenue),
                      const SizedBox(width: 14),
                      Expanded(child: views),
                    ],
                  );
                }
                return Column(
                  children: [revenue, const SizedBox(height: 14), views],
                );
              },
            ),
            const SizedBox(height: 14),
            _PlatformsTable(rows: data.platformRows, currency: currency),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final business = _BusinessSummary(
                  data: data,
                  currency: currency,
                );
                final recent = _RecentActivity(
                  events: data.recentEvents,
                  syncs: data.recentSyncs,
                  onAll: () =>
                      ref.read(shellIndexProvider.notifier).state = 10,
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: business),
                      const SizedBox(width: 14),
                      Expanded(child: recent),
                    ],
                  );
                }
                return Column(
                  children: [business, const SizedBox(height: 14), recent],
                );
              },
            ),
            const SizedBox(height: 16),
            const DataSourceNote(
              text:
                  'Аудитория и охваты рассчитываются только из сохранённых '
                  'снимков. Если площадка не предоставляет метрику через API, '
                  'она не подставляется и не оценивается. Демонстрационные '
                  'данные автоматически не загружаются.',
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1300
            ? 4
            : constraints.maxWidth >= 920
                ? 3
                : constraints.maxWidth >= 600
                    ? 2
                    : 1;
        const gap = 12.0;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _EmptyOnboarding extends StatelessWidget {
  const _EmptyOnboarding({required this.onAdd, required this.onRestore});

  final VoidCallback onAdd;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.accent, colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'Начните с первой площадки',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              'Добавьте YouTube, Telegram, Boosty, ВКонтакте или GitHub. '
              'Для каждой площадки можно подключить официальный API, ввести '
              'метрики вручную или импортировать резервную копию. Дашборд '
              'начнёт рассчитываться сразу после появления сохранённых данных.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.muted,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить площадку'),
              ),
              OutlinedButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Импорт данных'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final platform in PlatformType.values)
                PlatformChip(platform: platform),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlatformsTable extends ConsumerWidget {
  const _PlatformsTable({required this.rows, required this.currency});

  final List<PlatformTotals> rows;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    if (rows.isEmpty) {
      return SectionCard(
        title: 'Площадки',
        child: EmptyState(
          title: 'Нет площадок для отображения',
          message:
              'Добавьте канал и укажите метрики или подключите API, чтобы '
              'увидеть сравнение площадок.',
          icon: Icons.hub_outlined,
          compact: true,
          action: TextButton(
            onPressed: () => ref.read(shellIndexProvider.notifier).state = 2,
            child: const Text('Перейти к каналам'),
          ),
        ),
      );
    }
    return SectionCard(
      title: 'Сравнение площадок',
      subtitle: 'За выбранный период; пустые значения означают отсутствие данных',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.panelAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _TableHead('Площадка')),
                Expanded(flex: 2, child: _TableHead('Аудитория')),
                Expanded(flex: 2, child: _TableHead('Прирост')),
                Expanded(flex: 2, child: _TableHead('Просмотры')),
                Expanded(flex: 3, child: _TableHead('Выручка')),
                Expanded(flex: 2, child: _TableHead('Публикации')),
              ],
            ),
          ),
          for (final row in rows)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        PlatformChip(platform: row.platform, compact: true),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            row.platform.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _TableCell(
                      row.audience == 0 ? '—' : row.audience.formatCompact(),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        if (row.audienceGrowth != 0) ...[
                          Icon(
                            row.audienceGrowth > 0
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 11,
                            color: row.audienceGrowth > 0
                                ? colors.green
                                : colors.red,
                          ),
                          const SizedBox(width: 2),
                        ],
                        _TableCell(
                          row.audienceGrowth == 0
                              ? '—'
                              : row.audienceGrowth.abs().formatCompact(),
                          color: row.audienceGrowth > 0
                              ? colors.green
                              : row.audienceGrowth < 0
                                  ? colors.red
                                  : null,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _TableCell(
                      row.views == 0 ? '—' : row.views.formatCompact(),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _TableCell(
                      row.revenue == 0
                          ? '—'
                          : row.revenue.formatMoney(currency: currency),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _TableCell(
                      row.publications == 0 ? '—' : '${row.publications}',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: context.muted,
        ),
      );
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color ?? context.textColor,
        ),
      );
}

class _BusinessSummary extends StatelessWidget {
  const _BusinessSummary({required this.data, required this.currency});

  final DashboardData data;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SectionCard(
      title: 'Бизнес-показатели',
      subtitle: 'Реклама, партнёры и финансы за выбранный период',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniSummaryCard(
                  icon: Icons.campaign_outlined,
                  color: colors.accent,
                  label: 'Доход рекламодателей',
                  value: data.advertiserRevenue.formatMoney(currency: currency),
                  note: '${data.activeCampaigns} активных кампаний',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniSummaryCard(
                  icon: Icons.handshake_outlined,
                  color: colors.blue,
                  label: 'Партнёрские продажи',
                  value: '${data.partnerSales}',
                  note:
                      '${data.partnerClicks} переходов · ${data.partnerRegistrations} регистраций',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniSummaryCard(
                  icon: Icons.receipt_long_outlined,
                  color: colors.pink,
                  label: 'Расходы',
                  value: data.finance.expenses.formatMoney(currency: currency),
                  note: data.finance.refunds > 0
                      ? 'Возвраты: ${data.finance.refunds.formatMoney(currency: currency)}'
                      : 'Возвратов нет',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniSummaryCard(
                  icon: Icons.savings_outlined,
                  color: colors.green,
                  label: 'Комиссии партнёров',
                  value: data.partnerCommission.formatMoney(currency: currency),
                  note: data.finance.pendingIncome > 0
                      ? 'Ожидается: ${data.finance.pendingIncome.formatMoney(currency: currency)}'
                      : 'Ожидаемых поступлений нет',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.panelAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                KeyValueRow(
                  label: 'Задачи в работе',
                  value: '${data.openTasks}',
                  icon: Icons.task_alt_rounded,
                ),
                KeyValueRow(
                  label: 'Просроченные задачи',
                  value: '${data.overdueTasks}',
                  icon: Icons.warning_amber_rounded,
                  valueColor: data.overdueTasks > 0 ? colors.red : null,
                ),
                KeyValueRow(
                  label: 'Непрочитанные уведомления',
                  value: '${data.unreadNotifications}',
                  icon: Icons.notifications_none_rounded,
                ),
                KeyValueRow(
                  label: 'Ошибки последних синхронизаций',
                  value: '${data.syncErrors}',
                  icon: Icons.sync_problem_rounded,
                  valueColor: data.syncErrors > 0 ? colors.yellow : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  const _MiniSummaryCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.note,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.panelAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconSquare(icon: icon, color: color, size: 27),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.events,
    required this.syncs,
    required this.onAll,
  });

  final List<ActivityLogEntry> events;
  final List<SyncRun> syncs;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SectionCard(
      title: 'Последние события',
      subtitle: 'Журнал действий и синхронизаций',
      trailing: TextButton(onPressed: onAll, child: const Text('Все')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (events.isEmpty && syncs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'События появятся после первых действий в системе.',
                style: TextStyle(color: colors.muted, fontSize: 12),
              ),
            ),
          for (final event in events.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconSquare(
                    icon: _eventIcon(event.action),
                    color: colors.accent,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          event.createdAt.formatRelative(),
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (syncs.isNotEmpty) ...[
            Divider(color: colors.line, height: 20),
            Text(
              'Синхронизации',
              style: TextStyle(
                color: colors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            for (final run in syncs.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Icon(
                      run.status == SyncRunStatus.success
                          ? Icons.check_circle_outline_rounded
                          : run.status == SyncRunStatus.error
                              ? Icons.error_outline_rounded
                              : Icons.sync_rounded,
                      size: 13,
                      color: run.status == SyncRunStatus.success
                          ? colors.green
                          : run.status == SyncRunStatus.error
                              ? colors.red
                              : colors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        run.message ??
                            (run.status == SyncRunStatus.success
                                ? 'Успешно'
                                : 'Синхронизация'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    Text(
                      run.startedAt.formatRelative(),
                      style: TextStyle(color: colors.muted, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  IconData _eventIcon(String? action) => switch (action) {
        'created' => Icons.add_circle_outline_rounded,
        'updated' => Icons.edit_outlined,
        'deleted' => Icons.delete_outline_rounded,
        'imported' => Icons.file_download_outlined,
        'synced' => Icons.sync_rounded,
        _ => Icons.bolt_rounded,
      };
}
