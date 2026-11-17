import 'package:media_crm/core/utils/json_utils.dart';

enum AdvertiserStatus { active, inactive, blocked }

extension AdvertiserStatusInfo on AdvertiserStatus {
  String get label => switch (this) {
        AdvertiserStatus.active => 'Активный',
        AdvertiserStatus.inactive => 'Неактивный',
        AdvertiserStatus.blocked => 'Заблокирован',
      };
}

enum CampaignStatus { planned, active, completed, cancelled }

extension CampaignStatusInfo on CampaignStatus {
  String get label => switch (this) {
        CampaignStatus.planned => 'Запланирована',
        CampaignStatus.active => 'Активна',
        CampaignStatus.completed => 'Завершена',
        CampaignStatus.cancelled => 'Отменена',
      };
}

class Advertiser {
  final String id;
  final String userId;
  final String companyName;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? website;
  final String? industry;
  final String? notes;
  final AdvertiserStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Advertiser({
    required this.id,
    required this.userId,
    required this.companyName,
    this.contactPerson,
    this.email,
    this.phone,
    this.website,
    this.industry,
    this.notes,
    this.status = AdvertiserStatus.inactive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Advertiser.fromJson(Map<String, dynamic> json) => Advertiser(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        companyName: parseRequiredString(json['company_name'], 'Без названия'),
        contactPerson: parseString(json['contact_person']),
        email: parseString(json['email']),
        phone: parseString(json['phone']),
        website: parseString(json['website']),
        industry: parseString(json['industry']),
        notes: parseString(json['notes']),
        status: enumByName(
          AdvertiserStatus.values,
          json['status'],
          AdvertiserStatus.inactive,
        ),
        createdAt: parseDateOrNow(json['created_at']),
        updatedAt: parseDateOrNow(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'company_name': companyName,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'website': website,
        'industry': industry,
        'notes': notes,
        'status': status.name,
        'created_at': isoDateTime(createdAt),
        'updated_at': isoDateTime(updatedAt),
      };

  Advertiser copyWith({
    String? companyName,
    String? contactPerson,
    String? email,
    String? phone,
    String? website,
    String? industry,
    String? notes,
    AdvertiserStatus? status,
    DateTime? updatedAt,
  }) {
    return Advertiser(
      id: id,
      userId: userId,
      companyName: companyName ?? this.companyName,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      industry: industry ?? this.industry,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AdCampaign {
  final String id;
  final String advertiserId;
  final String userId;
  final String name;
  final String? description;
  final CampaignStatus status;
  final double budget;
  final double paidAmount;
  final String currency;
  final double exchangeRate;
  final List<String> channelIds;
  final String? deliverables;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdCampaign({
    required this.id,
    required this.advertiserId,
    required this.userId,
    required this.name,
    this.description,
    this.status = CampaignStatus.planned,
    required this.budget,
    this.paidAmount = 0,
    this.currency = 'RUB',
    this.exchangeRate = 1,
    this.channelIds = const [],
    this.deliverables,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  double get debt => (budget - paidAmount).clamp(0, double.infinity);

  factory AdCampaign.fromJson(Map<String, dynamic> json) => AdCampaign(
        id: parseRequiredString(json['id']),
        advertiserId: parseRequiredString(json['advertiser_id']),
        userId: parseRequiredString(json['user_id']),
        name: parseRequiredString(json['name'], 'Кампания'),
        description: parseString(json['description']),
        status: enumByName(
          CampaignStatus.values,
          json['status'],
          CampaignStatus.planned,
        ),
        budget: parseDouble(json['budget']),
        paidAmount: parseDouble(json['paid_amount']),
        currency: parseRequiredString(json['currency'], 'RUB'),
        exchangeRate: parseDouble(json['exchange_rate'], 1),
        channelIds: parseStringList(json['channel_ids']),
        deliverables: parseString(json['deliverables']),
        startDate: parseDateOrNow(json['start_date']),
        endDate: parseDateOrNow(json['end_date']),
        createdAt: parseDateOrNow(json['created_at']),
        updatedAt: parseDateOrNow(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'advertiser_id': advertiserId,
        'user_id': userId,
        'name': name,
        'description': description,
        'status': status.name,
        'budget': budget,
        'paid_amount': paidAmount,
        'currency': currency,
        'exchange_rate': exchangeRate,
        'channel_ids': channelIds,
        'deliverables': deliverables,
        'start_date': isoDate(startDate),
        'end_date': isoDate(endDate),
        'created_at': isoDateTime(createdAt),
        'updated_at': isoDateTime(updatedAt),
      };

  AdCampaign copyWith({
    String? advertiserId,
    String? name,
    String? description,
    CampaignStatus? status,
    double? budget,
    double? paidAmount,
    String? currency,
    double? exchangeRate,
    List<String>? channelIds,
    String? deliverables,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? updatedAt,
  }) {
    return AdCampaign(
      id: id,
      advertiserId: advertiserId ?? this.advertiserId,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      budget: budget ?? this.budget,
      paidAmount: paidAmount ?? this.paidAmount,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      channelIds: channelIds ?? this.channelIds,
      deliverables: deliverables ?? this.deliverables,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AdvertiserNote {
  final String id;
  final String userId;
  final String advertiserId;
  final String text;
  final DateTime createdAt;

  const AdvertiserNote({
    required this.id,
    required this.userId,
    required this.advertiserId,
    required this.text,
    required this.createdAt,
  });

  factory AdvertiserNote.fromJson(Map<String, dynamic> json) => AdvertiserNote(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        advertiserId: parseRequiredString(json['advertiser_id']),
        text: parseRequiredString(json['text']),
        createdAt: parseDateOrNow(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'advertiser_id': advertiserId,
        'text': text,
        'created_at': isoDateTime(createdAt),
      };
}

class CampaignDocument {
  final String id;
  final String userId;
  final String advertiserId;
  final String campaignId;
  final String name;
  final String? url;
  final String? notes;
  final DateTime createdAt;

  const CampaignDocument({
    required this.id,
    required this.userId,
    required this.advertiserId,
    required this.campaignId,
    required this.name,
    this.url,
    this.notes,
    required this.createdAt,
  });

  factory CampaignDocument.fromJson(Map<String, dynamic> json) =>
      CampaignDocument(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        advertiserId: parseRequiredString(json['advertiser_id']),
        campaignId: parseRequiredString(json['campaign_id']),
        name: parseRequiredString(json['name'], 'Документ'),
        url: parseString(json['url']),
        notes: parseString(json['notes']),
        createdAt: parseDateOrNow(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'advertiser_id': advertiserId,
        'campaign_id': campaignId,
        'name': name,
        'url': url,
        'notes': notes,
        'created_at': isoDateTime(createdAt),
      };
}
