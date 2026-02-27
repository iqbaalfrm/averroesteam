import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/routes/app_routes.dart';

class HalamanBantuan extends StatelessWidget {
  const HalamanBantuan({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF6F8F8).withOpacity(0.9),
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _IconCircleButton(
                    icon: Symbols.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  Text(
                    'Pusat Bantuan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D1B18),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HeroBantuan(),
                  const SizedBox(height: 16),
                  _SearchBantuan(),
                  const SizedBox(height: 20),
                  _MenuBantuan(),
                  const SizedBox(height: 24),
                  Text(
                    'Hubungi Kami',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D1B18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _KontakGrid(),
                  const SizedBox(height: 20),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        text: 'Ingin berbagi dengan sesama pejuang?\n',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Gabung Komunitas Averroes',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0EB58E),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF0D1B18)),
      ),
    );
  }
}

class _HeroBantuan extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: -20,
            top: -20,
            child: Opacity(
              opacity: 0.12,
              child: _PolaTitik(),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Halo, Apa yang bisa\nkami bantu?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D1B18),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Temukan jawaban cepat untuk pertanyaanmu.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBantuan extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Symbols.search,
            size: 20,
            color: Color(0xFF0EB58E),
          ),
          const SizedBox(width: 10),
          Text(
            'Cari bantuan...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuBantuan extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<_MenuItem> items = <_MenuItem>[
      _MenuItem(
        icon: Symbols.quiz,
        title: 'Pertanyaan Umum (FAQ)',
        subtitle: 'Jawaban untuk kendala populer',
        color: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF0EB58E),
      ),
      _MenuItem(
        icon: Symbols.menu_book,
        title: 'Panduan Penggunaan',
        subtitle: 'Cara menggunakan fitur aplikasi',
        color: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
      ),
      _MenuItem(
        icon: Symbols.gavel,
        title: 'Kebijakan Privasi',
        subtitle: 'Bagaimana kami mengelola data Anda',
        color: const Color(0xFFF5F3FF),
        iconColor: const Color(0xFF7C3AED),
        onTap: () => Get.toNamed(RuteAplikasi.kebijakanPrivasi),
      ),
    ];

    return Column(
      children: items
          .map(
            (_MenuItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 10,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(item.icon, color: item.iconColor, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0D1B18),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Symbols.chevron_right,
                        color: Color(0xFFCBD5F5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;
}

class _KontakGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const <Widget>[
        Expanded(
          child: _KontakItem(
            title: 'Chat Admin',
            subtitle: 'Respon Cepat',
            icon: Symbols.forum,
            background: Color(0xFF13ECB9),
            iconColor: Color(0xFF0D1B18),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _KontakItem(
            title: 'Kirim Email',
            subtitle: 'Bantuan Detail',
            icon: Symbols.alternate_email,
            background: Color(0xFFFFFBEB),
            iconColor: Color(0xFFCA8A04),
          ),
        ),
      ],
    );
  }
}

class _KontakItem extends StatelessWidget {
  const _KontakItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 28, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0D1B18),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolaTitik extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 180,
      child: CustomPaint(
        painter: _TitikPainter(),
      ),
    );
  }
}

class _TitikPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF13ECB9)
      ..style = PaintingStyle.fill;

    const double spacing = 24;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
