import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/models/ahli_syariah_model.dart';
import '../../app/services/api_dio.dart';

class HalamanKonsultasi extends StatefulWidget {
  const HalamanKonsultasi({super.key});

  @override
  State<HalamanKonsultasi> createState() => _HalamanKonsultasiState();
}

class _HalamanKonsultasiState extends State<HalamanKonsultasi> {
  final Dio _dio = ApiDio.create();
  List<AhliSyariahModel> _ahliList = <AhliSyariahModel>[];
  bool _isLoading = true;
  String _selectedKategori = 'Semua Ahli';

  @override
  void initState() {
    super.initState();
    _fetchAhli();
  }

  Future<void> _fetchAhli() async {
    setState(() => _isLoading = true);
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/konsultasi/ahli',
        queryParameters: <String, dynamic>{
          if (_selectedKategori != 'Semua Ahli') 'kategori_id': _selectedKategori,
        },
      );

      if (response.data != null && response.data['status'] == true) {
        final List<dynamic> data = response.data['data'] as List<dynamic>;
        setState(() {
          _ahliList = data
              .map((dynamic e) => AhliSyariahModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching ahli: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _hubungiWhatsApp(String phone, String nama) async {
    final String message = "Assalamu'alaikum ustadz $nama, saya ingin berkonsultasi mengenai syariah di aplikasi Averroes.";
    final Uri url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

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
                  _KategoriAhli(
                    selected: _selectedKategori,
                    onSelected: (String val) {
                      setState(() => _selectedKategori = val);
                      _fetchAhli();
                    },
                  ),
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
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(color: Color(0xFF064E3B)),
                      ),
                    )
                  else if (_ahliList.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          'Maaf, ustadz belum tersedia untuk kategori ini.',
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B)),
                        ),
                      ),
                    )
                  else
                    ..._ahliList.map((AhliSyariahModel ahli) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _KartuAhli(
                            ahli: ahli,
                            onTap: () => _konfirmasiKonsultasi(ahli),
                          ),
                        )),
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

  void _konfirmasiKonsultasi(AhliSyariahModel ahli) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Konfirmasi Konsultasi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundImage: NetworkImage(ahli.fotoUrl),
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        ahli.nama,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        ahli.spesialis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Biaya Sesi (Ijarah)',
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B)),
                  ),
                  Text(
                    'Rp ${ahli.hargaPerSesi ~/ 1000}rb',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF064E3B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _prosesBooking(ahli);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF064E3B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Bayar Sekarang',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Pembayaran aman via Midtrans',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _prosesBooking(AhliSyariahModel ahli) async {
    setState(() => _isLoading = true);
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/konsultasi/book',
        data: <String, dynamic>{
          'ahli_id': ahli.id,
          'user_id': '67d1bb333ce56ad257d0959c', // Placeholder ID User
        },
      );

      if (response.data != null && response.data['status'] == true) {
        final String redirectUrl = response.data['data']['redirect_url'] as String;
        final Uri uri = Uri.parse(redirectUrl);
        
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          // Setelah membuka payment, tampilkan dialog instruksi
          if (mounted) {
            _showSuccessInstruction(ahli);
          }
        }
      }
    } catch (e) {
      debugPrint('Error booking: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessInstruction(AhliSyariahModel ahli) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Menunggu Pembayaran', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text(
          'Silakan selesaikan pembayaran di browser. Setelah sukses, Anda bisa kembali ke sini dan klik Hubungi Ustadz.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _hubungiWhatsApp(ahli.noWhatsapp, ahli.nama);
            },
            child: Text('Hubungi Ustadz (WhatsApp)', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF064E3B))),
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
  const _KategoriAhli({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

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
            .map(
              (String label) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onSelected(label),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected == label ? const Color(0xFF064E3B) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected == label ? Colors.white : const Color(0xFF64748B),
                      ),
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
    required this.ahli,
    required this.onTap,
  });

  final AhliSyariahModel ahli;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: ahli.isOnline ? 1 : 0.8,
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
                      image: NetworkImage(ahli.fotoUrl),
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
                      color: ahli.isOnline ? const Color(0xFF10B981) : const Color(0xFFCBD5F5),
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
                          ahli.nama,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (ahli.isVerified)
                        const Icon(
                          Symbols.verified,
                          size: 14,
                          color: Color(0xFF3B82F6),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ahli.spesialis.toUpperCase(),
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
                            '${ahli.rating} (${ahli.totalReview}+)',
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
                            '${ahli.pengalamanTahun} Thn',
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
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${ahli.hargaPerSesi ~/ 1000}rb / Sesi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF064E3B),
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: ahli.isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ahli.isOnline ? const Color(0xFFD1FAE5) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  ahli.isOnline ? 'Konsultasi' : 'Offline',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ahli.isOnline ? const Color(0xFF064E3B) : const Color(0xFF94A3B8),
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
