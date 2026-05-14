import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'opus_tokens.dart';

/// 앱 전체 테마 — OPUS-X 디자인 토큰 기반 (Material 3).
class AppTheme {
  AppTheme._();

  static const Color _primary  = OpusColors.purple600;
  static const Color _accent   = OpusColors.purple500;
  static const Color _surface  = OpusColors.bgBase;
  static const Color _canvas   = OpusColors.bgCanvas;

  // 위치 핀
  static const Color pinFixed   = OpusColors.green500;
  static const Color pinUnfixed = OpusColors.yellow500;

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: Colors.white,
      secondary: _accent,
      tertiary: OpusColors.teal500,
      error: OpusColors.red600,
      surface: _surface,
    );

    final base = GoogleFonts.notoSansKrTextTheme();
    final textTheme = base.copyWith(
      displayLarge: GoogleFonts.sora(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        color: OpusColors.gray900,
        letterSpacing: -0.4,
      ),
      headlineMedium: GoogleFonts.notoSansKr(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: OpusColors.gray900,
        letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.notoSansKr(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: OpusColors.gray900,
      ),
      titleMedium: GoogleFonts.notoSansKr(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: OpusColors.gray900,
      ),
      bodyLarge: GoogleFonts.notoSansKr(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: OpusColors.gray700,
      ),
      bodyMedium: GoogleFonts.notoSansKr(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: OpusColors.gray600,
      ),
      bodySmall: GoogleFonts.notoSansKr(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: OpusColors.gray500,
      ),
      labelLarge: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _canvas,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: _surface,
        foregroundColor: OpusColors.gray900,
        titleTextStyle: GoogleFonts.notoSansKr(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: OpusColors.gray900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OpusRadius.xl),
          side: const BorderSide(color: OpusColors.gray100),
        ),
        color: _surface,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OpusRadius.xl),
          ),
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OpusRadius.xl),
          ),
          side: const BorderSide(color: OpusColors.purple200),
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OpusColors.gray50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpusRadius.xl),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpusRadius.xl),
          borderSide: const BorderSide(color: OpusColors.gray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpusRadius.xl),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: GoogleFonts.notoSansKr(
          fontSize: 14,
          color: OpusColors.gray400,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 6,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: OpusColors.purple50,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.notoSansKr(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? OpusColors.purple700
                : OpusColors.gray500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? OpusColors.purple600
                : OpusColors.gray500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OpusRadius.xl),
        ),
        backgroundColor: OpusColors.gray900,
        contentTextStyle: GoogleFonts.notoSansKr(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OpusRadius.xl3),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: OpusColors.gray100,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: OpusColors.gray100,
        labelStyle: GoogleFonts.notoSansKr(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: OpusColors.gray700,
        ),
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),
    );
  }

  /// 다크 테마 — 색상만 OPUS-X 톤으로 살짝 조정, 컴포넌트는 라이트와 동일 구조.
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.dark,
      primary: OpusColors.purple400,
      secondary: OpusColors.purple300,
      tertiary: OpusColors.teal500,
      error: OpusColors.red500,
      surface: OpusColors.gray900,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: OpusColors.gray900,
      textTheme: GoogleFonts.notoSansKrTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: OpusColors.gray900,
        foregroundColor: Colors.white,
      ),
    );
  }
}
