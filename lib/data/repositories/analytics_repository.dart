import 'package:media_crm/core/analytics/analytics_calculator.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/analytics/finance_calculator.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/notification_item.dart';
import 'package:media_crm/data/models/advertiser.dart';
import 'package:media_crm/data/models/analytics_snapshot.dart';
import 'package:media_crm/data/models/financial_operation.dart';
import 'package:media_crm/data/models/partner.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/publication.dart';
import 'package:media_crm/data/models/sync_run.dart';
import 'package:media_crm/data/repositories/advertiser_repository.dart';
import 'package:media_crm/data/repositories/channel_repository.dart';
import 'package:media_crm/data/repositories/contact_repository.dart';
import 'package:media_crm/data/repositories/finance_repository.dart';
import 'package:media_crm/data/repositories/notification_repository.dart';
import 'package:media_crm/data/repositories/partner_repository.dart';
import 'package:media_crm/data/repositories/publication_repository.dart';
import 'package:media_crm/data/repositories/task_repository.dart';

class DashboardData {
  final DateRange range;
  final PlatformType? platform;
  final double audience;
  final double previousAudience;
  final double audienceChange;
  final double audienceChangePercent;
  final double views;
  final double reach;
  final double impressions;
  final double likes;
  final double comments;
  final double shares;
  final int publications;
  final double paidSubscribers;
  final int channelsWithData;
  final FinanceSummary finance;
  final FinanceSummary previousFinance;
  final double advertiserRevenue;
  final int activeCampaigns;
  final double campaignDebt;
  final int partnerClicks;
  final int partnerRegistrations;
  final int partnerSales;
  final double partnerCommission;
  final int openTasks;
  final int overdueTasks;
  final int unreadNotifications;
  final int syncErrors;
  final List<MetricPoint> audienceSeries;
  final List<MetricPoint> revenueSeries;
  final List<MetricPoint> expenseSeries;
  final List<MetricPoint> viewsSeries;
  final List<PlatformTotals> platformRows;
  final List<ActivityLogEntry> recentEvents;
  final List<SyncRun> recentSyncs;
  final Map<String, int> publicationsByPlatform;

  const DashboardData({
    required this.range,
    required this.platform,
    required this.audience,
    required this.previousAudience,
    required this.audienceChange,
    required this.audienceChangePercent,
    required this.views,
    required this.reach,
    required this.impressions,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.publications,
    required this.paidSubscribers,
    required this.channelsWithData,
    required this.finance,
    required this.previousFinance,
    required this.advertiserRevenue,
    required this.activeCampaigns,
    required this.campaignDebt,
    required this.partnerClicks,
    required this.partnerRegistrations,
    required this.partnerSales,
    required this.partnerCommission,
    required this.openTasks,
    required this.overdueTasks,
    required this.unreadNotifications,
    required this.syncErrors,
    required this.audienceSeries,
    required this.revenueSeries,
    required this.expenseSeries,
    required this.viewsSeries,
    required this.platformRows,
    required this.recentEvents,
    required this.recentSyncs,
    required this.publicationsByPlatform,
  });

  bool get hasAnalytics => audienceSeries.isNotEmpty || views > 0;
  bool get hasFinance => finance.count > 0;
}

class AnalyticsOverview {
  final DashboardData data;
  final List<PublicationWithStats> topPublications;
  final List<PublicationWithStats> weakPublications;
  final List<AudienceDemographic> demographics;
  final List<Publication> periodPublications;
  final List<AnalyticsSnapshot> rangeSnapshots;

  const AnalyticsOverview({
    required this.data,
    required this.topPublications,
    required this.weakPublications,
    required this.demographics,
    required this.periodPublications,
    required this.rangeSnapshots,
  });
}

class AnalyticsRepository {
  AnalyticsRepository({
    required LocalStore store,
    required ChannelRepository channels,
    required FinanceRepository finance,
    required PublicationRepository publications,
    required AdvertiserRepository advertisers,
    required PartnerRepository partners,
    required TaskRepository tasks,
    required NotificationRepository notifications,
    required ContactRepository contacts,
  })  : _store = store,
        _channels = channels,
        _finance = finance,
        _publications = publications,
        _advertisers = advertisers,
        _partners = partners,
        _tasks = tasks,
        _notifications = notifications,
        _contacts = contacts;

  final LocalStore _store;
  final ChannelRepository _channels;
  final FinanceRepository _finance;
  final PublicationRepository _publications;
  final AdvertiserRepository _advertisers;
  final PartnerRepository _partners;
  final TaskRepository _tasks;
  final NotificationRepository _notifications;
  final ContactRepository _contacts;

  DashboardData dashboard({
    required DateRange range,
    PlatformType? platform,
  }) {
    final allChannels = _channels.getChannels();
    final channels = platform == null
        ? allChannels
        : allChannels.where((c) => c.platform == platform).toList();
    final channelIds = channels.map((c) => c.id).toSet();
    final allSnapshots = _channels
        .getSnapshots(platform: platform)
        .where((s) =>
            s.channelId == null || channelIds.contains(s.channelId))
        .toList();
    final rangeSnapshots = allSnapshots
        .where((s) =>
            !s.date.dateOnly.isBefore(range.start.dateOnly) &&
            !s.date.dateOnly.isAfter(range.end.dateOnly))
        .toList();
    final previous = range.previous;

    final audienceNow = audienceAt(channels, allSnapshots, range.end);
    final audienceBefore = audienceAt(
      channels,
      allSnapshots,
      range.start.subtract(const Duration(days: 1)),
    );
    final currentOps = _finance
        .getOperations(FinanceFilter(start: range.start, end: range.end))
        .where((op) =>
            platform == null ||
            (op.channelId != null && channelIds.contains(op.channelId)))
        .toList();
    final previousOps = _finance
        .getOperations(FinanceFilter(start: previous.start, end: previous.end))
        .where((op) =>
            platform == null ||
            (op.channelId != null && channelIds.contains(op.channelId)))
        .toList();
    final summary = calculateFinanceSummary(currentOps, channels: allChannels);
    final previousSummary =
        calculateFinanceSummary(previousOps, channels: allChannels);

    final publications = _publications.publicationsInPeriod(
      range.start,
      range.end,
      platform: platform,
    );
    final campaigns = _advertisers
        .getCampaigns()
        .where((c) =>
            c.status == CampaignStatus.active &&
            (platform == null ||
                c.channelIds.any((id) => channelIds.contains(id))))
        .toList();
    final campaignDebt = _advertisers.totalDebt();
    final advertiserRevenue = currentOps
        .where((o) =>
            o.type == TransactionType.income &&
            o.advertiserId != null &&
            o.isCompleted)
        .fold<double>(0, (sum, o) => sum + o.baseAmount);

    final events = <String, PartnerEvent>{};
    for (final partner in _partners.getPartners()) {
      for (final event in _partners.getEvents(partner.id)) {
        if (event.occurredAt.dateOnly.isBefore(range.start.dateOnly) ||
            event.occurredAt.dateOnly.isAfter(range.end.dateOnly)) {
          continue;
        }
        events[event.id] = event;
      }
    }
    final partnerClicks = events.values
        .where((e) => e.type == PartnerEventType.click)
        .length;
    final partnerRegistrations = events.values
        .where((e) => e.type == PartnerEventType.registration)
        .length;
    final partnerSales = events.values
        .where((e) => e.type == PartnerEventType.sale && e.confirmed)
        .length;
    final partnerCommission = events.values
        .where((e) => e.type == PartnerEventType.sale && e.confirmed)
        .fold<double>(0, (sum, e) => sum + e.commission);

    final audienceSeries = buildAudienceSeries(
      channels,
      allSnapshots,
      range.start,
      range.end,
    );
    final revenueSeries = _financeSeries(
      currentOps,
      range,
      TransactionType.income,
    );
    final expenseSeries = _financeSeries(
      currentOps,
      range,
      TransactionType.expense,
    );
    final viewsSeries = buildDailyFlowSeries(
      rangeSnapshots,
      AnalyticsMetric.views,
      range.start,
      range.end,
      channelIds: channelIds,
    );

    final platformRows = _buildPlatformRows(
      allChannels: allChannels,
      platformFilter: platform,
      allSnapshots: allSnapshots,
      rangeSnapshots: rangeSnapshots,
      currentOps: currentOps,
      range: range,
      publications: publications,
    );

    final recentEvents = _store
        .readRaw('activity_log')
        .map(ActivityLogEntry.fromJson)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentSyncs = _channels.getSyncRuns(limit: 5);

    return DashboardData(
      range: range,
      platform: platform,
      audience: audienceNow,
      previousAudience: audienceBefore,
      audienceChange: audienceNow - audienceBefore,
      audienceChangePercent: percentChange(audienceNow, audienceBefore),
      views: sumFlow(rangeSnapshots, AnalyticsMetric.views,
          channelIds: channelIds),
      reach: sumFlow(rangeSnapshots, AnalyticsMetric.reach,
          channelIds: channelIds),
      impressions: sumFlow(rangeSnapshots, AnalyticsMetric.impressions,
          channelIds: channelIds),
      likes: sumFlow(rangeSnapshots, AnalyticsMetric.likes,
          channelIds: channelIds),
      comments: sumFlow(rangeSnapshots, AnalyticsMetric.comments,
          channelIds: channelIds),
      shares: sumFlow(rangeSnapshots, AnalyticsMetric.shares,
          channelIds: channelIds),
      publications: publications.length,
      paidSubscribers: latestCumulative(
        rangeSnapshots,
        AnalyticsMetric.paidSubscribers,
        channelIds: channelIds,
        at: range.end,
      ),
      channelsWithData: channels
          .where((c) => rangeSnapshots.any((s) => s.channelId == c.id))
          .length,
      finance: summary,
      previousFinance: previousSummary,
      advertiserRevenue: advertiserRevenue,
      activeCampaigns: campaigns.length,
      campaignDebt: campaignDebt,
      partnerClicks: partnerClicks,
      partnerRegistrations: partnerRegistrations,
      partnerSales: partnerSales,
      partnerCommission: partnerCommission,
      openTasks: _tasks.getTasks(includeDone: false).length,
      overdueTasks: _tasks.overdueCount,
      unreadNotifications: _notifications.unreadCount,
      syncErrors:
          recentSyncs.where((r) => r.status == SyncRunStatus.error).length,
      audienceSeries: audienceSeries,
      revenueSeries: revenueSeries,
      expenseSeries: expenseSeries,
      viewsSeries: viewsSeries,
      platformRows: platformRows,
      recentEvents: recentEvents.take(8).toList(),
      recentSyncs: recentSyncs,
      publicationsByPlatform: {
        for (final p in publications)
          p.platform.label: publications
              .where((item) => item.platform == p.platform)
              .length,
      },
    );
  }

  List<MetricPoint> _financeSeries(
    List<FinancialOperation> operations,
    DateRange range,
    TransactionType type,
  ) {
    final byDay = <String, double>{};
    for (final op in operations) {
      if (op.type != type || !op.isCompleted) continue;
      final key = op.date.toIso8601String().substring(0, 10);
      byDay.update(key, (value) => value + op.baseAmount,
          ifAbsent: () => op.baseAmount);
    }
    final points = <MetricPoint>[];
    for (var day = range.start.dateOnly;
        !day.isAfter(range.end.dateOnly);
        day = day.add(const Duration(days: 1))) {
      final key = day.toIso8601String().substring(0, 10);
      points.add(MetricPoint(day, byDay[key] ?? 0));
    }
    return points;
  }

  List<PlatformTotals> _buildPlatformRows({
    required List<PlatformChannel> allChannels,
    required PlatformType? platformFilter,
    required List<AnalyticsSnapshot> allSnapshots,
    required List<AnalyticsSnapshot> rangeSnapshots,
    required List<FinancialOperation> currentOps,
    required DateRange range,
    required List<Publication> publications,
  }) {
    final platforms = platformFilter == null
        ? allChannels.map((c) => c.platform).toSet().toList()
        : [platformFilter];
    final rows = <PlatformTotals>[];
    for (final platform in platforms) {
      final channels =
          allChannels.where((c) => c.platform == platform).toList();
      final ids = channels.map((c) => c.id).toSet();
      final audienceNow = audienceAt(channels, allSnapshots, range.end);
      final audienceBefore = audienceAt(
        channels,
        allSnapshots,
        range.start.subtract(const Duration(days: 1)),
      );
      final views = sumFlow(rangeSnapshots, AnalyticsMetric.views,
          channelIds: ids);
      final revenue = currentOps
          .where((o) =>
              o.type == TransactionType.income &&
              o.isCompleted &&
              o.channelId != null &&
              ids.contains(o.channelId))
          .fold<double>(0, (sum, o) => sum + o.baseAmount);
      rows.add(PlatformTotals(
        platform: platform,
        audience: audienceNow,
        audienceGrowth: audienceNow - audienceBefore,
        views: views,
        revenue: revenue,
        publications:
            publications.where((p) => p.platform == platform).length,
        paidSubscribers: latestCumulative(
          allSnapshots,
          AnalyticsMetric.paidSubscribers,
          channelIds: ids,
          at: range.end,
        ).round(),
      ));
    }
    rows.sort((a, b) => b.audience.compareTo(a.audience));
    return rows;
  }

  AnalyticsOverview overview({
    required DateRange range,
    PlatformType? platform,
  }) {
    final data = dashboard(range: range, platform: platform);
    final top = _publications.ranked(platform: platform, limit: 5);
    final allRanked = _publications.ranked(platform: platform, limit: 100);
    final weak = allRanked.reversed.take(5).toList();
    final demographics = _store
        .readRaw('demographics')
        .map(AudienceDemographic.fromJson)
        .where((d) =>
            (platform == null || d.platform == platform) &&
            !d.date.dateOnly.isBefore(range.start.dateOnly) &&
            !d.date.dateOnly.isAfter(range.end.dateOnly))
        .toList();
    return AnalyticsOverview(
      data: data,
      topPublications: top,
      weakPublications: weak,
      demographics: demographics,
      periodPublications: _publications.publicationsInPeriod(
        range.start,
        range.end,
        platform: platform,
      ),
      rangeSnapshots: _channels
          .getSnapshots(
            start: range.start,
            end: range.end,
            platform: platform,
          )
          .toList(),
    );
  }

  int get contactsCount => _contacts.getContacts().length;
  int get partnersCount => _partners.getPartners().length;
  int get channelsCount => _channels.getChannels().length;
}
