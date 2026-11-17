import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/partner.dart';
import 'package:media_crm/providers/app_providers.dart';

class PartnersScreen extends ConsumerStatefulWidget {
  const PartnersScreen({super.key});

  @override
  ConsumerState<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends ConsumerState<PartnersScreen> {
  final _search = TextEditingController();
  PartnerStatus? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(partnerRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final all = repo.getPartners();
    final items = repo.getPartners(search: _search.text, status: _status);
    final colors = context.colors;
    final currency = settings.baseCurrency;
    final accrued = all.fold<double>(0, (sum, p) => sum + p.totalCommission);
    final outstanding =
        all.fold<double>(0, (sum, p) => sum + p.outstandingCommission);
    final sales = all.fold<int>(0, (sum, p) => sum + p.confirmedSales);

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Партнёры',
            subtitle:
                'Промокоды, реферальные ссылки, подтверждённые продажи и '
                'выплаты комиссии. Комиссия начисляется только по '
                'подтверждённым событиям.',
            actions: [
              FilledButton.icon(
                onPressed: () => _openPartnerForm(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить партнёра'),
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
                      label: 'Партнёры',
                      value: '${all.length}',
                      icon: Icons.handshake_outlined,
                      color: colors.accent,
                      footnote:
                          '${all.where((p) => p.status == PartnerStatus.active).length} активных',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Подтверждённые продажи',
                      value: '$sales',
                      icon: Icons.shopping_bag_outlined,
                      color: colors.blue,
                      footnote: 'Только confirmed-события',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'Начислено комиссии',
                      value: accrued.formatMoney(currency: currency),
                      icon: Icons.percent_rounded,
                      color: colors.green,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: 'К выплате',
                      value: outstanding.formatMoney(currency: currency),
                      icon: Icons.account_balance_wallet_outlined,
                      color: outstanding > 0 ? colors.yellow : colors.green,
                      footnote: 'Начислено минус выплачено',
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
                  hint: 'Имя, компания или промокод…',
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
              title: 'Партнёров пока нет',
              message:
                  'Добавьте партнёра и сгенерируйте промокод. События продаж '
                  'вносятся вручную и требуют подтверждения; автоматической '
                  'интеграции с платёжными системами нет.',
              icon: Icons.handshake_outlined,
              action: FilledButton.icon(
                onPressed: () => _openPartnerForm(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Добавить партнёра'),
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
                    for (final partner in items)
                      SizedBox(
                        width: width,
                        child: _PartnerCard(
                          partner: partner,
                          currency: currency,
                          onOpen: () => _openPanel(partner),
                          onEdit: () => _openPartnerForm(partner: partner),
                          onDelete: () => _deletePartner(partner),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          const DataSourceNote(
            text:
                'Партнёрские события и выплаты — учётные записи. Приложение не '
                'переводит деньги и не подтверждает продажи за платёжную '
                'систему: подтверждение вводит пользователь на основе '
                'внешнего события.',
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
        child: DropdownButton<PartnerStatus?>(
          value: _status,
          isDense: true,
          dropdownColor: colors.panel,
          hint: Text('Все статусы',
              style: TextStyle(fontSize: 11.5, color: colors.muted)),
          style: TextStyle(fontSize: 11.5, color: colors.text),
          items: [
            DropdownMenuItem<PartnerStatus?>(
              value: null,
              child: Text('Все статусы',
                  style: TextStyle(fontSize: 11.5, color: colors.muted)),
            ),
            for (final status in PartnerStatus.values)
              DropdownMenuItem<PartnerStatus?>(
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

  Future<void> _openPartnerForm({Partner? partner}) async {
    final name = TextEditingController(text: partner?.name ?? '');
    final company = TextEditingController(text: partner?.company ?? '');
    final person = TextEditingController(text: partner?.contactPerson ?? '');
    final email = TextEditingController(text: partner?.email ?? '');
    final phone = TextEditingController(text: partner?.phone ?? '');
    final website = TextEditingController(text: partner?.website ?? '');
    final promo = TextEditingController(text: partner?.promoCode ?? '');
    final referral = TextEditingController(text: partner?.referralLink ?? '');
    final notes = TextEditingController(text: partner?.notes ?? '');
    final rate = TextEditingController(
      text: (partner?.commissionRate ?? 10).toString(),
    );
    var status = partner?.status ?? PartnerStatus.pending;

    try {
      await showFormDialog(
        context,
        title: partner == null ? 'Новый партнёр' : 'Партнёр',
        description:
            'Промокод должен быть уникальным. Комиссия — процент от суммы '
            'подтверждённой продажи.',
        submitLabel: partner == null ? 'Добавить' : 'Сохранить',
        wide: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Имя',
                      child: TextField(
                        controller: name,
                        decoration: const InputDecoration(hintText: 'Партнёр'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Статус',
                      child: DropdownButtonFormField<PartnerStatus>(
                        value: status,
                        items: [
                          for (final item in PartnerStatus.values)
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
                      label: 'Компания',
                      child: TextField(controller: company),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Контактное лицо',
                      child: TextField(controller: person),
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
              LabeledField(
                label: 'Сайт',
                child: TextField(
                  controller: website,
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Промокод',
                      child: TextField(
                        controller: promo,
                        decoration: const InputDecoration(
                          hintText: 'Например, MC-AB12CD',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: OutlinedButton.icon(
                      onPressed: promo.text.trim().isEmpty
                          ? () async {
                              final code = await ref
                                  .read(partnerRepositoryProvider)
                                  .generateUniquePromoCode();
                              promo.text = code;
                              setDialogState(() {});
                            }
                          : null,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                      label: const Text('Сгенерировать'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: 'Комиссия, %',
                      child: TextField(
                        controller: rate,
                        keyboardType: numberKeyboard,
                        inputFormatters: decimalFormatters,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Реферальная ссылка',
                hint: 'если пусто, используется база из настроек',
                child: TextField(
                  controller: referral,
                  keyboardType: TextInputType.url,
                  decoration:
                      const InputDecoration(hintText: 'https://…'),
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
            throw const FormatException('Укажите имя партнёра');
          }
          final rateValue =
              double.tryParse(rate.text.trim().replaceAll(',', '.'));
          if (rateValue == null || rateValue < 0 || rateValue > 100) {
            throw const FormatException('Комиссия должна быть от 0 до 100%');
          }
          final repo = ref.read(partnerRepositoryProvider);
          final auth = ref.read(authProvider);
          final now = DateTime.now();
          final entity = partner == null
              ? Partner(
                  id: const Uuid().v4(),
                  userId: auth.userId,
                  name: trimmed,
                  company: _nullIfEmpty(company.text),
                  contactPerson: _nullIfEmpty(person.text),
                  email: _nullIfEmpty(email.text),
                  phone: _nullIfEmpty(phone.text),
                  website: _nullIfEmpty(website.text),
                  notes: _nullIfEmpty(notes.text),
                  status: status,
                  promoCode: _nullIfEmpty(promo.text),
                  referralLink: _nullIfEmpty(referral.text),
                  commissionRate: rateValue,
                  createdAt: now,
                  updatedAt: now,
                )
              : partner.copyWith(
                  name: trimmed,
                  company: _nullIfEmpty(company.text),
                  contactPerson: _nullIfEmpty(person.text),
                  email: _nullIfEmpty(email.text),
                  phone: _nullIfEmpty(phone.text),
                  website: _nullIfEmpty(website.text),
                  notes: _nullIfEmpty(notes.text),
                  status: status,
                  promoCode: _nullIfEmpty(promo.text),
                  referralLink: _nullIfEmpty(referral.text),
                  commissionRate: rateValue,
                  updatedAt: now,
                );
          await repo.savePartner(entity);
          bumpData(ref);
        },
      );
    } finally {
      for (final controller in [
        name,
        company,
        person,
        email,
        phone,
        website,
        promo,
        referral,
        notes,
        rate,
      ]) {
        controller.dispose();
      }
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _deletePartner(Partner partner) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить партнёра?',
      message:
          'Партнёр «${partner.name}» и его события будут удалены. '
          'Финансовые операции останутся в P&L.',
    );
    if (!confirmed) return;
    await ref.read(partnerRepositoryProvider).deletePartner(partner);
    if (!mounted) return;
    bumpData(ref);
    showAppSnack(context, 'Партнёр удалён');
  }

  Future<void> _openPanel(Partner partner) async {
    await showSidePanel<void>(
      context,
      title: partner.name,
      subtitle: partner.status.label,
      child: _PartnerPanel(
        partnerId: partner.id,
        onChanged: () => bumpData(ref),
        onDeleted: () => Navigator.of(context).maybePop(),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.currency,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Partner partner;
  final String currency;
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
              IconSquare(
                icon: Icons.handshake_outlined,
                color: partner.status == PartnerStatus.active
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
                      partner.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (partner.company != null)
                      Text(
                        partner.company!,
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                label: partner.status.label,
                color: partner.status == PartnerStatus.active
                    ? colors.green
                    : partner.status == PartnerStatus.suspended
                        ? colors.red
                        : colors.muted,
              ),
              Pill(
                label: '${partner.commissionRate.toStringAsFixed(0)}%',
                color: colors.accent,
              ),
              if (partner.promoCode != null)
                Pill(label: partner.promoCode!, color: colors.yellow),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              MiniStat(label: 'Клики', value: '${partner.clicks}'),
              const SizedBox(width: 14),
              MiniStat(
                label: 'Регистрации',
                value: '${partner.registrations}',
              ),
              const SizedBox(width: 14),
              MiniStat(
                label: 'Продажи',
                value: '${partner.confirmedSales}',
                color: colors.green,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Комиссия: ${partner.totalCommission.formatMoney(currency: currency)}',
                style: TextStyle(color: colors.muted, fontSize: 10.5),
              ),
              const Spacer(),
              if (partner.outstandingCommission > 0)
                Text(
                  'К выплате ${partner.outstandingCommission.formatMoney(currency: currency)}',
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

class _PartnerPanel extends ConsumerStatefulWidget {
  const _PartnerPanel({
    required this.partnerId,
    required this.onChanged,
    required this.onDeleted,
  });

  final String partnerId;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_PartnerPanel> createState() => _PartnerPanelState();
}

class _PartnerPanelState extends ConsumerState<_PartnerPanel> {
  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(partnerRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final partner = repo.getPartner(widget.partnerId);
    final colors = context.colors;
    if (partner == null) return const Center(child: Text('Партнёр удалён'));
    final events = repo.getEvents(partner.id);
    final link = repo.referralLinkFor(partner, settings);
    final currency = settings.baseCurrency;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Pill(
              label: partner.status.label,
              color: partner.status == PartnerStatus.active
                  ? colors.green
                  : colors.muted,
            ),
            Pill(
              label: '${partner.commissionRate.toStringAsFixed(0)}%',
              color: colors.accent,
            ),
            if (partner.promoCode != null)
              Pill(label: partner.promoCode!, color: colors.yellow),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Компания',
                value: partner.company ?? 'Не указана',
                icon: Icons.business_outlined,
              ),
              KeyValueRow(
                label: 'Контакт',
                value: partner.contactPerson ?? 'Не указан',
                icon: Icons.person_outline_rounded,
              ),
              KeyValueRow(
                label: 'Email',
                value: partner.email ?? 'Не указан',
                icon: Icons.mail_outline_rounded,
              ),
              KeyValueRow(
                label: 'Телефон',
                value: partner.phone ?? 'Не указан',
                icon: Icons.phone_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Промокод и ссылка',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                partner.promoCode ?? 'Промокод не задан',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              if (link == null || link.isEmpty)
                Text(
                  'Реферальная ссылка не задана. Укажите её у партнёра или '
                  'задайте базовый URL в настройках.',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        link,
                        style: TextStyle(color: colors.muted, fontSize: 11),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Скопировать',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (context.mounted) {
                          showAppSnack(context, 'Ссылка скопирована');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'События',
          subtitle: '${events.length} записей',
          trailing: Wrap(
            spacing: 4,
            children: [
              SmallIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Добавить событие',
                onPressed: () => _addEvent(partner),
              ),
              if (partner.outstandingCommission > 0)
                SmallIconButton(
                  icon: Icons.payments_outlined,
                  tooltip: 'Выплатить комиссию',
                  onPressed: () => _payout(partner),
                ),
            ],
          ),
          child: events.isEmpty
              ? Text(
                  'Событий пока нет. Переходы и регистрации можно вносить '
                  'вручную; продажа требует подтверждения.',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                )
              : Column(
                  children: [
                    for (final event in events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconSquare(
                              icon: switch (event.type) {
                                PartnerEventType.click =>
                                  Icons.ads_click_outlined,
                                PartnerEventType.registration =>
                                  Icons.person_add_alt_1_outlined,
                                PartnerEventType.sale =>
                                  Icons.shopping_bag_outlined,
                                PartnerEventType.refund =>
                                  Icons.undo_rounded,
                              },
                              color: switch (event.type) {
                                PartnerEventType.sale => colors.green,
                                PartnerEventType.refund => colors.red,
                                _ => colors.accent,
                              },
                              size: 27,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.type.label,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${event.occurredAt.formatShort()}'
                                    '${event.amount > 0 ? ' · ${event.amount.formatMoney(currency: event.currency)}' : ''}'
                                    '${event.commission > 0 ? ' · комиссия ${event.commission.formatMoney(currency: currency)}' : ''}',
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (event.note != null)
                                    Text(
                                      event.note!,
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (event.confirmed)
                              Pill(label: 'Подтв.', color: colors.green),
                            IconButton(
                              tooltip: 'Удалить',
                              onPressed: () async {
                                final confirmed = await showConfirmDialog(
                                  context,
                                  title: 'Удалить событие?',
                                  message:
                                      'Итоги партнёра будут пересчитаны.',
                                );
                                if (!confirmed) return;
                                await repo.deleteEvent(event);
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
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Начислено',
                value: partner.totalCommission.formatMoney(currency: currency),
                icon: Icons.percent_rounded,
              ),
              KeyValueRow(
                label: 'Выплачено',
                value: partner.paidCommission.formatMoney(currency: currency),
                icon: Icons.check_circle_outline_rounded,
              ),
              KeyValueRow(
                label: 'К выплате',
                value: partner.outstandingCommission
                    .formatMoney(currency: currency),
                icon: Icons.account_balance_wallet_outlined,
                valueColor:
                    partner.outstandingCommission > 0 ? colors.yellow : colors.green,
              ),
            ],
          ),
        ),
        if (partner.notes != null) ... [
          const SizedBox(height: 12),
          AppCard(
            child: Text(
              partner.notes!,
              style: const TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: 'Удалить партнёра?',
              message:
                  'Партнёр и его события будут удалены. Финансовые операции '
                  'останутся в истории.',
            );
            if (!confirmed) return;
            await repo.deletePartner(partner);
            widget.onChanged();
            widget.onDeleted();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.red,
            side: BorderSide(color: colors.red.withValues(alpha: 0.5)),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('Удалить партнёра'),
        ),
      ],
    );
  }

  Future<void> _addEvent(Partner partner) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var type = PartnerEventType.click;
    var confirmed = false;
    var date = DateTime.now();
    try {
      await showFormDialog(
        context,
        title: 'Событие партнёра',
        description:
            'Продажа или возврат требуют подтверждения. Комиссия '
            'рассчитывается от суммы продажи и ставки партнёра.',
        submitLabel: 'Добавить',
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Тип',
                child: DropdownButtonFormField<PartnerEventType>(
                  value: type,
                  items: [
                    for (final item in PartnerEventType.values)
                      DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                  ],
                  onChanged: (value) => setDialogState(
                      () => type = value ?? type),
                ),
              ),
              if (type != PartnerEventType.click &&
                  type != PartnerEventType.registration) ... [
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Сумма продажи',
                  child: TextField(
                    controller: amount,
                    keyboardType: numberKeyboard,
                    inputFormatters: decimalFormatters,
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Подтверждено внешним событием',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  subtitle: Text(
                    'Без подтверждения комиссия не начисляется.',
                    style: TextStyle(
                      color: context.muted,
                      fontSize: 10.5,
                    ),
                  ),
                  value: confirmed,
                  onChanged: (value) =>
                      setDialogState(() => confirmed = value),
                ),
              ],
              const SizedBox(height: 12),
              LabeledField(
                label: 'Дата',
                child: InkWell(
                  onTap: () async {
                    final picked = await pickDate(context, initial: date);
                    if (picked != null) setDialogState(() => date = picked);
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
                label: 'Заметка',
                child: TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Необязательно'),
                ),
              ),
            ],
          ),
        ),
        onSubmit: () async {
          double value = 0;
          if (type == PartnerEventType.sale ||
              type == PartnerEventType.refund) {
            value = double.tryParse(amount.text.trim().replaceAll(',', '.')) ??
                0;
            if (value <= 0) {
              throw const FormatException('Укажите сумму больше нуля');
            }
            if (!confirmed) {
              throw const FormatException(
                'Подтвердите событие: без этого комиссия не начисляется',
              );
            }
          }
          await ref.read(partnerRepositoryProvider).addEvent(
                partner: partner,
                type: type,
                amount: value,
                currency: ref.read(settingsProvider).baseCurrency,
                confirmed: confirmed,
                note: _nullIfEmpty(note.text),
                occurredAt: date,
              );
          widget.onChanged();
        },
      );
    } finally {
      amount.dispose();
      note.dispose();
    }
  }

  Future<void> _payout(Partner partner) async {
    final amount = TextEditingController(
      text: partner.outstandingCommission.toStringAsFixed(2),
    );
    var date = DateTime.now();
    try {
      await showFormDialog(
        context,
        title: 'Выплата комиссии',
        description:
            'Создаёт учётный расход категории «Партнёры». Реальный перевод '
            'средств приложение не выполняет.',
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
                    suffixText: ref.read(settingsProvider).baseCurrency,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Дата',
                child: InkWell(
                  onTap: () async {
                    final picked = await pickDate(context, initial: date);
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      suffixIcon: Icon(Icons.date_range_outlined, size: 17),
                    ),
                    child: Text(date.formatShort()),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Доступно к выплате: '
                '${partner.outstandingCommission.formatMoney(currency: ref.read(settingsProvider).baseCurrency)}',
                style: TextStyle(
                  color: context.muted,
                  fontSize: 11,
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
          await ref.read(partnerRepositoryProvider).recordPayout(
                partner: partner,
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

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
