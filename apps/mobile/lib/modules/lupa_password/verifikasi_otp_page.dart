import 'dart:async';

import 'package:averroes_core/averroes_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/routes/app_routes.dart';
import '../../app/services/api_dio.dart';
import '../../presentation/common/app_logo_badge.dart';
import '../../presentation/common/auth_ui_kit.dart';

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
  final Dio _dio = ApiDio.createAuth(attachAuthToken: false);
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String _email = '';
  String _mode = 'reset';
  bool _isVerifying = false;
  bool _isResetting = false;
  bool _otpVerified = false;
  String _verifiedKode = '';
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map<String, String>) {
      _email = args['email'] ?? '';
      _mode = args['mode'] ?? 'reset';
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
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_countdown <= 0) {
        timer.cancel();
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
      _showMessage('enter_6_digit_otp'.tr, isError: true);
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
        if (_mode == 'register') {
          _showMessage('otp_valid'.tr);
          Get.offAllNamed(RuteAplikasi.login);
        } else {
          setState(() {
            _otpVerified = true;
            _verifiedKode = kode;
          });
          _showMessage('otp_valid'.tr);
        }
      } else {
        _showMessage('otp_invalid'.tr, isError: true);
      }
    } on DioException catch (error) {
      final dynamic data = error.response?.data;
      final String message = _extractMessage(
        data,
        fallback:
            data is Map<String, dynamic> ? 'general_error'.tr : 'network_error'.tr,
      );
      _showMessage(message, isError: true);
    } catch (_) {
      _showMessage('general_error'.tr, isError: true);
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
      _showMessage('new_password_min'.tr, isError: true);
      return;
    }
    if (pw != confirmPw) {
      _showMessage('password_not_match'.tr, isError: true);
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
        _showMessage(
          _extractMessage(data, fallback: 'password_changed_success'.tr),
        );
        Get.offAllNamed(RuteAplikasi.login);
      } else {
        _showMessage('failed_change_password'.tr, isError: true);
      }
    } on DioException catch (error) {
      final dynamic data = error.response?.data;
      final String message = _extractMessage(
        data,
        fallback:
            data is Map<String, dynamic> ? 'general_error'.tr : 'network_error'.tr,
      );
      _showMessage(message, isError: true);
    } catch (_) {
      _showMessage('general_error'.tr, isError: true);
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
      _showMessage('new_otp_sent'.tr);
      _startCountdown();
      for (final TextEditingController c in _otpControllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } on DioException catch (error) {
      final dynamic data = error.response?.data;
      final String message = _extractMessage(
        data,
        fallback: 'failed_resend_otp'.tr,
      );
      _showMessage(message, isError: true);
    } catch (_) {
      _showMessage('failed_resend_otp'.tr, isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    AuthUiKit.showSnack(
      message: message,
      isError: isError,
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
      backgroundColor: AuthUiKit.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _otpVerified
                      ? _buildResetPasswordForm()
                      : _buildOTPForm(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPForm() {
    return Column(
      key: const ValueKey<String>('otp-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 12),
        _HeaderSection(
          badgeTint: const Color(0xFFEAF7F2),
          badgeBorder: const Color(0xFFCBEBDD),
          title: 'verify_otp_title'.tr,
          subtitleWidget: RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
                height: 1.5,
              ),
              children: <TextSpan>[
                TextSpan(text: 'otp_sent_to'.tr),
                TextSpan(
                  text: _email,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'verify_otp_title'.tr,
            style: AuthUiKit.labelStyle(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List<Widget>.generate(6, (int i) {
            return _OtpField(
              controller: _otpControllers[i],
              focusNode: _focusNodes[i],
              onChanged: (String value) {
                if (value.isNotEmpty && i < 5) {
                  _focusNodes[i + 1].requestFocus();
                }
                if (value.isEmpty && i > 0) {
                  _focusNodes[i - 1].requestFocus();
                }
              },
            );
          }),
        ),
        const SizedBox(height: 18),
        _PrimaryActionButton(
          isLoading: _isVerifying,
          label: 'verify_button'.tr,
          icon: Symbols.verified,
          onPressed: _verifikasiOTP,
        ),
        const SizedBox(height: 18),
        _ResendSection(
          countdown: _countdown,
          onTap: _resendOTP,
        ),
      ],
    );
  }

  Widget _buildResetPasswordForm() {
    return Column(
      key: const ValueKey<String>('reset-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 12),
        _HeaderSection(
          badgeTint: const Color(0xFFEAF7F2),
          badgeBorder: const Color(0xFFCBEBDD),
          title: 'create_new_password'.tr,
          subtitleWidget: Text(
            'new_password_subtitle'.tr,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _PasswordFieldBlock(
          label: 'new_password'.tr,
          hint: 'password_hint_8'.tr,
          controller: _newPasswordController,
          obscure: _obscureNew,
          onToggle: () => setState(() => _obscureNew = !_obscureNew),
        ),
        const SizedBox(height: 16),
        _PasswordFieldBlock(
          label: 'confirm_password'.tr,
          hint: 'reenter_new_password'.tr,
          controller: _confirmPasswordController,
          obscure: _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 18),
        _PrimaryActionButton(
          isLoading: _isResetting,
          label: 'save_new_password'.tr,
          icon: Symbols.check_circle,
          onPressed: _resetPassword,
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Symbols.arrow_back_ios_new,
              size: 20,
              color: AppColors.slate,
            ),
          ),
          const Spacer(),
          const AppLogoBadge(
            size: 48,
            radius: 14,
            padding: 8,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.badgeTint,
    required this.badgeBorder,
    required this.title,
    required this.subtitleWidget,
  });

  final Color badgeTint;
  final Color badgeBorder;
  final String title;
  final Widget subtitleWidget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppLogoBadge(
          size: 96,
          radius: 28,
          padding: 10,
          backgroundColor: badgeTint,
          borderColor: badgeBorder,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.slate,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        subtitleWidget,
      ],
    );
  }
}

class _OtpField extends StatelessWidget {
  const _OtpField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.slate,
        ),
        decoration: AuthUiKit.inputDecoration(
          hintText: '',
        ).copyWith(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintStyle: const TextStyle(fontSize: 0),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _PasswordFieldBlock extends StatelessWidget {
  const _PasswordFieldBlock({
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: AuthUiKit.labelStyle(),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: AuthUiKit.inputDecoration(
            hintText: hint,
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscure ? Symbols.visibility : Symbols.visibility_off,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.isLoading,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final bool isLoading;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: AuthUiKit.primaryButtonStyle(
          foregroundColor: Colors.white,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ),
      ),
    );
  }
}

class _ResendSection extends StatelessWidget {
  const _ResendSection({
    required this.countdown,
    required this.onTap,
  });

  final int countdown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool disabled = countdown > 0;
    return Center(
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
            children: <TextSpan>[
              TextSpan(text: 'not_receive_code'.tr),
              TextSpan(
                text: disabled
                    ? '${'resend'.tr} (${countdown}s)'
                    : 'resend_capital'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: disabled ? AppColors.muted : AppColors.emerald,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
