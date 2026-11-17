import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/export_utils.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/contact.dart';
import 'package:media_crm/providers/app_providers.dart';

class AudienceScreen extends ConsumerStatefulWidget {
  const AudienceScreen({super.key});

  @override
  ConsumerState<AudienceScreen> createState() => _AudienceScreenState();
}

class _AudienceScreenState extends ConsumerState<AudienceScreen> {
  final _search = TextEditingController();
  int _tab = 0;
  ContactType? _typeFilter;
  ContactSource? _sourceFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(contactRepositoryProvider);
    final contacts = repo.getContacts(
      search: _search.text,
      type: _typeFilter,
      source: _sourceFilter,
    );
    final all = repo.getContacts();
    final segments = repo.getSegments();
    final colors = context.colors;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Аудитория',
            subtitle:
                'Контакты, история взаимодействий и сегменты. Все записи '
                'хранятся локально и синхронизируются с облаком при наличии '
                'аккаунта.',
            actions: [
              OutlinedButton.icon(
                onPressed: all.isEmpty ? null : _exportCsv,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Экспорт CSV'),
              ),
              FilledButton.icon(
                onPressed: _tab == 0 ? () => _openContactForm() : _openSegmentForm,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(_tab == 0 ? 'Добавить контакт' : 'Новый сегмент'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedTabs(
            tabs: ['Контакты (${all.length})', 'Сегменты (${segments.length})'],
            selected: _tab,
            onChanged: (index) => setState(() => _tab = index),
          ),
          const SizedBox(height: 14),
          if (_tab == 0) ...[
            FilterBarShell(
              children: [
                SizedBox(
                  width: 260,
                  child: SearchField(
                    controller: _search,
                    hint: 'Имя, email, телефон, тег…',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                _dropdown<ContactType>(
                  value: _typeFilter,
                  hint: 'Все типы',
                  values: ContactType.values,
                  labelOf: (value) => value.label,
                  onChanged: (value) => setState(() => _typeFilter = value),
                ),
                _dropdown<ContactSource>(
                  value: _sourceFilter,
                  hint: 'Все источники',
                  values: ContactSource.values,
                  labelOf: (value) => value.label,
                  onChanged: (value) => setState(() => _sourceFilter = value),
                ),
                Text(
                  '${contacts.length} из ${all.length}',
                  style: TextStyle(color: colors.muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (all.isEmpty)
              EmptyState(
                title: 'Контактов пока нет',
                message:
                    'Добавьте рекламодателей, подписчиков и партнёров вручную '
                    'или импортируйте из резервной копии. Автоматического '
                    'импорта персональных данных из площадок нет.',
                icon: Icons.people_outline_rounded,
                action: FilledButton.icon(
                  onPressed: () => _openContactForm(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Добавить контакт'),
                ),
              )
            else if (contacts.isEmpty)
              const EmptyState(
                title: 'Ничего не найдено',
                message: 'Измените запрос или фильтры.',
                icon: Icons.search_off_rounded,
                compact: true,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1100
                      ? 3
                      : constraints.maxWidth >= 700
                          ? 2
                          : 1;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final contact in contacts)
                        SizedBox(
                          width: width,
                          child: _ContactCard(
                            contact: contact,
                            onOpen: () => _openContactPanel(contact),
                            onEdit: () => _openContactForm(contact: contact),
                            onDelete: () => _deleteContact(contact),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            const DataSourceNote(
              text:
                  'Персональные данные подписчиков не запрашиваются у площадок '
                  'автоматически: официальные API не предоставляют списки '
                  'подписчиков. Контакты добавляются вручную или импортом.',
            ),
          ] else ...[
            if (segments.isEmpty)
              EmptyState(
                title: 'Сегментов пока нет',
                message:
                    'Сегмент — это сохранённый фильтр по типу, источнику и '
                    'тегам. Размер пересчитывается по текущим контактам.',
                icon: Icons.segment_rounded,
                action: FilledButton.icon(
                  onPressed: _openSegmentForm,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Создать сегмент'),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1100
                      ? 3
                      : constraints.maxWidth >= 700
                          ? 2
                          : 1;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final segment in segments)
                        SizedBox(
                          width: width,
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconSquare(
                                      icon: Icons.segment_rounded,
                                      color: colors.accent,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        segment.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      tooltip: 'Действия',
                                      icon: Icon(Icons.more_vert_rounded,
                                          size: 17, color: colors.muted),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _openSegmentForm(segment: segment);
                                        } else if (value == 'delete') {
                                          _deleteSegment(segment);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Редактировать'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Удалить'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (segment.description != null) ...[
                                  const SizedBox(height: 7),
                                  Text(
                                    segment.description!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 11.5,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
                                  children: [
                                    if (segment.contactType != null)
                                      Pill(
                                        label: segment.contactType!.label,
                                        color: colors.accent,
                                      ),
                                    if (segment.source != null)
                                      Pill(
                                        label: segment.source!.label,
                                        color: colors.blue,
                                      ),
                                    for (final tag in segment.tags)
                                      Pill(
                                        label: tag,
                                        color: colors.yellow,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    MiniStat(
                                      label: 'Контактов в сегменте',
                                      value:
                                          '${repo.segmentSize(segment)}',
                                      color: colors.accent,
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _typeFilter = segment.contactType;
                                          _sourceFilter = segment.source;
                                          _search.text = segment.tags.isEmpty
                                              ? ''
                                              : segment.tags.first;
                                          _tab = 0;
                                        });
                                      },
                                      child: const Text('Показать'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            const DataSourceNote(
              text:
                  'Сегменты не копируют контакты: они пересчитываются по '
                  'текущим данным при каждом открытии. Теги задаются вручную.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<T> values,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
  }) {
    final colors = context.colors;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isDense: true,
          dropdownColor: colors.panel,
          hint: Text(hint,
              style: TextStyle(fontSize: 11.5, color: colors.muted)),
          style: TextStyle(fontSize: 11.5, color: colors.text),
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: Text(hint,
                  style: TextStyle(fontSize: 11.5, color: colors.muted)),
            ),
            for (final item in values)
              DropdownMenuItem<T?>(
                value: item,
                child: Text(labelOf(item),
                    style: TextStyle(fontSize: 11.5, color: colors.text)),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final repo = ref.read(contactRepositoryProvider);
    final contacts = repo.getContacts();
    final csv = repo.exportContactsCsv(contacts);
    final result = await exportTextFile(
      fileName: 'mediacrm-contacts.csv',
      content: csv,
    );
    if (!mounted) return;
    showAppSnack(context, result.message, error: !result.ok);
  }

  Future<void> _openContactForm({Contact? contact}) async {
    final name = TextEditingController(text: contact?.name ?? '');
    final email = TextEditingController(text: contact?.email ?? '');
    final phone = TextEditingController(text: contact?.phone ?? '');
    final company = TextEditingController(text: contact?.company ?? '');
    final telegram = TextEditingController(text: contact?.telegram ?? '');
    final social = TextEditingController(text: contact?.socialUrl ?? '');
    final tags = TextEditingController(text: contact?.tags.join(', ') ?? '');
    final notes = TextEditingController(text: contact?.notes ?? '');
    var type = contact?.type ?? ContactType.other;
    var source = contact?.source ?? ContactSource.manual;

    try {
      await showFormDialog(
        context,
        title: contact == null ? 'Новый контакт' : 'Контакт',
        description:
            'Email, телефон и соцсети необязательны. Теги разделяйте запятыми.',
        submitLabel: contact == null ? 'Добавить' : 'Сохранить',
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Имя',
                child: TextField(
                  controller: name,
                  decoration: const InputDecoration(hintText: 'Как обращаться'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Тип',
                      child: DropdownButtonFormField<ContactType>(
                        value: type,
                        items: [
                          for (final item in ContactType.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => type = value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Источник',
                      child: DropdownButtonFormField<ContactSource>(
                        value: source,
                        items: [
                          for (final item in ContactSource.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => source = value);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Email',
                      child: TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            const InputDecoration(hintText: 'name@mail.ru'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Телефон',
                      child: TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(hintText: '+7 …'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Компания',
                child: TextField(controller: company),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Telegram',
                      child: TextField(
                        controller: telegram,
                        decoration:
                            const InputDecoration(hintText: '@username'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Соцсеть / сайт',
                      child: TextField(
                        controller: social,
                        keyboardType: TextInputType.url,
                        decoration:
                            const InputDecoration(hintText: 'https://…'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Теги',
                hint: 'через запятую',
                child: TextField(
                  controller: tags,
                  decoration:
                      const InputDecoration(hintText: 'vip, реклама, партнёр'),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Заметки',
                child: TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Необязательно'),
                ),
              ),
            ],
          ),
        ),
        onSubmit: () async {
          final trimmed = name.text.trim();
          if (trimmed.isEmpty) {
            throw const FormatException('Укажите имя контакта');
          }
          final auth = ref.read(authProvider);
          final now = DateTime.now();
          final repo = ref.read(contactRepositoryProvider);
          final entity = contact == null
              ? Contact(
                  id: const Uuid().v4(),
                  userId: auth.userId,
                  name: trimmed,
                  email: _nullIfEmpty(email.text),
                  phone: _nullIfEmpty(phone.text),
                  company: _nullIfEmpty(company.text),
                  type: type,
                  source: source,
                  telegram: _nullIfEmpty(telegram.text),
                  socialUrl: _nullIfEmpty(social.text),
                  tags: _parseTags(tags.text),
                  notes: _nullIfEmpty(notes.text),
                  createdAt: now,
                  updatedAt: now,
                )
              : contact.copyWith(
                  name: trimmed,
                  email: _nullIfEmpty(email.text),
                  phone: _nullIfEmpty(phone.text),
                  company: _nullIfEmpty(company.text),
                  type: type,
                  source: source,
                  telegram: _nullIfEmpty(telegram.text),
                  socialUrl: _nullIfEmpty(social.text),
                  tags: _parseTags(tags.text),
                  notes: _nullIfEmpty(notes.text),
                  updatedAt: now,
                );
          await repo.saveContact(entity);
          bumpData(ref);
        },
      );
    } finally {
      for (final controller in [
        name,
        email,
        phone,
        company,
        telegram,
        social,
        tags,
        notes,
      ]) {
        controller.dispose();
      }
    }
  }

  List<String> _parseTags(String raw) => raw
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _deleteContact(Contact contact) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить контакт?',
      message:
          'Контакт «${contact.name}» и вся история взаимодействий с ним будут '
          'удалены без возможности восстановления.',
    );
    if (!confirmed) return;
    await ref.read(contactRepositoryProvider).deleteContact(contact);
    if (!mounted) return;
    bumpData(ref);
    showAppSnack(context, 'Контакт удалён');
  }

  Future<void> _openContactPanel(Contact contact) async {
    await showSidePanel<void>(
      context,
      title: contact.name,
      subtitle: contact.type.label,
      child: _ContactPanel(
        contactId: contact.id,
        onChanged: () => bumpData(ref),
        onDeleted: () => Navigator.of(context).maybePop(),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openSegmentForm({AudienceSegment? segment}) async {
    final name = TextEditingController(text: segment?.name ?? '');
    final description = TextEditingController(text: segment?.description ?? '');
    final tags = TextEditingController(text: segment?.tags.join(', ') ?? '');
    var type = segment?.contactType;
    var source = segment?.source;

    try {
      await showFormDialog(
        context,
        title: segment == null ? 'Новый сегмент' : 'Сегмент',
        description:
            'Сегмент — сохранённый фильтр. Он не копирует контакты и '
            'пересчитывается автоматически.',
        submitLabel: segment == null ? 'Создать' : 'Сохранить',
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Название',
                child: TextField(
                  controller: name,
                  decoration: const InputDecoration(hintText: 'Например, VIP-рекламодатели'),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Описание',
                child: TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Необязательно'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Тип контакта',
                      child: DropdownButtonFormField<ContactType?>(
                        value: type,
                        items: [
                          const DropdownMenuItem<ContactType?>(
                            value: null,
                            child: Text('Любой'),
                          ),
                          for (final item in ContactType.values)
                            DropdownMenuItem<ContactType?>(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => type = value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Источник',
                      child: DropdownButtonFormField<ContactSource?>(
                        value: source,
                        items: [
                          const DropdownMenuItem<ContactSource?>(
                            value: null,
                            child: Text('Любой'),
                          ),
                          for (final item in ContactSource.values)
                            DropdownMenuItem<ContactSource?>(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => source = value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Теги',
                hint: 'достаточно одного совпадающего',
                child: TextField(
                  controller: tags,
                  decoration: const InputDecoration(hintText: 'vip, реклама'),
                ),
              ),
            ],
          ),
        ),
        onSubmit: () async {
          final trimmed = name.text.trim();
          if (trimmed.isEmpty) {
            throw const FormatException('Укажите название сегмента');
          }
          final auth = ref.read(authProvider);
          final now = DateTime.now();
          final repo = ref.read(contactRepositoryProvider);
          final entity = segment == null
              ? AudienceSegment(
                  id: const Uuid().v4(),
                  userId: auth.userId,
                  name: trimmed,
                  description: _nullIfEmpty(description.text),
                  contactType: type,
                  source: source,
                  tags: _parseTags(tags.text),
                  createdAt: now,
                  updatedAt: now,
                )
              : AudienceSegment(
                  id: segment.id,
                  userId: segment.userId,
                  name: trimmed,
                  description: _nullIfEmpty(description.text),
                  contactType: type,
                  source: source,
                  tags: _parseTags(tags.text),
                  createdAt: segment.createdAt,
                  updatedAt: now,
                );
          await repo.saveSegment(entity);
          bumpData(ref);
        },
      );
    } finally {
      name.dispose();
      description.dispose();
      tags.dispose();
    }
  }

  Future<void> _deleteSegment(AudienceSegment segment) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить сегмент?',
      message:
          'Сегмент «${segment.name}» будет удалён. Контакты останутся на месте.',
    );
    if (!confirmed) return;
    await ref.read(contactRepositoryProvider).deleteSegment(segment);
    if (!mounted) return;
    bumpData(ref);
    showAppSnack(context, 'Сегмент удалён');
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Contact contact;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    contact.name.trim().isEmpty
                        ? '?'
                        : contact.name.trim().characters.first.toUpperCase(),
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        Pill(label: contact.type.label, color: colors.accent),
                        if (contact.source != null)
                          Pill(
                            label: contact.source!.label,
                            color: colors.blue,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Действия',
                icon: Icon(Icons.more_vert_rounded, size: 17, color: colors.muted),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
            ],
          ),
          if (contact.company != null) ...[
            const SizedBox(height: 8),
            Text(
              contact.company!,
              style: TextStyle(color: colors.muted, fontSize: 11.5),
            ),
          ],
          if (contact.email != null || contact.phone != null) ...[
            const SizedBox(height: 8),
            if (contact.email != null)
              _Line(icon: Icons.mail_outline_rounded, text: contact.email!),
            if (contact.phone != null)
              _Line(icon: Icons.phone_outlined, text: contact.phone!),
          ],
          if (contact.tags.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final tag in contact.tags.take(4))
                  Pill(label: tag, color: colors.yellow),
              ],
            ),
          ],
          if (contact.lastContactAt != null) ...[
            const SizedBox(height: 9),
            Text(
              'Последний контакт: ${contact.lastContactAt!.formatRelative()}',
              style: TextStyle(color: colors.muted, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: context.muted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactPanel extends ConsumerStatefulWidget {
  const _ContactPanel({
    required this.contactId,
    required this.onChanged,
    required this.onDeleted,
  });

  final String contactId;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ContactPanel> createState() => _ContactPanelState();
}

class _ContactPanelState extends ConsumerState<_ContactPanel> {
  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(contactRepositoryProvider);
    final contact = repo.getContact(widget.contactId);
    final colors = context.colors;
    if (contact == null) {
      return const Center(child: Text('Контакт удалён'));
    }
    final interactions = repo.getInteractions(contact.id);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Pill(label: contact.type.label, color: colors.accent),
            if (contact.source != null)
              Pill(label: contact.source!.label, color: colors.blue),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Email',
                value: contact.email ?? 'Не указан',
                icon: Icons.mail_outline_rounded,
              ),
              KeyValueRow(
                label: 'Телефон',
                value: contact.phone ?? 'Не указан',
                icon: Icons.phone_outlined,
              ),
              KeyValueRow(
                label: 'Компания',
                value: contact.company ?? 'Не указана',
                icon: Icons.business_outlined,
              ),
              KeyValueRow(
                label: 'Telegram',
                value: contact.telegram ?? 'Не указан',
                icon: Icons.send_rounded,
              ),
              KeyValueRow(
                label: 'Ссылка',
                value: contact.socialUrl ?? 'Не указана',
                icon: Icons.link_rounded,
              ),
              KeyValueRow(
                label: 'Создан',
                value: contact.createdAt.formatDateTime(),
                icon: Icons.schedule_rounded,
              ),
              KeyValueRow(
                label: 'Последний контакт',
                value: contact.lastContactAt == null
                    ? 'Не было'
                    : contact.lastContactAt!.formatDateTime(),
                icon: Icons.history_rounded,
              ),
            ],
          ),
        ),
        if (contact.notes != null) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Заметки',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(contact.notes!, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SectionCard(
          title: 'Взаимодействия',
          subtitle: 'История звонков, писем и встреч',
          trailing: SmallIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Добавить',
            onPressed: () => _addInteraction(contact),
          ),
          child: interactions.isEmpty
              ? Text(
                  'Взаимодействий пока нет.',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                )
              : Column(
                  children: [
                    for (final interaction in interactions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconSquare(
                              icon: _interactionIcon(interaction.type),
                              color: colors.accent,
                              size: 26,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _interactionLabel(interaction.type),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (interaction.description != null)
                                    Text(
                                      interaction.description!,
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  Text(
                                    interaction.date.formatDateTime(),
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Удалить',
                              onPressed: () async {
                                final confirmed = await showConfirmDialog(
                                  context,
                                  title: 'Удалить взаимодействие?',
                                  message:
                                      'Запись будет удалена из истории контакта.',
                                );
                                if (!confirmed) return;
                                await repo.deleteInteraction(interaction);
                                widget.onChanged();
                              },
                              icon: Icon(Icons.delete_outline_rounded,
                                  size: 15, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _delete,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.red,
            side: BorderSide(color: colors.red.withValues(alpha: 0.5)),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('Удалить контакт'),
        ),
      ],
    );
  }

  IconData _interactionIcon(String type) => switch (type) {
        'call' => Icons.call_outlined,
        'email' => Icons.mail_outline_rounded,
        'meeting' => Icons.groups_outlined,
        'message' => Icons.chat_bubble_outline_rounded,
        _ => Icons.sticky_note_2_outlined,
      };

  String _interactionLabel(String type) => switch (type) {
        'call' => 'Звонок',
        'email' => 'Письмо',
        'meeting' => 'Встреча',
        'message' => 'Сообщение',
        _ => 'Заметка',
      };

  Future<void> _addInteraction(Contact contact) async {
    final description = TextEditingController();
    var type = 'note';
    var date = DateTime.now();
    try {
      await showFormDialog(
        context,
        title: 'Новое взаимодействие',
        submitLabel: 'Добавить',
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Тип',
                child: DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'note', child: Text('Заметка')),
                    DropdownMenuItem(value: 'call', child: Text('Звонок')),
                    DropdownMenuItem(value: 'email', child: Text('Письмо')),
                    DropdownMenuItem(value: 'meeting', child: Text('Встреча')),
                    DropdownMenuItem(
                        value: 'message', child: Text('Сообщение')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? 'note'),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Дата',
                child: InkWell(
                  onTap: () async {
                    final picked = await pickDate(context, initial: date);
                    if (picked != null) {
                      setDialogState(() => date = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      suffixIcon: Icon(Icons.date_range_outlined, size: 17),
                    ),
                    child: Text(date.formatShort()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Описание',
                child: TextField(
                  controller: description,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(hintText: 'О чём договорились'),
                ),
              ),
            ],
          ),
        ),
        onSubmit: () async {
          await ref.read(contactRepositoryProvider).addInteraction(
                contact,
                type: type,
                description: _nullIfEmpty(description.text),
                date: date,
              );
          widget.onChanged();
        },
      );
    } finally {
      description.dispose();
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _delete() async {
    final repo = ref.read(contactRepositoryProvider);
    final contact = repo.getContact(widget.contactId);
    if (contact == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить контакт?',
      message: 'Контакт и история взаимодействий будут удалены.',
    );
    if (!confirmed) return;
    await repo.deleteContact(contact);
    widget.onChanged();
    widget.onDeleted();
  }
}
