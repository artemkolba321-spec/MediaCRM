import 'package:media_crm/core/utils/json_utils.dart';

enum PartnerStatus { active, pending, inactive, suspended }

extension PartnerStatusInfo on PartnerStatus {
  String get label => switch (this) {
        PartnerStatus.active => 'Активный',
        PartnerStatus.pending => 'На согласовании',
        PartnerStatus.inactive => 'Неактивный',
        PartnerStatus.suspended => 'Приостановлен',
      };
}

enum PartnerEventType { click, registration, sale, refund }

extension PartnerEventTypeInfo on PartnerEventType {
  String get label => switch (this) {
        PartnerEventType.click => 'Переход по ссылке',
        PartnerEventType.registration => 'Регистрация',
        PartnerEventType.sale => 'Подтверждённая продажа',
        PartnerEventType.refund => 'Возврат',
      };
}

class Partner {
  final String id;
  final String userId;
  final String name;
  final String? company;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? website;
  final String? notes;
  final PartnerStatus status;
  final String? promoCode;
  final String? referralLink;
  final double commissionRate;
  final int clicks;
  final int registrations;
  final int confirmedSales;
  final double totalCommission;
  final double paidCommission;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Partner({
    required this.id,
    required this.userId,
    required this.name,
    this.company,
    this.contactPerson,
    this.email,
    this.phone,
    this.website,
    this.notes,
    this.status = PartnerStatus.pending,
    this.promoCode,
    this.referralLink,
    this.commissionRate = 10,
    this.clicks = 0,
    this.registrations = 0,
    this.confirmedSales = 0,
    this.totalCommission = 0,
    this.paidCommission = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  double get outstandingCommission => totalCommission - paidCommission;

  factory Partner.fromJson(Map<String, dynamic> json) => Partner(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        name: parseRequiredString(json['name'], 'Без имени'),
        company: parseString(json['company']),
        contactPerson: parseString(json['contact_person']),
        email: parseString(json['email']),
        phone: parseString(json['phone']),
        website: parseString(json['website']),
        notes: parseString(json['notes']),
        status: enumByName(
          PartnerStatus.values,
          json['status'],
          PartnerStatus.pending,
        ),
        promoCode: parseString(json['promo_code']),
        referralLink: parseString(json['referral_link']),
        commissionRate: parseDouble(json['commission_rate'], 10),
        clicks: parseInt(json['clicks']),
        registrations: parseInt(json['registrations']),
        confirmedSales: parseInt(json['confirmed_sales']),
        totalCommission: parseDouble(json['total_commission']),
        paidCommission: parseDouble(json['paid_commission']),
        createdAt: parseDateOrNow(json['created_at']),
        updatedAt: parseDateOrNow(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'company': company,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'website': website,
        'notes': notes,
        'status': status.name,
        'promo_code': promoCode,
        'referral_link': referralLink,
        'commission_rate': commissionRate,
        'clicks': clicks,
        'registrations': registrations,
        'confirmed_sales': confirmedSales,
        'total_commission': totalCommission,
        'paid_commission': paidCommission,
        'created_at': isoDateTime(createdAt),
        'updated_at': isoDateTime(updatedAt),
      };

  Partner copyWith({
    String? id,
    String? userId,
    String? name,
    String? company,
    String? contactPerson,
    String? email,
    String? phone,
    String? website,
    String? notes,
    PartnerStatus? status,
    String? promoCode,
    String? referralLink,
    double? commissionRate,
    int? clicks,
    int? registrations,
    int? confirmedSales,
    double? totalCommission,
    double? paidCommission,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Partner(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      company: company ?? this.company,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      promoCode: promoCode ?? this.promoCode,
      referralLink: referralLink ?? this.referralLink,
      commissionRate: commissionRate ?? this.commissionRate,
      clicks: clicks ?? this.clicks,
      registrations: registrations ?? this.registrations,
      confirmedSales: confirmedSales ?? this.confirmedSales,
      totalCommission: totalCommission ?? this.totalCommission,
      paidCommission: paidCommission ?? this.paidCommission,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PartnerEvent {
  final String id;
  final String userId;
  final String partnerId;
  final PartnerEventType type;
  final double amount;
  final String currency;
  final double commission;
  final bool confirmed;
  final String? note;
  final DateTime occurredAt;
  final DateTime createdAt;

  const PartnerEvent({
    required this.id,
    required this.userId,
    required this.partnerId,
    required this.type,
    this.amount = 0,
    this.currency = 'RUB',
    this.commission = 0,
    this.confirmed = false,
    this.note,
    required this.occurredAt,
    required this.createdAt,
  });

  factory PartnerEvent.fromJson(Map<String, dynamic> json) => PartnerEvent(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        partnerId: parseRequiredString(json['partner_id']),
        type: enumByName(
          PartnerEventType.values,
          json['type'],
          PartnerEventType.click,
        ),
        amount: parseDouble(json['amount']),
        currency: parseRequiredString(json['currency'], 'RUB'),
        commission: parseDouble(json['commission']),
        confirmed: parseBool(json['confirmed']),
        note: parseString(json['note']),
        occurredAt: parseDateOrNow(json['occurred_at']),
        createdAt: parseDateOrNow(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'partner_id': partnerId,
        'type': type.name,
        'amount': amount,
        'currency': currency,
        'commission': commission,
        'confirmed': confirmed,
        'note': note,
        'occurred_at': isoDateTime(occurredAt),
        'created_at': isoDateTime(createdAt),
      };
}
