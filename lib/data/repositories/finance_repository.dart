import 'package:media_crm/core/analytics/finance_calculator.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/utils/json_utils.dart';
import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/financial_operation.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';

class FinanceFilter {
  final DateTime? start;
  final DateTime? end;
  final Set<TransactionType>? types;
  final Set<TransactionCategory>? categories;
  final String? channelId;
  final String? partnerId;
  final String? advertiserId;
  final String? search;

  const FinanceFilter({
    this.start,
    this.end,
    this.types,
    this.categories,
    this.channelId,
    this.partnerId,
    this.advertiserId,
    this.search,
  });
}

class FinanceRepository {
  FinanceRepository({
    required LocalStore store,
    required CloudService cloud,
    required ActivityService activity,
  }) : _store = store {
    _operations = EntityRepository<FinancialOperation>(
      store: store,
      cloud: cloud,
      collection: 'operations',
      fromJson: FinancialOperation.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.updatedAt,
      activity: activity,
    );
  }

  final LocalStore _store;
  late final EntityRepository<FinancialOperation> _operations;

  List<FinancialOperation> getOperations([FinanceFilter filter = const FinanceFilter()]) {
    var items = _operations.getAll();
    if (filter.start != null) {
      items = items
          .where((e) => !e.date.dateOnly.isBefore(filter.start!.dateOnly))
          .toList();
    }
    if (filter.end != null) {
      items = items
          .where((e) => !e.date.dateOnly.isAfter(filter.end!.dateOnly))
          .toList();
    }
    if (filter.types != null && filter.types!.isNotEmpty) {
      items = items.where((e) => filter.types!.contains(e.type)).toList();
    }
    if (filter.categories != null && filter.categories!.isNotEmpty) {
      items = items.where((e) => filter.categories!.contains(e.category)).toList();
    }
    if (filter.channelId != null) {
      items = items.where((e) => e.channelId == filter.channelId).toList();
    }
    if (filter.partnerId != null) {
      items = items.where((e) => e.partnerId == filter.partnerId).toList();
    }
    if (filter.advertiserId != null) {
      items = items.where((e) => e.advertiserId == filter.advertiserId).toList();
    }
    if (filter.search != null && filter.search!.trim().isNotEmpty) {
      final query = filter.search!.toLowerCase();
      items = items
          .where((e) =>
              (e.description ?? '').toLowerCase().contains(query) ||
              (e.counterparty ?? '').toLowerCase().contains(query) ||
              e.category.label.toLowerCase().contains(query))
          .toList();
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  FinancialOperation? getOperation(String id) => _operations.getById(id);

  Future<FinancialOperation> saveOperation(FinancialOperation operation) async {
    final isNew = _operations.getById(operation.id) == null;
    return _operations.save(
      operation,
      actionLabel: isNew ? 'created' : 'updated',
      title: isNew
          ? 'Финансовая операция: ${operation.category.label}'
          : 'Изменена финансовая операция',
    );
  }

  Future<void> deleteOperation(FinancialOperation operation) =>
      _operations.delete(
        operation.id,
        title: 'Удалена операция ${operation.amount.formatPlain()} '
            '${operation.currency}',
      );

  FinanceSummary summary({
    DateTime? start,
    DateTime? end,
    PlatformType? platform,
    List<PlatformChannel> channels = const [],
  }) {
    var ops = getOperations(FinanceFilter(start: start, end: end));
    ops = _filterByPlatform(ops, platform, channels);
    return calculateFinanceSummary(ops, channels: channels);
  }

  List<FinancialOperation> _filterByPlatform(
    List<FinancialOperation> ops,
    PlatformType? platform,
    List<PlatformChannel> channels,
  ) {
    if (platform == null) return ops;
    final ids = channels
        .where((c) => c.platform == platform)
        .map((c) => c.id)
        .toSet();
    return ops.where((o) => o.channelId != null && ids.contains(o.channelId)).toList();
  }

  List<CurrencyRate> getCurrencyRates() {
    return _store
        .readRaw('currency_rates')
        .map(CurrencyRate.fromJson)
        .toList();
  }

  Map<String, double> ratesToBase() => {
        for (final rate in getCurrencyRates()) rate.code: rate.rateToBase,
      };

  Future<void> saveCurrencyRate(String code, double rateToBase) async {
    await _store.upsert('currency_rates', {
      'code': code,
      'rate_to_base': rateToBase,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, idField: 'code');
    await _store.enqueue(
      collection: 'currency_rates',
      entityId: code,
      operation: 'upsert',
    );
  }

  double baseAmountFor({
    required double amount,
    required String currency,
    required String baseCurrency,
    required double exchangeRate,
  }) {
    return convertToBase(
      amount: amount,
      currency: currency,
      baseCurrency: baseCurrency,
      exchangeRate: exchangeRate,
      ratesToBase: ratesToBase(),
    );
  }

  List<Map<String, Object?>> exportRows([FinanceFilter filter = const FinanceFilter()]) {
    final rows = <Map<String, Object?>>[];
    for (final op in getOperations(filter)) {
      rows.add({
        'id': op.id,
        'date': isoDate(op.date),
        'type': op.type.name,
        'status': op.status.name,
        'category': op.category.name,
        'amount': op.amount,
        'currency': op.currency,
        'exchange_rate': op.exchangeRate,
        'base_amount': op.baseAmount,
        'base_currency': op.baseCurrency,
        'counterparty': op.counterparty,
        'description': op.description,
      });
    }
    return rows;
  }
}

extension on double {
  String formatPlain() => this == roundToDouble() ? toInt().toString() : toStringAsFixed(2);
}
