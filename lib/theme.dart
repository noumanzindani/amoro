import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// IMIC-style palette: pure black, dark-gray surfaces, white text, with a
/// rose accent instead of IMIC's brick red.
class AppColors {
  static const black = Color(0xFF000000);
  static const surface = Color(0xFF191919);
  static const surfaceHigh = Color(0xFF262626);
  static const rose = Color(0xFFE5395C);
  static const gold = Color(0xFFFFD700);
  static const white = Color(0xFFFFFFFF);
  static const muted = Color(0x99FFFFFF); // white @ 60%
  static const field = Color(0x1FFFFFFF); // translucent input fill
  static const outline = Color(0x33FFFFFF);
}

const _radius = 12.0;

ThemeData buildTheme() {
  final scheme = const ColorScheme.dark(
    primary: AppColors.rose,
    onPrimary: AppColors.white,
    secondary: AppColors.gold,
    onSecondary: AppColors.black,
    surface: AppColors.black,
    onSurface: AppColors.white,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerHighest: AppColors.surface,
    outline: AppColors.outline,
    outlineVariant: AppColors.outline,
    error: Color(0xFFFF5A5A),
  );
  final text = GoogleFonts.interTextTheme(
    ThemeData.dark().textTheme,
  ).apply(bodyColor: AppColors.white, displayColor: AppColors.white);
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_radius),
  );
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.black,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.black,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.white,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.rose,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.rose.withValues(alpha: 0.5),
        disabledForegroundColor: AppColors.white.withValues(alpha: 0.6),
        shape: rounded,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.outline),
        shape: rounded,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.rose,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.white),
      prefixIconColor: AppColors.white,
      suffixIconColor: AppColors.white,
      counterStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.rose,
      disabledColor: AppColors.surface,
      checkmarkColor: AppColors.white,
      labelStyle: GoogleFonts.inter(
        color: AppColors.white,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.muted,
      textColor: AppColors.white,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.surfaceHigh,
      space: 1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.black,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Color(0xFF757575),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: GoogleFonts.inter(color: AppColors.white),
      shape: rounded,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.rose,
      linearTrackColor: AppColors.surfaceHigh,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.rose,
      thumbColor: AppColors.rose,
      inactiveTrackColor: AppColors.surfaceHigh,
    ),
  );
}
