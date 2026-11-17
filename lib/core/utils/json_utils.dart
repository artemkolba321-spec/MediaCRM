/// Small helpers for parsing dynamic JSON coming from SharedPreferences,
/// Supabase and platform APIs. All parsers are lenient: stale or partial data
/// must never crash the whole application.
library;

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

DateTime parseDateOrNow(dynamic value) => parseDate(value) ?? DateTime.now();

String? parseString(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

String parseRequiredString(dynamic value, [String fallback = '']) =>
    parseString(value) ?? fallback;

int parseInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? parseIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double parseDouble(dynamic value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ??
      fallback;
}

bool parseBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return value == 'true' || value == '1';
  }
  return fallback;
}

List<String> parseStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  if (value is String && value.isNotEmpty) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

Map<String, dynamic> parseMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

T enumByName<T extends Enum>(List<T> values, dynamic raw, T fallback) {
  final name = raw?.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

String isoDate(DateTime date) => DateTime(date.year, date.month, date.day)
    .toIso8601String()
    .substring(0, 10);

String isoDateTime(DateTime date) => date.toUtc().toIso8601String();

String? isoDateOrNull(DateTime? date) => date == null ? null : isoDate(date);

String? isoDateTimeOrNull(DateTime? date) =>
    date == null ? null : isoDateTime(date);
