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
                        'Psikolog',
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
                  _HeroPsikolog(),
                  const SizedBox(height: 18),
                  _AksiPsikolog(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Rekomendasi Psikolog',
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
                  const SizedBox(height: 14),
                  const _KartuPsikolog(
                    nama: 'Fatimah Az-Zahra, M.Psi',
                    spesialis: 'Spesialis Kecemasan Investasi',
                    pengalaman: '8th Pengalaman',
                    rating: '4.9',
                    foto:
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuB_wvNPiGFaNktTYhmfvYQ6w7TCbHbWHYI43qpqEfH0u3hiTLcmctAelxz7sLgrCI-bzOCG4mLM4tSm8D2hx3U0O7BGDsYk5MZ9pqfNDcLjA3g60Q0HyHX7eRAYv86V8xSVAdP65mQrWuZTig9mprpMyTnFnWPQ4WQ7mU9Wxx90ThQuJQ8WWfqoHC7w2tY4wYrkoSAI0By4k6kfedfCpP4u7AFPfKZ84kMkzESfMBnCyX34NThdk9WeGIs2LihTX0W-PCYweB3rjZE',
                  ),
                  const SizedBox(height: 12),
                  const _KartuPsikolog(
                    nama: 'Lukman Hakim, M.Psi',
                    spesialis: 'Perilaku Konsumtif & Keuangan',
                    pengalaman: '12th Pengalaman',
                    rating: '4.8',
                    foto:
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuB2S_Y6NUBCSn12tQXdohsdZuijMULTgH4lhprVGzleH4XmtTH9S6FJvAQ1bo3Kp3d80fvM73VyZweoOpV_mZB4A9k0zmClQIzGSTd13D777eoq5pK6c_OyD7jIAXlsLcPR04juNzajQlaeDo4mKmINmqhat6W1MmHChA0QZxFP1L99gIFtke1gQkI0BhTOo2FsthC_9Pl94h4ASrdApKC6u3BsG3iVLPBKcS1El_7Msnyz7nd6MLQJGj35wbcXRfvezRKQo7VJRVc',
                  ),
                  const SizedBox(height: 12),
                  const _KartuPsikolog(
                    nama: 'Siti Safia, S.Psi',
                    spesialis: 'Psikologi Ekonomi Syariah',
                    pengalaman: '5th Pengalaman',
                    rating: '5.0',
                    foto:
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuCUZqc1qTEEpVetWMdfkIcAo05B7HnkuTLGfC4HrzIP7WP7xT-GXrpDR1jOmFO6AtgYKNzU1N74OLBEHHCP5GKbprpu0e9TiotuMG3gKMKJLzaKuAezeqFm7sDvBkiuTCe1-GNRuv2EsM8aaRlZp6nrc8sxNlu8PG47QOuVlMSRhPCfq-Lgsk4xnW3-17sgs_YCsQkEOpO96869RMsNO-9jIoK_nPFuWWYHkeegQLUhsFPxY6OM106UUfrOB1mFSW-54ThPCmbWgFk',
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
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22064E3B),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -30,
            top: -30,
            child: Icon(
              Symbols.psychology,
              size: 160,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  'Mental Health',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: const Color(0xFFBBF7D0),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Kesehatan Mental Finansial',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Kelola emosi dalam berinvestasi dengan bantuan profesional syariah.',
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
  @override
  Widget build(BuildContext context) {
    final List<_AksiItem> items = <_AksiItem>[
      _AksiItem(icon: Symbols.event_available, label: 'Booking\nSesi'),
      _AksiItem(icon: Symbols.quiz, label: 'Tes\nKepribadian'),
      _AksiItem(icon: Symbols.article, label: 'Artikel\nPsikologi'),
    ];

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        children: items
            .map(
              (_AksiItem item) => Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
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
                    child: Icon(item.icon, color: const Color(0xFF064E3B), size: 26),
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
            )
            .toList(),
      ),
    );
  }
}

class _AksiItem {
  const _AksiItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _KartuPsikolog extends StatelessWidget {
  const _KartuPsikolog({
    required this.nama,
    required this.spesialis,
    required this.pengalaman,
    required this.rating,
    required this.foto,
  });

  final String nama;
  final String spesialis;
  final String pengalaman;
  final String rating;
  final String foto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD1FAE5)),
              image: DecorationImage(
                image: NetworkImage(foto),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    Row(
                      children: <Widget>[
                        const Icon(
                          Symbols.star,
                          size: 16,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  spesialis.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      pengalaman,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFD1FAE5)),
                      ),
                      child: Text(
                        'Lihat Profil',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF064E3B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
