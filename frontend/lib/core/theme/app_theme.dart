import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ocean blue & white theme
class AppColors {
  // Primary - Ocean blue
  static const Color primary = Color(0xFF0288D1);
  static const Color primaryLight = Color(0xFF4FC3F7);
  static const Color primaryDark = Color(0xFF01579B);
  /// Trùng primary (theme); dùng [chartCategoryColor] cho biểu đồ nhiều danh mục.
  static const Color secondary = Color(0xFF0288D1);
  static const Color accent = Color(0xFFE64A19);

  // Gradient - ocean blue to white
  static const Color gradientStart = Color(0xFFE3F2FD);
  static const Color gradientEnd = Color(0xFFFFFFFF);

  // White/light backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5FAFF);

  // Income/Expense (green= thu, đỏ = chi)
  static const Color income = Color(0xFF4CAF50);
  static const Color expense = Color(0xFFD32F2F);

  // Text - dark for contrast on white
  static const Color textPrimary = Color(0xFF1A237E);
  static const Color textSecondary = Color(0xFF37474F);
  static const Color textMuted = Color(0xFF78909C);

  // Robot accent
  static const Color robotFace = Color(0xFF0288D1);
  static const Color robotBody = Color(0xFF0288D1);

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0288D1).withOpacity(0.08),
      blurRadius: 32,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2D2D2D);

  /// Màu khác nhau cho từng danh mục trên donut/pie (tránh primary/secondary trùng màu).
  static const List<Color> chartCategoryPalette = [
    Color(0xFF0288D1), // xanh dương
    Color(0xFFD32F2F), // đỏ
    Color(0xFF4CAF50), // xanh lá
    Color(0xFFFF9800), // cam
    Color(0xFF9C27B0), // tím
    Color(0xFF00ACC1), // cyan
    Color(0xFF795548), // nâu
    Color(0xFFE91E63), // hồng
    Color(0xFF3F51B5), // chàm
    Color(0xFF8BC34A), // xanh nhạt
    Color(0xFFFFC107), // vàng
    Color(0xFF607D8B), // xám xanh
    Color(0xFFFF7043), // cam đậm
    Color(0xFF5C6BC0), // tím xanh
  ];

  static Color chartCategoryColor(int index) =>
      chartCategoryPalette[index % chartCategoryPalette.length];
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.nunito().fontFamily,
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData.light().textTheme).copyWith(
        bodyLarge: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w400),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryLight,
        secondary: AppColors.primary,
        surface: AppColors.darkSurface,
        error: AppColors.accent,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily: GoogleFonts.nunito().fontFamily,
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyLarge: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white),
        bodyMedium: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white70),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
