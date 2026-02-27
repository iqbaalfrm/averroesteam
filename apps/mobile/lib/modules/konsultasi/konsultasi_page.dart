import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class HalamanKonsultasi extends StatelessWidget {
  const HalamanKonsultasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF8FAFC).withOpacity(0.8),
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
                        'Tanya Ahli Syariah',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const _IconCircleButton(icon: Symbols.search),
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
                  _MenuUtama(),
                  const SizedBox(height: 14),
                  _KategoriAhli(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Ahli Tersedia',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Filter',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF064E3B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _KartuAhli(
                    nama: 'Dr. Ahmad Hidayat',
                    spesialis: 'Ahli Fiqh Muamalah',
                    rating: '4.9 (120+)',
                    pengalaman: '12 Thn',
                    foto:
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuA6wdv3CSHlAgUXUTKatvNd7pFq5_DtsGM5RXtCNGOOg_FU7kQl_zsy6d-mZRxZR6VS5VhgGppyQaAUOvufZt1VGPFG7ekWi3ARygped7vn-a8uwu-hQVzKQiShYe6XGZG7iWpIZT3rPVboSeCheveyEiBF4CPevnwm-W8OLlEKqn66-niZwCGPBw31vXAoC7jxRSF3Y5cgW2qQpNgkDIOGEyNyx7Nbc0a1dthidyyrHhFlAWfBxDVVwIWWhFvViKkuK7chHa2C4dA',
                    online: true,
                  ),
                  const SizedBox(height: 12),
                  const _KartuAhli(
                    nama: 'H. Muhammad Zaki, Lc',
                    spesialis: 'Spesialis Zakat Digital',
                    rating: '4.8 (85)',
                    pengalaman: '8 Thn',
                    foto:
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuDCr7P7hom-AXpyjbrbfu4HfnbzDYI8Gv0h0BPZOHZ21IcsjuqkMf6209xp4v5wDA1JpaI9bVWwtHQyft5fgfsg1P_Q5nNjppIXiVt70xmOp6mmvegcUDLWzFRu2TUe9OPWaF9cWM5JJhIfhaAaOikdZlqN_V6Rfv1Y6aM2Gtnhmwb-Xdy8lKwhyEUJGarJF2zMuucnRRk8ovkwaJcLvJpzJfE6TJvdTBzUV_nRk__VJNPePhpMWdOgc54o_ptnzVPmt90FuVbEnW8',
                    online: true,
                  ),
                  const SizedBox(height: 12),
                  const _KartuAhli(
                    nama: 'Dr. Fatimah Zahra',
                    spesialis: 'Dewan Pengawas Syariah',
                    rating: '5.0 (210)',
                    pengalaman: '15 Thn',
                    foto:
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuBcrW3ePyd8Fk9_N4w5WUyl--cOXRfh0habRU9qOqlpJZfAz53Bb1U3WdHxaSVJhDMkAZT8KsElfABog3-_2WNB39kD6KIg_aYLjFK6NNgmnYi_UltjDLzbaaer1-1lsR5ue178r_xXlf9RNwnJG0WFrZcaVmtDej_QuZWUMlhqE4VeIjL9U6cV0kDnkkmjdyA5nD07VMtHSHJCmT9eRi1ZylMAxtha5Iny-zb_vlOJyvf7cwXvlazs_GEJo9M0iZE_svtysIxc5tk',
                    online: false,
                  ),
                  const SizedBox(height: 20),
                  _KartuAman(),
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

class _MenuUtama extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<_MenuItem> menu = <_MenuItem>[
      _MenuItem(icon: Symbols.chat_bubble, label: 'Chat Langsung'),
      _MenuItem(icon: Symbols.calendar_month, label: 'Jadwal Konsultasi'),
      _MenuItem(icon: Symbols.history, label: 'Riwayat Tanya Jawab'),
    ];

    return Row(
      children: menu
          .map(
            (_MenuItem item) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    Icon(item.icon, size: 28, color: const Color(0xFF064E3B)),
                    const SizedBox(height: 6),
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

class _MenuItem {
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _KategoriAhli extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<String> labels = <String>[
      'Semua Ahli',
      'Fiqh Muamalah',
      'Investasi Syariah',
      'Zakat & Wakaf',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels
            .asMap()
            .entries
            .map(
              (MapEntry<int, String> entry) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: entry.key == 0 ? const Color(0xFF064E3B) : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    entry.value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: entry.key == 0 ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _KartuAhli extends StatelessWidget {
  const _KartuAhli({
    required this.nama,
    required this.spesialis,
    required this.rating,
    required this.pengalaman,
    required this.foto,
    required this.online,
  });

  final String nama;
  final String spesialis;
  final String rating;
  final String pengalaman;
  final String foto;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: online ? 1 : 0.8,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Stack(
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: NetworkImage(foto),
                      fit: BoxFit.cover,
                    ),
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: online ? const Color(0xFF10B981) : const Color(0xFFCBD5F5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
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
                          nama,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Symbols.verified,
                        size: 14,
                        color: Color(0xFF3B82F6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spesialis.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: const Color(0xFF064E3B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Symbols.star,
                            size: 12,
                            color: Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Symbols.work_history,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pengalaman,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: online ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: online ? const Color(0xFFD1FAE5) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                online ? 'Konsultasi' : 'Offline',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: online ? const Color(0xFF064E3B) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuAman extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22064E3B),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              Symbols.verified_user,
              size: 80,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Konsultasi Aman & Terpercaya',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Semua ahli kami telah tersertifikasi oleh Dewan Syariah Nasional dan melewati verifikasi ketat Averroes.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
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
