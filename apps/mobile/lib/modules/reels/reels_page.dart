import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:averroes_core/averroes_core.dart';

class HalamanReels extends StatelessWidget {
  const HalamanReels({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Refleksi'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Ayat, hadits, dan kaidah fiqh yang menenangkan.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.slate,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Konten teks tematik akan hadir bertahap.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
