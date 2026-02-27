import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../routes/app_routes.dart';
import '../services/auth_service.dart';

/// Daftar fitur yang dibatasi untuk pengguna tamu.
const Set<String> fiturTerbatasGuest = <String>{
  RuteAplikasi.portofolio,
  RuteAplikasi.zakat,
  RuteAplikasi.psikolog,
  RuteAplikasi.konsultasi,
  RuteAplikasi.editProfil,
  RuteAplikasi.sertifikat,
  RuteAplikasi.notifikasi,
};

/// Cek apakah fitur tertentu dilarang untuk guest.
/// Jika ya, tampilkan dialog ajakan daftar dan return `true`.
/// Jika tidak (user terdaftar), return `false`.
bool cekAksesGuest(BuildContext context, String rute) {
  final AuthService auth = AuthService.instance;

  // Jika belum login atau bukan guest, izinkan akses
  if (!auth.sudahLogin || !auth.adalahTamu) {
    return false;
  }

  // Jika fitur tidak dibatasi, izinkan
  if (!fiturTerbatasGuest.contains(rute)) {
    return false;
  }

  // Tampilkan dialog
  tampilkanDialogDaftar(context);
  return true;
}

/// Tampilkan bottom sheet ajakan daftar akun.
void tampilkanDialogDaftar(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Symbols.lock,
                color: Color(0xFFF59E0B),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'Fitur Terbatas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              'Fitur ini memerlukan akun terdaftar.\nBuat akun gratis untuk mengakses portofolio,\nzakat, konsultasi, dan fitur lainnya.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Register button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: const Color(0x44059669),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Get.toNamed(RuteAplikasi.register);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Symbols.person_add, size: 18),
                    const SizedBox(width: 8),
                    const Text('Daftar Sekarang'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Login button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Get.toNamed(RuteAplikasi.login);
                },
                child: Text(
                  'Sudah punya akun? Masuk',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Dismiss
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Nanti Saja',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
