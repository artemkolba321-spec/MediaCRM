import 'package:media_crm/core/utils/json_utils.dart';
import 'package:media_crm/data/models/platform_channel.dart';

enum SyncRunStatus { running, success, error, skipped }

enum SyncTrigger { manual, scheduled, retry, import }

class SyncRun {
  final String id;
  final String userId;
  final String? channelId;
  final PlatformType platform;
  final SyncRunStatus status;
  final SyncTrigger trigger;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? message;
  final int metricsWritten;
  final int publicationsWritten;
  final int retryCount;

  const SyncRun({
    required this.id,
    required this.userId,
    this.channelId,
    required this.platform,
    required this.status,
    required this.trigger,
    required this.startedAt,
    this.finishedAt,
    this.message,
    this.metricsWritten = 0,
    this.publicationsWritten = 0,
    this.retryCount = 0,
  });

  Duration? get duration =>
      finishedAt?.difference(startedAt);

  factory SyncRun.fromJson(Map<String, dynamic> json) {
    return SyncRun(
      id: parseRequiredString(json['id']),
      userId: parseRequiredString(json['user_id']),
      channelId: parseString(json['channel_id']),
      platform: enumByName(
        PlatformType.values,
        json['platform'],
        PlatformType.youtube,
      ),
      status: enumByName(
        SyncRunStatus.values,
        json['status'],
        SyncRunStatus.error,
      ),
      trigger: enumByName(
        SyncTrigger.values,
        json['trigger'],
        SyncTrigger.manual,
      ),
      startedAt: parseDateOrNow(json['started_at']),
      finishedAt: parseDate(json['finished_at']),
      message: parseString(json['message']),
      metricsWritten: parseInt(json['metrics_written']),
      publicationsWritten: parseInt(json['publications_written']),
      retryCount: parseInt(json['retry_count']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'channel_id': channelId,
        'platform': platform.name,
        'status': status.name,
        'trigger': trigger.name,
        'started_at': isoDateTime(startedAt),
        'finished_at': isoDateTimeOrNull(finishedAt),
        'message': message,
        'metrics_written': metricsWritten,
        'publications_written': publicationsWritten,
        'retry_count': retryCount,
      };
}

class AudienceDemographic {
  final String id;
  final String userId;
  final String? channelId;
  final PlatformType platform;
  final String dimension; // gender, age, country, city, device
  final String bucket;
  final double value;
  final DateTime date;
  final String source;

  const AudienceDemographic({
    required this.id,
    required this.userId,
    this.channelId,
    required this.platform,
    required this.dimension,
    required this.bucket,
    required this.value,
    required this.date,
    required this.source,
  });

  factory AudienceDemographic.fromJson(Map<String, dynamic> json) {
    return AudienceDemographic(
      id: parseRequiredString(json['id']),
      userId: parseRequiredString(json['user_id']),
      channelId: parseString(json['channel_id']),
      platform: enumByName(
        PlatformType.values,
        json['platform'],
        PlatformType.youtube,
      ),
      dimension: parseRequiredString(json['dimension']),
      bucket: parseRequiredString(json['bucket']),
      value: parseDouble(json['value']),
      date: parseDateOrNow(json['date']),
      source: parseRequiredString(json['source'], 'api'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'channel_id': channelId,
        'platform': platform.name,
        'dimension': dimension,
        'bucket': bucket,
        'value': value,
        'date': isoDate(date),
        'source': source,
      };
}
