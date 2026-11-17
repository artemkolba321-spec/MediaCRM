import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:media_crm/core/config/app_config.dart';
import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/providers/app_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController(text: 'Моя медиасеть');
  bool _register = false;
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    final controller = ref.read(authProvider.notifier);
    try {
      if (_register) {
        await controller.signUp(
          _email.text,
          _password.text,
          displayName: _name.text,
        );
      } else {
        await controller.signIn(_email.text, _password.text);
      }
    } catch (_) {
      // The controller exposes a human-readable notice; nothing else to do.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueLocally() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authProvider.notifier)
          .continueLocally(displayName: _name.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final controller = TextEditingController(text: _email.text);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Восстановление доступа'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Укажите email аккаунта. Supabase отправит ссылку для смены пароля.',
              style: TextStyle(color: context.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'you@example.com'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;
    try {
      await ref.read(authProvider.notifier).resetPassword(email);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final bootstrapNotice = ref.watch(bootstrapNoticeProvider);
    final colors = context.colors;
    final wide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.7, -0.8),
            radius: 1.4,
            colors: [
              colors.accent.withValues(alpha: 0.16),
              colors.bg,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _BrandPanel()),
                          const SizedBox(width: 56),
                          SizedBox(width: 430, child: _buildForm(context, auth, bootstrapNotice)),
                        ],
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          children: [
                            const _BrandHeader(),
                            const SizedBox(height: 26),
                            _buildForm(context, auth, bootstrapNotice),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppAuthState auth,
    String? bootstrapNotice,
  ) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!auth.cloudConfigured) ...[
              InfoNotice(
                message:
                    'Облачный backend не настроен, поэтому доступен локальный '
                    'режим: все данные хранятся на этом устройстве. Чтобы включить '
                    'аккаунты и синхронизацию, соберите приложение с параметрами '
                    'SUPABASE_URL и SUPABASE_ANON_KEY.',
                color: colors.yellow,
                icon: Icons.cloud_off_rounded,
              ),
              const SizedBox(height: 16),
            ] else if (bootstrapNotice != null) ...[
              ErrorNotice(message: bootstrapNotice),
              const SizedBox(height: 16),
            ],
            SegmentedTabs(
              tabs: const ['Вход', 'Регистрация'],
              selected: _register ? 1 : 0,
              scrollable: true,
              onChanged: (index) => setState(() => _register = index == 1),
            ),
            const SizedBox(height: 20),
            if (_register) ...[
              LabeledField(
                label: 'Название медиасети',
                child: TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Моя медиасеть'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            LabeledField(
              label: 'Email',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'you@example.com'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Введите email';
                  if (!text.contains('@') || !text.contains('.')) {
                    return 'Некорректный email';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Пароль',
              hint: _register ? 'минимум 6 символов' : null,
              child: TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: _register
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Показать' : 'Скрыть',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 17,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Пароль должен содержать минимум 6 символов';
                  }
                  return null;
                },
              ),
            ),
            if (auth.notice != null) ...[
              const SizedBox(height: 14),
              InfoNotice(
                message: auth.notice!,
                color: auth.notice!.toLowerCase().contains('неверн') ||
                        auth.notice!.toLowerCase().contains('ошиб')
                    ? colors.red
                    : colors.blue,
                icon: Icons.info_outline_rounded,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed:
                  auth.cloudConfigured && !_busy ? _submit : null,
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_register ? 'Создать аккаунт' : 'Войти'),
            ),
            if (auth.cloudConfigured) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _resetPassword,
                child: const Text('Забыли пароль?'),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Divider(color: colors.line)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'или',
                    style: TextStyle(color: colors.muted, fontSize: 11),
                  ),
                ),
                Expanded(child: Divider(color: colors.line)),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _busy ? null : _continueLocally,
              icon: const Icon(Icons.offline_bolt_outlined, size: 17),
              label: const Text('Продолжить без сервера'),
            ),
            const SizedBox(height: 10),
            Text(
              'Локальный режим не требует интернета. Данные сохраняются на '
              'устройстве; серверная синхронизация и автоматический сбор '
              'статистики в нём недоступны.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.muted,
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.accent, colors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 16),
        const Text(
          AppConfig.appName,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          AppConfig.tagline,
          style: TextStyle(
            color: colors.muted,
            fontSize: 10,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BrandHeader(),
          const SizedBox(height: 36),
          const Text(
            'Одна панель для всей\nмедиасети',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 470,
            child: Text(
              'YouTube, Telegram, Boosty, ВКонтакте и GitHub: аудитория, '
              'публикации, доходы, рекламодатели, партнёры и задачи — в единой '
              'рабочей среде, которая работает даже без сети.',
              style: TextStyle(
                color: colors.muted,
                fontSize: 14,
                height: 1.65,
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Feature(icon: Icons.insights_rounded, label: 'Аналитика и история'),
              _Feature(icon: Icons.account_balance_wallet_outlined, label: 'Финансы и P&L'),
              _Feature(icon: Icons.group_outlined, label: 'Аудитория и контакты'),
              _Feature(icon: Icons.handshake_outlined, label: 'Партнёры и промокоды'),
              _Feature(icon: Icons.ads_click_rounded, label: 'Рекламодатели'),
              _Feature(icon: Icons.view_kanban_outlined, label: 'Воронки и задачи'),
              _Feature(icon: Icons.cloud_sync_outlined, label: 'Supabase sync'),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 15, color: colors.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'OAuth-токены площадок хранятся только в Edge Functions',
                  style: TextStyle(color: colors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
