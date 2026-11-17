import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/data/models/analytics_snapshot.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/publication.dart';

class DateRange {
  final DateTime start;
  final DateTime end;
  final String label;

  const DateRange({
    required this.start,
    required this.end,
    this.label = 'Период',
  });

  int get days => end.difference(start).inDays + 1;

  PeriodWindow get previous => PeriodWindow(
        start: start.subtract(Duration(days: days)),
        end: start.subtract(const Duration(days: 1)),
      );

  factory DateRange.lastDays(int days, {DateTime? now}) {
    final clock = (now ?? DateTime.now()).dateOnly;
    return DateRange(
      start: clock.subtract(Duration(days: days - 1)),
      end: clock,
      label: 'Последние $days дн.',
    );
  }

  factory DateRange.all({DateTime? now}) => DateRange(
        start: DateTime(2000),
        end: (now ?? DateTime.now()).dateOnly,
        label: 'Всё время',
      );
}

class PeriodWindow {
  final DateTime start;
  final DateTime end;
  const PeriodWindow({required this.start, required this.end});
}

class MetricPoint {
  final DateTime date;
  final double value;
  const MetricPoint(this.date, this.value);
}

class PlatformTotals {
  final PlatformType platform;
  final double audience;
  final double audienceGrowth;
  final double views;
  final double revenue;
  final int publications;
  final int paidSubscribers;

  const PlatformTotals({
    required this.platform,
    this.audience = 0,
    this.audienceGrowth = 0,
    this.views = 0,
    this.revenue = 0,
    this.publications = 0,
    this.paidSubscribers = 0,
  });
}

/// Picks the latest cumulative value per channel on or before [at].
double latestCumulative(
  List<AnalyticsSnapshot> snapshots,
  String metric, {
  Set<String>? channelIds,
  DateTime? at,
}) {
  final limit = (at ?? DateTime.now()).dateOnly;
  final latestPerChannel = <String, AnalyticsSnapshot>{};
  for (final snapshot in snapshots) {
    if (snapshot.metric != metric) continue;
    if (channelIds != null &&
        snapshot.channelId != null &&
        !channelIds.contains(snapshot.channelId)) {
      continue;
    }
    if (snapshot.date.dateOnly.isAfter(limit)) continue;
    final key = snapshot.channelId ?? 'global';
    final existing = latestPerChannel[key];
    if (existing == null || snapshot.date.isAfter(existing.date)) {
      latestPerChannel[key] = snapshot;
    }
  }
  return latestPerChannel.values.fold(0, (sum, s) => sum + s.value);
}

double sumFlow(
  List<AnalyticsSnapshot> snapshots,
  String metric, {
  Set<String>? channelIds,
}) {
  return snapshots.where((s) {
    if (s.metric != metric) return false;
    if (channelIds != null &&
        s.channelId != null &&
        !channelIds.contains(s.channelId)) {
      return false;
    }
    return true;
  }).fold(0, (sum, s) => sum + s.value);
}

/// Builds a day-by-day audience series. Values are carried forward when a
/// platform did not return a snapshot for a particular day.
List<MetricPoint> buildAudienceSeries(
  List<PlatformChannel> channels,
  List<AnalyticsSnapshot> snapshots,
  DateTime start,
  DateTime end, {
  String metric = AnalyticsMetric.followers,
}) {
  final relevant = snapshots
      .where((s) =>
          s.metric == metric &&
          s.channelId != null &&
          channels.any((c) => c.id == s.channelId))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  if (relevant.isEmpty) return const [];

  final points = <MetricPoint>[];
  final lastPerChannel = <String, double>{};
  var index = 0;
  final startDate = start.dateOnly;
  final endDate = end.dateOnly;
  // Seed with values known before the selected period.
  for (final snapshot in relevant) {
    if (snapshot.date.dateOnly.isBefore(startDate)) {
      lastPerChannel[snapshot.channelId!] = snapshot.value;
    }
  }
  final relevantInRange = relevant
      .where((s) =>
          !s.date.dateOnly.isBefore(startDate) &&
          !s.date.dateOnly.isAfter(endDate))
      .toList();
  for (var day = startDate;
      !day.isAfter(endDate);
      day = day.add(const Duration(days: 1))) {
    while (index < relevantInRange.length &&
        !relevantInRange[index].date.dateOnly.isAfter(day)) {
      final snapshot = relevantInRange[index];
      lastPerChannel[snapshot.channelId!] = snapshot.value;
      index++;
    }
    final total = lastPerChannel.values.fold(0.0, (sum, value) => sum + value);
    points.add(MetricPoint(day, total));
  }
  return points;
}

/// Sums a flow metric (views, likes, revenue) per day.
List<MetricPoint> buildDailyFlowSeries(
  List<AnalyticsSnapshot> snapshots,
  String metric,
  DateTime start,
  DateTime end, {
  Set<String>? channelIds,
}) {
  final byDay = <String, double>{};
  for (final snapshot in snapshots) {
    if (snapshot.metric != metric) continue;
    if (channelIds != null &&
        snapshot.channelId != null &&
        !channelIds.contains(snapshot.channelId)) {
      continue;
    }
    if (snapshot.date.dateOnly.isBefore(start.dateOnly) ||
        snapshot.date.dateOnly.isAfter(end.dateOnly)) {
      continue;
    }
    final key = snapshot.date.toIso8601String().substring(0, 10);
    byDay.update(key, (value) => value + snapshot.value,
        ifAbsent: () => snapshot.value);
  }
  final points = <MetricPoint>[];
  for (var day = start.dateOnly;
      !day.isAfter(end.dateOnly);
      day = day.add(const Duration(days: 1))) {
    final key = day.toIso8601String().substring(0, 10);
    points.add(MetricPoint(day, byDay[key] ?? 0));
  }
  return points;
}

double calculateAudienceGrowth(
  List<PlatformChannel> channels,
  List<AnalyticsSnapshot> snapshots,
  DateTime start,
  DateTime end,
) {
  final ids = channels.map((c) => c.id).toSet();
  final startValue = latestCumulative(
    snapshots,
    AnalyticsMetric.followers,
    channelIds: ids,
    at: start.subtract(const Duration(days: 1)),
  );
  final endValue = latestCumulative(
    snapshots,
    AnalyticsMetric.followers,
    channelIds: ids,
    at: end,
  );
  return endValue - startValue;
}

double audienceAt(
  List<PlatformChannel> channels,
  List<AnalyticsSnapshot> snapshots,
  DateTime at,
) {
  final ids = channels.map((c) => c.id).toSet();
  final fromSnapshots = latestCumulative(
    snapshots,
    AnalyticsMetric.followers,
    channelIds: ids,
    at: at,
  );
  if (fromSnapshots > 0) return fromSnapshots;
  return channels.fold(0.0, (sum, c) => sum + c.subscriberCount);
}

double engagementRate(PublicationStats? stats) {
  if (stats == null || stats.views == 0) return 0;
  return stats.engagement / stats.views * 100;
}

class PublicationWithStats {
  final Publication publication;
  final PublicationStats? latest;
  final double engagementRate;

  const PublicationWithStats({
    required this.publication,
    required this.latest,
    required this.engagementRate,
  });
}

List<PublicationWithStats> rankPublications(
  List<Publication> publications,
  List<PublicationStats> stats, {
  PlatformType? platform,
  int limit = 10,
}) {
  final latestByPublication = <String, PublicationStats>{};
  for (final item in stats) {
    final existing = latestByPublication[item.publicationId];
    if (existing == null || item.recordedAt.isAfter(existing.recordedAt)) {
      latestByPublication[item.publicationId] = item;
    }
  }
  final rows = publications
      .where((p) => platform == null || p.platform == platform)
      .map((p) {
    final latest = latestByPublication[p.id];
    return PublicationWithStats(
      publication: p,
      latest: latest,
      engagementRate: engagementRate(latest),
    );
  }).toList()
    ..sort((a, b) {
      final viewsA = a.latest?.views ?? 0;
      final viewsB = b.latest?.views ?? 0;
      return viewsB.compareTo(viewsA);
    });
  return rows.take(limit).toList();
}
