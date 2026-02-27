import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/routes/app_routes.dart';
import '../../app/services/api_dio.dart';

class HalamanVerifikasiOTP extends StatefulWidget {
  const HalamanVerifikasiOTP({super.key});

  @override
  State<HalamanVerifikasiOTP> createState() => _HalamanVerifikasiOTPState();
}

class _HalamanVerifikasiOTPState extends State<HalamanVerifikasiOTP> {
  final List<TextEditingController> _otpControllers =
      List<TextEditingController>.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes =
      List<FocusNode>.generate(6, (_) => FocusNode());
  final Dio _dio = ApiDio.create(attachAuthToken: false);

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String _email = '';
  bool _isVerifying = false;
  bool _isResetting = false;
  bool _otpVerified = false;
  String _verifiedKode = '';
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Countdown timer untuk resend
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map<String, String>) {
      _email = args['email'] ?? '';
    }
    _startCountdown();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _otpControllers) {
      c.dispose();
    }
    for (final FocusNode n in _focusNodes) {
      n.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (_countdown <= 0) {
        t.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  String get _otpValue =>
      _otpControllers.map((TextEditingController c) => c.text).join();

  Future<void> _verifikasiOTP() async {
    final String kode = _otpValue;
    if (kode.length < 6) {
      _showMessage('Masukkan 6 digit kode OTP', isError: true);
      return;
    }
    if (_isVerifying) {
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/auth/verifikasi-otp',
        data: <String, dynamic>{
          'email': _email,
          'kode': kode,
        },
      );

      final dynamic data = response.data;
      if (data is Map<String, dynamic> && data['status'] == true) {
        setState(() {
          _otpVerified = true;
          _verifiedKode = kode;
        });
        _showMessage('Kode OTP valid! Silakan buat password baru.');
      } else {
        _showMessage('Kode OTP tidak valid', isError: true);
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
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final String pw = _newPasswordController.text;
    final String confirmPw = _confirmPasswordController.text;

    if (pw.isEmpty || pw.length < 8) {
      _showMessage('Password baru minimal 8 karakter', isError: true);
      return;
    }
    if (pw != confirmPw) {
      _showMessage('Konfirmasi password tidak cocok', isError: true);
      return;
    }
    if (_isResetting) {
      return;
    }

    setState(() => _isResetting = true);

    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/auth/reset-password',
        data: <String, dynamic>{
          'email': _email,
          'kode': _verifiedKode,
          'password_baru': pw,
        },
      );

      final dynamic data = response.data;
      if (data is Map<String, dynamic> && data['status'] == true) {
        _showMessage(_extractMessage(data, fallback: 'Password berhasil diubah'));
        // Kembali ke login
        Get.offAllNamed(RuteAplikasi.login);
      } else {
        _showMessage('Gagal mengubah password', isError: true);
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
        setState(() => _isResetting = false);
      }
    }
  }

  Future<void> _resendOTP() async {
    if (_countdown > 0) {
      return;
    }

    try {
      await _dio.post<dynamic>(
        '/api/auth/lupa-password',
        data: <String, dynamic>{'email': _email},
      );
      _showMessage('Kode OTP baru telah dikirim');
      _startCountdown();
      // Clear fields
      for (final TextEditingController c in _otpControllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } on DioException catch (error) {
      final dynamic data = error.response?.data;
      final String message = _extractMessage(data, fallback: 'Gagal mengirim ulang OTP');
      _showMessage(message, isError: true);
    } catch (_) {
      _showMessage('Gagal mengirim ulang OTP', isError: true);
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
                child: _otpVerified
                    ? _buildResetPasswordForm()
                    : _buildOTPForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 24),
        // Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Symbols.pin,
            color: Color(0xFF059669),
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Verifikasi Kode OTP',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D1B18),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
            children: <TextSpan>[
              const TextSpan(text: 'Kode verifikasi 6 digit telah dikirim ke '),
              TextSpan(
                text: _email,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // OTP Input Fields
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List<Widget>.generate(6, (int i) {
            return SizedBox(
              width: 48,
              height: 56,
              child: TextFormField(
                controller: _otpControllers[i],
                focusNode: _focusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D1B18),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF059669), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (String value) {
                  if (value.isNotEmpty && i < 5) {
                    _focusNodes[i + 1].requestFocus();
                  }
                  if (value.isEmpty && i > 0) {
                    _focusNodes[i - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        // Verify button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 6,
              shadowColor: const Color(0x55059669),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            onPressed: _isVerifying ? null : _verifikasiOTP,
            child: _isVerifying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Verifikasi'),
          ),
        ),
        const SizedBox(height: 20),
        // Resend OTP
        Center(
          child: GestureDetector(
            onTap: _countdown > 0 ? null : _resendOTP,
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
                children: <TextSpan>[
                  const TextSpan(text: 'Belum menerima kode? '),
                  TextSpan(
                    text: _countdown > 0
                        ? 'Kirim ulang (${_countdown}d)'
                        : 'Kirim Ulang',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _countdown > 0
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 24),
        // Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Symbols.lock_open,
            color: Color(0xFF059669),
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Buat Password Baru',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D1B18),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Password baru harus berbeda dari password sebelumnya dan minimal 8 karakter.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        // New password
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Password Baru',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0D1B18),
            ),
          ),
        ),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            hintText: 'Minimal 8 karakter',
            hintStyle:
                GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF059669)),
            ),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
              icon: Icon(
                _obscureNew ? Symbols.visibility : Symbols.visibility_off,
                color: const Color(0xFF94A3B8),
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
        // Confirm password
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Konfirmasi Password',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0D1B18),
            ),
          ),
        ),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            hintText: 'Masukkan ulang password baru',
            hintStyle:
                GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF059669)),
            ),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm
                    ? Symbols.visibility
                    : Symbols.visibility_off,
                color: const Color(0xFF94A3B8),
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 24),
        // Reset button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 6,
              shadowColor: const Color(0x55059669),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            onPressed: _isResetting ? null : _resetPassword,
            child: _isResetting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Symbols.check_circle, size: 18),
                      const SizedBox(width: 8),
                      const Text('Simpan Password Baru'),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
