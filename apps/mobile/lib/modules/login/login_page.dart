import 'package:dio/dio.dart';
import 'package:averroes_core/averroes_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/config/app_config.dart';
import '../../app/routes/app_routes.dart';
import '../../app/services/api_dio.dart';
import '../../app/services/auth_service.dart';
import '../../presentation/common/app_logo_badge.dart';
import '../../presentation/common/auth_ui_kit.dart';

class HalamanLogin extends StatefulWidget {
  const HalamanLogin({super.key});

  @override
  State<HalamanLogin> createState() => _HalamanLoginState();
}

class _HalamanLoginState extends State<HalamanLogin> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final Dio _dio = ApiDio.create(attachAuthToken: false);
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
    serverClientId: AppConfig.googleWebClientId,
  );

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginEmailPassword() async {
    if (!_validateForm()) {
      return;
    }

    await _runRequest(() async {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/auth/login',
        data: <String, dynamic>{
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );

      await _handleAuthResponse(response);
    });
  }

  Future<void> _loginGoogle() async {
    await _runRequest(() async {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return;
      }
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        _showMessage('general_error'.tr, isError: true);
        return;
      }

      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/auth/google',
        data: <String, dynamic>{'id_token': idToken},
      );

      await _handleAuthResponse(response);
    });
  }

  Future<void> _loginGuest() async {
    await _runRequest(() async {
      final Response<dynamic> response =
          await _dio.post<dynamic>('/api/auth/guest');
      await _handleAuthResponse(response);
    });
  }

  bool _validateForm() {
    final FormState? state = _formKey.currentState;
    if (state == null) {
      return false;
    }
    return state.validate();
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

      if (innerData != null) {
        final String? token = innerData['token'] as String?;
        final Map<String, dynamic>? user =
            innerData['user'] as Map<String, dynamic>?;

        if (token != null && token.isNotEmpty) {
          await AuthService.instance
              .simpanAuth(token, user ?? <String, dynamic>{});
          _showMessage(_extractMessage(data, fallback: 'login_success'.tr));
          Get.offAllNamed(RuteAplikasi.beranda);
          return;
        }
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
                child: Stack(
                  children: <Widget>[
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.08,
                          child: _IslamicPattern(),
                        ),
                      ),
                    ),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SizedBox(height: 12),
                          _HeaderSection(),
                          const SizedBox(height: 24),
                          _EmailField(controller: _emailController),
                          const SizedBox(height: 16),
                          _PasswordField(
                            controller: _passwordController,
                            obscure: _obscurePassword,
                            onToggle: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            onLupaPassword: () =>
                                Get.toNamed(RuteAplikasi.lupaPassword),
                          ),
                          const SizedBox(height: 18),
                          _PrimaryButton(
                            isLoading: _isLoading,
                            onPressed: _loginEmailPassword,
                          ),
                          const SizedBox(height: 24),
                          _DividerSection(),
                          const SizedBox(height: 12),
                          _GoogleButton(
                            isLoading: _isLoading,
                            onPressed: _loginGoogle,
                          ),
                          const SizedBox(height: 24),
                          _BottomSection(
                            isLoading: _isLoading,
                            onGuestTap: _loginGuest,
                            onRegisterTap: () =>
                                Get.toNamed(RuteAplikasi.register),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
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
          IconButton(
            onPressed: () => Get.toNamed(RuteAplikasi.bantuan),
            icon: const Icon(
              Symbols.help_outline,
              size: 22,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppLogoBadge(
          size: 108,
          radius: 30,
          padding: 10,
          backgroundColor: Color(0xFFEFF8F6),
          borderColor: Color(0xFFBFE8DF),
        ),
        const SizedBox(height: 16),
        Text(
          'login_title'.tr,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.slate,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'login_subtitle'.tr,
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
          decoration:
              AuthUiKit.inputDecoration(hintText: 'enter_email'.tr),
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    required this.onLupaPassword,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final VoidCallback onLupaPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: <Widget>[
              Text(
                'password'.tr,
                style: AuthUiKit.labelStyle(),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onLupaPassword,
                child: Text(
                  'forgot_password'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald,
                  ),
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: AuthUiKit.inputDecoration(
            hintText: 'enter_password'.tr,
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
            if (input.length < 6) {
              return 'password_min'.tr;
            }
            return null;
          },
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
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: AppColors.slate,
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
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.slate),
                ),
              )
            : Text('login'.tr),
      ),
    );
  }
}

class _DividerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: AuthUiKit.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or_login_with'.tr,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AuthUiKit.border)),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        style: AuthUiKit.secondaryOutlineButtonStyle(),
        onPressed: isLoading ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const AuthBrandTile(size: 20, radius: 6),
            const SizedBox(width: 12),
            Text(
              'continue_with_google'.tr,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSection extends StatelessWidget {
  const _BottomSection({
    required this.isLoading,
    required this.onGuestTap,
    required this.onRegisterTap,
  });

  final bool isLoading;
  final VoidCallback onGuestTap;
  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextButton(
          onPressed: isLoading ? null : onGuestTap,
          child: Text(
            'login_as_guest'.tr,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: isLoading ? null : onRegisterTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '${'no_account'.tr} ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
              Text(
                'register_now'.tr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emerald,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IslamicPattern extends StatelessWidget {
  const _IslamicPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppColors.emerald
      ..style = PaintingStyle.fill;

    const double spacing = 24;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
