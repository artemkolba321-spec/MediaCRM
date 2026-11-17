import 'package:flutter_test/flutter_test.dart';
import 'package:media_crm/core/analytics/finance_calculator.dart';
import 'package:media_crm/data/models/financial_operation.dart';

void main() {
  group('FinanceSummary', () {
    test('calculates net profit correctly', () {
      final operations = [
        FinancialOperation(
          id: '1',
          userId: 'user1',
          type: TransactionType.income,
          status: TransactionStatus.completed,
          amount: 10000,
          currency: 'RUB',
          category: TransactionCategory.adRevenue,
          date: DateTime(2024, 1, 1),
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        FinancialOperation(
          id: '2',
          userId: 'user1',
          type: TransactionType.expense,
          status: TransactionStatus.completed,
          amount: 3000,
          currency: 'RUB',
          category: TransactionCategory.hosting,
          date: DateTime(2024, 1, 2),
          createdAt: DateTime(2024, 1, 2),
          updatedAt: DateTime(2024, 1, 2),
        ),
        FinancialOperation(
          id: '3',
          userId: 'user1',
          type: TransactionType.refund,
          status: TransactionStatus.completed,
          amount: 500,
          currency: 'RUB',
          category: TransactionCategory.other,
          date: DateTime(2024, 1, 3),
          createdAt: DateTime(2024, 1, 3),
          updatedAt: DateTime(2024, 1, 3),
        ),
      ];

      final summary = calculateFinanceSummary(operations);

      expect(summary.income, 10000);
      expect(summary.expenses, 3000);
      expect(summary.refunds, 500);
      expect(summary.netProfit, 10000 - 3000 - 500); // 6500
      expect(summary.count, 3);
    });

    test('excludes pending operations from net profit', () {
      final operations = [
        FinancialOperation(
          id: '1',
          userId: 'user1',
          type: TransactionType.income,
          status: TransactionStatus.completed,
          amount: 10000,
          currency: 'RUB',
          date: DateTime(2024, 1, 1),
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        FinancialOperation(
          id: '2',
          userId: 'user1',
          type: TransactionType.pending,
          status: TransactionStatus.pending,
          amount: 5000,
          currency: 'RUB',
          date: DateTime(2024, 1, 2),
          createdAt: DateTime(2024, 1, 2),
          updatedAt: DateTime(2024, 1, 2),
        ),
      ];

      final summary = calculateFinanceSummary(operations);

      expect(summary.income, 10000);
      expect(summary.pendingIncome, 5000);
      expect(summary.netProfit, 10000); // pending doesn't affect net
    });

    test('excludes cancelled and failed operations', () {
      final operations = [
        FinancialOperation(
          id: '1',
          userId: 'user1',
          type: TransactionType.income,
          status: TransactionStatus.completed,
          amount: 10000,
          currency: 'RUB',
          date: DateTime(2024, 1, 1),
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        FinancialOperation(
          id: '2',
          userId: 'user1',
          type: TransactionType.expense,
          status: TransactionStatus.cancelled,
          amount: 5000,
          currency: 'RUB',
          date: DateTime(2024, 1, 2),
          createdAt: DateTime(2024, 1, 2),
          updatedAt: DateTime(2024, 1, 2),
        ),
        FinancialOperation(
          id: '3',
          userId: 'user1',
          type: TransactionType.expense,
          status: TransactionStatus.failed,
          amount: 2000,
          currency: 'RUB',
          date: DateTime(2024, 1, 3),
          createdAt: DateTime(2024, 1, 3),
          updatedAt: DateTime(2024, 1, 3),
        ),
      ];

      final summary = calculateFinanceSummary(operations);

      expect(summary.expenses, 0); // cancelled and failed excluded
      expect(summary.netProfit, 10000);
    });

    test('withdrawals and transfers do not affect P&L', () {
      final operations = [
        FinancialOperation(
          id: '1',
          userId: 'user1',
          type: TransactionType.income,
          status: TransactionStatus.completed,
          amount: 10000,
          currency: 'RUB',
          date: DateTime(2024, 1, 1),
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        FinancialOperation(
          id: '2',
          userId: 'user1',
          type: TransactionType.withdrawal,
          status: TransactionStatus.completed,
          amount: 7000,
          currency: 'RUB',
          date: DateTime(2024, 1, 2),
          createdAt: DateTime(2024, 1, 2),
          updatedAt: DateTime(2024, 1, 2),
        ),
        FinancialOperation(
          id: '3',
          userId: 'user1',
          type: TransactionType.transfer,
          status: TransactionStatus.completed,
          amount: 3000,
          currency: 'RUB',
          date: DateTime(2024, 1, 3),
          createdAt: DateTime(2024, 1, 3),
          updatedAt: DateTime(2024, 1, 3),
        ),
      ];

      final summary = calculateFinanceSummary(operations);

      expect(summary.income, 10000);
      expect(summary.withdrawn, 7000);
      expect(summary.transfers, 3000);
      expect(summary.netProfit, 10000); // withdrawals/transfers don't affect P&L
      expect(summary.cashBalance, 10000 - 7000); // 3000
    });

    test('calculates margin correctly', () {
      final operations = [
        FinancialOperation(
          id: '1',
          userId: 'user1',
          type: TransactionType.income,
          status: TransactionStatus.completed,
          amount: 10000,
          currency: 'RUB',
          date: DateTime(2024, 1, 1),
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        FinancialOperation(
          id: '2',
          userId: 'user1',
          type: TransactionType.expense,
          status: TransactionStatus.completed,
          amount: 2000,
          currency: 'RUB',
          date: DateTime(2024, 1, 2),
          createdAt: DateTime(2024, 1, 2),
          updatedAt: DateTime(2024, 1, 2),
        ),
      ];

      final summary = calculateFinanceSummary(operations);

      expect(summary.margin, (10000 - 2000) / 10000 * 100); // 80%
    });

    test('margin is 0 when income is 0', () {
      final operations = [
        FinancialOperation(
          id: '1',
          userId: 'user1',
          type: TransactionType.expense,
          status: TransactionStatus.completed,
          amount: 5000,
          currency: 'RUB',
          date: DateTime(2024, 1, 1),
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];

      final summary = calculateFinanceSummary(operations);

      expect(summary.income, 0);
      expect(summary.margin, 0);
    });

    test('categorizes operations correctly', () {
      final operations = [
        FinancialOperation(
          id: '1',
          userId: 'user1',
          type: TransactionType.income,
          status: TransactionStatus.completed,
          amount: 5000,
          currency: 'RUB',
          category: TransactionCategory.adRevenue,
          date: DateTime(2024, 1, 1),
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        FinancialOperation(
          id: '2',
          userId: 'user1',
          type: TransactionType.income,
          status: TransactionStatus.completed,
          amount: 3000,
          currency: 'RUB',
          category: TransactionCategory.subscription,
          date: DateTime(2024, 1, 2),
          createdAt: DateTime(2024, 1, 2),
          updatedAt: DateTime(2024, 1, 2),
        ),
        FinancialOperation(
          id: '3',
          userId: 'user1',
          type: TransactionType.expense,
          status: TransactionStatus.completed,
          amount: 2000,
          currency: 'RUB',
          category: TransactionCategory.hosting,
          date: DateTime(2024, 1, 3),
          createdAt: DateTime(2024, 1, 3),
          updatedAt: DateTime(2024, 1, 3),
        ),
      ];

      final summary = calculateFinanceSummary(operations);

      expect(summary.byCategory[TransactionCategory.adRevenue], 5000);
      expect(summary.byCategory[TransactionCategory.subscription], 3000);
      expect(summary.byCategory[TransactionCategory.hosting], -2000);
    });

    test('converts to base currency correctly', () {
      expect(
        convertToBase(
          amount: 100,
          currency: 'RUB',
          baseCurrency: 'RUB',
          exchangeRate: 1,
          ratesToBase: {'RUB': 1, 'USD': 90},
        ),
        100,
      );

      expect(
        convertToBase(
          amount: 1,
          currency: 'USD',
          baseCurrency: 'RUB',
          exchangeRate: 90,
          ratesToBase: {'RUB': 1, 'USD': 90},
        ),
        90,
      );

      expect(
        convertToBase(
          amount: 100,
          currency: 'USD',
          baseCurrency: 'RUB',
          exchangeRate: 0,
          ratesToBase: {'RUB': 1, 'USD': 90},
        ),
        9000,
      );
    });

    test('handles empty operations list', () {
      final summary = calculateFinanceSummary([]);

      expect(summary.income, 0);
      expect(summary.expenses, 0);
      expect(summary.netProfit, 0);
      expect(summary.count, 0);
    });
  });
}
