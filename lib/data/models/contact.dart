import 'package:media_crm/core/utils/json_utils.dart';

enum ContactType { advertiser, subscriber, partner, other }

extension ContactTypeInfo on ContactType {
  String get label => switch (this) {
        ContactType.advertiser => 'Рекламодатель',
        ContactType.subscriber => 'Подписчик',
        ContactType.partner => 'Партнёр',
        ContactType.other => 'Другое',
      };
}

enum ContactSource {
  youtube,
  telegram,
  boosty,
  vk,
  github,
  website,
  manual,
  referral,
  import,
}

extension ContactSourceInfo on ContactSource {
  String get label => switch (this) {
        ContactSource.youtube => 'YouTube',
        ContactSource.telegram => 'Telegram',
        ContactSource.boosty => 'Boosty',
        ContactSource.vk => 'ВКонтакте',
        ContactSource.github => 'GitHub',
        ContactSource.website => 'Сайт',
        ContactSource.manual => 'Добавлен вручную',
        ContactSource.referral => 'Партнёрская ссылка',
        ContactSource.import => 'Импорт',
      };
}

class Contact {
  final String id;
  final String userId;
  final String name;
  final String? email;
  final String? phone;
  final String? company;
  final ContactType type;
  final ContactSource? source;
  final String? notes;
  final List<String> tags;
  final String? telegram;
  final String? socialUrl;
  final DateTime? lastContactAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Contact({
    required this.id,
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.company,
    this.type = ContactType.other,
    this.source,
    this.notes,
    this.tags = const [],
    this.telegram,
    this.socialUrl,
    this.lastContactAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        name: parseRequiredString(json['name'], 'Без имени'),
        email: parseString(json['email']),
        phone: parseString(json['phone']),
        company: parseString(json['company']),
        type: enumByName(ContactType.values, json['type'], ContactType.other),
        source: json['source'] == null
            ? null
            : enumByName(
                ContactSource.values,
                json['source'],
                ContactSource.manual,
              ),
        notes: parseString(json['notes']),
        tags: parseStringList(json['tags']),
        telegram: parseString(json['telegram']),
        socialUrl: parseString(json['social_url']),
        lastContactAt: parseDate(json['last_contact_at']),
        createdAt: parseDateOrNow(json['created_at']),
        updatedAt: parseDateOrNow(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'company': company,
        'type': type.name,
        'source': source?.name,
        'notes': notes,
        'tags': tags,
        'telegram': telegram,
        'social_url': socialUrl,
        'last_contact_at': isoDateTimeOrNull(lastContactAt),
        'created_at': isoDateTime(createdAt),
        'updated_at': isoDateTime(updatedAt),
      };

  Contact copyWith({
    String? name,
    String? email,
    String? phone,
    String? company,
    ContactType? type,
    ContactSource? source,
    String? notes,
    List<String>? tags,
    String? telegram,
    String? socialUrl,
    DateTime? lastContactAt,
    DateTime? updatedAt,
  }) {
    return Contact(
      id: id,
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      type: type ?? this.type,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      telegram: telegram ?? this.telegram,
      socialUrl: socialUrl ?? this.socialUrl,
      lastContactAt: lastContactAt ?? this.lastContactAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ContactInteraction {
  final String id;
  final String userId;
  final String contactId;
  final String type; // call, email, meeting, message, note
  final String? description;
  final DateTime date;
  final DateTime createdAt;

  const ContactInteraction({
    required this.id,
    required this.userId,
    required this.contactId,
    required this.type,
    this.description,
    required this.date,
    required this.createdAt,
  });

  factory ContactInteraction.fromJson(Map<String, dynamic> json) =>
      ContactInteraction(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        contactId: parseRequiredString(json['contact_id']),
        type: parseRequiredString(json['type'], 'note'),
        description: parseString(json['description']),
        date: parseDateOrNow(json['date']),
        createdAt: parseDateOrNow(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'contact_id': contactId,
        'type': type,
        'description': description,
        'date': isoDateTime(date),
        'created_at': isoDateTime(createdAt),
      };
}

class AudienceSegment {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final ContactType? contactType;
  final ContactSource? source;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AudienceSegment({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.contactType,
    this.source,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory AudienceSegment.fromJson(Map<String, dynamic> json) =>
      AudienceSegment(
        id: parseRequiredString(json['id']),
        userId: parseRequiredString(json['user_id']),
        name: parseRequiredString(json['name'], 'Сегмент'),
        description: parseString(json['description']),
        contactType: json['contact_type'] == null
            ? null
            : enumByName(
                ContactType.values,
                json['contact_type'],
                ContactType.other,
              ),
        source: json['source'] == null
            ? null
            : enumByName(
                ContactSource.values,
                json['source'],
                ContactSource.manual,
              ),
        tags: parseStringList(json['tags']),
        createdAt: parseDateOrNow(json['created_at']),
        updatedAt: parseDateOrNow(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'description': description,
        'contact_type': contactType?.name,
        'source': source?.name,
        'tags': tags,
        'created_at': isoDateTime(createdAt),
        'updated_at': isoDateTime(updatedAt),
      };

  bool matches(Contact contact) {
    if (contactType != null && contact.type != contactType) return false;
    if (source != null && contact.source != source) return false;
    if (tags.isNotEmpty && !contact.tags.any(tags.contains)) return false;
    return true;
  }
}
