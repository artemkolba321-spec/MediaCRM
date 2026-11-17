import 'package:uuid/uuid.dart';

import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/financial_operation.dart';
import 'package:media_crm/data/models/partner.dart';
import 'package:media_crm/data/models/user_settings.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';
import 'package:media_crm/data/repositories/finance_repository.dart';

class PromoCodeException implements Exception {
  final String message;
  const PromoCodeException(this.message);
  @override
  String toString() => message;
}

class PartnerRepository {
  PartnerRepository({
    required LocalStore store,
    required CloudService cloud,
    required ActivityService activity,
    required FinanceRepository finance,
  })
      : _finance = finance {
    _partners = EntityRepository<Partner>(
      store: store,
      cloud: cloud,
      collection: 'partners',
      fromJson: Partner.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.updatedAt,
      activity: activity,
    );
    _events = EntityRepository<PartnerEvent>(
      store: store,
      cloud: cloud,
      collection: 'partner_events',
      fromJson: PartnerEvent.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.createdAt,
    );
  }

  final FinanceRepository _finance;
  late final EntityRepository<Partner> _partners;
  late final EntityRepository<PartnerEvent> _events;
  final _uuid = const Uuid();

  List<Partner> getPartners({String? search, PartnerStatus? status}) {
    var items = _partners.getAll();
    if (status != null) items = items.where((p) => p.status == status).toList();
    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      items = items
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              (p.company ?? '').toLowerCase().contains(q) ||
              (p.promoCode ?? '').toLowerCase().contains(q))
          .toList();
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Partner? getPartner(String id) => _partners.getById(id);

  Future<Partner> savePartner(Partner partner) async {
    if (partner.promoCode != null && partner.promoCode!.trim().isNotEmpty) {
      final duplicate = _partners.getAll().where(
            (p) =>
                p.id != partner.id &&
                p.promoCode?.toLowerCase() ==
                    partner.promoCode!.trim().toLowerCase(),
          );
      if (duplicate.isNotEmpty) {
        throw const PromoCodeException('Такой промокод уже используется');
      }
    }
    final isNew = _partners.getById(partner.id) == null;
    return _partners.save(
      partner,
      actionLabel: isNew ? 'created' : 'updated',
      title: isNew
          ? 'Добавлен партнёр «${partner.name}»'
          : 'Обновлён партнёр «${partner.name}»',
    );
  }

  Future<void> deletePartner(Partner partner) async {
    for (final event in getEvents(partner.id)) {
      await _events.delete(event.id);
    }
    await _partners.delete(
      partner.id,
      title: 'Удалён партнёр «${partner.name}»',
    );
  }

  Future<String> generateUniquePromoCode({String prefix = 'MC'}) async {
    final existing = _partners
        .getAll()
        .map((p) => p.promoCode?.toUpperCase())
        .whereType<String>()
        .toSet();
    for (var attempt = 0; attempt < 50; attempt++) {
      final random = _uuid.v4().replaceAll('-', '').substring(0, 6).toUpperCase();
      final code = '$prefix-$random';
      if (!existing.contains(code)) return code;
    }
    throw const PromoCodeException('Не удалось сгенерировать уникальный код');
  }

  String? referralLinkFor(Partner partner, UserSettings settings) {
    if (partner.promoCode == null) return partner.referralLink;
    final base = settings.referralBaseUrl.trim();
    if (base.isEmpty) return partner.referralLink;
    final separator = base.contains('?') ? '&' : '?';
    return '$base${separator}ref=${Uri.encodeComponent(partner.promoCode!)}';
  }

  List<PartnerEvent> getEvents(String partnerId) {
    final items = _events
        .getAll()
        .where((e) => e.partnerId == partnerId)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items;
  }

  Future<PartnerEvent> addEvent({
    required Partner partner,
    required PartnerEventType type,
    double amount = 0,
    String currency = 'RUB',
    bool confirmed = false,
    String? note,
    DateTime? occurredAt,
  }) async {
    if (type == PartnerEventType.sale && !confirmed) {
      throw const PromoCodeException(
        'Продажа должна быть подтверждена событием из платёжной системы. '
        'Без подтверждения комиссия не начисляется.',
      );
    }
    final commission = switch (type) {
      PartnerEventType.sale when confirmed =>
        amount * partner.commissionRate / 100,
      PartnerEventType.refund when confirmed =>
        amount * partner.commissionRate / 100,
      _ => 0.0,
    };
    final event = PartnerEvent(
      id: _uuid.v4(),
      userId: partner.userId,
      partnerId: partner.id,
      type: type,
      amount: amount,
      currency: currency,
      commission: commission,
      confirmed: confirmed,
      note: note,
      occurredAt: occurredAt ?? DateTime.now(),
      createdAt: DateTime.now(),
    );
    await _events.append(event);
    await recalculate(partner.id);
    return event;
  }

  Future<Partner?> recalculate(String partnerId) async {
    final partner = getPartner(partnerId);
    if (partner == null) return null;
    final events = getEvents(partnerId);
    final clicks = events.where((e) => e.type == PartnerEventType.click).length;
    final registrations =
        events.where((e) => e.type == PartnerEventType.registration).length;
    final sales = events
        .where((e) => e.type == PartnerEventType.sale && e.confirmed)
        .toList();
    final refunds = events
        .where((e) => e.type == PartnerEventType.refund && e.confirmed)
        .toList();
    final totalCommission =
        sales.fold<double>(0, (sum, e) => sum + e.commission) -
            refunds.fold<double>(0, (sum, e) => sum + e.commission);
    final updated = partner.copyWith(
      clicks: clicks,
      registrations: registrations,
      confirmedSales: sales.length,
      totalCommission: totalCommission < 0 ? 0 : totalCommission,
      updatedAt: DateTime.now(),
    );
    return _partners.save(updated);
  }

  Future<void> deleteEvent(PartnerEvent event) async {
    await _events.delete(event.id);
    await recalculate(event.partnerId);
  }

  /// Records a payout as an accounting operation. No real money movement is
  /// performed; a payment provider integration is required for that.
  Future<FinancialOperation> recordPayout({
    required Partner partner,
    required double amount,
    required UserSettings settings,
    DateTime? date,
  }) async {
    if (amount <= 0) {
      throw const PromoCodeException('Сумма выплаты должна быть больше нуля');
    }
    final outstanding = partner.outstandingCommission;
    if (amount > outstanding + 0.01) {
      throw PromoCodeException(
        'Сумма превышает начисленную комиссию '
        '(${outstanding.toStringAsFixed(2)} ${settings.baseCurrency})',
      );
    }
    final now = DateTime.now();
    final operation = FinancialOperation(
      id: _uuid.v4(),
      userId: partner.userId,
      type: TransactionType.expense,
      status: TransactionStatus.completed,
      amount: amount,
      currency: settings.baseCurrency,
      baseAmount: amount,
      baseCurrency: settings.baseCurrency,
      category: TransactionCategory.affiliate,
      description: 'Выплата партнёрской комиссии: ${partner.name}',
      counterparty: partner.name,
      partnerId: partner.id,
      date: date ?? now,
      createdAt: now,
      updatedAt: now,
    );
    await _finance.saveOperation(operation);
    await _partners.save(partner.copyWith(
      paidCommission: partner.paidCommission + amount,
      updatedAt: now,
    ));
    return operation;
  }
}
