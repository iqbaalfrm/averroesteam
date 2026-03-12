import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class HalamanPsikolog extends StatelessWidget {
  const HalamanPsikolog({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF8FAFC).withValues(alpha: 0.9),
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _IconCircleButton(
                        icon: Symbols.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Psikologi Islam',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const _IconCircleButton(icon: Symbols.info),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _HeroPsikolog(),
                  const SizedBox(height: 16),
                  const _AksiPsikolog(),
                  const SizedBox(height: 22),
                  Text(
                    'Materi Utama',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _KartuTopik(
                    icon: Symbols.auto_stories,
                    title: 'Pembahasan Takdir',
                    subtitle: 'Memahami qadha dan qadar agar hati lebih tenang saat menghadapi risiko hidup.',
                    tag: 'Aqidah',
                  ),
                  const SizedBox(height: 10),
                  const _KartuTopik(
                    icon: Symbols.self_improvement,
                    title: 'Tazkiyatun Nufuz',
                    subtitle: 'Latihan pembersihan jiwa: muraqabah, muhasabah, dan manajemen emosi.',
                    tag: 'Tazkiyah',
                  ),
                  const SizedBox(height: 10),
                  const _KartuTopik(
                    icon: Symbols.psychology_alt,
                    title: 'Tes Psikolog',
                    subtitle: 'Tes ringkas untuk mengenali pola stres, kontrol diri, dan kecenderungan perilaku.',
                    tag: 'Assessment',
                  ),
                  const SizedBox(height: 10),
                  const _KartuTopik(
                    icon: Symbols.article,
                    title: 'Artikel Psikologi',
                    subtitle: 'Kumpulan artikel psikologi terkurasi dengan sudut pandang islami.',
                    tag: 'Artikel',
                  ),
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
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      ),
    );
  }
}

class _HeroPsikolog extends StatelessWidget {
  const _HeroPsikolog();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A0F766E),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -28,
            top: -28,
            child: Icon(
              Symbols.psychology,
              size: 140,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Konten Kurasi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: const Color(0xFFD1FAE5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Jaga Jiwa, Jaga Arah Hidup',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Belajar psikologi dengan pendekatan islami yang praktis dan mudah dipahami.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AksiPsikolog extends StatelessWidget {
  const _AksiPsikolog();

  @override
  Widget build(BuildContext context) {
    const List<_AksiItem> items = <_AksiItem>[
      _AksiItem(icon: Symbols.menu_book, label: 'Takdir'),
      _AksiItem(icon: Symbols.spa, label: 'Tazkiyatun\nNufuz'),
      _AksiItem(icon: Symbols.quiz, label: 'Tes\nPsikolog'),
      _AksiItem(icon: Symbols.article, label: 'Artikel\nPsikologi'),
    ];

    return Row(
      children: items
          .map(
            (_AksiItem item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Icon(item.icon, color: const Color(0xFF0F766E), size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AksiItem {
  const _AksiItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _KartuTopik extends StatelessWidget {
  const _KartuTopik({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
