import 'package:flutter/material.dart';

/// Single source of truth for the MediaCRM visual language.
/// The dark palette preserves the original product look; the light palette is
/// a complete counterpart for daylight work.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color panel;
  final Color panelAlt;
  final Color line;
  final Color accent;
  final Color accentSoft;
  final Color muted;
  final Color text;
  final Color green;
  final Color red;
  final Color pink;
  final Color blue;
  final Color yellow;
  final Color shadow;

  const AppColors({
    required this.bg,
    required this.panel,
    required this.panelAlt,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.muted,
    required this.text,
    required this.green,
    required this.red,
    required this.pink,
    required this.blue,
    required this.yellow,
    required this.shadow,
  });

  static const dark = AppColors(
    bg: Color(0xFF0D1018),
    panel: Color(0xFF151A26),
    panelAlt: Color(0xFF1B2231),
    line: Color(0xFF293246),
    accent: Color(0xFF8B7CFF),
    accentSoft: Color(0x338B7CFF),
    muted: Color(0xFF9AA5B8),
    text: Color(0xFFF2F4F9),
    green: Color(0xFF55D6A3),
    red: Color(0xFFFF5F6D),
    pink: Color(0xFFFF829D),
    blue: Color(0xFF78A7FF),
    yellow: Color(0xFFFFC56E),
    shadow: Color(0x66000000),
  );

  static const light = AppColors(
    bg: Color(0xFFF3F5FA),
    panel: Color(0xFFFFFFFF),
    panelAlt: Color(0xFFEDF0F7),
    line: Color(0xFFDCE2ED),
    accent: Color(0xFF6757E8),
    accentSoft: Color(0x1A6757E8),
    muted: Color(0xFF66708A),
    text: Color(0xFF141A29),
    green: Color(0xFF139A6B),
    red: Color(0xFFD93A4B),
    pink: Color(0xFFD9506F),
    blue: Color(0xFF2D6FE0),
    yellow: Color(0xFFB57A12),
    shadow: Color(0x1A1B2438),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? panel,
    Color? panelAlt,
    Color? line,
    Color? accent,
    Color? accentSoft,
    Color? muted,
    Color? text,
    Color? green,
    Color? red,
    Color? pink,
    Color? blue,
    Color? yellow,
    Color? shadow,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      panel: panel ?? this.panel,
      panelAlt: panelAlt ?? this.panelAlt,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      muted: muted ?? this.muted,
      text: text ?? this.text,
      green: green ?? this.green,
      red: red ?? this.red,
      pink: pink ?? this.pink,
      blue: blue ?? this.blue,
      yellow: yellow ?? this.yellow,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelAlt: Color.lerp(panelAlt, other.panelAlt, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      text: Color.lerp(text, other.text, t)!,
      green: Color.lerp(green, other.green, t)!,
      red: Color.lerp(red, other.red, t)!,
      pink: Color.lerp(pink, other.pink, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.dark;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => colors.bg;
  Color get panel => colors.panel;
  Color get panelAlt => colors.panelAlt;
  Color get line => colors.line;
  Color get accent => colors.accent;
  Color get muted => colors.muted;
  Color get textColor => colors.text;
}

class AppTheme {
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: Colors.white,
      primaryContainer: colors.accentSoft,
      onPrimaryContainer: colors.text,
      secondary: colors.blue,
      onSecondary: Colors.white,
      tertiary: colors.green,
      onTertiary: Colors.black,
      error: colors.red,
      onError: Colors.white,
      surface: colors.panel,
      onSurface: colors.text,
      surfaceContainerHighest: colors.panelAlt,
      onSurfaceVariant: colors.muted,
      outline: colors.line,
      outlineVariant: colors.line.withValues(alpha: 0.55),
      shadow: colors.shadow,
      scrim: Colors.black54,
      inverseSurface: colors.text,
      onInverseSurface: colors.bg,
      inversePrimary: colors.accent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.bg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme
        .apply(bodyColor: colors.text, displayColor: colors.text)
        .copyWith(
          displayLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: colors.text,
            height: 1.1,
          ),
          headlineMedium: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: colors.text,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: colors.text,
          ),
          titleMedium: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
          bodyLarge: TextStyle(fontSize: 14, color: colors.text, height: 1.45),
          bodyMedium: TextStyle(fontSize: 13, color: colors.text, height: 1.45),
          bodySmall: TextStyle(fontSize: 12, color: colors.muted, height: 1.4),
          labelLarge: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [colors],
      dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colors.muted, size: 20),
      ),
      cardTheme: CardThemeData(
        color: colors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.line),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.panel,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.panelAlt,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        hintStyle: TextStyle(color: colors.muted, fontSize: 13),
        labelStyle: TextStyle(color: colors.muted, fontSize: 13),
        floatingLabelStyle: TextStyle(color: colors.accent, fontSize: 13),
        border: _border(colors.line),
        enabledBorder: _border(colors.line),
        focusedBorder: _border(colors.accent, width: 1.4),
        errorBorder: _border(colors.red),
        focusedErrorBorder: _border(colors.red, width: 1.4),
        disabledBorder: _border(colors.line.withValues(alpha: 0.5)),
        prefixIconColor: colors.muted,
        suffixIconColor: colors.muted,
        errorStyle: TextStyle(color: colors.red, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.panelAlt,
          disabledForegroundColor: colors.muted,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.text,
          side: BorderSide(color: colors.line),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.muted,
          highlightColor: colors.accentSoft,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.panelAlt,
        contentTextStyle: TextStyle(color: colors.text, fontSize: 13),
        actionTextColor: colors.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.line),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.panelAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.line),
        ),
        textStyle: TextStyle(color: colors.text, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.panelAlt,
        selectedColor: colors.accentSoft,
        disabledColor: colors.panelAlt,
        side: BorderSide(color: colors.line),
        labelStyle: TextStyle(color: colors.text, fontSize: 12),
        secondaryLabelStyle: TextStyle(color: colors.accent, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.panel),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.line),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.line),
        ),
        textStyle: TextStyle(color: colors.text, fontSize: 13),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.panel),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.line),
            ),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : colors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : colors.panelAlt,
        ),
        trackOutlineColor: WidgetStatePropertyAll(colors.line),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: colors.line, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(colors.line),
        radius: const Radius.circular(8),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.panelAlt,
        circularTrackColor: colors.panelAlt,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.panel,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: colors.panelAlt,
        headerForegroundColor: colors.text,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.line),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.muted,
        textColor: colors.text,
        subtitleTextStyle: TextStyle(color: colors.muted, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: colors.muted,
        collapsedIconColor: colors.muted,
        textColor: colors.text,
        collapsedTextColor: colors.text,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
}
