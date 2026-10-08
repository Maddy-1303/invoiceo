import 'package:flutter/material.dart';
import 'package:invoiceo/theme/brand_colors.dart';

class AppTheme {
  // Non-Latin app-UI text (Nepali/Hindi Devanagari, Tibetan, Tamil) falls back
  // to these bundled fonts instead of rendering as tofu boxes.
  static const _scriptFontFallback = [
    'NotoSansDevanagari',
    'NotoSerifTibetan',
    'NotoSansTamil',
  ];

  static ThemeData get light {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: BrandColors.primary,
        primary: BrandColors.primary,
        secondary: BrandColors.accent,
      ),
      primaryColor: BrandColors.primary,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      fontFamilyFallback: _scriptFontFallback,
    );
    return base.copyWith(
      // Explicit split between the page canvas and card surfaces — cards
      // are pure white, the page sits on a very light grey behind them,
      // so cards actually stand out instead of blending into the page.
      scaffoldBackgroundColor: BrandColors.page,
      // White header with a hairline underneath instead of a coloured bar.
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.surface,
        foregroundColor: BrandColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: BrandColors.line)),
        titleTextStyle: TextStyle(
          color: BrandColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      //cardColor: Colors.grey[50],
      // White cards, dialogs and menus on the soft grey page.
      cardTheme: const CardThemeData(
          color: BrandColors.surface, surfaceTintColor: Colors.transparent),
      dialogTheme: const DialogThemeData(
          backgroundColor: BrandColors.surface,
          surfaceTintColor: Colors.transparent),
      popupMenuTheme: const PopupMenuThemeData(
          color: BrandColors.surface, surfaceTintColor: Colors.transparent),
      // App-wide dismiss (X) button on every SnackBar so users don't have
      // to wait one out.
      snackBarTheme: const SnackBarThemeData(
          showCloseIcon: true, closeIconColor: Colors.white),
      colorScheme: base.colorScheme.copyWith(
        surfaceContainer: Colors.grey[50]!,
        surface: Colors.grey[50]!,
        surfaceContainerHighest: Colors.white,
        outline: Colors.grey[400]!,
        outlineVariant: Colors.grey[300]!,
        onSurface: Colors.black,
        onSurfaceVariant: Colors.grey[600]!,
      ),
    );
  }

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        primaryColor: BrandColors.primaryOnDark,
        fontFamilyFallback: _scriptFontFallback,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: BrandColors.darkBar,
          foregroundColor: Colors.white,
        ),
        colorScheme: const ColorScheme.dark(
          primary: BrandColors.primaryOnDark,
          secondary: Color(0xFF60A5FA),
          surface: Color(0xFF1E1E1E),
          surfaceContainer: Color(0xFF1E1E1E),
          surfaceContainerHighest: Color(0xFF2A2A2A),
          outline: Color(0xFF4A4A4A),
          outlineVariant: Color(0xFF3A3A3A),
          onSurface: Color(0xFFCCCCCC),
          onSurfaceVariant: Color(0xFF9E9E9E),
        ),
        cardColor: const Color(0xFF1E1E1E),
        cardTheme: const CardThemeData(surfaceTintColor: Colors.transparent),
        snackBarTheme: const SnackBarThemeData(
            showCloseIcon: true, closeIconColor: Colors.white),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF262626),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );
}
