import 'package:flutter/material.dart';

import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/widgets/ui.dart';
import 'package:media_crm/data/models/platform_channel.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.days,
    required this.onChanged,
    this.allowAll = true,
    this.onCustom,
    this.customLabel,
  });

  final int days;
  final ValueChanged<int> onChanged;
  final bool allowAll;
  final VoidCallback? onCustom;
  final String? customLabel;

  static const _options = <int, String>{
    7: '7 дн.',
    30: '30 дн.',
    90: '90 дн.',
    365: 'Год',
    0: 'Всё время',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final entry in _options.entries)
          if (entry.key != 0 || allowAll)
            _SegmentButton(
              label: entry.value,
              selected: days == entry.key && customLabel == null,
              onTap: () => onChanged(entry.key),
            ),
        if (onCustom != null)
          _SegmentButton(
            label: customLabel ?? 'Период…',
            selected: customLabel != null,
            icon: Icons.date_range_outlined,
            onTap: onCustom!,
          ),
      ],
    );
  }

  static String labelForDays(int days) => switch (days) {
        7 => '7 дн.',
        30 => '30 дн.',
        90 => '90 дн.',
        365 => 'Год',
        _ => 'Всё время',
      };
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? colors.accent.withValues(alpha: 0.5) : colors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: selected ? colors.accent : colors.muted,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? colors.accent : colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlatformDropdown extends StatelessWidget {
  const PlatformDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowAll = true,
    this.platforms = PlatformType.values,
    this.width,
  });

  final PlatformType? value;
  final ValueChanged<PlatformType?> onChanged;
  final bool allowAll;
  final List<PlatformType> platforms;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final field = Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PlatformType?>(
          value: value,
          isDense: true,
          isExpanded: width != null,
          dropdownColor: colors.panel,
          borderRadius: BorderRadius.circular(10),
          icon: Icon(Icons.expand_more_rounded, size: 16, color: colors.muted),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
          items: [
            if (allowAll)
              DropdownMenuItem<PlatformType?>(
                value: null,
                child: Text('Все площадки',
                    style: TextStyle(fontSize: 11.5, color: colors.muted)),
              ),
            for (final platform in platforms)
              DropdownMenuItem<PlatformType?>(
                value: platform,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      platformIcon(platform),
                      size: 13,
                      color: platformColor(platform),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      platform.label,
                      style: TextStyle(fontSize: 11.5, color: colors.text),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }
}

class FilterBarShell extends StatelessWidget {
  const FilterBarShell({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.line),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 9,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

class SmallIconButton extends StatelessWidget {
  const SmallIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        iconSize: 16,
        color: color,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          side: BorderSide(color: context.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class DataSourceNote extends StatelessWidget {
  const DataSourceNote({super.key, required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: context.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.muted,
              fontSize: 10.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
