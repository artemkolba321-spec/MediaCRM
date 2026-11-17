import 'package:uuid/uuid.dart';

import 'package:media_crm/core/analytics/analytics_calculator.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/publication.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';

class PublicationRepository {
  PublicationRepository({
    required LocalStore store,
    required CloudService cloud,
    required ActivityService activity,
  }) {
    _publications = EntityRepository<Publication>(
      store: store,
      cloud: cloud,
      collection: 'publications',
      fromJson: Publication.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.updatedAt,
      activity: activity,
    );
    _stats = EntityRepository<PublicationStats>(
      store: store,
      cloud: cloud,
      collection: 'publication_stats',
      fromJson: PublicationStats.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.recordedAt,
    );
  }

  late final EntityRepository<Publication> _publications;
  late final EntityRepository<PublicationStats> _stats;
  final _uuid = const Uuid();

  List<Publication> getPublications({
    PlatformType? platform,
    String? channelId,
    DateTime? start,
    DateTime? end,
    String? search,
    PublicationType? type,
    int limit = 500,
  }) {
    var items = _publications.getAll();
    if (platform != null) {
      items = items.where((p) => p.platform == platform).toList();
    }
    if (channelId != null) {
      items = items.where((p) => p.channelId == channelId).toList();
    }
    if (start != null) {
      items = items
          .where((p) => !p.publishedAt.dateOnly.isBefore(start.dateOnly))
          .toList();
    }
    if (end != null) {
      items = items
          .where((p) => !p.publishedAt.dateOnly.isAfter(end.dateOnly))
          .toList();
    }
    if (type != null) items = items.where((p) => p.type == type).toList();
    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      items = items
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              (p.content ?? '').toLowerCase().contains(q))
          .toList();
    }
    items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return items.take(limit).toList();
  }

  Publication? getPublication(String id) => _publications.getById(id);

  Publication? findByPlatformPost(PlatformType platform, String postId) {
    return _publications.getAll().where((p) =>
        p.platform == platform && p.platformPostId == postId).firstOrNull;
  }

  Future<Publication> savePublication(Publication publication) async {
    final isNew = _publications.getById(publication.id) == null;
    return _publications.save(
      publication,
      actionLabel: isNew ? 'created' : 'updated',
      title: isNew
          ? 'Добавлена публикация «${publication.title}»'
          : 'Обновлена публикация «${publication.title}»',
    );
  }

  Future<void> deletePublication(Publication publication) async {
    for (final stats in getStats(publication.id)) {
      await _stats.delete(stats.id);
    }
    await _publications.delete(
      publication.id,
      title: 'Удалена публикация «${publication.title}»',
    );
  }

  List<PublicationStats> getStats(String publicationId) {
    final items = _stats
        .getAll()
        .where((s) => s.publicationId == publicationId)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return items;
  }

  PublicationStats? latestStats(String publicationId) {
    final items = getStats(publicationId);
    return items.isEmpty ? null : items.first;
  }

  Future<PublicationStats> addStats({
    required Publication publication,
    required int views,
    int likes = 0,
    int comments = 0,
    int shares = 0,
    int? reach,
    int? impressions,
    String source = 'manual',
    DateTime? recordedAt,
  }) async {
    final stats = PublicationStats(
      id: _uuid.v4(),
      userId: publication.userId,
      publicationId: publication.id,
      views: views,
      likes: likes,
      comments: comments,
      shares: shares,
      reach: reach,
      impressions: impressions,
      source: source,
      recordedAt: recordedAt ?? DateTime.now(),
    );
    await _stats.append(stats);
    return stats;
  }

  List<PublicationWithStats> ranked({
    PlatformType? platform,
    int limit = 10,
  }) =>
      rankPublications(
        getPublications(platform: platform),
        _stats.getAll(),
        platform: platform,
        limit: limit,
      );

  List<Publication> publicationsInPeriod(
    DateTime start,
    DateTime end, {
    PlatformType? platform,
  }) =>
      getPublications(platform: platform, start: start, end: end);
}
