import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:media_crm/core/config/app_config.dart';
import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/export_utils.dart';
import 'package:media_crm/core/utils/formatters.dart';
import 'package:media_crm/core/widgets/filters.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/notification_item.dart';
import 'package:media_crm/data/models/user_settings.dart';
import 'package:media_crm/providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);
    final sync = ref.watch(syncControllerProvider);
    final cloud = ref.watch(cloudServiceProvider);
    final colors = context.colors;
    final log = _activity();

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Настройки',
            subtitle:
                'Профиль, тема, валюта, синхронизация, уведомления и '
                'резервное копирование. Секреты площадок хранятся только на '
                'сервере.',
            actions: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Резервная копия'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: const Text('Импорт'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final left = Column(
                children: [
                  _ProfileCard(
                    settings: settings,
                    auth: auth,
                    onEdit: _editProfile,
                  ),
                  const SizedBox(height: 14),
                  _AppearanceCard(
                    settings: settings,
                    onTheme: (value) => ref
                        .read(settingsProvider.notifier)
                        .setTheme(value),
                    onCurrency: (value) => ref
                        .read(settingsProvider.notifier)
                        .setCurrency(value),
                    onRates: _openRates,
                  ),
                  const SizedBox(height: 14),
                  _SyncCard(
                    settings: settings,
                    sync: sync,
                    cloudConnected: cloud.isConfigured,
                    cloudSignedIn: cloud.isSignedIn,
                    onAutoSync: (value) => _update(
                      (current) => current.copyWith(autoSyncEnabled: value),
                    ),
                    onInterval: (value) => _update(
                      (current) => current.copyWith(syncIntervalMinutes: value),
                    ),
                    onSync: () =>
                        ref.read(syncControllerProvider.notifier).synchronize(),
                  ),
                ],
              );
              final right = Column(
                children: [
                  _NotificationsCard(
                    settings: settings,
                    onChanged: _update,
                  ),
                  const SizedBox(height: 14),
                  _ReferralCard(settings: settings, onSave: _editReferral),
                  const SizedBox(height: 14),
                  _BackupCard(
                    onExport: _export,
                    onImport: _import,
                    onClear: _clear,
                  ),
                  const SizedBox(height: 14),
                  _AccountCard(
                    auth: auth,
                    cloudConnected: cloud.isConfigured,
                    onSignOut: _signOut,
                  ),
                ],
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 14),
                    Expanded(child: right),
                  ],
                );
              }
              return Column(
                children: [left, const SizedBox(height: 14), right],
              );
            },
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Журнал действий',
            subtitle: 'Последние 40 локальных событий',
            child: log.isEmpty
                ? Text(
                    'Журнал пуст. Действия появятся после создания или '
                    'изменения записей.',
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  )
                : Column(
                    children: [
                      for (final entry in log)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconSquare(
                                icon: _actionIcon(entry.action),
                                color: _actionColor(entry.action, colors),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.title,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${entry.entityType} · ${entry.action}'
                                      '${entry.details == null ? '' : ' · ${entry.details}'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                entry.createdAt.formatRelative(),
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          const DataSourceNote(
            text:
                'Версия ${AppConfig.appVersion}. Локальный режим не требует '
                'сервера. При настроенном backend изменения синхронизируются '
                'пакетно и инкрементально; фоновая синхронизация при закрытом '
                'приложении не выполняется.',
          ),
        ],
      ),
    );
  }

  List<ActivityLogEntry> _activity() {
    final store = ref.watch(localStoreProvider);
    final rows = store.readRaw('activity_log');
    rows.sort((a, b) {
      final left = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final right = DateTime.tryParse(b['created_at']?.toString() ?? '');
      return (right ?? DateTime(0)).compareTo(left ?? DateTime(0));
    });
    return rows
        .take(40)
        .map(ActivityLogEntry.fromJson)
        .toList();
  }

  IconData _actionIcon(String action) => switch (action) {
        'created' => Icons.add_circle_outline_rounded,
        'updated' => Icons.edit_outlined,
        'deleted' => Icons.delete_outline_rounded,
        'imported' => Icons.download_done_rounded,
        'exported' => Icons.upload_file_outlined,
        _ => Icons.sync_rounded,
      };

  Color _actionColor(String action, AppColors colors) => switch (action) {
        'created' => colors.green,
        'deleted' => colors.red,
        'imported' => colors.blue,
        'exported' => colors.accent,
        _ => colors.muted,
      };

  Future<void> _update(UserSettingsUpdate update) async {
    await ref.read(settingsProvider.notifier).update(update);
    bumpData(ref);
  }

  Future<void> _editProfile() async {
    final auth = ref.read(authProvider);
    final settings = ref.read(settingsProvider);
    final name = TextEditingController(text: settings.displayName);
    try {
      await showFormDialog(
        context,
        title: 'Профиль',
        description:
            'Имя отображается в интерфейсе и сохраняется в настройках. '
            'Email меняется только через сервер авторизации.',
        submitLabel: 'Сохранить',
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: 'Отображаемое имя',
              child: TextField(controller: name),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: KeyValueRow(
                label: 'Email',
                value: auth.email ?? 'Локальный режим',
                icon: Icons.mail_outline_rounded,
              ),
            ),
          ],
        ),
        onSubmit: () async {
          final trimmed = name.text.trim();
          if (trimmed.isEmpty) {
            throw const FormatException('Имя не может быть пустым');
          }
          await ref.read(settingsProvider.notifier).update(
                (value) => value.copyWith(displayName: trimmed),
              );
          await ref.read(authProvider.notifier).refreshProfile(trimmed);
          bumpData(ref);
        },
      );
    } finally {
      name.dispose();
    }
  }

  Future<void> _editReferral() async {
    final settings = ref.read(settingsProvider);
    final url = TextEditingController(text: settings.referralBaseUrl);
    try {
      await showFormDialog(
        context,
        title: 'Базовая ссылка для рефералов',
        description:
            'К ссылке добавляется параметр ref с промокодом партнёра. '
            'Пустое значение означает, что используется индивидуальная ссылка '
            'партнёра.',
        submitLabel: 'Сохранить',
        builder: (context) => LabeledField(
          label: 'URL',
          child: TextField(
            controller: url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: 'https://example.com'),
          ),
        ),
        onSubmit: () async {
          final trimmed = url.text.trim();
          if (trimmed.isNotEmpty &&
              !trimmed.startsWith('http://') &&
              !trimmed.startsWith('https://')) {
            throw const FormatException('Ссылка должна начинаться с http(s)://');
          }
          await _update(
            (current) => current.copyWith(referralBaseUrl: trimmed),
          );
        },
      );
    } finally {
      url.dispose();
    }
  }

  Future<void> _openRates() async {
    final settings = ref.read(settingsProvider);
    final repo = ref.read(financeRepositoryProvider);
    final rates = repo.getCurrencyRates();
    final controllers = <String, TextEditingController>{
      for (final rate in rates)
        rate.code: TextEditingController(text: rate.rateToBase.toString()),
    };
    try {
      await showFormDialog(
        context,
        title: 'Курсы валют',
        description:
            'Курс показывает, сколько ${settings.baseCurrency} содержится в '
            'одной единице валюты. Значения не загружаются автоматически.',
        submitLabel: 'Сохранить',
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final code in controllers.keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LabeledField(
                  label: '1 $code = ? ${settings.baseCurrency}',
                  child: TextField(
                    controller: controllers[code],
                    keyboardType: numberKeyboard,
                    inputFormatters: decimalFormatters,
                  ),
                ),
              ),
          ],
        ),
        onSubmit: () async {
          for (final entry in controllers.entries) {
            final value = double.tryParse(
              entry.value.text.trim().replaceAll(',', '.'),
            );
            if (value == null || value <= 0) {
              throw FormatException('Некорректный курс для ${entry.key}');
            }
            await repo.saveCurrencyRate(entry.key, value);
          }
          bumpData(ref);
        },
      );
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = await ref.read(settingsProvider.notifier).exportJson();
      final result = await exportTextFile(
        fileName:
            'mediacrm-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json',
        content: json,
      );
      if (!mounted) return;
      showAppSnack(context, result.message, error: !result.ok);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, 'Экспорт не удался: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    String? content;
    try {
      content = await pickTextFile(extensions: const ['json']);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, 'Не удалось прочитать файл: $error', error: true);
      return;
    }
    if (!mounted || content == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Импортировать резервную копию?',
      message:
          'Текущие локальные коллекции будут заменены данными из файла. '
          'Действие не затрагивает облачную копию автоматически.',
      confirmLabel: 'Импортировать',
      danger: false,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await ref.read(settingsProvider.notifier).importJson(content);
      if (!mounted) return;
      bumpData(ref);
      ref.read(syncControllerProvider.notifier).refreshPending();
      showAppSnack(context, 'Данные импортированы');
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, 'Импорт не удался: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить все данные?',
      message:
          'Все локальные коллекции, настройки и очередь синхронизации будут '
          'удалены. Резервную копию нужно было сохранить заранее. '
          'Облачные данные не удаляются.',
      confirmLabel: 'Удалить всё',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await ref.read(settingsProvider.notifier).clearEverything();
      if (!mounted) return;
      bumpData(ref);
      ref.read(syncControllerProvider.notifier).refreshPending();
      showAppSnack(context, 'Локальные данные удалены');
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, 'Ошибка удаления: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Выйти из аккаунта?',
      message:
          'Локальные данные останутся на устройстве в пространстве '
          'пользователя. Для входа потребуется сеть.',
      confirmLabel: 'Выйти',
      danger: false,
    );
    if (!confirmed) return;
    await ref.read(authProvider.notifier).signOut();
  }
}

typedef UserSettingsUpdate = UserSettings Function(UserSettings);

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconSquare(icon: icon, color: colors.accent, size: 30),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(color: colors.muted, fontSize: 10.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.settings,
    required this.auth,
    required this.onEdit,
  });

  final UserSettings settings;
  final AppAuthState auth;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _SettingsCard(
      title: 'Профиль',
      icon: Icons.person_outline_rounded,
      subtitle: auth.isCloud ? 'Облачный аккаунт' : 'Локальный режим',
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  settings.displayName.toString().isEmpty
                      ? '?'
                      : settings.displayName
                          .toString()
                          .trim()
                          .characters
                          .first
                          .toUpperCase(),
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.displayName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    auth.email ?? 'Данные хранятся только на устройстве',
                    style: TextStyle(color: colors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onEdit, child: const Text('Изменить')),
          ],
        ),
      ],
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({
    required this.settings,
    required this.onTheme,
    required this.onCurrency,
    required this.onRates,
  });

  final UserSettings settings;
  final ValueChanged<String> onTheme;
  final ValueChanged<String> onCurrency;
  final VoidCallback onRates;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _SettingsCard(
      title: 'Внешний вид и валюта',
      icon: Icons.palette_outlined,
      children: [
        Text(
          'Тема',
          style: TextStyle(
            color: colors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SegmentedTabs(
          tabs: const ['Тёмная', 'Светлая', 'Системная'],
          selected: switch (settings.themeMode) {
            'light' => 1,
            'system' => 2,
            _ => 0,
          },
          onChanged: (index) => onTheme(
            const ['dark', 'light', 'system'][index],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Базовая валюта',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Используется для P&L и сводных отчётов',
                    style: TextStyle(color: colors.muted, fontSize: 9.5),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 104,
              child: DropdownButtonFormField<String>(
                value: AppConfig.supportedCurrencies
                        .contains(settings.baseCurrency)
                    ? settings.baseCurrency
                    : AppConfig.defaultCurrency,
                isDense: true,
                items: [
                  for (final code in AppConfig.supportedCurrencies)
                    DropdownMenuItem(value: code, child: Text(code)),
                ],
                onChanged: (value) {
                  if (value != null) onCurrency(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onRates,
            icon: const Icon(Icons.currency_exchange_rounded, size: 15),
            label: const Text('Курсы валют'),
          ),
        ),
      ],
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.settings,
    required this.sync,
    required this.cloudConnected,
    required this.cloudSignedIn,
    required this.onAutoSync,
    required this.onInterval,
    required this.onSync,
  });

  final UserSettings settings;
  final GlobalSyncState sync;
  final bool cloudConnected;
  final bool cloudSignedIn;
  final ValueChanged<bool> onAutoSync;
  final ValueChanged<int> onInterval;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _SettingsCard(
      title: 'Синхронизация',
      icon: Icons.sync_rounded,
      subtitle: cloudConnected
          ? (cloudSignedIn
              ? 'Backend подключён, вход выполнен'
              : 'Backend настроен, требуется вход')
          : 'Backend не настроен — локальный режим',
      children: [
        if (sync.message != null) ... [
          if (sync.error)
            ErrorNotice(message: sync.message!, compact: true)
          else
            InfoNotice(
              message: sync.message!,
              color: sync.error ? colors.red : colors.green,
              icon: sync.error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
            ),
          const SizedBox(height: 10),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Автосинхронизация',
            style: TextStyle(fontSize: 12.5),
          ),
          subtitle: Text(
            'Только пока приложение открыто',
            style: TextStyle(color: colors.muted, fontSize: 10.5),
          ),
          value: settings.autoSyncEnabled,
          onChanged: onAutoSync,
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Интервал',
                style: TextStyle(color: colors.muted, fontSize: 11.5),
              ),
            ),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                value: const [15, 30, 60, 180, 360, 720, 1440]
                        .contains(settings.syncIntervalMinutes)
                    ? settings.syncIntervalMinutes
                    : 180,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 минут')),
                  DropdownMenuItem(value: 30, child: Text('30 минут')),
                  DropdownMenuItem(value: 60, child: Text('1 час')),
                  DropdownMenuItem(value: 180, child: Text('3 часа')),
                  DropdownMenuItem(value: 360, child: Text('6 часов')),
                  DropdownMenuItem(value: 720, child: Text('12 часов')),
                  DropdownMenuItem(value: 1440, child: Text('Раз в сутки')),
                ],
                onChanged: (value) {
                  if (value != null) onInterval(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                sync.pendingChanges == 0
                    ? 'Нет неотправленных изменений'
                    : 'В очереди: ${sync.pendingChanges}',
                style: TextStyle(color: colors.muted, fontSize: 10.5),
              ),
            ),
            FilledButton.icon(
              onPressed: (!cloudConnected || !cloudSignedIn || sync.busy)
                  ? null
                  : onSync,
              icon: sync.busy
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 15),
              label: const Text('Синхронизировать'),
            ),
          ],
        ),
        if (sync.lastSyncedAt != null) ... [
          const SizedBox(height: 6),
          Text(
            'Последняя синхронизация: '
            '${sync.lastSyncedAt!.formatDateTime()}',
            style: TextStyle(color: colors.muted, fontSize: 9.5),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Синхронизация выполняется пакетами с ограничением количества '
          'записей. Фоновые задачи при закрытом приложении не запускаются.',
          style: TextStyle(
            color: colors.muted,
            fontSize: 9.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({required this.settings, required this.onChanged});

  final UserSettings settings;
  final Future<void> Function(UserSettingsUpdate update) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget tile({
      required String title,
      required String subtitle,
      required bool value,
      required void Function(bool) update,
    }) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 12.5)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: colors.muted, fontSize: 10.5),
        ),
        value: value,
        onChanged: update,
      );
    }

    return _SettingsCard(
      title: 'Уведомления',
      icon: Icons.notifications_none_rounded,
      subtitle: 'Внутри приложения; email и push не отправляются',
      children: [
        tile(
          title: 'Синхронизация',
          subtitle: 'Успешные запуски и ошибки',
          value: settings.syncNotifications,
          update: (value) => onChanged(
            (current) => current.copyWith(syncNotifications: value),
          ),
        ),
        tile(
          title: 'Финансовые события',
          subtitle: 'Новые операции и выплаты',
          value: settings.financialNotifications,
          update: (value) => onChanged(
            (current) => current.copyWith(financialNotifications: value),
          ),
        ),
        tile(
          title: 'Задачи',
          subtitle: 'Напоминания при открытом приложении',
          value: settings.taskNotifications,
          update: (value) => onChanged(
            (current) => current.copyWith(taskNotifications: value),
          ),
        ),
        tile(
          title: 'Изменения показателей',
          subtitle: 'Только при реальном расхождении метрик',
          value: settings.metricNotifications,
          update: (value) => onChanged(
            (current) => current.copyWith(metricNotifications: value),
          ),
        ),
        tile(
          title: 'Email',
          subtitle: 'Не реализовано: сервер не отправляет письма',
          value: settings.emailNotifications,
          update: (value) => onChanged(
            (current) => current.copyWith(emailNotifications: value),
          ),
        ),
        tile(
          title: 'Push',
          subtitle: 'Не реализовано: только внутренние уведомления',
          value: settings.pushNotifications,
          update: (value) => onChanged(
            (current) => current.copyWith(pushNotifications: value),
          ),
        ),
      ],
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.settings, required this.onSave});

  final UserSettings settings;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _SettingsCard(
      title: 'Партнёрские ссылки',
      icon: Icons.link_rounded,
      children: [
        Text(
          settings.referralBaseUrl.toString().isEmpty
              ? 'Базовый URL не задан.'
              : settings.referralBaseUrl,
          style: TextStyle(
            color: colors.muted,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: const Text('Изменить'),
          ),
        ),
      ],
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.onExport,
    required this.onImport,
    required this.onClear,
  });

  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _SettingsCard(
      title: 'Данные и резервная копия',
      icon: Icons.storage_outlined,
      children: [
        Text(
          'JSON-архив содержит все локальные коллекции, настройки и курсы '
          'валют. Секреты площадок в архив не попадают.',
          style: TextStyle(
            color: colors.muted,
            fontSize: 11,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined, size: 15),
              label: const Text('Экспорт JSON'),
            ),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_outlined, size: 15),
              label: const Text('Импорт JSON'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onClear,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.red,
            side: BorderSide(color: colors.red.withValues(alpha: 0.5)),
          ),
          icon: const Icon(Icons.delete_forever_outlined, size: 15),
          label: const Text('Удалить все локальные данные'),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.auth,
    required this.cloudConnected,
    required this.onSignOut,
  });

  final AppAuthState auth;
  final bool cloudConnected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Аккаунт',
      icon: Icons.shield_outlined,
      children: [
        KeyValueRow(
          label: 'Режим',
          value: auth.isCloud
              ? 'Облачный аккаунт'
              : auth.status == AuthStatus.local
                  ? 'Локальный режим'
                  : 'Не выполнен вход',
          icon: Icons.person_outline_rounded,
        ),
        KeyValueRow(
          label: 'Backend',
          value: cloudConnected ? 'Настроен' : 'Не настроен',
          icon: Icons.dns_outlined,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded, size: 15),
          label: const Text('Выйти'),
        ),
      ],
    );
  }
}
