import 'package:media_crm/core/utils/json_utils.dart';

class Funnel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Funnel({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Funnel.fromJson(Map<String, dynamic> json) => Funnel(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        name: parseRequiredString(json['name'], 'Воронка'),
        description: parseString(json['description']),
        createdAt: parseDateOrNow(json['created_at']),
        updatedAt: parseDateOrNow(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'description': description,
        'created_at': isoDateTime(createdAt),
        'updated_at': isoDateTime(updatedAt),
      };

  Funnel copyWith({
    String? name,
    String? description,
    DateTime? updatedAt,
  }) =>
      Funnel(
        id: id,
        userId: userId,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class FunnelStage {
  final String id;
  final String funnelId;
  final String userId;
  final String name;
  final int order;
  final String? color;

  const FunnelStage({
    required this.id,
    required this.funnelId,
    required this.userId,
    required this.name,
    required this.order,
    this.color,
  });

  factory FunnelStage.fromJson(Map<String, dynamic> json) => FunnelStage(
        id: parseRequiredString(json['id']),
        funnelId: parseRequiredString(json['funnel_id']),
        userId: parseRequiredString(json['user_id']),
        name: parseRequiredString(json['name'], 'Этап'),
        order: parseInt(json['order']),
        color: parseString(json['color']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'funnel_id': funnelId,
        'user_id': userId,
        'name': name,
        'order': order,
        'color': color,
      };

  FunnelStage copyWith({String? name, int? order, String? color}) =>
      FunnelStage(
        id: id,
        funnelId: funnelId,
        userId: userId,
        name: name ?? this.name,
        order: order ?? this.order,
        color: color ?? this.color,
      );
}

class FunnelDeal {
  final String id;
  final String userId;
  final String funnelId;
  final String stageId;
  final String contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? source;
  final String? notes;
  final double value;
  final String currency;
  final DateTime? expectedCloseDate;
  final DateTime createdAt;
  final DateTime? movedAt;
  final DateTime updatedAt;

  const FunnelDeal({
    required this.id,
    required this.userId,
    required this.funnelId,
    required this.stageId,
    required this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.source,
    this.notes,
    this.value = 0,
    this.currency = 'RUB',
    this.expectedCloseDate,
    required this.createdAt,
    this.movedAt,
    required this.updatedAt,
  });

  factory FunnelDeal.fromJson(Map<String, dynamic> json) => FunnelDeal(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        funnelId: parseRequiredString(json['funnel_id']),
        stageId: parseRequiredString(json['stage_id']),
        contactName:
            parseRequiredString(json['contact_name'], 'Без контакта'),
        contactEmail: parseString(json['contact_email']),
        contactPhone: parseString(json['contact_phone']),
        source: parseString(json['source']),
        notes: parseString(json['notes']),
        value: parseDouble(json['value']),
        currency: parseRequiredString(json['currency'], 'RUB'),
        expectedCloseDate: parseDate(json['expected_close_date']),
        createdAt: parseDateOrNow(json['created_at']),
        movedAt: parseDate(json['moved_at']),
        updatedAt: parseDateOrNow(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'funnel_id': funnelId,
        'stage_id': stageId,
        'contact_name': contactName,
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'source': source,
        'notes': notes,
        'value': value,
        'currency': currency,
        'expected_close_date': isoDateOrNull(expectedCloseDate),
        'created_at': isoDateTime(createdAt),
        'moved_at': isoDateTimeOrNull(movedAt),
        'updated_at': isoDateTime(updatedAt),
      };

  FunnelDeal copyWith({
    String? stageId,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    String? source,
    String? notes,
    double? value,
    String? currency,
    DateTime? expectedCloseDate,
    DateTime? movedAt,
    DateTime? updatedAt,
  }) {
    return FunnelDeal(
      id: id,
      userId: userId,
      funnelId: funnelId,
      stageId: stageId ?? this.stageId,
      contactName: contactName ?? this.contactName,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      value: value ?? this.value,
      currency: currency ?? this.currency,
      expectedCloseDate: expectedCloseDate ?? this.expectedCloseDate,
      createdAt: createdAt,
      movedAt: movedAt ?? this.movedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FunnelStageMetrics {
  final FunnelStage stage;
  final int deals;
  final double value;
  final int lostFromPrevious;
  final double conversionFromPrevious;

  const FunnelStageMetrics({
    required this.stage,
    required this.deals,
    required this.value,
    required this.lostFromPrevious,
    required this.conversionFromPrevious,
  });
}

List<FunnelStageMetrics> calculateFunnelMetrics(
  List<FunnelStage> stages,
  List<FunnelDeal> deals,
) {
  final sorted = [...stages]..sort((a, b) => a.order.compareTo(b.order));
  final metrics = <FunnelStageMetrics>[];
  var previousDeals = 0;
  for (var i = 0; i < sorted.length; i++) {
    final stage = sorted[i];
    final stageDeals = deals.where((d) => d.stageId == stage.id).toList();
    final value = stageDeals.fold<double>(0, (sum, d) => sum + d.value);
    final lost = i == 0 ? 0 : (previousDeals - stageDeals.length).clamp(0, 1 << 30);
    final conversion = i == 0 || previousDeals == 0
        ? (i == 0 ? 100.0 : 0.0)
        : stageDeals.length / previousDeals * 100;
    metrics.add(FunnelStageMetrics(
      stage: stage,
      deals: stageDeals.length,
      value: value,
      lostFromPrevious: lost,
      conversionFromPrevious: conversion,
    ));
    previousDeals = stageDeals.length;
  }
  return metrics;
}
