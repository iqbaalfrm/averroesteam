import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class HalamanZikir extends StatelessWidget {
  const HalamanZikir({super.key});

  static const List<ZikirItem> _pagi = <ZikirItem>[
    ZikirItem(
        'Surah Al-Ikhlas',
        'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
        'Qul huwallāhu aḥad.',
        'Katakanlah (Muhammad), "Dialah Allah, Yang Maha Esa."',
        3),
    ZikirItem(
        'Surah Al-Falaq',
        'قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ',
        'Qul a\'ūżu birabbil-falaq.',
        'Katakanlah, "Aku berlindung kepada Tuhan yang menguasai subuh (fajar)."',
        3),
    ZikirItem(
        'Surah An-Nas',
        'قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ',
        'Qul a\'ūżu birabbin-nās.',
        'Katakanlah, "Aku berlindung kepada Tuhannya manusia."',
        3),
  ];

  static const List<ZikirItem> _petang = <ZikirItem>[
    ZikirItem(
        'Ayat Kursi',
        'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ',
        'Allāhu lā ilāha illā huwal-ḥayyul-qayyūm.',
        'Allah, tidak ada tuhan selain Dia. Yang Mahahidup, Yang terus-menerus mengurus (makhluk-Nya).',
        1),
    ZikirItem('Istighfar', 'أَسْتَغْفِرُ ٱللَّهَ', 'Astaghfirullāh.',
        'Aku memohon ampunan kepada Allah.', 100),
  ];

  static const List<DoaItem> _doaHarian = <DoaItem>[
    DoaItem('Doa Sebelum Makan', 'بِسْمِ ٱللَّهِ', 'Bismillāh.',
        'Dengan menyebut nama Allah.'),
    DoaItem('Doa Sesudah Makan', 'ٱلْحَمْدُ لِلَّهِ', 'Alḥamdulillāh.',
        'Segala puji bagi Allah.'),
    DoaItem(
        'Doa Sebelum Tidur',
        'بِاسْمِكَ ٱللَّهُمَّ أَمُوتُ وَأَحْيَا',
        'Bismikallāhumma amūtu wa aḥyā.',
        'Dengan nama-Mu, ya Allah, aku mati dan aku hidup.'),
  ];

  static const List<DoaItem> _asmaul = <DoaItem>[
    DoaItem('Ar-Rahman', 'ٱلرَّحْمَٰنُ', 'Ar-Raḥmān.', 'Yang Maha Pengasih.'),
    DoaItem('Ar-Rahim', 'ٱلرَّحِيمُ', 'Ar-Raḥīm.', 'Yang Maha Penyayang.'),
    DoaItem('Al-Malik', 'ٱلْمَلِكُ', 'Al-Malik.', 'Yang Maha Merajai.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            _topBar(context),
            _headline(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Expanded(
                      child: _heroCard(
                          'Dzikir Pagi',
                          'Pagi Hari • 24 Doa',
                          Symbols.light_mode,
                          'Mustajab',
                          () => _openSesi(context, 'Dzikir Pagi', _pagi))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _heroCard(
                          'Dzikir Petang',
                          'Petang Hari • 22 Doa',
                          Symbols.dark_mode,
                          '',
                          () => _openSesi(context, 'Dzikir Petang', _petang))),
                ],
              ),
            ),
            _searchStub(),
            _sectionTitle('Kategori Pilihan'),
            _menuTile('Dzikir Setelah Shalat', '12/20', Symbols.prayer_times,
                onTap: () =>
                    _openSesi(context, 'Dzikir Setelah Shalat', _petang),
                progress: 0.6,
                trailing: '60%'),
            _menuTile('Kumpulan Doa Harian', 'Doa makan, tidur, bepergian...',
                Symbols.menu_book,
                onTap: () =>
                    _openDoa(context, 'Kumpulan Doa Harian', _doaHarian),
                trailing: '120 Doa'),
            _menuTile('Asmaul Husna', '15/99', Symbols.stars,
                onTap: () => _openDoa(context, 'Asmaul Husna', _asmaul),
                progress: 0.15,
                trailing: '99 Nama'),
            _menuTile('Zikir Pilihan & Selawat', 'Selawat Jibril, Nariyah...',
                Symbols.auto_awesome,
                onTap: () =>
                    _openSesi(context, 'Zikir Pilihan & Selawat', _pagi)),
            _sectionTitle('Kajian & Adab'),
            SizedBox(
              height: 176,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: const <Widget>[
                  _AdabCard('FIKIH', 'Adab-Adab Berdoa Sesuai Sunnah',
                      Symbols.menu_book),
                  SizedBox(width: 12),
                  _AdabCard('WAKTU MUSTAJAB', 'Waktu Terbaik Dikabulkannya Doa',
                      Symbols.person_pin_circle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Symbols.arrow_back_ios_new)),
              Text('Zikir & Doa',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 19, fontWeight: FontWeight.w700)),
              const IconButton(onPressed: null, icon: Icon(Symbols.search)),
            ]),
      );

  Widget _headline() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Penyejuk Kalbu',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 28, fontWeight: FontWeight.w800)),
              Text('Temukan kedamaian dalam setiap lantunan zikir',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4C9A88))),
            ]),
      );

  Widget _heroCard(
          String t, String s, IconData i, String b, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 184,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0x1A0DA582),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(i,
                              color: const Color(0xFF0DA582), size: 30)),
                      if (b.isNotEmpty)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0x1A0DA582),
                                borderRadius: BorderRadius.circular(999)),
                            child: Text(b,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0DA582)))),
                    ]),
                const Spacer(),
                Text(t,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                Text(s,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4C9A88))),
              ]),
        ),
      );

  Widget _searchStub() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(children: <Widget>[
            const Icon(Symbols.manage_search,
                size: 20, color: Color(0xFF4C9A88)),
            const SizedBox(width: 8),
            Text('Cari doa atau kategori...',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4C9A88))),
          ]),
        ),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
        child: Text(t,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w800)),
      );

  Widget _menuTile(String t, String s, IconData i,
          {required VoidCallback onTap,
          double? progress,
          String trailing = ''}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEAF5F1))),
            child: Row(children: <Widget>[
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE7F3F0),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(i, color: const Color(0xFF0DA582))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                    Text(t,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(s,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4C9A88))),
                    if (progress != null) ...<Widget>[
                      const SizedBox(height: 8),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFCFE7E2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0DA582)))),
                    ],
                  ])),
              if (trailing.isNotEmpty)
                Text(trailing,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8))),
              const SizedBox(width: 4),
              const Icon(Symbols.chevron_right, color: Color(0xFFCBD5F5)),
            ]),
          ),
        ),
      );

  void _openSesi(BuildContext context, String judul, List<ZikirItem> items) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => HalamanSesiZikir(judul: judul, items: items)));
  }

  void _openDoa(BuildContext context, String judul, List<DoaItem> items) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => HalamanDaftarDoa(judul: judul, items: items)));
  }
}

class HalamanSesiZikir extends StatefulWidget {
  const HalamanSesiZikir({super.key, required this.judul, required this.items});
  final String judul;
  final List<ZikirItem> items;
  @override
  State<HalamanSesiZikir> createState() => _HalamanSesiZikirState();
}

class _HalamanSesiZikirState extends State<HalamanSesiZikir> {
  late final List<int> hitung;
  int i = 0;
  @override
  void initState() {
    super.initState();
    hitung = List<int>.filled(widget.items.length, 0);
  }

  @override
  Widget build(BuildContext context) {
    final ZikirItem d = widget.items[i];
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: SafeArea(
        child: Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Symbols.close)),
                  Text('${i + 1} dari ${widget.items.length} dzikir',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF064E3B))),
                  IconButton(
                      onPressed: () => setState(() => hitung[i] = 0),
                      icon: const Icon(Symbols.refresh)),
                ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                    value: (i + 1) / widget.items.length,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFD7EDE5),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF0DA582)))),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE9F2EE))),
                      child: Column(children: <Widget>[
                        Text(d.arab,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.amiri(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF064E3B))),
                        const SizedBox(height: 10),
                        Text(d.latin,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFF0DA582))),
                        const SizedBox(height: 8),
                        Text('"${d.arti}"',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xB30D1B18))),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (hitung[i] < d.target) hitung[i]++;
                        if (hitung[i] >= d.target &&
                            i < widget.items.length - 1) i++;
                      }),
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0DA582),
                            border: Border.all(color: Colors.white, width: 6)),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text('${hitung[i]}',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                              Text('KETUK',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withAlpha(190))),
                            ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Target: ${hitung[i]}/${d.target}',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4C9A88))),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class HalamanDaftarDoa extends StatelessWidget {
  const HalamanDaftarDoa({super.key, required this.judul, required this.items});
  final String judul;
  final List<DoaItem> items;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: SafeArea(
        child: Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Symbols.arrow_back_ios_new)),
                  Text(judul,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 48),
                ]),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, int idx) {
                final DoaItem d = items[idx];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEAF5F1))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(d.judul,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(d.arab,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.amiri(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF064E3B))),
                        const SizedBox(height: 10),
                        Text(d.latin,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFF0DA582))),
                        const SizedBox(height: 6),
                        Text('"${d.arti}"',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: const Color(0xB30D1B18))),
                      ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _AdabCard extends StatelessWidget {
  const _AdabCard(this.tag, this.title, this.icon);
  final String tag;
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 204,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEAF5F1))),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
                height: 94,
                decoration: const BoxDecoration(
                    color: Color(0x220DA582),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(14))),
                child: Center(
                    child:
                        Icon(icon, size: 46, color: const Color(0x660DA582)))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(tag,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0DA582))),
                    const SizedBox(height: 4),
                    Text(title,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
            ),
          ]),
    );
  }
}

class ZikirItem {
  const ZikirItem(this.judul, this.arab, this.latin, this.arti, this.target);
  final String judul;
  final String arab;
  final String latin;
  final String arti;
  final int target;
}

class DoaItem {
  const DoaItem(this.judul, this.arab, this.latin, this.arti);
  final String judul;
  final String arab;
  final String latin;
  final String arti;
}
