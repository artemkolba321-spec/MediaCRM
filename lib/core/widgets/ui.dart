import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/data/models/platform_channel.dart';

// ─── Keyboard & Input Formatters ─────────────────────────────────────────────

const double kMobileBreakpoint = 600;

const TextInputType numberKeyboard = TextInputType.numberWithOptions(
  signed: false,
  decimal: false,
);

final List<TextInputFormatter> decimalFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
];

// ─── Platform Helpers ────────────────────────────────────────────────────────

IconData platformIcon(PlatformType platform) => switch (platform) {
  PlatformType.youtube => Icons.video_library_rounded,
  PlatformType.telegram => Icons.telegram_rounded,
  PlatformType.boosty => Icons.forest_rounded,
  PlatformType.vk => Icons.chat_rounded,
  PlatformType.github => Icons.code_rounded,
};

Color platformColor(PlatformType platform) => switch (platform) {
  PlatformType.youtube => const Color(0xFFFF0000),
  PlatformType.telegram => const Color(0xFF26A5E4),
  PlatformType.boosty => const Color(0xFFEE4420),
  PlatformType.vk => const Color(0xFF0077FF),
  PlatformType.github => const Color(0xFF333333),
};

// ─── Snack Bar ───────────────────────────────────────────────────────────────

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final colors = context.colors;
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: error ? colors.red : colors.text,
          fontSize: 12.5,
        ),
      ),
      backgroundColor: error ? colors.red.withValues(alpha: 0.15) : colors.panel,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
      dismissDirection: DismissDirection.down,
    ),
  );
}

// ─── Confirm Dialog ──────────────────────────────────────────────────────────

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  bool danger = false,
}) async {
  final colors = context.colors;
  final label = confirmLabel ?? 'Подтвердить';
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? colors.red : null,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(label),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ─── Side Panel ──────────────────────────────────────────────────────────────

Future<T?> showSidePanel<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
  double maxWidth = 560,
}) async {
  final colors = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.bg,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            decoration: BoxDecoration(
              color: colors.panel,
              border: Border(bottom: BorderSide(color: colors.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(ctx).textTheme.titleLarge,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: child,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Pick Date ───────────────────────────────────────────────────────────────

Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  DateTime? last,
}) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: last ?? DateTime.now().add(const Duration(days: 365)),
    locale: const Locale('ru'),
  );
  return picked;
}

// ─── PageHeader ──────────────────────────────────────────────────────────────

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: subtitle != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions!,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─── PlatformChip ────────────────────────────────────────────────────────────

class PlatformChip extends StatelessWidget {
  const PlatformChip({
    super.key,
    required this.platform,
    this.compact = false,
  });

  final PlatformType platform;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = platformColor(platform);
    if (compact) {
      return Icon(platformIcon(platform), size: 13, color: color);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(platformIcon(platform), size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            platform.label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AppPage ─────────────────────────────────────────────────────────────────

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: child,
    );
  }
}

// ─── AppCard ─────────────────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.line),
        ),
        child: child,
      ),
    );
  }
}

// ─── SectionCard ─────────────────────────────────────────────────────────────

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─── StatTile ────────────────────────────────────────────────────────────────

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
    this.deltaLabel,
    this.footnote,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? delta;
  final String? deltaLabel;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  delta! > 0
                      ? Icons.trending_up_rounded
                      : delta! < 0
                          ? Icons.trending_down_rounded
                          : Icons.remove_rounded,
                  size: 11,
                  color: delta! > 0 ? colors.green : colors.red,
                ),
                const SizedBox(width: 3),
                Text(
                  '${delta!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: delta! > 0 ? colors.green : colors.red,
                  ),
                ),
                if (deltaLabel != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    deltaLabel!,
                    style: TextStyle(color: colors.muted, fontSize: 9.5),
                  ),
                ],
              ],
            ),
          ],
          if (footnote != null) ...[
            const SizedBox(height: 6),
            Text(
              footnote!,
              style: TextStyle(color: colors.muted, fontSize: 9.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Pill ────────────────────────────────────────────────────────────────────

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── EmptyState ──────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.compact = false,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final bool compact;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 16 : 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 28 : 48, color: colors.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 13 : 16,
              fontWeight: FontWeight.w700,
              color: colors.muted,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 14),
            action!,
          ],
        ],
      ),
    );
  }
}

// ─── ErrorNotice ─────────────────────────────────────────────────────────────

class ErrorNotice extends StatelessWidget {
  const ErrorNotice({
    super.key,
    required this.message,
    this.compact = false,
  });

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.red,
                fontSize: compact ? 11 : 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── InfoNotice ──────────────────────────────────────────────────────────────

class InfoNotice extends StatelessWidget {
  const InfoNotice({
    super.key,
    required this.message,
    this.color,
    this.icon,
    this.action,
  });

  final String message;
  final Color? color;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = color ?? colors.blue;
    final i = icon ?? Icons.info_outline_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 16, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: c,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action!,
          ],
        ],
      ),
    );
  }
}

// ─── Spinner ─────────────────────────────────────────────────────────────────

class Spinner extends StatelessWidget {
  const Spinner({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: context.colors.accent,
      ),
    );
  }
}

// ─── LabeledField ────────────────────────────────────────────────────────────

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 1),
          Text(
            hint!,
            style: TextStyle(
              color: colors.muted,
              fontSize: 9.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

// ─── SearchField ─────────────────────────────────────────────────────────────

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint ?? 'Поиск…',
        prefixIcon: const Icon(Icons.search_rounded, size: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.accent),
        ),
        isDense: true,
        fillColor: colors.panel,
        filled: true,
        hintStyle: TextStyle(color: colors.muted, fontSize: 11.5),
      ),
      onChanged: onChanged,
    );
  }
}

// ─── SegmentedTabs ───────────────────────────────────────────────────────────

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
    this.scrollable = false,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (scrollable) {
      return Container(
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.line),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              _SegmentTab(
                label: tabs[i],
                selected: i == selected,
                onTap: () => onChanged(i),
              ),
            ],
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: _SegmentTab(
                label: tabs[i],
                selected: i == selected,
                onTap: () => onChanged(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? colors.accent : colors.muted,
          ),
        ),
      ),
    );
  }
}

// ─── ProgressLine ────────────────────────────────────────────────────────────

class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.value,
    this.max = 1.0,
    this.color,
    this.height = 5,
  });

  final double value;
  final double max;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: max > 0 ? value / max : 0,
        minHeight: height,
        backgroundColor: colors.panelAlt,
        valueColor: AlwaysStoppedAnimation(color ?? colors.accent),
      ),
    );
  }
}

// ─── KeyValueRow ─────────────────────────────────────────────────────────────

class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.muted),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? colors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── IconSquare ──────────────────────────────────────────────────────────────

class IconSquare extends StatelessWidget {
  const IconSquare({
    super.key,
    required this.icon,
    required this.color,
    this.size = 24,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

// ─── MiniStat ────────────────────────────────────────────────────────────────

class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.muted,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color ?? colors.text,
          ),
        ),
      ],
    );
  }
}

// ─── showFormDialog (generic, returns result via Navigator.pop) ────────────

/// Shows a form dialog that calls [onSubmit] on save.
///
/// Returns the value returned by [onSubmit], or [null] if the dialog was
/// dismissed without saving (user pressed Cancel or the barrier).
Future<T?> showFormDialog<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  required String submitLabel,
  required Future<T?> Function() onSubmit,
  String? description,
  double maxWidth = 540,
  bool wide = false,
}) {
  return showDialog<T?>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _AsyncFormDialog<T?>(
      title: title,
      description: description,
      submitLabel: submitLabel,
      onSubmit: onSubmit,
      maxWidth: wide ? 860 : maxWidth,
      builder: builder,
    ),
  );
}

class _AsyncFormDialog<T> extends StatefulWidget {
  const _AsyncFormDialog({
    required this.title,
    required this.description,
    required this.submitLabel,
    required this.onSubmit,
    required this.builder,
    required this.maxWidth,
  });

  final String title;
  final String? description;
  final String submitLabel;
  final Future<T?> Function() onSubmit;
  final WidgetBuilder builder;
  final double maxWidth;

  @override
  State<_AsyncFormDialog<T>> createState() => _AsyncFormDialogState<T>();
}

class _AsyncFormDialogState<T> extends State<_AsyncFormDialog<T>> {
  bool _busy = false;
  bool _closing = false;
  String? _error;

  Future<void> _close() async {
    if (_closing || !mounted) return;

    _closing = true;

    // Закрываем диалог независимо от состояния сохранения.
    Navigator.of(context).pop<T?>(null);
  }

  Future<void> _submit() async {
    if (_busy || _closing || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await widget.onSubmit();

      if (!mounted || _closing) return;

      _closing = true;
      Navigator.of(context).pop<T?>(result);
    } catch (error, stackTrace) {
      debugPrint('Channel form submit error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || _closing) return;

      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: true,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth,
            maxHeight: media.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (widget.description != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.description!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _close,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Закрыть',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: widget.builder(context),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: ErrorNotice(message: _error!),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _close,
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(widget.submitLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
