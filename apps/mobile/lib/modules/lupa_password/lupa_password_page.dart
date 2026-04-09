import 'package:averroes_core/averroes_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/routes/app_routes.dart';
import '../../app/services/auth_service.dart';
import '../../presentation/common/app_logo_badge.dart';
import '../../presentation/common/auth_ui_kit.dart';

class HalamanLupaPassword extends StatefulWidget {
  const HalamanLupaPassword({super.key});

  @override
  State<HalamanLupaPassword> createState() => _HalamanLupaPasswordState();
}

class _HalamanLupaPasswordState extends State<HalamanLupaPassword> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _kirimOTP() async {
    final FormState? state = _formKey.currentState;
    if (state == null || !state.validate() || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.sendPasswordResetEmail(
        _emailController.text.trim(),
      );
      _showMessage('otp_sent'.tr);
      Get.toNamed(
        RuteAplikasi.verifikasiOtp,
        arguments: <String, String>{
          'email': _emailController.text.trim(),
        },
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''),
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    AuthUiKit.showSnack(
      message: message,
      isError: isError,
    );
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 12),
                      const _HeaderSection(),
                      const SizedBox(height: 24),
                      _EmailField(controller: _emailController),
                      const SizedBox(height: 18),
                      _PrimaryButton(
                        isLoading: _isLoading,
                        onPressed: _kirimOTP,
                      ),
                      const SizedBox(height: 20),
                      _BackToLoginLink(
                        onTap: () => Get.offNamed(RuteAplikasi.login),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
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

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppLogoBadge(
          size: 96,
          radius: 28,
          padding: 10,
          backgroundColor: Color(0xFFFFF7E7),
          borderColor: Color(0xFFF8DFA7),
        ),
        const SizedBox(height: 16),
        Text(
          'forgot_password_title'.tr,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.slate,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'forgot_password_subtitle'.tr,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'email'.tr,
            style: AuthUiKit.labelStyle(),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: AuthUiKit.inputDecoration(
            hintText: 'enter_registered_email'.tr,
          ).copyWith(
            prefixIcon: const Icon(
              Symbols.mail,
              color: AppColors.muted,
              size: 20,
            ),
          ),
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
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
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
                  const Icon(Symbols.send, size: 18),
                  const SizedBox(width: 8),
                  Text('send_otp'.tr),
                ],
              ),
      ),
    );
  }
}

class _BackToLoginLink extends StatelessWidget {
  const _BackToLoginLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          'back_to_login'.tr,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.emerald,
          ),
        ),
      ),
    );
  }
}
