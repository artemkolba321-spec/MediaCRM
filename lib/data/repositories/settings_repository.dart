import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';

import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/financial_operation.dart';
import 'package:media_crm/data/models/user_settings.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';
import 'package:media_crm/data/repositories/finance_repository.dart';

class SettingsRepository {
  SettingsRepository({
    required LocalStore store,
    required CloudService cloud,
    required FinanceRepository finance,
    required ActivityService activity,
  })  : _store = store,
        _cloud = cloud,
        _finance = finance,
        _activity = activity;

  final LocalStore _store;
  final CloudService _cloud;
  final FinanceRepository _finance;
  final ActivityService _activity;
  final _uuid = const Uuid();

  UserSettings ensureSettings({
    String? displayName,
    String? email,
    String? userId,
  }) {
    final owner = userId ?? _store.userId;
    final saved = _store.readSettings();
    if (saved != null && saved['user_id'] == owner) {
      return UserSettings.fromJson(saved);
    }
    final settings = UserSettings.defaults(
      owner,
      displayName: displayName,
      email: email,
    );
    _store.writeSettings(settings.toJson());
    for (final code in const ['USD', 'EUR', 'KZT', 'BYN', 'UAH']) {
      if (_finance.getCurrencyRates().every((r) => r.code != code)) {
        // Rates are user-editable. RUB=1; other defaults are deliberately 1 so
        // no invented exchange rate is ever used in calculations.
        _store.upsert('currency_rates', {
          'code': code,
          'rate_to_base': 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, idField: 'code');
      }
    }
    return settings;
  }

  UserSettings getSettings() => ensureSettings();

  Future<UserSettings> saveSettings(UserSettings settings) async {
    final updated = settings.copyWith(updatedAt: DateTime.now());
    await _store.writeSettings(updated.toJson());
    final queue = _store.readQueue();
    if (_cloud.isConfigured) {
      try {
        await _cloud.client!.from('user_settings').upsert(
          updated.toJson()..['user_id'] = _store.userId,
          onConflict: 'user_id',
        );
      } catch (_) {
        // The settings document is local-first; a later sync will retry.
        await _store.setMeta(
          'settings_sync_error',
          'Изменения сохранены локально, облако недоступно',
        );
        return updated;
      }
    }
    // Settings are not part of the generic queue; trigger a pull next time.
    if (queue.isEmpty) return updated;
    return updated;
  }

  Future<UserSettings> update(UserSettings Function(UserSettings) updater) {
    return saveSettings(updater(getSettings()));
  }

  Future<void> setTheme(String themeMode) =>
      update((settings) => settings.copyWith(themeMode: themeMode));

  Future<void> setCurrency(String currency) => update(
        (settings) => settings.copyWith(
          currency: currency,
          baseCurrency: currency,
        ),
      );

  double rateFor(String code) {
    if (code == getSettings().baseCurrency) return 1;
    for (final rate in _finance.getCurrencyRates()) {
      if (rate.code == code) return rate.rateToBase;
    }
    return 1;
  }

  Future<void> saveRate(String code, double rate) async {
    if (rate <= 0) throw ArgumentError('Курс должен быть больше нуля');
    await _finance.saveCurrencyRate(code, rate);
  }

  Map<String, dynamic> exportBackup() => _store.exportBackup(
        settings: getSettings().toJson(),
      );

  String exportBackupJson() =>
      const JsonEncoder.withIndent('  ').convert(exportBackup());

  Future<void> importBackupJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Ожидается JSON-объект резервной копии');
    }
    final backup = Map<String, dynamic>.from(decoded);
    if (backup['format'] != 'mediacrm-backup') {
      throw const FormatException('Неизвестный формат резервной копии');
    }
    await _store.importBackup(backup);
    await _activity.log(
      entityType: 'settings',
      action: 'imported',
      title: 'Импортирована резервная копия',
    );
  }

  Future<void> clearAllData() async {
    await _store.clearAllData();
    await _activity.log(
      entityType: 'settings',
      action: 'deleted',
      title: 'Все локальные данные удалены',
    );
  }

  /// Creates a new random promo/referral token. Actual uniqueness is enforced
  /// by the partner repository and the database.
  String newReferralToken() {
    final random = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> createFinancialNotification(FinancialOperation operation) async {
    if (operation.status != TransactionStatus.completed) return;
    final settings = getSettings();
    if (!settings.financialNotifications) return;
    final title = operation.type == TransactionType.income
        ? 'Новое поступление'
        : operation.type == TransactionType.expense
            ? 'Новый расход'
            : 'Финансовая операция';
    await _activity.log(
      entityType: 'operations',
      entityId: operation.id,
      action: 'created',
      title: title,
      details: '${operation.amount} ${operation.currency}',
    );
  }

  String newId() => _uuid.v4();
}
