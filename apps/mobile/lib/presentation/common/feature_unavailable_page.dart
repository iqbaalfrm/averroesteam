import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class FeatureUnavailablePage extends StatelessWidget {
  const FeatureUnavailablePage({
    super.key,
    this.title = 'Belum Tersedia',
    this.subtitle = 'Insyaallah Segera Hadir',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            if (canPop)
              Positioned(
                left: 12,
                top: 8,
                child: _GlassBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const _UnavailableIllustration(),
                    const SizedBox(height: 28),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF5B6472),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.white.withValues(alpha: 0.82),
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Symbols.arrow_back_ios_new_rounded,
                size: 18,
                color: Color(0xFF5B6472),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailableIllustration extends StatelessWidget {
  const _UnavailableIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 210,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            top: 22,
            child: Container(
              width: 106,
              height: 116,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(24)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 44,
            child: Column(
              children: List<Widget>.generate(
                4,
                (int index) => Container(
                  width: index == 1 ? 100 : 76,
                  height: 14,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8FA7A8),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 78,
            child: Container(
              width: 158,
              height: 92,
              decoration: const BoxDecoration(
                color: Color(0xFFF7D980),
                borderRadius: BorderRadius.all(Radius.circular(24)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x14CBA94E),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 68,
            right: 40,
            child: Container(
              width: 46,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7DD),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            left: 22,
            bottom: 14,
            child: Container(
              width: 86,
              height: 86,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFFA6F0EC),
                    Color(0xFF7FD2CB),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x1A58B8B0),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF94E4DE),
                ),
                child: const Icon(
                  Symbols.download_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
