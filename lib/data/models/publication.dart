import 'package:media_crm/core/utils/json_utils.dart';
import 'package:media_crm/data/models/platform_channel.dart';

enum PublicationType { video, post, article, release, stream, other }

extension PublicationTypeInfo on PublicationType {
  String get label => switch (this) {
        PublicationType.video => 'Видео',
        PublicationType.post => 'Пост',
        PublicationType.article => 'Статья',
        PublicationType.release => 'Релиз',
        PublicationType.stream => 'Стрим',
        PublicationType.other => 'Публикация',
      };
}

class Publication {
  final String id;
  final String userId;
  final PlatformType platform;
  final String? channelId;
  final String? platformPostId;
  final String title;
  final String? content;
  final String? imageUrl;
  final String? url;
  final PublicationType type;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Publication({
    required this.id,
    required this.userId,
    required this.platform,
    this.channelId,
    this.platformPostId,
    required this.title,
    this.content,
    this.imageUrl,
    this.url,
    this.type = PublicationType.post,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  String get externalKey => platformPostId ?? id;

  factory Publication.fromJson(Map<String, dynamic> json) => Publication(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        platform: enumByName(
          PlatformType.values,
          json['platform'],
          PlatformType.youtube,
        ),
        channelId: parseString(json['channel_id']),
        platformPostId: parseString(json['platform_post_id']),
        title: parseRequiredString(json['title'], 'Без названия'),
        content: parseString(json['content']),
        imageUrl: parseString(json['image_url']),
        url: parseString(json['url']),
        type: enumByName(
          PublicationType.values,
          json['type'],
          PublicationType.post,
        ),
        publishedAt: parseDateOrNow(json['published_at']),
        createdAt: parseDateOrNow(json['created_at']),
        updatedAt: parseDateOrNow(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'platform': platform.name,
        'channel_id': channelId,
        'platform_post_id': platformPostId,
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'url': url,
        'type': type.name,
        'published_at': isoDateTime(publishedAt),
        'created_at': isoDateTime(createdAt),
        'updated_at': isoDateTime(updatedAt),
      };

  Publication copyWith({
    String? channelId,
    String? platformPostId,
    String? title,
    String? content,
    String? imageUrl,
    String? url,
    PlatformType? platform,
    PublicationType? type,
    DateTime? publishedAt,
    DateTime? updatedAt,
  }) {
    return Publication(
      id: id,
      userId: userId,
      platform: platform ?? this.platform,
      channelId: channelId ?? this.channelId,
      platformPostId: platformPostId ?? this.platformPostId,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      url: url ?? this.url,
      type: type ?? this.type,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PublicationStats {
  final String id;
  final String userId;
  final String publicationId;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final int? reach;
  final int? impressions;
  final String source;
  final DateTime recordedAt;

  const PublicationStats({
    required this.id,
    required this.userId,
    required this.publicationId,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.reach,
    this.impressions,
    this.source = 'api',
    required this.recordedAt,
  });

  int get engagement => likes + comments + shares;

  factory PublicationStats.fromJson(Map<String, dynamic> json) =>
      PublicationStats(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        publicationId: parseRequiredString(json['publication_id']),
        views: parseInt(json['views']),
        likes: parseInt(json['likes']),
        comments: parseInt(json['comments']),
        shares: parseInt(json['shares']),
        reach: parseIntOrNull(json['reach']),
        impressions: parseIntOrNull(json['impressions']),
        source: parseRequiredString(json['source'], 'api'),
        recordedAt: parseDateOrNow(json['recorded_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'publication_id': publicationId,
        'views': views,
        'likes': likes,
        'comments': comments,
        'shares': shares,
        'reach': reach,
        'impressions': impressions,
        'source': source,
        'recorded_at': isoDateTime(recordedAt),
      };
}
