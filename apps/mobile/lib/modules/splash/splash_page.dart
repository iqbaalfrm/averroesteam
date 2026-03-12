import 'package:averroes_core/averroes_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/routes/app_routes.dart';
import '../../app/services/auth_service.dart';
import '../../presentation/common/app_logo_badge.dart';

class HalamanSplash extends StatefulWidget {
  const HalamanSplash({super.key});

  @override
  State<HalamanSplash> createState() => _HalamanSplashState();
}

class _HalamanSplashState extends State<HalamanSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Get.offAllNamed(
      AuthService.instance.sudahLogin
          ? RuteAplikasi.beranda
          : RuteAplikasi.login,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFA),
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const AppLogoBadge(
                  size: 84,
                  radius: 24,
                  padding: 12,
                  backgroundColor: Color(0xFFEFF8F6),
                  borderColor: Color(0xFFBFE8DF),
                ),
                const SizedBox(height: 14),
                Text(
                  'averroes',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 8),
                Image.asset(
                  'assets/images/frostack_wordmark.png',
                  width: 92,
                  height: 26,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) {
                    return Text(
                      'FROSTACK STUDIO',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
