import 'package:media_crm/core/utils/json_utils.dart';
import 'package:media_crm/data/models/platform_channel.dart';

/// Canonical metric keys. `followers`, `paidSubscribers` and `stars` are
/// point-in-time values; `views`, `likes`, etc. are values for the day/period
/// in which they were recorded.
class AnalyticsMetric {
  const AnalyticsMetric._();

  static const followers = 'followers';
  static const followersGained = 'followers_gained';
  static const followersLost = 'followers_lost';
  static const views = 'views';
  static const reach = 'reach';
  static const impressions = 'impressions';
  static const likes = 'likes';
  static const comments = 'comments';
  static const shares = 'shares';
  static const paidSubscribers = 'paid_subscribers';
  static const revenue = 'revenue';
  static const posts = 'posts';
  static const videos = 'videos';
  static const stars = 'stars';
  static const forks = 'forks';

  static const all = [
    followers,
    followersGained,
    followersLost,
    views,
    reach,
    impressions,
    likes,
    comments,
    shares,
    paidSubscribers,
    revenue,
    posts,
    videos,
    stars,
    forks,
  ];

  static String label(String metric) => switch (metric) {
        followers => 'Подписчики',
        followersGained => 'Прирост подписчиков',
        followersLost => 'Отписки',
        views => 'Просмотры',
        reach => 'Охват',
        impressions => 'Показы',
        likes => 'Лайки',
        comments => 'Комментарии',
        shares => 'Репосты',
        paidSubscribers => 'Платные подписчики',
        revenue => 'Доход',
        posts => 'Публикации',
        videos => 'Видео',
        stars => 'Звёзды',
        forks => 'Форки',
        _ => metric,
      };

  static bool isCumulative(String metric) => const {
        followers,
        paidSubscribers,
        stars,
        forks,
        videos,
      }.contains(metric);

  static bool isMoney(String metric) => metric == revenue;
}

enum SnapshotSource { api, manual, import, derived }

enum SnapshotReliability { verified, manual, estimated }

class AnalyticsSnapshot {
  final String id;
  final String userId;
  final String? channelId;
  final PlatformType platform;
  final String metric;
  final double value;
  final DateTime date;
  final SnapshotSource source;
  final SnapshotReliability reliability;
  final DateTime recordedAt;

  const AnalyticsSnapshot({
    required this.id,
    required this.userId,
    this.channelId,
    required this.platform,
    required this.metric,
    required this.value,
    required this.date,
    this.source = SnapshotSource.api,
    this.reliability = SnapshotReliability.verified,
    required this.recordedAt,
  });

  String get uniqueKey =>
      '${channelId ?? 'all'}|$metric|${isoDate(date)}|${source.name}';

  factory AnalyticsSnapshot.fromJson(Map<String, dynamic> json) {
    return AnalyticsSnapshot(
      id: parseRequiredString(json['id']),
      userId: parseRequiredString(json['user_id']),
      channelId: parseString(json['channel_id']),
      platform: enumByName(
        PlatformType.values,
        json['platform'],
        PlatformType.youtube,
      ),
      metric: parseRequiredString(json['metric']),
      value: parseDouble(json['value']),
      date: parseDateOrNow(json['date']),
      source: enumByName(
        SnapshotSource.values,
        json['source'],
        SnapshotSource.api,
      ),
      reliability: enumByName(
        SnapshotReliability.values,
        json['reliability'],
        SnapshotReliability.verified,
      ),
      recordedAt: parseDateOrNow(json['recorded_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'channel_id': channelId,
        'platform': platform.name,
        'metric': metric,
        'value': value,
        'date': isoDate(date),
        'source': source.name,
        'reliability': reliability.name,
        'recorded_at': isoDateTime(recordedAt),
      };
}
