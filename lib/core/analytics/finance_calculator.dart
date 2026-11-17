import 'package:media_crm/data/models/financial_operation.dart';
import 'package:media_crm/data/models/platform_channel.dart';

class FinanceSummary {
  final double income;
  final double expenses;
  final double refunds;
  final double pendingIncome;
  final double withdrawn;
  final double transfers;
  final double netProfit;
  final double cashBalance;
  final int count;
  final Map<TransactionCategory, double> byCategory;
  final Map<TransactionType, double> byType;
  final Map<String, double> byPlatform;

  const FinanceSummary({
    this.income = 0,
    this.expenses = 0,
    this.refunds = 0,
    this.pendingIncome = 0,
    this.withdrawn = 0,
    this.transfers = 0,
    this.netProfit = 0,
    this.cashBalance = 0,
    this.count = 0,
    this.byCategory = const {},
    this.byType = const {},
    this.byPlatform = const {},
  });

  double get margin => income == 0 ? 0 : netProfit / income * 100;
}

/// Accrual accounting:
/// * net profit = completed income - expenses - refunds
/// * withdrawals/transfers are cash movements, not P&L expenses
/// * pending operations never affect actual totals
FinanceSummary calculateFinanceSummary(
  List<FinancialOperation> operations, {
  List<PlatformChannel> channels = const [],
}) {
  final channelPlatforms = {
    for (final channel in channels) channel.id: channel.platform,
  };
  var income = 0.0;
  var expenses = 0.0;
  var refunds = 0.0;
  var pending = 0.0;
  var withdrawn = 0.0;
  var transfers = 0.0;
  final byCategory = <TransactionCategory, double>{};
  final byType = <TransactionType, double>{};
  final byPlatform = <String, double>{};

  for (final operation in operations) {
    if (operation.status == TransactionStatus.cancelled ||
        operation.status == TransactionStatus.failed) {
      continue;
    }
    final amount = operation.baseAmount;
    byType.update(
      operation.type,
      (value) => value + amount,
      ifAbsent: () => amount,
    );
    if (operation.status == TransactionStatus.pending ||
        operation.type == TransactionType.pending) {
      pending += amount;
      continue;
    }
    switch (operation.type) {
      case TransactionType.income:
        income += amount;
        byCategory.update(
          operation.category,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
        final platform = operation.channelId == null
            ? null
            : channelPlatforms[operation.channelId];
        if (platform != null) {
          byPlatform.update(
            platform.label,
            (value) => value + amount,
            ifAbsent: () => amount,
          );
        }
      case TransactionType.expense:
        expenses += amount;
        byCategory.update(
          operation.category,
          (value) => value - amount,
          ifAbsent: () => -amount,
        );
      case TransactionType.refund:
        refunds += amount;
      case TransactionType.withdrawal:
        withdrawn += amount;
      case TransactionType.transfer:
        transfers += amount;
      case TransactionType.pending:
        pending += amount;
    }
  }

  final netProfit = income - expenses - refunds;
  final cashBalance = income - expenses - refunds - withdrawn;
  return FinanceSummary(
    income: income,
    expenses: expenses,
    refunds: refunds,
    pendingIncome: pending,
    withdrawn: withdrawn,
    transfers: transfers,
    netProfit: netProfit,
    cashBalance: cashBalance,
    count: operations.length,
    byCategory: byCategory,
    byType: byType,
    byPlatform: byPlatform,
  );
}

double convertToBase({
  required double amount,
  required String currency,
  required String baseCurrency,
  required double exchangeRate,
  required Map<String, double> ratesToBase,
}) {
  if (currency == baseCurrency) return amount;
  if (exchangeRate > 0 && exchangeRate != 1) return amount * exchangeRate;
  final rate = ratesToBase[currency] ?? 1;
  return amount * rate;
}
