import 'package:flutter/material.dart';

class CustomerPortalTheme {
  const CustomerPortalTheme._();

  static const _primary = Color(0xff1f6f43);
  static const _secondary = Color(0xff2563eb);
  static const _tertiary = Color(0xffb7791f);
  static const _error = Color(0xffb42318);
  static const _background = Color(0xfff7f9f5);
  static const _surface = Color(0xffffffff);
  static const _surfaceLow = Color(0xfff1f5ee);
  static const _surfaceMid = Color(0xffeaf0e7);
  static const _text = Color(0xff1f2a24);
  static const _mutedText = Color(0xff59655b);
  static const _outline = Color(0xffb8c3b7);
  static const _outlineSoft = Color(0xffdde5da);

  static ThemeData light() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
    );
    final scheme = baseScheme.copyWith(
      primary: _primary,
      secondary: _secondary,
      tertiary: _tertiary,
      error: _error,
      surface: _surface,
      onSurface: _text,
      onSurfaceVariant: _mutedText,
      outline: _outline,
      outlineVariant: _outlineSoft,
      surfaceContainerLowest: _surface,
      surfaceContainerLow: _surfaceLow,
      surfaceContainer: _surfaceMid,
      surfaceContainerHigh: const Color(0xffe3ebe0),
      surfaceContainerHighest: const Color(0xffdce6da),
      primaryContainer: const Color(0xffd9f2df),
      onPrimaryContainer: const Color(0xff0d3a21),
      secondaryContainer: const Color(0xffdbeafe),
      onSecondaryContainer: const Color(0xff173a8a),
      tertiaryContainer: const Color(0xfffff1c2),
      onTertiaryContainer: const Color(0xff5f3b00),
      errorContainer: const Color(0xffffe0dc),
      onErrorContainer: const Color(0xff6f120b),
    );

    final textTheme = Typography.blackCupertino.apply(
      bodyColor: _text,
      displayColor: _text,
      fontFamily: 'Roboto',
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _background,
      canvasColor: _background,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: _mutedText,
          letterSpacing: 0,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: _mutedText,
          letterSpacing: 0,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _outlineSoft,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _outlineSoft),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _error),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _mutedText,
        textColor: _text,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceLow,
        selectedColor: scheme.primaryContainer,
        disabledColor: _surfaceMid,
        side: const BorderSide(color: _outlineSoft),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(color: _text, fontWeight: FontWeight.w600),
        secondaryLabelStyle:
            const TextStyle(color: _text, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(_primary),
          side: const WidgetStatePropertyAll(BorderSide(color: _outline)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(_primary),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _text,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white),
      ),
    );
  }
}
