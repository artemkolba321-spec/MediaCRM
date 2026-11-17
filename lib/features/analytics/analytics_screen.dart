import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:media_crm/core/analytics/analytics_calculator.dart';
import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/charts.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/analytics_snapshot.dart';
import 'package:media_crm/data/models/financial_operation.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/publication.dart';
import 'package:media_crm/data/models/sync_run.dart';
import 'package:media_crm/data/repositories/analytics_repository.dart';
import 'package:media_crm/data/repositories/finance_repository.dart';
import 'package:media_crm/providers/app_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(analyticsFilterProvider);
    ref.watch(dataVersionProvider);
    final settings = ref.watch(settingsProvider);
    final channels = ref.watch(channelRepositoryProvider).getChannels();
    final overview = ref
        .watch(analyticsRepositoryProvider)
        .overview(range: filter.range, platform: filter.platform);
    final colors = context.colors;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Аналитика',
            subtitle:
                'Показатели рассчитываются из сохранённых снимков метрик, '
                'публикаций и финансовых операций. Пустые значения означают, '
                'что данные не собирались.',
            actions: [
              if (channels.isEmpty)
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(shellIndexProvider.notifier).state = 2,
                  icon: const Icon(Icons.add_link_rounded, size: 16),
                  label: const Text('Подключить площадку'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilterBarShell(
            children: [
              PeriodSelector(
                days: filter.days,
                allowAll: false,
                onChanged: (days) => ref
                    .read(analyticsFilterProvider.notifier)
                    .state = filter.copyWith(days: days),
              ),
              SizedBox(height: 20, child: VerticalDivider(color: colors.line)),
              PlatformDropdown(
                value: filter.platform,
                onChanged: (platform) => ref
                    .read(analyticsFilterProvider.notifier)
                    .state = filter.copyWith(
                  platform: platform,
                  clearPlatform: platform == null,
                ),
              ),
              Text(
                filter.range.label,
                style: TextStyle(color: colors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedTabs(
            tabs: const ['Обзор', 'Охват', 'Доход', 'Аудитория'],
            selected: filter.tab,
            scrollable: true,
            onChanged: (tab) => ref
                .read(analyticsFilterProvider.notifier)
                .state = filter.copyWith(tab: tab),
          ),
          const SizedBox(height: 16),
          switch (filter.tab) {
            0 => _OverviewTab(
                overview: overview,
                currency: settings.baseCurrency,
              ),
            1 => _ReachTab(
                overview: overview,
                range: filter.range,
                platform: filter.platform,
              ),
            2 => _RevenueTab(
                overview: overview,
                currency: settings.baseCurrency,
              ),
            _ => _AudienceTab(
                overview: overview,
                currency: settings.baseCurrency,
              ),
          },
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.overview, required this.currency});

  final AnalyticsOverview overview;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final data = overview.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KpiGrid(
          tiles: [
            _Kpi(
              label: 'Аудитория',
              value: data.audience.formatCompact(),
              icon: Icons.people_alt_outlined,
              color: colors.accent,
              delta: data.audienceChangePercent,
              footnote: 'На конец периода',
            ),
            _Kpi(
              label: 'Просмотры',
              value: data.views.formatCompact(),
              icon: Icons.visibility_outlined,
              color: colors.blue,
              footnote: data.views == 0 ? 'Нет снимков за период' : 'Сумма по площадкам',
            ),
            _Kpi(
              label: 'Вовлечённость',
              value: (data.likes + data.comments + data.shares).formatCompact(),
              icon: Icons.favorite_border_rounded,
              color: colors.pink,
              footnote:
                  '${data.likes.formatCompact()} лайков · ${data.comments.formatCompact()} комментариев',
            ),
            _Kpi(
              label: 'Публикации',
              value: '${data.publications}',
              icon: Icons.article_outlined,
              color: colors.yellow,
              footnote: 'Записей за период',
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final audience = SectionCard(
              title: 'Динамика аудитории',
              subtitle: 'История снимков; пропуски заполняются последним '
                  'известным значением',
              child: TimeSeriesChart(
                series: [
                  ChartSeries(
                    label: 'Аудитория',
                    color: colors.accent,
                    points: data.audienceSeries,
                    filled: true,
                  ),
                ],
                height: wide ? 270 : 220,
              ),
            );
            final views = SectionCard(
              title: 'Просмотры по дням',
              subtitle: 'Только фактические снимки метрик',
              child: TimeSeriesChart(
                series: [
                  ChartSeries(
                    label: 'Просмотры',
                    color: colors.blue,
                    points: data.viewsSeries,
                    filled: true,
                  ),
                ],
                height: wide ? 270 : 220,
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: audience),
                  const SizedBox(width: 14),
                  Expanded(child: views),
                ],
              );
            }
            return Column(
              children: [audience, const SizedBox(height: 14), views],
            );
          },
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Площадки',
          subtitle: 'Сравнение за выбранный период',
          child: _PlatformTable(rows: data.platformRows, currency: currency),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Лучшие публикации',
          subtitle: 'Рейтинг по последнему сохранённому снимку просмотров',
          child: _RankedPublications(rows: overview.topPublications),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(
          text:
              'Демографические данные и охваты площадки предоставляют не '
              'всегда. Если метрика не пришла из API и не введена вручную, '
              'она остаётся пустой — система не подставляет оценки.',
        ),
      ],
    );
  }
}

class _ReachTab extends ConsumerWidget {
  const _ReachTab({
    required this.overview,
    required this.range,
    required this.platform,
  });

  final AnalyticsOverview overview;
  final DateRange range;
  final PlatformType? platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final snapshots = overview.rangeSnapshots;
    final channelIds = ref
        .watch(channelRepositoryProvider)
        .getChannels()
        .where((c) => platform == null || c.platform == platform)
        .map((c) => c.id)
        .toSet();
    final data = overview.data;

    List<MetricPoint> series(String metric) => buildDailyFlowSeries(
          snapshots,
          metric,
          range.start,
          range.end,
          channelIds: channelIds,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KpiGrid(
          tiles: [
            _Kpi(
              label: 'Просмотры',
              value: data.views.formatCompact(),
              icon: Icons.visibility_outlined,
              color: colors.blue,
            ),
            _Kpi(
              label: 'Охват',
              value: data.reach.formatCompact(),
              icon: Icons.podcasts_outlined,
              color: colors.accent,
              footnote: data.reach == 0 ? 'Площадки не вернули охват' : null,
            ),
            _Kpi(
              label: 'Показы',
              value: data.impressions.formatCompact(),
              icon: Icons.ads_click_outlined,
              color: colors.yellow,
              footnote:
                  data.impressions == 0 ? 'Нет данных о показах' : null,
            ),
            _Kpi(
              label: 'Реакции',
              value: (data.likes + data.comments + data.shares).formatCompact(),
              icon: Icons.forum_outlined,
              color: colors.pink,
              footnote:
                  '${data.likes.formatCompact()} · ${data.comments.formatCompact()} · ${data.shares.formatCompact()}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Охват и просмотры',
          subtitle: 'Ежедневные значения из снимков',
          child: TimeSeriesChart(
            series: [
              ChartSeries(
                label: 'Просмотры',
                color: colors.blue,
                points: series(AnalyticsMetric.views),
                filled: true,
              ),
              ChartSeries(
                label: 'Охват',
                color: colors.accent,
                points: series(AnalyticsMetric.reach),
              ),
            ],
            height: 280,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final reaction = SectionCard(
              title: 'Реакции по дням',
              subtitle: 'Лайки, комментарии и репосты',
              child: TimeSeriesChart(
                series: [
                  ChartSeries(
                    label: 'Лайки',
                    color: colors.pink,
                    points: series(AnalyticsMetric.likes),
                    filled: true,
                  ),
                  ChartSeries(
                    label: 'Комментарии',
                    color: colors.yellow,
                    points: series(AnalyticsMetric.comments),
                  ),
                  ChartSeries(
                    label: 'Репосты',
                    color: colors.green,
                    points: series(AnalyticsMetric.shares),
                  ),
                ],
                height: 220,
              ),
            );
            final breakdown = SectionCard(
              title: 'Итого по метрикам',
              subtitle: 'За «${range.label}»',
              child: HBarChart(
                items: [
                  (label: 'Просмотры', value: data.views, color: colors.blue),
                  (label: 'Охват', value: data.reach, color: colors.accent),
                  (label: 'Показы', value: data.impressions, color: colors.yellow),
                  (label: 'Лайки', value: data.likes, color: colors.pink),
                  (label: 'Комментарии', value: data.comments, color: colors.green),
                  (label: 'Репосты', value: data.shares, color: colors.muted),
                ],
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: reaction),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: breakdown),
                ],
              );
            }
            return Column(
              children: [reaction, const SizedBox(height: 14), breakdown],
            );
          },
        ),
        const SizedBox(height: 16),
        const DataSourceNote(
          text:
              'Telegram Bot API не отдаёт просмотры постов, а YouTube Analytics '
              'ограничен правами аккаунта. Значения, введённые вручную, '
              'сохраняются отдельно от API и помечаются источником manual.',
        ),
      ],
    );
  }
}

class _RevenueTab extends ConsumerWidget {
  const _RevenueTab({required this.overview, required this.currency});

  final AnalyticsOverview overview;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final data = overview.data;
    final finance = data.finance;
    final ops = ref.watch(financeRepositoryProvider).getOperations(
          FinanceFilter(start: data.range.start, end: data.range.end),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KpiGrid(
          tiles: [
            _Kpi(
              label: 'Выручка',
              value: finance.income.formatCompact(),
              icon: Icons.payments_outlined,
              color: colors.green,
              footnote: 'Проведённые поступления, $currency',
            ),
            _Kpi(
              label: 'Расходы',
              value: finance.expenses.formatCompact(),
              icon: Icons.receipt_long_outlined,
              color: colors.pink,
              footnote: finance.refunds > 0
                  ? 'Плюс возвраты ${finance.refunds.formatMoney(currency: currency)}'
                  : 'Без возвратов',
            ),
            _Kpi(
              label: 'Чистая прибыль',
              value: finance.netProfit.formatCompact(),
              icon: Icons.savings_outlined,
              color: finance.netProfit >= 0 ? colors.green : colors.red,
              footnote: 'Маржа ${finance.margin.toStringAsFixed(1)}%',
            ),
            _Kpi(
              label: 'Ожидается',
              value: finance.pendingIncome.formatCompact(),
              icon: Icons.hourglass_bottom_rounded,
              color: colors.yellow,
              footnote: 'Не входит в прибыль до проведения',
            ),
          ],
        ),
        const SizedBox(height: 14),
        SectionCard(
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
            height: 270,
            valueFormatter: (value) => value.formatMoney(currency: currency),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final categories = SectionCard(
              title: 'Структура по категориям',
              subtitle: 'Суммы по проведённым операциям',
              child: HBarChart(
                items: [
                  for (final entry in finance.byCategory.entries)
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
            final platforms = SectionCard(
              title: 'Доход по площадкам',
              subtitle: 'Только операции с привязкой к каналу',
              child: HBarChart(
                items: [
                  for (final entry in finance.byPlatform.entries)
                    (
                      label: entry.key,
                      value: entry.value,
                      color: colors.accent,
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
                  Expanded(child: categories),
                  const SizedBox(width: 14),
                  Expanded(child: platforms),
                ],
              );
            }
            return Column(
              children: [categories, const SizedBox(height: 14), platforms],
            );
          },
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Последние операции',
          subtitle: 'Все статусы; в прибыль попадают только проведённые',
          trailing: TextButton(
            onPressed: () =>
                ref.read(shellIndexProvider.notifier).state = 5,
            child: const Text('Все операции'),
          ),
          child: ops.isEmpty
              ? const EmptyState(
                  title: 'Операций за период нет',
                  message:
                      'Добавьте доход или расход в разделе «Финансы». '
                      'Данные не создаются автоматически.',
                  icon: Icons.receipt_long_outlined,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final op in ops.take(6))
                      _OperationRow(operation: op),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(
          text:
              'Выводы средств и переводы не уменьшают прибыль: это движение '
              'денег, а не расход. Возвраты уменьшают прибыль. Ожидаемые '
              'поступления не учитываются до подтверждения.',
        ),
      ],
    );
  }
}

class _AudienceTab extends StatelessWidget {
  const _AudienceTab({required this.overview, required this.currency});

  final AnalyticsOverview overview;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final data = overview.data;
    final byDimension = <String, List<AudienceDemographic>>{};
    for (final row in overview.demographics) {
      byDimension.putIfAbsent(row.dimension, () => []).add(row);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KpiGrid(
          tiles: [
            _Kpi(
              label: 'Аудитория',
              value: data.audience.formatCompact(),
              icon: Icons.people_alt_outlined,
              color: colors.accent,
              delta: data.audienceChangePercent,
            ),
            _Kpi(
              label: 'Прирост',
              value:
                  '${data.audienceChange >= 0 ? '+' : ''}${data.audienceChange.formatCompact()}',
              icon: Icons.trending_up_rounded,
              color: data.audienceChange >= 0 ? colors.green : colors.red,
              footnote: 'Чистое изменение за период',
            ),
            _Kpi(
              label: 'Платные подписчики',
              value: data.paidSubscribers.formatCompact(),
              icon: Icons.workspace_premium_outlined,
              color: colors.yellow,
              footnote: data.paidSubscribers == 0
                  ? 'Нет снимков paid_subscribers'
                  : 'Последнее известное значение',
            ),
            _Kpi(
              label: 'Площадок с историей',
              value: '${data.channelsWithData}',
              icon: Icons.hub_outlined,
              color: colors.blue,
              footnote: 'Из ${data.platformRows.length} в сравнении',
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final chart = SectionCard(
              title: 'Динамика аудитории',
              subtitle: 'Сумма последних известных значений по каналам',
              child: TimeSeriesChart(
                series: [
                  ChartSeries(
                    label: 'Аудитория',
                    color: colors.accent,
                    points: data.audienceSeries,
                    filled: true,
                  ),
                ],
                height: 260,
              ),
            );
            final donut = SectionCard(
              title: 'Структура',
              subtitle: 'Доля площадок в аудитории',
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
                  Expanded(flex: 7, child: chart),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: donut),
                ],
              );
            }
            return Column(
              children: [chart, const SizedBox(height: 14), donut],
            );
          },
        ),
        const SizedBox(height: 14),
        if (byDimension.isEmpty)
          InfoNotice(
            message:
                'Демография не сохранена. Эти данные доступны только через '
                'YouTube Analytics API при наличии прав владельца канала; '
                'Telegram Bot API, Boosty и GitHub демографию не отдают. '
                'Приложение не подставляет вымышленные значения.',
            color: colors.yellow,
            icon: Icons.groups_outlined,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final cards = [
                for (final entry in byDimension.entries)
                  SectionCard(
                    title: _dimensionLabel(entry.key),
                    subtitle: 'Источник: API площадки',
                    child: _DemographicBars(rows: entry.value),
                  ),
              ];
              if (wide) {
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final card in cards)
                      SizedBox(
                        width: (constraints.maxWidth - 14) / 2,
                        child: card,
                      ),
                  ],
                );
              }
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
        const SizedBox(height: 16),
        const DataSourceNote(
          text:
              'Демографические срезы агрегируются по сохранённым записям '
              'audience_demographics. Они не рассчитываются и не оцениваются '
              'при отсутствии ответа API.',
        ),
      ],
    );
  }

  String _dimensionLabel(String dimension) => switch (dimension) {
        'gender' => 'Пол',
        'age' => 'Возраст',
        'country' => 'Страны',
        'city' => 'Города',
        'device' => 'Устройства',
        _ => dimension,
      };
}

class _DemographicBars extends StatelessWidget {
  const _DemographicBars({required this.rows});

  final List<AudienceDemographic> rows;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final row in rows) {
      totals.update(row.bucket, (value) => value + row.value,
          ifAbsent: () => row.value);
    }
    final colors = context.colors;
    return HBarChart(
      items: [
        for (final entry in totals.entries)
          (
            label: entry.key,
            value: entry.value,
            color: colors.accent,
          ),
      ],
      valueFormatter: (value) => value.formatCompact(),
    );
  }
}

class _PlatformTable extends StatelessWidget {
  const _PlatformTable({required this.rows, required this.currency});

  final List<PlatformTotals> rows;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (rows.isEmpty) {
      return const EmptyState(
        title: 'Площадок пока нет',
        message: 'Добавьте канал, чтобы увидеть сравнение.',
        icon: Icons.hub_outlined,
        compact: true,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 720),
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
                  Expanded(flex: 3, child: _Head('Площадка')),
                  Expanded(flex: 2, child: _Head('Аудитория')),
                  Expanded(flex: 2, child: _Head('Прирост')),
                  Expanded(flex: 2, child: _Head('Просмотры')),
                  Expanded(flex: 3, child: _Head('Доход')),
                  Expanded(flex: 2, child: _Head('Публикации')),
                ],
              ),
            ),
            for (final row in rows)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
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
                      child: _Cell(
                        row.audience == 0
                            ? '—'
                            : row.audience.formatCompact(),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _Cell(
                        row.audienceGrowth == 0
                            ? '—'
                            : '${row.audienceGrowth > 0 ? '+' : ''}${row.audienceGrowth.formatCompact()}',
                        color: row.audienceGrowth > 0
                            ? colors.green
                            : row.audienceGrowth < 0
                                ? colors.red
                                : null,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _Cell(
                        row.views == 0 ? '—' : row.views.formatCompact(),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _Cell(
                        row.revenue == 0
                            ? '—'
                            : row.revenue.formatMoney(currency: currency),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _Cell(
                        row.publications == 0 ? '—' : '${row.publications}',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);

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

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.color});

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

class _RankedPublications extends StatelessWidget {
  const _RankedPublications({required this.rows});

  final List<PublicationWithStats> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (rows.isEmpty) {
      return const EmptyState(
        title: 'Публикаций пока нет',
        message:
            'Добавьте публикации в разделе «Публикации» или синхронизируйте '
            'площадку с API.',
        icon: Icons.article_outlined,
        compact: true,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PlatformChip(platform: rows[i].publication.platform, compact: true),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[i].publication.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${rows[i].publication.publishedAt.formatShort()} · '
                        '${rows[i].publication.type.label}',
                        style: TextStyle(color: colors.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                MiniStat(
                  label: 'Просмотры',
                  value: rows[i].latest == null
                      ? '—'
                      : rows[i].latest!.views.formatCompact(),
                ),
                const SizedBox(width: 16),
                MiniStat(
                  label: 'ER',
                  value: rows[i].latest == null
                      ? '—'
                      : rows[i].engagementRate.formatPercent(),
                  color: colors.accent,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({required this.operation});

  final FinancialOperation operation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final positive = operation.type == TransactionType.income;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconSquare(
            icon: positive
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: positive ? colors.green : colors.pink,
            size: 28,
          ),
          const SizedBox(width: 9),
          Expanded(
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
                  '${operation.date.formatShort()} · ${operation.category.label} · '
                  '${operation.status.label}',
                  style: TextStyle(color: colors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : '−'}${operation.baseAmount.formatMoney(currency: operation.baseCurrency)}',
            style: TextStyle(
              color: positive ? colors.green : colors.pink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
    this.footnote,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? delta;
  final String? footnote;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.tiles});

  final List<_Kpi> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
                ? 2
                : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: width,
                child: StatTile(
                  label: tile.label,
                  value: tile.value,
                  icon: tile.icon,
                  color: tile.color,
                  delta: tile.delta,
                  footnote: tile.footnote,
                ),
              ),
          ],
        );
      },
    );
  }
}
