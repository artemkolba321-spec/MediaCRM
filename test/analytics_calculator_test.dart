import 'package:flutter_test/flutter_test.dart';
import 'package:media_crm/core/analytics/analytics_calculator.dart';
import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/analytics_snapshot.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/publication.dart';
import 'package:media_crm/data/repositories/channel_repository.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';

void main() {
  group('DateRange', () {
    test('lastDays creates correct range', () {
      final range = DateRange.lastDays(30);
      expect(range.days, 30);
      expect(range.label, 'Последние 30 дн.');
    });

    test('all creates range from 2000 to now', () {
      final range = DateRange.all();
      expect(range.start.year, 2000);
      expect(range.label, 'Всё время');
    });

    test('previous returns correct previous period', () {
      final range = DateRange(
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 31),
      );
      final prev = range.previous;
      // days = 31, prev.start = March 1 - 31 days = Jan 30
      // prev.end = March 1 - 1 day = Feb 29
      expect(prev.start.year, 2024);
      expect(prev.start.month, 1);
      expect(prev.start.day, 30);
      expect(prev.end.year, 2024);
      expect(prev.end.month, 2);
      expect(prev.end.day, 29);
    });
  });

  group('latestCumulative', () {
    test('returns latest value per channel', () {
      final snapshots = [
        AnalyticsSnapshot(
          id: '1',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.followers,
          value: 100,
          date: DateTime(2024, 1, 1),
          recordedAt: DateTime(2024, 1, 1),
        ),
        AnalyticsSnapshot(
          id: '2',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.followers,
          value: 150,
          date: DateTime(2024, 1, 5),
          recordedAt: DateTime(2024, 1, 5),
        ),
        AnalyticsSnapshot(
          id: '3',
          userId: 'user1',
          channelId: 'ch2',
          platform: PlatformType.telegram,
          metric: AnalyticsMetric.followers,
          value: 200,
          date: DateTime(2024, 1, 3),
          recordedAt: DateTime(2024, 1, 3),
        ),
      ];

      final result = latestCumulative(
        snapshots,
        AnalyticsMetric.followers,
        channelIds: {'ch1', 'ch2'},
      );

      expect(result, 350); // 150 + 200
    });

    test('filters by channelIds', () {
      final snapshots = [
        AnalyticsSnapshot(
          id: '1',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.followers,
          value: 100,
          date: DateTime(2024, 1, 1),
          recordedAt: DateTime(2024, 1, 1),
        ),
        AnalyticsSnapshot(
          id: '2',
          userId: 'user1',
          channelId: 'ch2',
          platform: PlatformType.telegram,
          metric: AnalyticsMetric.followers,
          value: 200,
          date: DateTime(2024, 1, 1),
          recordedAt: DateTime(2024, 1, 1),
        ),
      ];

      final result = latestCumulative(
        snapshots,
        AnalyticsMetric.followers,
        channelIds: {'ch1'},
      );

      expect(result, 100);
    });

    test('filters by date', () {
      final snapshots = [
        AnalyticsSnapshot(
          id: '1',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.followers,
          value: 100,
          date: DateTime(2024, 1, 1),
          recordedAt: DateTime(2024, 1, 1),
        ),
        AnalyticsSnapshot(
          id: '2',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.followers,
          value: 200,
          date: DateTime(2024, 1, 10),
          recordedAt: DateTime(2024, 1, 10),
        ),
      ];

      final result = latestCumulative(
        snapshots,
        AnalyticsMetric.followers,
        channelIds: {'ch1'},
        at: DateTime(2024, 1, 5),
      );

      expect(result, 100); // value at Jan 5 is 100
    });
  });

  group('sumFlow', () {
    test('sums all values for a metric', () {
      final snapshots = [
        AnalyticsSnapshot(
          id: '1',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.views,
          value: 1000,
          date: DateTime(2024, 1, 1),
          recordedAt: DateTime(2024, 1, 1),
        ),
        AnalyticsSnapshot(
          id: '2',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.views,
          value: 2000,
          date: DateTime(2024, 1, 2),
          recordedAt: DateTime(2024, 1, 2),
        ),
        AnalyticsSnapshot(
          id: '3',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.likes,
          value: 500,
          date: DateTime(2024, 1, 1),
          recordedAt: DateTime(2024, 1, 1),
        ),
      ];

      final result = sumFlow(snapshots, AnalyticsMetric.views);
      expect(result, 3000);
    });

    test('filters by metric', () {
      final snapshots = [
        AnalyticsSnapshot(
          id: '1',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.views,
          value: 1000,
          date: DateTime(2024, 1, 1),
          recordedAt: DateTime(2024, 1, 1),
        ),
        AnalyticsSnapshot(
          id: '2',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.likes,
          value: 500,
          date: DateTime(2024, 1, 1),
          recordedAt: DateTime(2024, 1, 1),
        ),
      ];

      final views = sumFlow(snapshots, AnalyticsMetric.views);
      expect(views, 1000);

      final likes = sumFlow(snapshots, AnalyticsMetric.likes);
      expect(likes, 500);
    });
  });

  group('buildAudienceSeries', () {
    test('returns empty for no snapshots', () {
      final channels = [
        PlatformChannel(
          id: 'ch1',
          userId: 'user1',
          platform: PlatformType.youtube,
          name: 'Test',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      final result = buildAudienceSeries(channels, [], DateTime(2024, 1, 1), DateTime(2024, 1, 7));
      expect(result, isEmpty);
    });

    test('carries forward last known value', () {
      final channels = [
        PlatformChannel(
          id: 'ch1',
          userId: 'user1',
          platform: PlatformType.youtube,
          name: 'Test',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      final snapshots = [
        AnalyticsSnapshot(
          id: '1',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.followers,
          value: 100,
          date: DateTime(2024, 1, 1),
          recordedAt: DateTime(2024, 1, 1),
        ),
        AnalyticsSnapshot(
          id: '2',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.followers,
          value: 150,
          date: DateTime(2024, 1, 5),
          recordedAt: DateTime(2024, 1, 5),
        ),
      ];

      final result = buildAudienceSeries(
        channels,
        snapshots,
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 7),
      );

      expect(result.length, 7);
      // Day 1-4 should carry 100, Day 5-7 should carry 150
      expect(result[0].value, 100);
      expect(result[4].value, 150);
      expect(result[6].value, 150);
    });
  });

  group('engagementRate', () {
    test('calculates engagement rate correctly', () {
      final stats = PublicationStats(
        id: '1',
        userId: 'user1',
        publicationId: 'pub1',
        views: 1000,
        likes: 50,
        comments: 10,
        shares: 5,
        recordedAt: DateTime(2024, 1, 1),
      );

      final rate = engagementRate(stats);
      expect(rate, (50 + 10 + 5) / 1000 * 100); // 6.5%
    });

    test('returns 0 for null stats', () {
      expect(engagementRate(null), 0);
    });

    test('returns 0 for zero views', () {
      final stats = PublicationStats(
        id: '1',
        userId: 'user1',
        publicationId: 'pub1',
        views: 0,
        likes: 50,
        comments: 10,
        recordedAt: DateTime(2024, 1, 1),
      );
      expect(engagementRate(stats), 0);
    });
  });

  group('AnalyticsMetric', () {
    test('returns correct labels', () {
      expect(AnalyticsMetric.label('followers'), 'Подписчики');
      expect(AnalyticsMetric.label('views'), 'Просмотры');
      expect(AnalyticsMetric.label('revenue'), 'Доход');
      expect(AnalyticsMetric.label('unknown'), 'unknown');
    });

    test('isMoney identifies monetary metrics', () {
      expect(AnalyticsMetric.isMoney('revenue'), true);
      expect(AnalyticsMetric.isMoney('income'), false);
      expect(AnalyticsMetric.isMoney('followers'), false);
      expect(AnalyticsMetric.isMoney('views'), false);
    });
  });

  group('AnalyticsSnapshot deduplication', () {
    test('dedupeSnapshots keeps latest per unique key', () {
      final repo = ChannelRepository(
        store: FakeLocalStore(),
        cloud: FakeCloudService(),
        activity: FakeActivityService(),
      );

      final snapshots = [
        AnalyticsSnapshot(
          id: '1',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.followers,
          value: 100,
          date: DateTime(2024, 1, 1),
          recordedAt: DateTime(2024, 1, 1),
        ),
        AnalyticsSnapshot(
          id: '2',
          userId: 'user1',
          channelId: 'ch1',
          platform: PlatformType.youtube,
          metric: AnalyticsMetric.followers,
          value: 150,
          date: DateTime(2024, 1, 1),
          recordedAt: DateTime(2024, 1, 5),
        ),
      ];

      final result = repo.dedupeSnapshots(snapshots);
      expect(result.length, 1);
      expect(result.first.value, 150);
    });
  });
}

// ─── Fakes ──────────────────────────────────────────────────────────────────

class FakeLocalStore extends LocalStore {
  final Map<String, List<Map<String, dynamic>>> _data = {};

  @override
  List<Map<String, dynamic>> readRaw(String collection) =>
      List.unmodifiable(_data[collection] ?? []);

  @override
  Future<void> writeRaw(
    String collection,
    List<Map<String, dynamic>> items,
  ) async {
    _data[collection] = List.from(items);
  }

  @override
  Future<void> upsert(
    String collection,
    Map<String, dynamic> json, {
    String idField = 'id',
  }) async {
    _data.putIfAbsent(collection, () => []);
    final list = _data[collection]!;
    final id = json[idField] as String?;
    if (id != null) {
      final idx = list.indexWhere((e) => e[idField] == id);
      if (idx >= 0) {
        list[idx] = json;
      } else {
        list.add(json);
      }
    } else {
      list.add(json);
    }
  }

  @override
  Future<void> deleteById(String collection, String id) async {
    _data.putIfAbsent(collection, () => []);
    _data[collection]!.removeWhere((e) => e['id'] == id);
  }

  @override
  Future<void> replaceAll(
    String collection,
    List<Map<String, dynamic>> items,
  ) async {
    _data[collection] = List.from(items);
  }

  @override
  Future<void> useUser(String userId) async {}
}

class FakeCloudService extends CloudService {
  FakeCloudService() : super(null, FakeLocalStore());

  @override
  bool get isConfigured => false;

  @override
  bool get isSignedIn => false;
}

class FakeActivityService extends ActivityService {
  FakeActivityService() : super(FakeLocalStore(), FakeCloudService());
}
