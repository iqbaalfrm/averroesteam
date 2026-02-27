import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class HalamanSertifikat extends StatelessWidget {
  const HalamanSertifikat({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFFDFBF7).withOpacity(0.95),
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
                    'Sertifikat Saya',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D1B18),
                    ),
                  ),
                  const _IconCircleButton(icon: Symbols.filter_list),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SearchSertifikat(),
                  const SizedBox(height: 14),
                  _RingkasanTotal(),
                  const SizedBox(height: 16),
                  _KartuSertifikat(
                    title: 'Dasar Ekonomi Islam',
                    date: 'Diselesaikan 12 Okt 2023',
                    badge: 'Cum Laude',
                    icon: Symbols.verified,
                    accent: const Color(0xFFE7F3F0),
                    badgeColor: const Color(0xFFFDE68A),
                  ),
                  const SizedBox(height: 12),
                  _KartuSertifikat(
                    title: 'Fikih Muamalah I',
                    date: 'Diselesaikan 28 Sep 2023',
                    badge: 'Level 1',
                    icon: Symbols.verified_user,
                    accent: const Color(0xFFE7F3F0),
                    badgeColor: const Color(0xFFF3F4F6),
                  ),
                  const SizedBox(height: 12),
                  _KartuSertifikat(
                    title: 'Pengenalan Perbankan Syariah',
                    date: 'Diselesaikan 05 Sep 2023',
                    badge: 'Sangat Baik',
                    icon: Symbols.stars,
                    accent: const Color(0xFFE7F3F0),
                    badgeColor: const Color(0xFFFDE68A),
                  ),
                  const SizedBox(height: 12),
                  _KartuSertifikat(
                    title: 'Etika Bisnis Islami',
                    date: 'Diselesaikan 20 Ags 2023',
                    badge: '',
                    icon: Symbols.military_tech,
                    accent: const Color(0xFFE7F3F0),
                    badgeColor: const Color(0xFFF3F4F6),
                    disabled: true,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: <Widget>[
                        Text(
                          '"Ilmu itu bagaikan binatang buruan, dan tulisan adalah pengikatnya."',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '— Imam Syafi\'i',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            color: const Color(0xFF0EB58E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
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
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF0D1B18)),
      ),
    );
  }
}

class _SearchSertifikat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          top: 14,
          child: const Icon(
            Symbols.search,
            size: 20,
            color: Color(0xFF9CA3AF),
          ),
        ),
        Positioned(
          left: 44,
          top: 16,
          child: Text(
            'Cari nama sertifikat...',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingkasanTotal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22064E3B),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'TOTAL PENCAPAIAN',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: const Color(0xFF13ECB9),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '4 Sertifikat',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Symbols.workspace_premium,
              color: Color(0xFF13ECB9),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuSertifikat extends StatelessWidget {
  const _KartuSertifikat({
    required this.title,
    required this.date,
    required this.badge,
    required this.icon,
    required this.accent,
    required this.badgeColor,
    this.disabled = false,
  });

  final String title;
  final String date;
  final String badge;
  final IconData icon;
  final Color accent;
  final Color badgeColor;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.8 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD1FAE5)),
                  ),
                  child: Icon(icon, color: const Color(0xFF0EB58E), size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D1B18),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        date,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      if (badge.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HalamanDetailSertifikat(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13ECB9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Symbols.visibility,
                          size: 16,
                          color: Color(0xFF0D1B18),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Lihat Detail',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D1B18),
                          ),
                        ),
                      ],
                      ),
                    ),
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F3F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Symbols.share,
                    size: 16,
                    color: Color(0xFF4C9A88),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HalamanDetailSertifikat extends StatelessWidget {
  const HalamanDetailSertifikat({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF6F8F8),
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: <Widget>[
                  _IconCircleButton(
                    icon: Symbols.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Detail Sertifikat',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D1B18),
                      ),
                    ),
                  ),
                  const _IconCircleButton(icon: Symbols.more_vert),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                children: <Widget>[
                  _KartuPreviewSertifikat(),
                  const SizedBox(height: 20),
                  Text(
                    'Mastering Fiqh Muamalah 101',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D1B18),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Diterbitkan pada 24 Oktober 2023',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _AksiDetailSertifikat(),
                  const SizedBox(height: 16),
                  _KartuVerifikasi(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuPreviewSertifikat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7F3F0), width: 10),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              child: _CornerBorder(),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: _CornerBorder(right: true),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: _CornerBorder(bottom: true),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: _CornerBorder(bottom: true, right: true),
            ),
            Column(
              children: <Widget>[
                const SizedBox(height: 8),
                Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuAFmXHju9BVj43u-Pku2CGPwZmHY7e0iIOVLqu8b0yfCPwACaPHBvQ9gqmsXpxBx-5zOUWFDmW3cW0nxXfV0S9hVdqAKgnijZUuxBhL5-RIxFje0_UQ8Bzy-A5ghBRI5U-sXRwU3dZgji7JU9OvWmeC4o1Tfzqo6mHrA5yDDHA-n6xD1vAP1MAl49tcQX5VzzE2DpYhU9nc3jrIoCvkC4fpVjaaWep7Yv9ZsvMglJvsMwvYObac2c48v0WCCQ0zoGiUsXbdDzdKYgo',
                  width: 64,
                  height: 64,
                ),
                const SizedBox(height: 10),
                Text(
                  'SERTIFIKAT KELULUSAN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: const Color(0xFF0D1B18).withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Diberikan dengan bangga kepada:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ahmad Fauzan Al-Zahrani',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF13ECB9),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 80,
                  height: 1,
                  color: const Color(0xFF13ECB9).withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'Atas penyelesaian yang luar biasa dan dedikasi penuh dalam kursus intensif mengenai hukum ekonomi Islam dan praktik kontemporer.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mastering Fiqh Muamalah 101',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D1B18),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _SignatureBlock(
                      name: 'Ustadz Devin Halim',
                      role: 'Pakar Fiqh Kontemporer',
                      signature: 'Ustadz Devin',
                    ),
                    _SignatureBlock(
                      name: 'Direktur Averroes',
                      role: 'Jakarta, 24 Okt 2023',
                      signature: 'Averroes Team',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'ID Sertifikat: AV-2023-FM101-99812',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerBorder extends StatelessWidget {
  const _CornerBorder({this.bottom = false, this.right = false});

  final bool bottom;
  final bool right;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color(0xFF13ECB9).withOpacity(0.3),
            width: 3,
          ),
          left: BorderSide(
            color: const Color(0xFF13ECB9).withOpacity(0.3),
            width: 3,
          ),
          right: right
              ? BorderSide(
                  color: const Color(0xFF13ECB9).withOpacity(0.3),
                  width: 3,
                )
              : BorderSide.none,
          bottom: bottom
              ? BorderSide(
                  color: const Color(0xFF13ECB9).withOpacity(0.3),
                  width: 3,
                )
              : BorderSide.none,
        ),
      ),
    );
  }
}

class _SignatureBlock extends StatelessWidget {
  const _SignatureBlock({
    required this.name,
    required this.role,
    required this.signature,
  });

  final String name;
  final String role;
  final String signature;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 24,
          width: 90,
          child: Center(
            child: Text(
              signature,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF0D1B18).withOpacity(0.4),
              ),
            ),
          ),
        ),
        Container(
          width: 90,
          height: 1,
          color: const Color(0xFF94A3B8),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D1B18),
          ),
        ),
        Text(
          role,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 8,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class _AksiDetailSertifikat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const <Widget>[
        _AksiItem(icon: Symbols.download, label: 'Unduh PDF'),
        _AksiItem(icon: Symbols.share, label: 'LinkedIn'),
        _AksiItem(icon: Symbols.content_copy, label: 'Salin ID'),
      ],
    );
  }
}

class _AksiItem extends StatelessWidget {
  const _AksiItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF13ECB9).withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF13ECB9)),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0D1B18),
          ),
        ),
      ],
    );
  }
}

class _KartuVerifikasi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7F3F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Symbols.verified,
                color: Color(0xFF13ECB9),
              ),
              const SizedBox(width: 8),
              Text(
                'Terverifikasi oleh Averroes',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D1B18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sertifikat ini secara resmi diterbitkan oleh platform Averroes untuk menandai kompetensi dalam bidang Fiqh Muamalah. Gunakan ID sertifikat untuk verifikasi eksternal.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
