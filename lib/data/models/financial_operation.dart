import 'package:media_crm/core/utils/json_utils.dart';

enum TransactionType { income, expense, refund, pending, transfer, withdrawal }

extension TransactionTypeInfo on TransactionType {
  String get label => switch (this) {
        TransactionType.income => 'Доход',
        TransactionType.expense => 'Расход',
        TransactionType.refund => 'Возврат',
        TransactionType.pending => 'Ожидается',
        TransactionType.transfer => 'Перевод',
        TransactionType.withdrawal => 'Вывод средств',
      };

  String get hint => switch (this) {
        TransactionType.income => 'Поступление денег',
        TransactionType.expense => 'Списание денег',
        TransactionType.refund => 'Возврат клиенту',
        TransactionType.pending => 'Ожидаемое поступление',
        TransactionType.transfer => 'Учётный перевод между счетами',
        TransactionType.withdrawal =>
          'Учётная запись вывода, не банковская операция',
      };
}

enum TransactionStatus { completed, pending, failed, cancelled }

extension TransactionStatusInfo on TransactionStatus {
  String get label => switch (this) {
        TransactionStatus.completed => 'Проведена',
        TransactionStatus.pending => 'В ожидании',
        TransactionStatus.failed => 'Ошибка',
        TransactionStatus.cancelled => 'Отменена',
      };
}

enum TransactionCategory {
  adRevenue,
  subscription,
  sponsorship,
  affiliate,
  productSale,
  hosting,
  equipment,
  marketing,
  salary,
  taxes,
  fees,
  other,
}

extension TransactionCategoryInfo on TransactionCategory {
  String get label => switch (this) {
        TransactionCategory.adRevenue => 'Реклама',
        TransactionCategory.subscription => 'Подписки',
        TransactionCategory.sponsorship => 'Спонсорство',
        TransactionCategory.affiliate => 'Партнёрское вознаграждение',
        TransactionCategory.productSale => 'Продажа продукта',
        TransactionCategory.hosting => 'Хостинг и сервисы',
        TransactionCategory.equipment => 'Оборудование',
        TransactionCategory.marketing => 'Маркетинг',
        TransactionCategory.salary => 'Команда',
        TransactionCategory.taxes => 'Налоги',
        TransactionCategory.fees => 'Комиссии',
        TransactionCategory.other => 'Прочее',
      };

  bool get isIncome => const {
        TransactionCategory.adRevenue,
        TransactionCategory.subscription,
        TransactionCategory.sponsorship,
        TransactionCategory.affiliate,
        TransactionCategory.productSale,
      }.contains(this);
}

class FinancialOperation {
  final String id;
  final String userId;
  final TransactionType type;
  final TransactionStatus status;
  final double amount;
  final String currency;
  final double exchangeRate;
  final double baseAmount;
  final String baseCurrency;
  final TransactionCategory category;
  final String? description;
  final String? counterparty;
  final String? channelId;
  final String? partnerId;
  final String? advertiserId;
  final String? campaignId;
  final String? publicationId;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinancialOperation({
    required this.id,
    required this.userId,
    required this.type,
    this.status = TransactionStatus.completed,
    required this.amount,
    this.currency = 'RUB',
    this.exchangeRate = 1,
    double? baseAmount,
    this.baseCurrency = 'RUB',
    this.category = TransactionCategory.other,
    this.description,
    this.counterparty,
    this.channelId,
    this.partnerId,
    this.advertiserId,
    this.campaignId,
    this.publicationId,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  }) : baseAmount = baseAmount ?? amount;

  bool get isCompleted => status == TransactionStatus.completed;

  double get signedBaseAmount => switch (type) {
        TransactionType.income => baseAmount,
        TransactionType.expense ||
        TransactionType.refund ||
        TransactionType.withdrawal =>
          -baseAmount,
        TransactionType.pending ||
        TransactionType.transfer =>
          0,
      };

  factory FinancialOperation.fromJson(Map<String, dynamic> json) {
    final amount = parseDouble(json['amount']);
    return FinancialOperation(
      id: parseRequiredString(json['id']),
      userId: parseRequiredString(json['user_id']),
      type: enumByName(
        TransactionType.values,
        json['type'],
        TransactionType.income,
      ),
      status: enumByName(
        TransactionStatus.values,
        json['status'],
        TransactionStatus.completed,
      ),
      amount: amount,
      currency: parseRequiredString(json['currency'], 'RUB'),
      exchangeRate: parseDouble(json['exchange_rate'], 1),
      baseAmount: parseDouble(json['base_amount'], amount),
      baseCurrency: parseRequiredString(json['base_currency'], 'RUB'),
      category: enumByName(
        TransactionCategory.values,
        json['category'],
        TransactionCategory.other,
      ),
      description: parseString(json['description']),
      counterparty: parseString(json['counterparty']),
      channelId: parseString(json['channel_id']),
      partnerId: parseString(json['partner_id']),
      advertiserId: parseString(json['advertiser_id']),
      campaignId: parseString(json['campaign_id']),
      publicationId: parseString(json['publication_id']),
      date: parseDateOrNow(json['date']),
      createdAt: parseDateOrNow(json['created_at']),
      updatedAt: parseDateOrNow(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type.name,
        'status': status.name,
        'amount': amount,
        'currency': currency,
        'exchange_rate': exchangeRate,
        'base_amount': baseAmount,
        'base_currency': baseCurrency,
        'category': category.name,
        'description': description,
        'counterparty': counterparty,
        'channel_id': channelId,
        'partner_id': partnerId,
        'advertiser_id': advertiserId,
        'campaign_id': campaignId,
        'publication_id': publicationId,
        'date': isoDate(date),
        'created_at': isoDateTime(createdAt),
        'updated_at': isoDateTime(updatedAt),
      };

  FinancialOperation copyWith({
    String? id,
    String? userId,
    TransactionType? type,
    TransactionStatus? status,
    double? amount,
    String? currency,
    double? exchangeRate,
    double? baseAmount,
    String? baseCurrency,
    TransactionCategory? category,
    String? description,
    String? counterparty,
    String? channelId,
    String? partnerId,
    String? advertiserId,
    String? campaignId,
    String? publicationId,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialOperation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      baseAmount: baseAmount ?? this.baseAmount,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      category: category ?? this.category,
      description: description ?? this.description,
      counterparty: counterparty ?? this.counterparty,
      channelId: channelId ?? this.channelId,
      partnerId: partnerId ?? this.partnerId,
      advertiserId: advertiserId ?? this.advertiserId,
      campaignId: campaignId ?? this.campaignId,
      publicationId: publicationId ?? this.publicationId,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CurrencyRate {
  final String code;
  final double rateToBase;
  final DateTime updatedAt;

  const CurrencyRate({
    required this.code,
    required this.rateToBase,
    required this.updatedAt,
  });

  factory CurrencyRate.fromJson(Map<String, dynamic> json) => CurrencyRate(
        code: parseRequiredString(json['code'], 'RUB'),
        rateToBase: parseDouble(json['rate_to_base'], 1),
        updatedAt: parseDateOrNow(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'rate_to_base': rateToBase,
        'updated_at': isoDateTime(updatedAt),
      };
}
