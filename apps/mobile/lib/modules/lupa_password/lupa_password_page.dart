import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/routes/app_routes.dart';
import '../../app/services/api_dio.dart';

class HalamanLupaPassword extends StatefulWidget {
  const HalamanLupaPassword({super.key});

  @override
  State<HalamanLupaPassword> createState() => _HalamanLupaPasswordState();
}

class _HalamanLupaPasswordState extends State<HalamanLupaPassword> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final Dio _dio = ApiDio.create(attachAuthToken: false);

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _kirimOTP() async {
    final FormState? state = _formKey.currentState;
    if (state == null || !state.validate()) {
      return;
    }
    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/auth/lupa-password',
        data: <String, dynamic>{
          'email': _emailController.text.trim(),
        },
      );

      final dynamic data = response.data;
      if (data is Map<String, dynamic> && data['status'] == true) {
        final String pesan = _extractMessage(data, fallback: 'OTP terkirim');
        _showMessage(pesan);

        // Navigate ke halaman OTP verification
        Get.toNamed(
          RuteAplikasi.verifikasiOtp,
          arguments: <String, String>{
            'email': _emailController.text.trim(),
          },
        );
      } else {
        _showMessage('Gagal mengirim OTP', isError: true);
      }
    } on DioException catch (error) {
      final dynamic data = error.response?.data;
      final String message = _extractMessage(
        data,
        fallback: data is Map<String, dynamic>
            ? 'Terjadi kesalahan'
            : 'Terjadi kesalahan jaringan',
      );
      _showMessage(message, isError: true);
    } catch (_) {
      _showMessage('Terjadi kesalahan', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    Get.snackbar(
      isError ? 'Gagal' : 'Berhasil',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor:
          isError ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
      colorText: const Color(0xFF0D1B18),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  String _extractMessage(dynamic data, {required String fallback}) {
    if (data is Map<String, dynamic>) {
      final String? pesan = data['pesan']?.toString();
      if (pesan != null && pesan.isNotEmpty) {
        return pesan;
      }
      final String? message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Symbols.arrow_back_ios_new,
                      size: 20,
                      color: Color(0xFF0D1B18),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 24),
                      // Icon
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Symbols.lock_reset,
                          color: Color(0xFFF59E0B),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Lupa Password?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D1B18),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Masukkan email yang terdaftar, kami akan mengirimkan kode OTP untuk mengatur ulang password Anda.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Email field
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Email',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0D1B18),
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Masukkan email terdaftar',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(
                            Symbols.mail,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFF59E0B)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (String? value) {
                          final String input = value?.trim() ?? '';
                          if (input.isEmpty) {
                            return 'Email wajib diisi';
                          }
                          if (!input.contains('@') || !input.contains('.')) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                            elevation: 6,
                            shadowColor: const Color(0x55F59E0B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          onPressed: _isLoading ? null : _kirimOTP,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    const Icon(Symbols.send, size: 18),
                                    const SizedBox(width: 8),
                                    const Text('Kirim Kode OTP'),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Back to login
                      Center(
                        child: GestureDetector(
                          onTap: () => Get.back(),
                          child: Text(
                            'Kembali ke halaman Masuk',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4C9A88),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
