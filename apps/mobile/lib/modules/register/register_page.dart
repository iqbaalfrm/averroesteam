import 'package:dio/dio.dart';
import 'package:averroes_core/averroes_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/routes/app_routes.dart';
import '../../app/services/api_dio.dart';
import '../../app/services/auth_service.dart';
import '../../presentation/common/app_logo_badge.dart';
import '../../presentation/common/auth_ui_kit.dart';

class HalamanRegister extends StatefulWidget {
  const HalamanRegister({super.key});

  @override
  State<HalamanRegister> createState() => _HalamanRegisterState();
}

class _HalamanRegisterState extends State<HalamanRegister> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final Dio _dio = ApiDio.createAuth(attachAuthToken: false);

  bool _obscurePassword = true;
  bool _agreeTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? state = _formKey.currentState;
    if (state == null || !state.validate()) {
      return;
    }
    if (!_agreeTerms) {
      _showMessage('must_agree_terms'.tr, isError: true);
      return;
    }

    await _runRequest(() async {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/auth/register',
        data: <String, dynamic>{
          'nama': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );

      await _handleAuthResponse(response);
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    AuthUiKit.showSnack(
      message: message,
      isError: isError,
      successTitle: 'Info',
    );
  }

  Future<void> _runRequest(Future<void> Function() action) async {
    if (_isLoading) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await action();
    } on DioException catch (error) {
      final dynamic data = error.response?.data;
      final String message =
          _extractMessage(data, fallback: 'network_error'.tr);
      _showMessage(message, isError: true);
    } catch (_) {
      _showMessage('general_error'.tr, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAuthResponse(Response<dynamic> response) async {
    final dynamic data = response.data;
    if (data is Map<String, dynamic> && _isSuccess(data)) {
      final Map<String, dynamic>? innerData =
          data['data'] as Map<String, dynamic>?;
      final String? token = innerData?['token'] as String?;
      final Map<String, dynamic>? user = innerData?['user'] as Map<String, dynamic>?;

      if (token != null && token.isNotEmpty) {
        await AuthService.instance
            .simpanAuth(token, user ?? <String, dynamic>{});
        _showMessage(
          _extractMessage(data, fallback: 'Registrasi berhasil'),
        );
        Get.offAllNamed(RuteAplikasi.beranda);
        return;
      }
    }
    _showMessage('general_error'.tr, isError: true);
  }

  bool _isSuccess(Map<String, dynamic> data) {
    final dynamic status = data['status'];
    if (status == true) {
      return true;
    }
    if (status is String && status.toLowerCase() == 'success') {
      return true;
    }
    return false;
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
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 6),
                      _HeadlineSection(),
                      const SizedBox(height: 18),
                      _TextFieldBlock(
                        label: 'full_name'.tr,
                        hint: 'name_hint'.tr,
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        validator: (String? value) {
                          final String input = value?.trim() ?? '';
                          if (input.isEmpty) {
                            return 'name_required'.tr;
                          }
                          if (input.length < 3) {
                            return 'name_min'.tr;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      _TextFieldBlock(
                        label: 'email'.tr,
                        hint: 'email_hint'.tr,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (String? value) {
                          final String input = value?.trim() ?? '';
                          if (input.isEmpty) {
                            return 'email_required'.tr;
                          }
                          if (!input.contains('@') || !input.contains('.')) {
                            return 'invalid_email'.tr;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      _PasswordBlock(
                        controller: _passwordController,
                        obscure: _obscurePassword,
                        onToggle: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      const SizedBox(height: 12),
                      _TermsRow(
                        value: _agreeTerms,
                        onChanged: (bool? value) =>
                            setState(() => _agreeTerms = value ?? false),
                      ),
                      const SizedBox(height: 16),
                      _PrimaryButton(
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 16),
                      _SwitchLogin(
                        onTap: () => Get.toNamed(RuteAplikasi.login),
                      ),
                      const SizedBox(height: 24),
                      _FooterNote(),
                      const SizedBox(height: 12),
                      const _HomeIndicator(),
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

class _HeadlineSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'register_title'.tr,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.slate,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'register_subtitle'.tr,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _TextFieldBlock extends StatelessWidget {
  const _TextFieldBlock({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboardType,
    required this.validator,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AuthUiKit.labelStyle(),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: AuthUiKit.inputDecoration(hintText: hint),
            validator: validator,
          ),
        ],
      ),
    );
  }
}

class _PasswordBlock extends StatelessWidget {
  const _PasswordBlock({
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'password_label'.tr,
            style: AuthUiKit.labelStyle(),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            decoration: AuthUiKit.inputDecoration(
              hintText: 'password_hint_8'.tr,
              suffixIcon: IconButton(
                onPressed: onToggle,
                icon: Icon(
                  obscure ? Symbols.visibility : Symbols.visibility_off,
                  color: AppColors.muted,
                ),
              ),
            ),
            validator: (String? value) {
              final String input = value ?? '';
              if (input.trim().isEmpty) {
                return 'password_required'.tr;
              }
              if (input.length < 8) {
                return 'password_hint_8'.tr;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.emerald,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'agree_terms'.tr,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.4,
                color: AppColors.slate,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: const Color(0x330F766E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 16),
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
                  Text('register_button'.tr),
                  const SizedBox(width: 8),
                  const Icon(Symbols.arrow_forward, size: 18),
                ],
              ),
      ),
    );
  }
}

class _SwitchLogin extends StatelessWidget {
  const _SwitchLogin({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          'already_have_account'.tr,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Symbols.verified_user,
            size: 14,
            color: AppColors.emerald,
          ),
          const SizedBox(width: 6),
          Text(
            'supervised_by'.tr,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.emerald,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
