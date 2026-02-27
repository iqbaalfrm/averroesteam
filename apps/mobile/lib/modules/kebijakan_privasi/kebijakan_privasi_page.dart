import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class HalamanKebijakanPrivasi extends StatelessWidget {
  const HalamanKebijakanPrivasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF9FAFB).withOpacity(0.8),
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
                      'Kebijakan Privasi',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HeaderKomitmen(),
                  const SizedBox(height: 20),
                  _SectionTitle(number: '1', title: 'Data yang Kami Kumpulkan'),
                  const SizedBox(height: 10),
                  _ListCard(
                    items: const <_ListItem>[
                      _ListItem(
                        title: 'Informasi Akun',
                        subtitle: 'Nama lengkap, alamat email, dan nomor telepon saat pendaftaran.',
                      ),
                      _ListItem(
                        title: 'Data Aktivitas',
                        subtitle: 'Catatan ibadah, preferensi konten, dan interaksi dalam aplikasi.',
                      ),
                      _ListItem(
                        title: 'Lokasi',
                        subtitle: 'Digunakan secara anonim untuk menentukan waktu shalat dan arah kiblat yang akurat.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(number: '2', title: 'Penggunaan Informasi'),
                  const SizedBox(height: 10),
                  _Paragraph(
                    text:
                        'Kami menggunakan data Anda semata-mata untuk meningkatkan pengalaman spiritual Anda, mempersonalisasi konten pengingat, dan memastikan keamanan akun Anda. Kami tidak akan pernah menjual data pribadi Anda kepada pihak ketiga.',
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(number: '3', title: 'Keamanan Data'),
                  const SizedBox(height: 10),
                  _QuoteBox(
                    text:
                        'Kami menggunakan enkripsi tingkat industri (AES-256) untuk melindungi semua data sensitif yang dikirimkan melalui aplikasi kami.',
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(number: '4', title: 'Hak-Hak Anda'),
                  const SizedBox(height: 10),
                  _HakGrid(),
                  const SizedBox(height: 24),
                  _FooterContact(),
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
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: const Color(0xFF059669)),
      ),
    );
  }
}

class _HeaderKomitmen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Symbols.gavel,
            color: Color(0xFF059669),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Komitmen Kami',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Terakhir diperbarui: 24 Mei 2024',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 6,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF059669),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$number. $title',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF059669),
          ),
        ),
      ],
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.items});

  final List<_ListItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: items
            .map(
              (_ListItem item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Symbols.check_circle,
                      size: 16,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ListItem {
  const _ListItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFFECFDF5), width: 2),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _QuoteBox extends StatelessWidget {
  const _QuoteBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Text(
        '"$text"',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _HakGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<_HakItem> items = <_HakItem>[
      _HakItem(icon: Symbols.visibility, title: 'Akses Data'),
      _HakItem(icon: Symbols.edit_note, title: 'Koreksi'),
      _HakItem(icon: Symbols.delete_outline, title: 'Penghapusan'),
      _HakItem(icon: Symbols.lock_reset, title: 'Portabilitas'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: items
          .map(
            (_HakItem item) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(item.icon, color: const Color(0xFF059669)),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _HakItem {
  const _HakItem({required this.icon, required this.title});

  final IconData icon;
  final String title;
}

class _FooterContact extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 12),
        Text(
          'Punya pertanyaan lebih lanjut?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF059669),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Symbols.mail,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'Hubungi Kami',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '© 2024 Averroes Tech',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
