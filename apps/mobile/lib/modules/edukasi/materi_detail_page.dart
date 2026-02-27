import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'edukasi_api.dart';

class HalamanDetailMateri extends StatefulWidget {
  const HalamanDetailMateri({
    required this.kelasJudul,
    required this.modulUrutan,
    required this.modulJudul,
    required this.materi,
    required this.sudahSelesai,
    required this.isActionLoading,
    required this.onComplete,
    super.key,
  });

  final String kelasJudul;
  final int modulUrutan;
  final String modulJudul;
  final MateriEdukasi materi;
  final bool sudahSelesai;
  final bool isActionLoading;
  final Future<void> Function() onComplete;

  @override
  State<HalamanDetailMateri> createState() => _HalamanDetailMateriState();
}

class _HalamanDetailMateriState extends State<HalamanDetailMateri> {
  late final List<_LearningCheck> _checks;

  @override
  void initState() {
    super.initState();
    _checks = <_LearningCheck>[
      _LearningCheck('Saya sudah membaca ringkasan materi ini'),
      _LearningCheck('Saya memahami inti konsep dan larangan utamanya'),
      _LearningCheck('Saya siap lanjut ke materi berikutnya'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final points = _extractPoints(widget.materi.konten);
    final dalil = _arabicDalil(widget.modulUrutan);
    final canMarkDone = !widget.sudahSelesai && !widget.isActionLoading;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: const Color(0xFF065F46),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              title: Text(
                'Materi ${widget.materi.urutan}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _heroImage(widget.materi.id),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F766E)),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x66000000), Color(0xB3000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 42,
                    child: Text(
                      widget.materi.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaCard(kelasJudul: widget.kelasJudul, modulJudul: widget.modulJudul),
                  const SizedBox(height: 14),
                  _SectionTitle('Poin Inti Materi'),
                  const SizedBox(height: 8),
                  ...points.map((p) => _PointTile(text: p)),
                  if (dalil != null) ...[
                    const SizedBox(height: 14),
                    _SectionTitle('Dalil Ayat (Arab)'),
                    const SizedBox(height: 8),
                    _ArabicCard(text: dalil.$1),
                    const SizedBox(height: 10),
                    _SectionTitle('Dalil Hadits (Arab)'),
                    const SizedBox(height: 8),
                    _ArabicCard(text: dalil.$2),
                  ],
                  const SizedBox(height: 14),
                  _SectionTitle('Konten Lengkap'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      widget.materi.konten,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF334155),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle('Checklist Belajar'),
                  const SizedBox(height: 8),
                  ..._checks.map(
                    (item) => CheckboxListTile(
                      value: item.checked,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      activeColor: const Color(0xFF10B981),
                      onChanged: (v) => setState(() => item.checked = v ?? false),
                      title: Text(
                        item.text,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: ElevatedButton.icon(
          onPressed: canMarkDone
              ? () async {
                  await widget.onComplete();
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                }
              : null,
          icon: Icon(widget.sudahSelesai ? Symbols.check_circle : Symbols.task_alt),
          label: Text(
            widget.sudahSelesai ? 'Materi Sudah Selesai' : 'Tandai Selesai',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: const Color(0xFF052E2B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  List<String> _extractPoints(String content) {
    final normalized = content.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return <String>['Belum ada ringkasan materi.'];
    final parts = normalized
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((e) => e.trim().isNotEmpty)
        .take(4)
        .toList();
    if (parts.isEmpty) return <String>[normalized];
    return parts;
  }

  String _heroImage(int seed) {
    const images = <String>[
      'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=1200&q=60',
      'https://images.unsplash.com/photo-1633158829875-e5316a358c6f?auto=format&fit=crop&w=1200&q=60',
      'https://images.unsplash.com/photo-1553729459-efe14ef6055d?auto=format&fit=crop&w=1200&q=60',
      'https://images.unsplash.com/photo-1621761191319-c6fb62004040?auto=format&fit=crop&w=1200&q=60',
      'https://images.unsplash.com/photo-1621504450181-5d356f61d307?auto=format&fit=crop&w=1200&q=60',
    ];
    return images[seed % images.length];
  }

  (String, String)? _arabicDalil(int modul) {
    const ayat = <int, String>{
      1: 'وَأَحَلَّ اللَّهُ الْبَيْعَ وَحَرَّمَ الرِّبَا',
      2: 'يَا أَيُّهَا الَّذِينَ آمَنُوا أَوْفُوا بِالْعُقُودِ',
      3: 'يَا أَيُّهَا الَّذِينَ آمَنُوا اتَّقُوا اللَّهَ وَذَرُوا مَا بَقِيَ مِنَ الرِّبَا',
      4: 'يَا أَيُّهَا الَّذِينَ آمَنُوا إِذَا تَدَايَنْتُمْ بِدَيْنٍ إِلَىٰ أَجَلٍ مُسَمًّى فَاكْتُبُوهُ',
      5: 'يَا أَيُّهَا الَّذِينَ آمَنُوا إِنَّمَا الْخَمْرُ وَالْمَيْسِرُ رِجْسٌ',
      6: 'إِنَّ اللَّهَ يَأْمُرُكُمْ أَنْ تُؤَدُّوا الْأَمَانَاتِ إِلَىٰ أَهْلِهَا',
      7: 'وَيْلٌ لِّلْمُطَفِّفِينَ',
      8: 'يَا أَيُّهَا الَّذِينَ آمَنُوا اتَّقُوا اللَّهَ وَلْتَنظُرْ نَفْسٌ مَّا قَدَّمَتْ لِغَدٍ',
      9: 'يَا أَيُّهَا الَّذِينَ آمَنُوا إِن جَاءَكُمْ فَاسِقٌ بِنَبَإٍ فَتَبَيَّنُوا',
      10: 'قُلْ هَلْ يَسْتَوِي الَّذِينَ يَعْلَمُونَ وَالَّذِينَ لَا يَعْلَمُونَ',
    };
    const hadits = <int, String>{
      1: 'الْمُسْلِمُونَ عَلَى شُرُوطِهِمْ',
      2: 'الْمُسْلِمُونَ عَلَى شُرُوطِهِمْ',
      3: 'لَعَنَ رَسُولُ اللَّهِ آكِلَ الرِّبَا وَمُوكِلَهُ',
      4: 'نَهَى رَسُولُ اللَّهِ عَنْ بَيْعِ الْغَرَرِ',
      5: 'لَا ضَرَرَ وَلَا ضِرَارَ',
      6: 'أَدِّ الْأَمَانَةَ إِلَىٰ مَنِ ائْتَمَنَكَ',
      7: 'مَنْ غَشَّنَا فَلَيْسَ مِنَّا',
      8: 'اعْقِلْهَا وَتَوَكَّلْ',
      9: 'دَعْ مَا يَرِيبُكَ إِلَىٰ مَا لَا يَرِيبُكَ',
      10: 'مَنْ سَلَكَ طَرِيقًا يَلْتَمِسُ فِيهِ عِلْمًا سَهَّلَ اللَّهُ لَهُ طَرِيقًا إِلَى الْجَنَّةِ',
    };
    final a = ayat[modul];
    final h = hadits[modul];
    if (a == null || h == null) return null;
    return (a, h);
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.kelasJudul, required this.modulJudul});

  final String kelasJudul;
  final String modulJudul;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kelasJudul,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            modulJudul,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F172A),
      ),
    );
  }
}

class _PointTile extends StatelessWidget {
  const _PointTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Symbols.auto_awesome, size: 16, color: Color(0xFF059669)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF14532D),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArabicCard extends StatelessWidget {
  const _ArabicCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: GoogleFonts.notoNaskhArabic(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
            height: 1.7,
          ),
        ),
      ),
    );
  }
}

class _LearningCheck {
  _LearningCheck(this.text);

  final String text;
  bool checked = false;
}
