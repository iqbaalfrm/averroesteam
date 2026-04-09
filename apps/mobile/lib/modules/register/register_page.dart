import 'package:averroes_core/averroes_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/routes/app_routes.dart';
import '../../app/services/auth_service.dart';
import '../../presentation/common/app_logo_badge.dart';
import '../../presentation/common/auth_ui_kit.dart';

String _trOr(String key, String fallback) {
  final String translated = key.tr;
  return translated == key ? fallback : translated;
}

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
      final AuthFlowResult result =
          await AuthService.instance.signUpWithEmailPassword(
        nama: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result.requiresVerification) {
        _showMessage(
          result.message ??
              'Registrasi berhasil. Kode OTP telah dikirim ke email Anda',
        );
        Get.toNamed(
          RuteAplikasi.verifikasiOtp,
          arguments: <String, String>{
            'email': _emailController.text.trim(),
            'mode': 'register',
            'password': _passwordController.text,
          },
        );
        return;
      }

      _showMessage(result.message ?? 'login_success'.tr);
      Get.offAllNamed(RuteAplikasi.beranda);
    });
  }

  void _showPolicySheet({
    required String title,
    required List<String> points,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _PolicySheet(
          title: title,
          points: points,
        );
      },
    );
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
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''),
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                        onOpenTerms: () => _showPolicySheet(
                          title: _trOr(
                            'terms_conditions',
                            'Syarat & Ketentuan',
                          ),
                          points: <String>[
                            _trOr(
                              'terms_point_account',
                              'Akun digunakan untuk mengakses layanan edukasi, profil, dan fitur personal Averroes secara sah dan bertanggung jawab.',
                            ),
                            _trOr(
                              'terms_point_data',
                              'Anda wajib memberikan data yang akurat, menjaga kerahasiaan akun, dan memperbarui informasi bila ada perubahan penting.',
                            ),
                            _trOr(
                              'terms_point_content',
                              'Seluruh materi, artikel, dan tampilan di aplikasi disediakan untuk edukasi dan penggunaan pribadi, bukan untuk disalin atau disalahgunakan.',
                            ),
                            _trOr(
                              'terms_point_conduct',
                              'Pengguna dilarang memakai platform untuk aktivitas yang melanggar hukum, manipulatif, menyesatkan, atau merugikan pengguna lain.',
                            ),
                            _trOr(
                              'terms_point_updates',
                              'Averroes dapat memperbarui fitur, isi layanan, dan kebijakan sewaktu-waktu demi keamanan, kepatuhan, dan peningkatan layanan.',
                            ),
                          ],
                        ),
                        onOpenPrivacy: () => _showPolicySheet(
                          title: 'privacy_policy'.tr,
                          points: <String>[
                            _trOr(
                              'privacy_point_collection',
                              'Kami mengumpulkan data yang Anda berikan saat mendaftar, menggunakan aplikasi, dan berinteraksi dengan fitur yang tersedia.',
                            ),
                            _trOr(
                              'privacy_point_usage',
                              'Data digunakan untuk autentikasi, personalisasi pengalaman belajar, dukungan akun, keamanan, dan peningkatan kualitas layanan.',
                            ),
                            _trOr(
                              'privacy_point_security',
                              'Kami berupaya melindungi data dengan kontrol akses, penyimpanan yang wajar, dan proses keamanan yang relevan.',
                            ),
                            _trOr(
                              'privacy_point_sharing',
                              'Data tidak dibagikan secara sembarangan dan hanya digunakan untuk kebutuhan operasional, integrasi resmi, atau kewajiban hukum yang berlaku.',
                            ),
                            _trOr(
                              'privacy_point_control',
                              'Anda dapat meminta pembaruan data profil tertentu dan berhenti menggunakan layanan jika tidak lagi menyetujui kebijakan yang berlaku.',
                            ),
                          ],
                        ),
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
  const _TermsRow({
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

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
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.slate,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: _trOr(
                      'agree_terms_prefix',
                      'Saya setuju dengan ',
                    ),
                  ),
                  TextSpan(
                    text: _trOr(
                      'terms_conditions',
                      'Syarat & Ketentuan',
                    ),
                    style: const TextStyle(
                      color: AppColors.emerald,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = onOpenTerms,
                  ),
                  TextSpan(
                    text: _trOr(
                      'agree_terms_middle',
                      ' serta ',
                    ),
                  ),
                  TextSpan(
                    text: 'privacy_policy'.tr,
                    style: const TextStyle(
                      color: AppColors.emerald,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = onOpenPrivacy,
                  ),
                  TextSpan(
                    text: _trOr(
                      'agree_terms_suffix',
                      ' Averroes.',
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
}

class _PolicySheet extends StatelessWidget {
  const _PolicySheet({
    required this.title,
    required this.points,
  });

  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8E5E2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Symbols.close,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _trOr(
                  'policy_sheet_intro',
                  'Harap baca ringkasan kebijakan berikut sebelum melanjutkan pendaftaran.',
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: points
                        .map(
                          (String point) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin:
                                      const EdgeInsets.only(top: 6, right: 10),
                                  decoration: const BoxDecoration(
                                    color: AppColors.emerald,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      height: 1.55,
                                      color: AppColors.slate,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_trOr('understand', 'Saya Mengerti')),
                ),
              ),
            ],
          ),
        ),
      ),
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
