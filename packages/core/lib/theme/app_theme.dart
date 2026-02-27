import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class TemaAverroes {
  const TemaAverroes._();

  static ThemeData get temaUtama {
    final ColorScheme skema = ColorScheme.fromSeed(
      seedColor: AppColors.emeraldDark,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      scaffoldBackgroundColor: AppColors.sand,
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: AppColors.slate,
        displayColor: AppColors.slate,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.sand,
        foregroundColor: AppColors.slate,
        elevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.slate,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        indicatorColor: AppColors.emeraldSoft,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(color: AppColors.muted),
        ),
      ),
    );
  }
}
