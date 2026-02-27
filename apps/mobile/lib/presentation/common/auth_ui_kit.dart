import 'package:averroes_core/averroes_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthUiKit {
  const AuthUiKit._();

  static const Color background = Color(0xFFF6F8F8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocus = AppColors.emerald;
  static const Color softBrand = Color(0xFFE7F3F0);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color successBg = Color(0xFFDCFCE7);

  static TextStyle labelStyle() => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.slate,
      );

  static TextStyle hintStyle() => GoogleFonts.plusJakartaSans(
        color: AppColors.muted,
        fontWeight: FontWeight.w500,
      );

  static InputDecoration inputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle(),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderFocus),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  static ButtonStyle primaryButtonStyle({
    required Color foregroundColor,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.emerald,
      foregroundColor: foregroundColor,
      elevation: 3,
      shadowColor: const Color(0x330F766E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }

  static ButtonStyle secondaryOutlineButtonStyle() {
    return OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  static void showSnack({
    required String message,
    required bool isError,
    String? successTitle,
  }) {
    Get.snackbar(
      isError ? 'Gagal' : (successTitle ?? 'Berhasil'),
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? dangerBg : successBg,
      colorText: AppColors.slate,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }
}

class AuthBrandTile extends StatelessWidget {
  const AuthBrandTile({super.key, this.size = 40, this.radius = 12});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AuthUiKit.border),
      ),
      alignment: Alignment.center,
      child: _GoogleLogoGlyph(size: size * 0.76),
    );
  }
}

class _GoogleLogoGlyph extends StatelessWidget {
  const _GoogleLogoGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF4285F4), // Blue
                Color(0xFFEA4335), // Red
                Color(0xFFFBBC05), // Yellow
                Color(0xFF34A853), // Green
              ],
              stops: <double>[0.0, 0.35, 0.62, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            'G',
            style: GoogleFonts.notoSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
