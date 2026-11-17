import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Formats used across the UI. Kept in one place so numbers and dates are
/// rendered consistently on every platform.
extension DateX on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);

  String formatShort() => DateFormat('dd.MM.yyyy').format(this);
  String formatDateTime() => DateFormat('dd.MM.yyyy HH:mm').format(this);
  String formatMonth() => DateFormat('LLL yyyy', 'ru').format(this);
  String formatDayMonth() => DateFormat('dd.MM').format(this);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  bool isToday() => isSameDay(DateTime.now());

  String formatRelative([DateTime? clock]) {
    final now = clock ?? DateTime.now();
    final diff = now.difference(this);
    if (diff.isNegative) {
      final ahead = -diff;
      if (ahead.inMinutes < 60) return 'через ${ahead.inMinutes} мин.';
      if (ahead.inHours < 24) return 'через ${ahead.inHours} ч.';
      return 'через ${ahead.inDays} дн.';
    }
    if (diff.inSeconds < 60) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return formatShort();
  }
}

extension NumX on num {
  String formatCompact() {
    final magnitude = abs();
    final sign = this < 0 ? '-' : '';
    if (magnitude >= 1000000000) {
      return '$sign${_trim(magnitude / 1000000000)} млрд';
    }
    if (magnitude >= 1000000) {
      return '$sign${_trim(magnitude / 1000000)} млн';
    }
    if (magnitude >= 1000) {
      return '$sign${_trim(magnitude / 1000)} тыс.';
    }
    if (this == roundToDouble()) return '$sign${toInt()}';
    return '$sign${toStringAsFixed(1)}';
  }

  String _trim(double value) {
    final fixed = value.toStringAsFixed(value >= 100 ? 0 : 1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  String formatNumber([int decimals = 0]) =>
      NumberFormat.decimalPattern('ru').format(this);

  String formatMoney({String currency = 'RUB'}) {
    final symbol = switch (currency) {
      'RUB' => '₽',
      'USD' => '\$',
      'EUR' => '€',
      'KZT' => '₸',
      'BYN' => 'Br',
      'UAH' => '₴',
      _ => currency,
    };
    return '${formatNumber(2).replaceAll(RegExp(r',00$'), '')} $symbol';
  }

  String formatPercent({int decimals = 1}) =>
      '${toStringAsFixed(decimals).replaceAll('.', ',')}%';
}

double safeDivide(num a, num b) => b == 0 ? 0 : a / b;

double percentChange(num current, num previous) {
  if (previous == 0) return current == 0 ? 0 : 100;
  return (current - previous) / previous.abs() * 100;
}

double clampDouble(double value, double min, double max) =>
    math.min(math.max(value, min), max);

String csvEscape(Object? value) {
  final text = value?.toString() ?? '';
  if (text.contains('"') || text.contains(',') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String buildCsv(List<List<Object?>> rows) =>
    rows.map((row) => row.map(csvEscape).join(',')).join('\n');
