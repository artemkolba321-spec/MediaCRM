import 'package:uuid/uuid.dart';

import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/contact.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';

class ContactRepository {
  ContactRepository({
    required LocalStore store,
    required CloudService cloud,
    required ActivityService activity,
  }) {
    _contacts = EntityRepository<Contact>(
      store: store,
      cloud: cloud,
      collection: 'contacts',
      fromJson: Contact.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.updatedAt,
      activity: activity,
    );
    _interactions = EntityRepository<ContactInteraction>(
      store: store,
      cloud: cloud,
      collection: 'interactions',
      fromJson: ContactInteraction.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.createdAt,
    );
    _segments = EntityRepository<AudienceSegment>(
      store: store,
      cloud: cloud,
      collection: 'segments',
      fromJson: AudienceSegment.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.updatedAt,
      activity: activity,
    );
  }

  late final EntityRepository<Contact> _contacts;
  late final EntityRepository<ContactInteraction> _interactions;
  late final EntityRepository<AudienceSegment> _segments;
  final _uuid = const Uuid();

  List<Contact> getContacts({
    String? search,
    ContactType? type,
    ContactSource? source,
    Set<String> tags = const {},
    String sortBy = 'updated',
  }) {
    var items = _contacts.getAll();
    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      items = items
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              (c.email ?? '').toLowerCase().contains(q) ||
              (c.phone ?? '').toLowerCase().contains(q) ||
              (c.company ?? '').toLowerCase().contains(q) ||
              c.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }
    if (type != null) items = items.where((c) => c.type == type).toList();
    if (source != null) items = items.where((c) => c.source == source).toList();
    if (tags.isNotEmpty) {
      items = items.where((c) => c.tags.any(tags.contains)).toList();
    }
    switch (sortBy) {
      case 'name':
        items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'created':
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      default:
        items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return items;
  }

  Contact? getContact(String id) => _contacts.getById(id);

  Future<Contact> saveContact(Contact contact) async {
    final isNew = _contacts.getById(contact.id) == null;
    return _contacts.save(
      contact,
      actionLabel: isNew ? 'created' : 'updated',
      title: isNew
          ? 'Добавлен контакт «${contact.name}»'
          : 'Обновлён контакт «${contact.name}»',
    );
  }

  Future<void> deleteContact(Contact contact) async {
    for (final interaction in getInteractions(contact.id)) {
      await _interactions.delete(interaction.id);
    }
    await _contacts.delete(
      contact.id,
      title: 'Удалён контакт «${contact.name}»',
    );
  }

  List<ContactInteraction> getInteractions(String contactId) {
    final items = _interactions
        .getAll()
        .where((e) => e.contactId == contactId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Future<ContactInteraction> addInteraction(
    Contact contact, {
    required String type,
    String? description,
    DateTime? date,
  }) async {
    final now = DateTime.now();
    final interaction = ContactInteraction(
      id: _uuid.v4(),
      userId: contact.userId,
      contactId: contact.id,
      type: type,
      description: description,
      date: date ?? now,
      createdAt: now,
    );
    await _interactions.append(interaction);
    await _contacts.save(contact.copyWith(
      lastContactAt: interaction.date,
      updatedAt: now,
    ));
    return interaction;
  }

  Future<void> deleteInteraction(ContactInteraction interaction) =>
      _interactions.delete(interaction.id);

  List<AudienceSegment> getSegments() {
    final items = _segments.getAll()
      ..sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  int segmentSize(AudienceSegment segment) =>
      getContacts().where(segment.matches).length;

  Future<AudienceSegment> saveSegment(AudienceSegment segment) =>
      _segments.save(
        segment,
        actionLabel: 'updated',
        title: 'Сегмент аудитории «${segment.name}»',
      );

  Future<void> deleteSegment(AudienceSegment segment) =>
      _segments.delete(segment.id);

  String exportContactsCsv(List<Contact> contacts) {
    final rows = <List<Object?>>[
      ['name', 'type', 'source', 'email', 'phone', 'company', 'tags', 'notes',
        'last_contact_at', 'created_at'],
      for (final contact in contacts)
        [
          contact.name,
          contact.type.label,
          contact.source?.label ?? '',
          contact.email ?? '',
          contact.phone ?? '',
          contact.company ?? '',
          contact.tags.join('; '),
          contact.notes ?? '',
          contact.lastContactAt?.formatDateTime() ?? '',
          contact.createdAt.formatDateTime(),
        ],
    ];
    return buildCsv(rows);
  }
}
