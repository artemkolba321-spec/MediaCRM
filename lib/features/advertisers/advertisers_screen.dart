import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/advertiser.dart';
import 'package:media_crm/providers/app_providers.dart';

class AdvertisersScreen extends ConsumerStatefulWidget {
  const AdvertisersScreen({super.key});

  @override
  ConsumerState<AdvertisersScreen> createState() => _AdvertisersScreenState();
}

class _AdvertisersScreenState extends ConsumerState<AdvertisersScreen> {
  final _search = TextEditingController();
  AdvertiserStatus? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(advertiserRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final all = repo.getAdvertisers();
    final items = repo.getAdvertisers(search: _search.text, status: _status);
    final campaigns = repo.getCampaigns();
    final active = campaigns.where((c) => c.status == CampaignStatus.active);
    final colors = context.colors;
    final currency = settings.baseCurrency;
    final revenue = all.fold<double>(
      0,
      (sum, advertiser) => sum + repo.advertiserRevenue(advertiser.id),
    );
    final debt = repo.totalDebt();

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Рекламодатели',
            subtitle:
                'База рекламодателей, кампании, оплаты и отчёты. Оплата '
                'фиксируется учётной операцией: реальные платежи приложение '
                'не проводит.',
            actions: [
              FilledButton.icon(
                onPressed: () => _openAdvertiserForm(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить рекламодателя'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 720
                      ? 2
                      : 1;
              const gap = 12.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Рекламодатели',
                      value: '${all.length}',
                      icon: Icons.business_center_outlined,
                      color: colors.accent,
                      footnote:
                          '${all.where((a) => a.status == AdvertiserStatus.active).length} активных',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Активные кампании',
                      value: '${active.length}',
                      icon: Icons.campaign_outlined,
                      color: colors.blue,
                      footnote: 'Из ${campaigns.length} всего',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Задолженность',
                      value: debt.formatMoney(currency: currency),
                      icon: Icons.request_quote_outlined,
                      color: debt > 0 ? colors.yellow : colors.green,
                      footnote: 'Бюджет минус оплачено',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Доход от рекламы',
                      value: revenue.formatMoney(currency: currency),
                      icon: Icons.payments_outlined,
                      color: colors.green,
                      footnote: 'По проведённым поступлениям',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilterBarShell(
            children: [
              SizedBox(
                width: 260,
                child: SearchField(
                  controller: _search,
                  hint: 'Компания, контакт или email…',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              _statusDropdown(colors),
              Text(
                '${items.length} из ${all.length}',
                style: TextStyle(color: colors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (all.isEmpty)
            EmptyState(
              title: 'Рекламодателей пока нет',
              message:
                  'Добавьте компанию, затем создайте кампанию с бюджетом и '
                  'сроками. Задолженность рассчитается по сохранённым оплатам.',
              icon: Icons.business_center_outlined,
              action: FilledButton.icon(
                onPressed: () => _openAdvertiserForm(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить рекламодателя'),
              ),
            )
          else if (items.isEmpty)
            const EmptyState(
              title: 'Ничего не найдено',
              message: 'Измените запрос или фильтр статуса.',
              icon: Icons.search_off_rounded,
              compact: true,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1180
                    ? 3
                    : constraints.maxWidth >= 740
                        ? 2
                        : 1;
                const gap = 12.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final advertiser in items)
                      SizedBox(
                        width: width,
                        child: _AdvertiserCard(
                          advertiser: advertiser,
                          campaigns:
                              repo.getCampaigns(advertiserId: advertiser.id),
                          revenue: repo.advertiserRevenue(advertiser.id),
                          currency: currency,
                          onOpen: () => _openPanel(advertiser),
                          onEdit: () =>
                              _openAdvertiserForm(advertiser: advertiser),
                          onDelete: () => _deleteAdvertiser(advertiser),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          const DataSourceNote(
            text:
                'Отчёты по кампаниям рассчитываются из сохранённых снимков '
                'площадок за период кампании и помечены как производные. '
                'Оплаты создают доход только после подтверждения пользователем.',
          ),
        ],
      ),
    );
  }

  Widget _statusDropdown(AppColors colors) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AdvertiserStatus?>(
          value: _status,
          isDense: true,
          dropdownColor: colors.panel,
          hint: Text('Все статусы',
              style: TextStyle(fontSize: 11.5, color: colors.muted)),
          style: TextStyle(fontSize: 11.5, color: colors.text),
          items: [
            DropdownMenuItem<AdvertiserStatus?>(
              value: null,
              child: Text('Все статусы',
                  style: TextStyle(fontSize: 11.5, color: colors.muted)),
            ),
            for (final status in AdvertiserStatus.values)
              DropdownMenuItem<AdvertiserStatus?>(
                value: status,
                child: Text(status.label,
                    style: TextStyle(fontSize: 11.5, color: colors.text)),
              ),
          ],
          onChanged: (value) => setState(() => _status = value),
        ),
      ),
    );
  }

  Future<void> _openAdvertiserForm({Advertiser? advertiser}) async {
    final company = TextEditingController(text: advertiser?.companyName ?? '');
    final person = TextEditingController(text: advertiser?.contactPerson ?? '');
    final email = TextEditingController(text: advertiser?.email ?? '');
    final phone = TextEditingController(text: advertiser?.phone ?? '');
    final website = TextEditingController(text: advertiser?.website ?? '');
    final industry = TextEditingController(text: advertiser?.industry ?? '');
    final notes = TextEditingController(text: advertiser?.notes ?? '');
    var status = advertiser?.status ?? AdvertiserStatus.active;

    try {
      await showFormDialog(
        context,
        title: advertiser == null ? 'Новый рекламодатель' : 'Рекламодатель',
        description:
            'Контакты и реквизиты необязательны. Платёжные данные карт здесь '
            'не хранятся.',
        submitLabel: advertiser == null ? 'Добавить' : 'Сохранить',
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Компания',
                child: TextField(
                  controller: company,
                  decoration: const InputDecoration(hintText: 'Название'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Контактное лицо',
                      child: TextField(controller: person),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Статус',
                      child: DropdownButtonFormField<AdvertiserStatus>(
                        value: status,
                        items: [
                          for (final item in AdvertiserStatus.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) => setDialogState(
                            () => status = value ?? status),
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
                      label: 'Сайт',
                      child: TextField(
                        controller: website,
                        keyboardType: TextInputType.url,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Отрасль',
                      child: TextField(controller: industry),
                    ),
                  ),
                ],
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
          final trimmed = company.text.trim();
          if (trimmed.isEmpty) {
            throw const FormatException('Укажите название компании');
          }
          final repo = ref.read(advertiserRepositoryProvider);
          final auth = ref.read(authProvider);
          final now = DateTime.now();
          final entity = advertiser == null
              ? Advertiser(
                  id: const Uuid().v4(),
                  userId: auth.userId,
                  companyName: trimmed,
                  contactPerson: _nullIfEmpty(person.text),
                  email: _nullIfEmpty(email.text),
                  phone: _nullIfEmpty(phone.text),
                  website: _nullIfEmpty(website.text),
                  industry: _nullIfEmpty(industry.text),
                  notes: _nullIfEmpty(notes.text),
                  status: status,
                  createdAt: now,
                  updatedAt: now,
                )
              : advertiser.copyWith(
                  companyName: trimmed,
                  contactPerson: _nullIfEmpty(person.text),
                  email: _nullIfEmpty(email.text),
                  phone: _nullIfEmpty(phone.text),
                  website: _nullIfEmpty(website.text),
                  industry: _nullIfEmpty(industry.text),
                  notes: _nullIfEmpty(notes.text),
                  status: status,
                  updatedAt: now,
                );
          await repo.saveAdvertiser(entity);
          bumpData(ref);
        },
      );
    } finally {
      for (final controller in [company, person, email, phone, website, industry, notes]) {
        controller.dispose();
      }
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _deleteAdvertiser(Advertiser advertiser) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить рекламодателя?',
      message:
          'Компания «${advertiser.companyName}», её кампании, заметки и '
          'документы будут удалены. Финансовые операции останутся в P&L.',
    );
    if (!confirmed) return;
    await ref.read(advertiserRepositoryProvider).deleteAdvertiser(advertiser);
    if (!mounted) return;
    bumpData(ref);
    showAppSnack(context, 'Рекламодатель удалён');
  }

  Future<void> _openPanel(Advertiser advertiser) async {
    await showSidePanel<void>(
      context,
      title: advertiser.companyName,
      subtitle: advertiser.status.label,
      child: _AdvertiserPanel(
        advertiserId: advertiser.id,
        onChanged: () => bumpData(ref),
        onDeleted: () => Navigator.of(context).maybePop(),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _AdvertiserCard extends StatelessWidget {
  const _AdvertiserCard({
    required this.advertiser,
    required this.campaigns,
    required this.revenue,
    required this.currency,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Advertiser advertiser;
  final List<AdCampaign> campaigns;
  final double revenue;
  final String currency;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final debt = campaigns.fold<double>(
      0,
      (sum, campaign) => sum + campaign.debt * campaign.exchangeRate,
    );
    final active = campaigns.where((c) => c.status == CampaignStatus.active).length;
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconSquare(
                icon: Icons.business_center_outlined,
                color: advertiser.status == AdvertiserStatus.active
                    ? colors.accent
                    : colors.muted,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advertiser.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (advertiser.contactPerson != null)
                      Text(
                        advertiser.contactPerson!,
                        style: TextStyle(color: colors.muted, fontSize: 11),
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
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                label: advertiser.status.label,
                color: advertiser.status == AdvertiserStatus.active
                    ? colors.green
                    : advertiser.status == AdvertiserStatus.blocked
                        ? colors.red
                        : colors.muted,
              ),
              if (advertiser.industry != null)
                Pill(label: advertiser.industry!, color: colors.blue),
              if (active > 0)
                Pill(label: '$active активных', color: colors.yellow),
            ],
          ),
          if (advertiser.email != null || advertiser.phone != null) ... [
            const SizedBox(height: 9),
            if (advertiser.email != null)
              _Line(icon: Icons.mail_outline_rounded, text: advertiser.email!),
            if (advertiser.phone != null)
              _Line(icon: Icons.phone_outlined, text: advertiser.phone!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              MiniStat(
                label: 'Кампаний',
                value: '${campaigns.length}',
                color: colors.accent,
              ),
              const SizedBox(width: 18),
              MiniStat(
                label: 'Доход',
                value: revenue.formatMoney(currency: currency),
                color: colors.green,
              ),
              const Spacer(),
              if (debt > 0)
                Text(
                  'Долг ${debt.formatMoney(currency: currency)}',
                  style: TextStyle(
                    color: colors.yellow,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
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

class _AdvertiserPanel extends ConsumerStatefulWidget {
  const _AdvertiserPanel({
    required this.advertiserId,
    required this.onChanged,
    required this.onDeleted,
  });

  final String advertiserId;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_AdvertiserPanel> createState() => _AdvertiserPanelState();
}

class _AdvertiserPanelState extends ConsumerState<_AdvertiserPanel> {
  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(advertiserRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final advertiser = repo.getAdvertiser(widget.advertiserId);
    final colors = context.colors;
    if (advertiser == null) {
      return const Center(child: Text('Рекламодатель удалён'));
    }
    final campaigns = repo.getCampaigns(advertiserId: advertiser.id);
    final notes = repo.getNotes(advertiser.id);
    final currency = settings.baseCurrency;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Pill(
              label: advertiser.status.label,
              color: advertiser.status == AdvertiserStatus.active
                  ? colors.green
                  : colors.muted,
            ),
            if (advertiser.industry != null)
              Pill(label: advertiser.industry!, color: colors.blue),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Контакт',
                value: advertiser.contactPerson ?? 'Не указан',
                icon: Icons.person_outline_rounded,
              ),
              KeyValueRow(
                label: 'Email',
                value: advertiser.email ?? 'Не указан',
                icon: Icons.mail_outline_rounded,
              ),
              KeyValueRow(
                label: 'Телефон',
                value: advertiser.phone ?? 'Не указан',
                icon: Icons.phone_outlined,
              ),
              KeyValueRow(
                label: 'Сайт',
                value: advertiser.website ?? 'Не указан',
                icon: Icons.link_rounded,
              ),
              KeyValueRow(
                label: 'Доход',
                value: repo
                    .advertiserRevenue(advertiser.id)
                    .formatMoney(currency: currency),
                icon: Icons.payments_outlined,
              ),
              KeyValueRow(
                label: 'Задолженность',
                value: repo
                    .totalDebt(advertiserId: advertiser.id)
                    .formatMoney(currency: currency),
                icon: Icons.request_quote_outlined,
                valueColor: repo.totalDebt(advertiserId: advertiser.id) > 0
                    ? colors.yellow
                    : colors.green,
              ),
            ],
          ),
        ),
        if (advertiser.notes != null) ... [
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
                Text(advertiser.notes!, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SectionCard(
          title: 'Кампании',
          subtitle: '${campaigns.length} записей',
          trailing: SmallIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Новая кампания',
            onPressed: () => _openCampaignForm(advertiser),
          ),
          child: campaigns.isEmpty
              ? Text(
                  'Кампаний пока нет. Создайте кампанию с бюджетом и сроками.',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                )
              : Column(
                  children: [
                    for (final campaign in campaigns)
                      _CampaignTile(
                        campaign: campaign,
                        currency: currency,
                        onOpen: () => _openCampaignPanel(advertiser, campaign),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Заметки и история',
          subtitle: 'Сохранённые вручную записи',
          trailing: SmallIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Добавить заметку',
            onPressed: () => _addNote(advertiser),
          ),
          child: notes.isEmpty
              ? Text(
                  'Заметок пока нет.',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                )
              : Column(
                  children: [
                    for (final note in notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note.text,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  Text(
                                    note.createdAt.formatDateTime(),
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
                                  title: 'Удалить заметку?',
                                  message: 'Запись будет удалена.',
                                );
                                if (!confirmed) return;
                                await repo.deleteNote(note);
                                widget.onChanged();
                              },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 15,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: 'Удалить рекламодателя?',
              message:
                  'Компания, кампании, заметки и документы будут удалены. '
                  'Финансовые операции останутся.',
            );
            if (!confirmed) return;
            await repo.deleteAdvertiser(advertiser);
            widget.onChanged();
            widget.onDeleted();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.red,
            side: BorderSide(color: colors.red.withValues(alpha: 0.5)),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('Удалить рекламодателя'),
        ),
      ],
    );
  }

  Future<void> _openCampaignForm(Advertiser advertiser) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final budget = TextEditingController();
    final deliverables = TextEditingController();
    var status = CampaignStatus.planned;
    var start = DateTime.now();
    var end = DateTime.now().add(const Duration(days: 30));
    final settings = ref.read(settingsProvider);
    final channels = ref.read(channelRepositoryProvider).getChannels();
    final selectedChannels = <String>{};

    try {
      await showFormDialog(
        context,
        title: 'Новая кампания',
        description:
            'Бюджет и сроки обязательны. Каналы используются для расчёта '
            'производного отчёта по сохранённым метрикам.',
        submitLabel: 'Создать',
        wide: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Название',
                child: TextField(controller: name),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Бюджет',
                      child: TextField(
                        controller: budget,
                        keyboardType: numberKeyboard,
                        inputFormatters: decimalFormatters,
                        decoration: InputDecoration(
                          suffixText: settings.baseCurrency,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Статус',
                      child: DropdownButtonFormField<CampaignStatus>(
                        value: status,
                        items: [
                          for (final item in CampaignStatus.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) => setDialogState(
                            () => status = value ?? status),
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
                      label: 'Начало',
                      child: _DateField(
                        value: start,
                        onPick: (value) =>
                            setDialogState(() => start = value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Окончание',
                      child: _DateField(
                        value: end,
                        onPick: (value) => setDialogState(() => end = value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Каналы',
                hint: 'для отчёта',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final channel in channels)
                      FilterChip(
                        label: Text(channel.name),
                        selected: selectedChannels.contains(channel.id),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            selectedChannels.add(channel.id);
                          } else {
                            selectedChannels.remove(channel.id);
                          }
                        }),
                      ),
                    if (channels.isEmpty)
                      Text(
                        'Сначала подключите канал.',
                        style: TextStyle(
                          color: context.muted,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Обязательства',
                child: TextField(
                  controller: deliverables,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(hintText: 'Что входит в кампанию'),
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
            ],
          ),
        ),
        onSubmit: () async {
          final trimmed = name.text.trim();
          if (trimmed.isEmpty) {
            throw const FormatException('Укажите название кампании');
          }
          final budgetValue =
              double.tryParse(budget.text.trim().replaceAll(',', '.'));
          if (budgetValue == null || budgetValue <= 0) {
            throw const FormatException('Укажите бюджет больше нуля');
          }
          if (end.isBefore(start)) {
            throw const FormatException('Дата окончания раньше начала');
          }
          final repo = ref.read(advertiserRepositoryProvider);
          final now = DateTime.now();
          final campaign = AdCampaign(
            id: const Uuid().v4(),
            advertiserId: advertiser.id,
            userId: advertiser.userId,
            name: trimmed,
            description: _nullIfEmpty(description.text),
            status: status,
            budget: budgetValue,
            currency: settings.baseCurrency,
            exchangeRate: 1,
            channelIds: selectedChannels.toList(),
            deliverables: _nullIfEmpty(deliverables.text),
            startDate: start,
            endDate: end,
            createdAt: now,
            updatedAt: now,
          );
          await repo.saveCampaign(campaign);
          bumpData(ref);
        },
      );
    } finally {
      name.dispose();
      description.dispose();
      budget.dispose();
      deliverables.dispose();
    }
  }

  Future<void> _addNote(Advertiser advertiser) async {
    final text = TextEditingController();
    try {
      await showFormDialog(
        context,
        title: 'Новая заметка',
        submitLabel: 'Добавить',
        builder: (context) => LabeledField(
          label: 'Текст',
          child: TextField(
            controller: text,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Договорённости, звонки…'),
          ),
        ),
        onSubmit: () async {
          if (text.text.trim().isEmpty) {
            throw const FormatException('Введите текст заметки');
          }
          await ref
              .read(advertiserRepositoryProvider)
              .addNote(advertiser, text.text);
          widget.onChanged();
        },
      );
    } finally {
      text.dispose();
    }
  }

  Future<void> _openCampaignPanel(
    Advertiser advertiser,
    AdCampaign campaign,
  ) async {
    await showSidePanel<void>(
      context,
      title: campaign.name,
      subtitle: '${campaign.status.label} · ${advertiser.companyName}',
      child: _CampaignPanel(
        campaignId: campaign.id,
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onPick});

  final DateTime value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await pickDate(context, initial: value);
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.date_range_outlined, size: 17),
        ),
        child: Text(value.formatShort()),
      ),
    );
  }
}

class _CampaignTile extends StatelessWidget {
  const _CampaignTile({
    required this.campaign,
    required this.currency,
    required this.onOpen,
  });

  final AdCampaign campaign;
  final String currency;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = campaign.budget == 0
        ? 0.0
        : (campaign.paidAmount / campaign.budget).clamp(0.0, 1.0);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Pill(
                  label: campaign.status.label,
                  color: switch (campaign.status) {
                    CampaignStatus.active => colors.green,
                    CampaignStatus.planned => colors.blue,
                    CampaignStatus.completed => colors.muted,
                    CampaignStatus.cancelled => colors.red,
                  },
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${campaign.startDate.formatShort()} — '
              '${campaign.endDate.formatShort()} · '
              '${campaign.paidAmount.formatMoney(currency: currency)} из '
              '${campaign.budget.formatMoney(currency: currency)}',
              style: TextStyle(color: colors.muted, fontSize: 10.5),
            ),
            const SizedBox(height: 6),
            ProgressLine(value: progress, color: colors.accent, height: 4),
            if (campaign.debt > 0) ... [
              const SizedBox(height: 4),
              Text(
                'Осталось оплатить '
                '${(campaign.debt * campaign.exchangeRate).formatMoney(currency: currency)}',
                style: TextStyle(color: colors.yellow, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CampaignPanel extends ConsumerStatefulWidget {
  const _CampaignPanel({required this.campaignId, required this.onChanged});

  final String campaignId;
  final VoidCallback onChanged;

  @override
  ConsumerState<_CampaignPanel> createState() => _CampaignPanelState();
}

class _CampaignPanelState extends ConsumerState<_CampaignPanel> {
  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(advertiserRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final campaign = repo.getCampaign(widget.campaignId);
    final colors = context.colors;
    if (campaign == null) return const Center(child: Text('Кампания удалена'));
    final report = repo.campaignReport(campaign);
    final documents = repo.getDocuments(campaign.id);
    final channels = repo.channelsFor(campaign);
    final currency = settings.baseCurrency;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Pill(
              label: campaign.status.label,
              color: switch (campaign.status) {
                CampaignStatus.active => colors.green,
                CampaignStatus.planned => colors.blue,
                CampaignStatus.completed => colors.muted,
                CampaignStatus.cancelled => colors.red,
              },
            ),
            Pill(
              label:
                  '${campaign.startDate.formatShort()} — ${campaign.endDate.formatShort()}',
              color: colors.blue,
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Бюджет',
                value: campaign.budget.formatMoney(currency: campaign.currency),
                icon: Icons.account_balance_wallet_outlined,
              ),
              KeyValueRow(
                label: 'Оплачено',
                value:
                    campaign.paidAmount.formatMoney(currency: campaign.currency),
                icon: Icons.check_circle_outline_rounded,
                valueColor: colors.green,
              ),
              KeyValueRow(
                label: 'Задолженность',
                value: (campaign.debt * campaign.exchangeRate)
                    .formatMoney(currency: currency),
                icon: Icons.request_quote_outlined,
                valueColor: campaign.debt > 0 ? colors.yellow : colors.green,
              ),
              KeyValueRow(
                label: 'Каналы',
                value: channels.isEmpty
                    ? 'Не выбраны'
                    : channels.map((c) => c.name).join(', '),
                icon: Icons.hub_outlined,
              ),
              KeyValueRow(
                label: 'Обязательства',
                value: campaign.deliverables ?? 'Не указаны',
                icon: Icons.description_outlined,
              ),
            ],
          ),
        ),
        if (campaign.description != null) ... [
          const SizedBox(height: 12),
          AppCard(
            child: Text(
              campaign.description!,
              style: const TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 14),
        SectionCard(
          title: 'Отчёт по кампании',
          subtitle: 'Производные значения из сохранённых снимков',
          child: Column(
            children: [
              Wrap(
                spacing: 22,
                runSpacing: 12,
                children: [
                  MiniStat(
                    label: 'Просмотры',
                    value: report.views.formatCompact(),
                  ),
                  MiniStat(
                    label: 'Охват',
                    value: report.reach.formatCompact(),
                  ),
                  MiniStat(
                    label: 'Публикации',
                    value: '${report.publications}',
                  ),
                  MiniStat(
                    label: 'Прирост аудитории',
                    value:
                        '${report.audienceGrowth >= 0 ? '+' : ''}${report.audienceGrowth.formatCompact()}',
                    color: report.audienceGrowth >= 0
                        ? colors.green
                        : colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Показатели суммируются за период кампании по выбранным каналам. '
                'Если снимков нет, значения остаются нулевыми — они не '
                'подменяются оценкой.',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 10.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (campaign.debt > 0) ... [
          const SizedBox(height: 14),
          SectionCard(
            title: 'Оплата',
            subtitle:
                'Создаёт доход adRevenue; реальное перечисление не выполняется',
            trailing: FilledButton.icon(
              onPressed: () => _recordPayment(campaign),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('Зафиксировать'),
            ),
            child: ProgressLine(
              value: campaign.budget == 0
                  ? 0
                  : (campaign.paidAmount / campaign.budget).clamp(0.0, 1.0),
              color: colors.green,
            ),
          ),
        ],
        const SizedBox(height: 14),
        SectionCard(
          title: 'Документы',
          subtitle: 'Ссылки и пометки, файлы не загружаются',
          trailing: SmallIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Добавить',
            onPressed: () => _addDocument(campaign),
          ),
          child: documents.isEmpty
              ? Text(
                  'Документов пока нет. Приложение хранит название, ссылку и '
                  'заметку; загрузка файлов не поддерживается.',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                )
              : Column(
                  children: [
                    for (final document in documents)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined,
                                size: 15, color: colors.muted),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    document.name,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (document.url != null)
                                    Text(
                                      document.url!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 10,
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
                                  title: 'Удалить документ?',
                                  message: 'Ссылка будет удалена из кампании.',
                                );
                                if (!confirmed) return;
                                await repo.deleteDocument(document);
                                widget.onChanged();
                              },
                              icon: Icon(Icons.close_rounded,
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
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: 'Удалить кампанию?',
              message:
                  'Кампания и её документы будут удалены. Финансовые операции '
                  'останутся в истории.',
            );
            if (!confirmed) return;
            await repo.deleteCampaign(campaign);
            widget.onChanged();
            if (context.mounted) Navigator.of(context).maybePop();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.red,
            side: BorderSide(color: colors.red.withValues(alpha: 0.5)),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('Удалить кампанию'),
        ),
      ],
    );
  }

  Future<void> _recordPayment(AdCampaign campaign) async {
    final amount = TextEditingController(
      text: campaign.debt.toStringAsFixed(2),
    );
    var date = DateTime.now();
    try {
      await showFormDialog(
        context,
        title: 'Оплата кампании',
        description:
            'Сумма будет добавлена как проведённый доход. Это учётная запись, '
            'деньги не переводятся.',
        submitLabel: 'Зафиксировать',
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Сумма',
                child: TextField(
                  controller: amount,
                  keyboardType: numberKeyboard,
                  inputFormatters: decimalFormatters,
                  decoration: InputDecoration(
                    suffixText: campaign.currency,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Дата',
                child: _DateField(
                  value: date,
                  onPick: (value) => setDialogState(() => date = value),
                ),
              ),
            ],
          ),
        ),
        onSubmit: () async {
          final value =
              double.tryParse(amount.text.trim().replaceAll(',', '.'));
          if (value == null || value <= 0) {
            throw const FormatException('Введите сумму больше нуля');
          }
          if (value > campaign.debt + 0.01) {
            throw const FormatException(
              'Сумма превышает остаток по кампании',
            );
          }
          await ref.read(advertiserRepositoryProvider).recordPayment(
                campaign: campaign,
                amount: value,
                settings: ref.read(settingsProvider),
                date: date,
              );
          widget.onChanged();
        },
      );
    } finally {
      amount.dispose();
    }
  }

  Future<void> _addDocument(AdCampaign campaign) async {
    final name = TextEditingController();
    final url = TextEditingController();
    final notes = TextEditingController();
    try {
      await showFormDialog(
        context,
        title: 'Документ кампании',
        submitLabel: 'Добавить',
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: 'Название',
              child: TextField(controller: name),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Ссылка',
              child: TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(hintText: 'https://…'),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Заметка',
              child: TextField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Необязательно'),
              ),
            ),
          ],
        ),
        onSubmit: () async {
          if (name.text.trim().isEmpty) {
            throw const FormatException('Укажите название документа');
          }
          await ref.read(advertiserRepositoryProvider).addDocument(
                campaign: campaign,
                name: name.text,
                url: _nullIfEmpty(url.text),
                notes: _nullIfEmpty(notes.text),
              );
          widget.onChanged();
        },
      );
    } finally {
      name.dispose();
      url.dispose();
      notes.dispose();
    }
  }
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
