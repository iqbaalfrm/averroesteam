import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:averroes_core/averroes_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config/app_config.dart';
import '../../app/routes/app_routes.dart';
import '../../app/services/api_dio.dart';
import '../../app/services/auth_service.dart';
import '../../app/services/shalat_notification_service.dart';
import '../../app/widgets/guest_guard.dart';
import '../portofolio/portofolio_api.dart';
import '../portofolio/portofolio_sync.dart';
import '../edukasi/edukasi_api.dart';

class _BerandaUi {
  const _BerandaUi._();

  static const double screenPadding = 20;
  static const double sectionGap = 20;
  static const Color softLine = Color(0xFFF1F5F9);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  if (leadingIcon != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD1FAE5)),
                      ),
                      child: Icon(
                        leadingIcon,
                        size: 16,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    this.action,
  });

  final IconData icon;
  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 28, color: foregroundColor),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

class HalamanBeranda extends StatelessWidget {
  const HalamanBeranda({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.sand,
              AppColors.emeraldSoft,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _HeaderBerandaDelegate(
                topPadding: MediaQuery.of(context).padding.top,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _BerandaUi.screenPadding,
                  16,
                  _BerandaUi.screenPadding,
                  140,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _KartuJadwalShalat(),
                    const SizedBox(height: _BerandaUi.sectionGap),
                    _KartuPortofolio(),
                    const SizedBox(height: _BerandaUi.sectionGap),
                    _GridFitur(),
                    const SizedBox(height: _BerandaUi.sectionGap),
                    _KartuLanjutkanBelajar(),
                    const SizedBox(height: _BerandaUi.sectionGap),
                    _BagianBeritaTerbaru(),
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

class _HeaderBerandaDelegate extends SliverPersistentHeaderDelegate {
  _HeaderBerandaDelegate({required this.topPadding});

  final double topPadding;

  @override
  double get minExtent => topPadding + 64;

  @override
  double get maxExtent => topPadding + 64;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            border: Border(
              bottom: BorderSide(
                color: _BerandaUi.softLine.withValues(alpha: 0.9),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            AppColors.emerald,
                            Color(0xFF14B8A6),
                          ],
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x16000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: const Icon(
                        Symbols.person,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'Assalamu\u2019alaikum,',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: const Color(0xFF059669).withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Text(
                              AuthService.instance.namaUser,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            if (AuthService.instance.adalahTamu) ...<Widget>[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Text(
                                  'Mode Tamu',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Stack(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _BerandaUi.softLine),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Symbols.notifications_active,
                        color: Color(0xFF475569),
                        size: 22,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

class _KartuJadwalShalat extends StatefulWidget {
  @override
  State<_KartuJadwalShalat> createState() => _KartuJadwalShalatState();
}

class _KartuJadwalShalatState extends State<_KartuJadwalShalat> {
  _PrayerCityData _jakarta = const _PrayerCityData(city: 'Jakarta', prayer: 'Subuh', time: '--:--');
  _PrayerCityData _makkah = const _PrayerCityData(city: 'Makkah', prayer: 'Subuh', time: '--:--');
  bool _loading = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _fetchPrayerTimes();
  }

  Future<void> _fetchPrayerTimes() async {
    setState(() => _loading = true);
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.aladhan.com/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final rs = await Future.wait<Response<dynamic>>([
        dio.get('/timingsByCity', queryParameters: {
          'city': 'Jakarta',
          'country': 'Indonesia',
          'method': 11,
        }),
        dio.get('/timingsByCity', queryParameters: {
          'city': 'Makkah',
          'country': 'Saudi Arabia',
          'method': 4,
        }),
      ]);
      _jakarta = _PrayerCityData.fromAladhan(
        city: 'Jakarta',
        utcOffsetHours: 7,
        raw: rs[0].data,
      );
      _makkah = _PrayerCityData.fromAladhan(
        city: 'Makkah',
        utcOffsetHours: 3,
        raw: rs[1].data,
      );
      await ShalatNotificationService.instance.scheduleFromAladhanRaw(
        city: 'Jakarta',
        timezoneName: 'Asia/Jakarta',
        raw: rs[0].data,
      );
      await ShalatNotificationService.instance.scheduleFromAladhanRaw(
        city: 'Makkah',
        timezoneName: 'Asia/Riyadh',
        raw: rs[1].data,
      );
      await ShalatNotificationService.instance.debugPrintPending();
      _loadFailed = false;
    } catch (_) {
      _loadFailed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final badgeDate = _formatDateId(now);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BerandaUi.softLine),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -24,
            top: -24,
            child: Opacity(
              opacity: 0.1,
              child: Transform.rotate(
                angle: 0.2,
                child: Icon(
                  Symbols.mosque,
                  size: 120,
                  color: AppColors.emerald,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD1FAE5)),
                        ),
                        child: const Icon(
                          Symbols.schedule,
                          size: 18,
                          color: AppColors.emerald,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Jadwal Shalat',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldSoft.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                    ),
                    child: Text(
                      _loading ? 'Memuat...' : badgeDate,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emeraldDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loadFailed) ...<Widget>[
                Text(
                  'Gagal memuat jadwal terbaru',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _jakarta.city,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              _jakarta.prayer,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _jakarta.time,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.emerald,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          Color(0xFFE2E8F0),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          _makkah.city,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              _makkah.prayer,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _makkah.time,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateId(DateTime d) {
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final h = hari[(d.weekday - 1).clamp(0, 6)];
    final b = bulan[(d.month - 1).clamp(0, 11)];
    return '$h, ${d.day} $b';
  }
}

class _PrayerCityData {
  const _PrayerCityData({
    required this.city,
    required this.prayer,
    required this.time,
  });

  final String city;
  final String prayer;
  final String time;

  factory _PrayerCityData.fromAladhan({
    required String city,
    required int utcOffsetHours,
    required dynamic raw,
  }) {
    final data = raw is Map ? raw['data'] : null;
    final timings = data is Map ? data['timings'] : null;
    final timingMap = timings is Map ? timings : const {};
    const prayerOrder = <String>[
      'Fajr',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
    ];
    const prayerLabel = <String, String>{
      'Fajr': 'Subuh',
      'Dhuhr': 'Dzuhur',
      'Asr': 'Ashar',
      'Maghrib': 'Maghrib',
      'Isha': 'Isya',
    };

    final nowUtc = DateTime.now().toUtc();
    final cityNow = nowUtc.add(Duration(hours: utcOffsetHours));
    final cityNowMinutes = (cityNow.hour * 60) + cityNow.minute;
    String chosenPrayer = 'Maghrib';
    String chosenTime = '--';

    for (final key in prayerOrder) {
      final rawValue = (timingMap[key] ?? '').toString().split(' ').first.trim();
      final hhmm = _parseHourMinute(rawValue);
      if (hhmm == null) continue;
      final prayerMinutes = (hhmm.$1 * 60) + hhmm.$2;
      if (prayerMinutes > cityNowMinutes) {
        chosenPrayer = key;
        chosenTime = _formatHm(hhmm.$1, hhmm.$2);
        break;
      }
    }

    if (chosenTime == '--') {
      final rawFajr = (timingMap['Fajr'] ?? '').toString().split(' ').first.trim();
      final hhmm = _parseHourMinute(rawFajr);
      if (hhmm != null) {
        chosenPrayer = 'Fajr';
        chosenTime = _formatHm(hhmm.$1, hhmm.$2);
      }
    }

    return _PrayerCityData(
      city: city,
      prayer: prayerLabel[chosenPrayer] ?? chosenPrayer,
      time: chosenTime,
    );
  }

  static (int, int)? _parseHourMinute(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (h, m);
  }

  static String _formatHm(int h, int m) {
    final hs = h.toString().padLeft(2, '0');
    final ms = m.toString().padLeft(2, '0');
    return '$hs:$ms';
  }
}

class _GridFitur extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bool isTamu = AuthService.instance.adalahTamu;

    final List<_ItemFitur> fitur = <_ItemFitur>[
      _ItemFitur(
        judul: 'Screener',
        ikon: Symbols.rule_folder,
        warna: const Color(0xFFE8F5F0),
        tujuan: RuteAplikasi.penyaring,
      ),
      _ItemFitur(
        judul: 'Pasar',
        ikon: Symbols.candlestick_chart,
        warna: const Color(0xFFEFF6FF),
        tujuan: RuteAplikasi.pasar,
      ),
      _ItemFitur(
        judul: 'Pustaka',
        ikon: Symbols.menu_book,
        warna: const Color(0xFFFFF7ED),
        tujuan: RuteAplikasi.pustaka,
      ),
      _ItemFitur(
        judul: 'Portofolio',
        ikon: Symbols.account_balance_wallet,
        warna: const Color(0xFFEDE9FE),
        tujuan: RuteAplikasi.portofolio,
        terbatasGuest: true,
      ),
      _ItemFitur(
        judul: 'Zakat',
        ikon: Symbols.calculate,
        warna: const Color(0xFFFFE4E6),
        tujuan: RuteAplikasi.zakat,
        terbatasGuest: true,
      ),
      _ItemFitur(
        judul: 'Psikolog',
        ikon: Symbols.psychology,
        warna: const Color(0xFFE0F2FE),
        tujuan: RuteAplikasi.psikolog,
        terbatasGuest: true,
      ),
      _ItemFitur(
        judul: 'Konsultasi',
        ikon: Symbols.support_agent,
        warna: const Color(0xFFFFEDD5),
        tujuan: RuteAplikasi.konsultasi,
        terbatasGuest: true,
      ),
      _ItemFitur(
        judul: 'Zikir',
        ikon: Symbols.auto_stories,
        warna: const Color(0xFFE2E8F0),
        tujuan: RuteAplikasi.zikir,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(
          title: 'Fitur Utama',
          subtitle: 'Akses cepat fitur utama Averroes',
          leadingIcon: Symbols.apps,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: fitur.length,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (BuildContext context, int index) {
            final _ItemFitur item = fitur[index];
            final bool terkunci = isTamu && item.terbatasGuest;

            return InkWell(
              onTap: () {
                if (cekAksesGuest(context, item.tujuan)) {
                  return;
                }
                Get.toNamed(item.tujuan);
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: terkunci ? const Color(0xFFFBFCFE) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _BerandaUi.softLine),
                  boxShadow: terkunci
                      ? null
                      : const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                child: Stack(
                  children: <Widget>[
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: terkunci
                                  ? const Color(0xFFF1F5F9)
                                  : item.warna,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: terkunci
                                    ? _BerandaUi.softLine
                                    : const Color(0xFFFFFFFF),
                                width: 1.2,
                              ),
                              boxShadow: terkunci
                                  ? null
                                  : const <BoxShadow>[
                                      BoxShadow(
                                        color: Color(0x12000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                            ),
                            child: Icon(
                              item.ikon,
                              size: 19,
                              color: terkunci
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.judul,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: terkunci
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (terkunci)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Symbols.lock,
                            size: 11,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _KartuLanjutkanBelajar extends StatefulWidget {
  @override
  State<_KartuLanjutkanBelajar> createState() => _KartuLanjutkanBelajarState();
}

class _KartuLanjutkanBelajarState extends State<_KartuLanjutkanBelajar> {
  final EdukasiApi _api = EdukasiApi();
  LastLearningEdukasi? _last;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!AuthService.instance.sudahLogin) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _last = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await _api.fetchLastLearning();
      if (!mounted) return;
      setState(() => _last = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _last = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEdukasi() async {
    await Get.toNamed(RuteAplikasi.edukasi);
    await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _loading
        ? 'Memuat kelas terakhir...'
        : _last == null
            ? 'Belum ada progress materi'
            : 'Kelas: ${_last!.kelasJudul} (Materi ${_last!.nextMateriIndex}/${_last!.totalMateri})';
    return InkWell(
      onTap: _openEdukasi,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFECFDF5),
              Color(0xFFFFFFFF),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Symbols.menu_book,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Lanjutkan Belajar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Symbols.chevron_right,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemFitur {
  const _ItemFitur({
    required this.judul,
    required this.ikon,
    required this.warna,
    required this.tujuan,
    this.terbatasGuest = false,
  });

  final String judul;
  final IconData ikon;
  final Color warna;
  final String tujuan;
  final bool terbatasGuest;
}

class _BagianBeritaTerbaru extends StatefulWidget {
  @override
  State<_BagianBeritaTerbaru> createState() => _BagianBeritaTerbaruState();
}

class _BagianBeritaTerbaruState extends State<_BagianBeritaTerbaru> {
  List<Map<String, dynamic>> _beritaList = <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchBerita();
  }

  Future<void> _fetchBerita() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final Dio dio = ApiDio.create(attachAuthToken: false);
      final Response<dynamic> response = await dio.get<dynamic>(
        '${AppConfig.apiBaseUrl}/api/berita?per_page=5',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;

        final dynamic rawStatus = data['status'];
        final bool isSuccess =
            rawStatus == true || rawStatus?.toString().toLowerCase() == 'success';

        if (isSuccess && data['data'] != null) {
          final Map<String, dynamic> innerData =
              data['data'] as Map<String, dynamic>;
          final List<dynamic> beritaRaw = (innerData['berita'] is List<dynamic>)
              ? innerData['berita'] as List<dynamic>
              : (innerData['items'] as List<dynamic>? ?? <dynamic>[]);

          setState(() {
            _beritaList = beritaRaw
                .map((dynamic e) => e as Map<String, dynamic>)
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['pesan']?.toString() ??
                data['message']?.toString() ??
                'Gagal memuat berita';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Gagal memuat berita';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Tidak dapat terhubung ke server';
        _isLoading = false;
      });
    }
  }

  Future<void> _bukaBerita(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(
          title: 'Berita Aset Kripto',
          subtitle: 'Sumber: cryptowave.co.id',
          leadingIcon: Symbols.newspaper,
          trailing: !_isLoading
              ? GestureDetector(
                  onTap: _fetchBerita,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD1FAE5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Symbols.refresh,
                          size: 14,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Perbarui',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          _buildLoadingShimmer()
        else if (_errorMessage != null)
          _buildError()
        else if (_beritaList.isEmpty)
          _buildEmpty()
        else
          ...[
            ..._beritaList.map(
              (Map<String, dynamic> item) => _buildKartuBerita(item),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _HalamanDaftarBeritaTerbaru(),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _BerandaUi.softLine),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.newspaper, size: 16, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Text(
                      'Lihat Berita',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Symbols.arrow_forward, size: 14, color: Color(0xFF059669)),
                  ],
                ),
              ),
            ),
          ],
      ],
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: List<Widget>.generate(
        3,
        (int i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _BerandaUi.softLine),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return _StateCard(
      icon: Symbols.cloud_off,
      message: _errorMessage ?? 'Terjadi kesalahan saat memuat berita',
      backgroundColor: const Color(0xFFFEF2F2),
      borderColor: const Color(0xFFFECACA),
      foregroundColor: const Color(0xFFB91C1C),
      action: GestureDetector(
        onTap: _fetchBerita,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Coba Lagi',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const _StateCard(
      icon: Symbols.article,
      message: 'Belum ada berita terbaru untuk ditampilkan',
      backgroundColor: Colors.white,
      borderColor: _BerandaUi.softLine,
      foregroundColor: AppColors.muted,
    );
  }

  Widget _buildKartuBerita(Map<String, dynamic> item) {
    final String judul = (item['judul'] as String?) ?? '';
    final String ringkasan = (item['ringkasan'] as String?) ?? '';
    final String penulis = (item['penulis'] as String?) ?? '';
    final String tanggal = (item['tanggal_asli'] as String?) ?? '';
    final String sumberUrl = (item['sumber_url'] as String?) ?? '';
    final String gambarUrl = ((item['gambar_url'] ??
                item['thumbnail'] ??
                item['image_url'] ??
                item['urlToImage']) as String?) ??
        '';

    return GestureDetector(
      onTap: () => _bukaBerita(sumberUrl),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _BerandaUi.softLine),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: gambarUrl.isNotEmpty
                  ? Image.network(
                      gambarUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext context, Object error,
                          StackTrace? stackTrace) {
                        return Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Symbols.newspaper,
                            size: 28,
                            color: Color(0xFF059669),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Symbols.newspaper,
                        size: 28,
                        color: Color(0xFF059669),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Konten
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    judul,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (ringkasan.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      ringkasan,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      if (penulis.isNotEmpty) ...[
                        Icon(
                          Symbols.person,
                          size: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            penulis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (penulis.isNotEmpty && tanggal.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: Color(0xFFCBD5E1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      if (tanggal.isNotEmpty)
                        Flexible(
                          child: Text(
                            tanggal,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Symbols.open_in_new,
              size: 16,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}

class _HalamanDaftarBeritaTerbaru extends StatefulWidget {
  const _HalamanDaftarBeritaTerbaru();

  @override
  State<_HalamanDaftarBeritaTerbaru> createState() => _HalamanDaftarBeritaTerbaruState();
}

class _HalamanDaftarBeritaTerbaruState extends State<_HalamanDaftarBeritaTerbaru> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Dio dio = ApiDio.create(attachAuthToken: false);
      final Response<dynamic> response = await dio.get<dynamic>(
        '${AppConfig.apiBaseUrl}/api/berita?per_page=20',
      );
      final raw = response.data is String
          ? jsonDecode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;
      final data = raw['data'];
      final rows = data is Map ? (data['items'] as List<dynamic>? ?? <dynamic>[]) : <dynamic>[];
      setState(() {
        _items = rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Gagal memuat berita';
        _loading = false;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '20 Berita Terbaru',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _fetch, child: const Text('Coba lagi')),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    final judul = (item['judul'] as String?) ?? '';
                    final ringkasan = (item['ringkasan'] as String?) ?? '';
                    final tanggal = (item['tanggal_asli'] as String?) ?? '';
                    final sumberUrl = (item['sumber_url'] as String?) ?? '';
                    final gambarUrl = ((item['gambar_url'] ??
                                item['thumbnail'] ??
                                item['image_url'] ??
                                item['urlToImage']) as String?) ??
                        '';
                    return GestureDetector(
                      onTap: () => _openUrl(sumberUrl),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: gambarUrl.isNotEmpty
                                  ? Image.network(
                                      gambarUrl,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _newsThumbFallback(),
                                    )
                                  : _newsThumbFallback(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    judul,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (ringkasan.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      ringkasan,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    tanggal,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _newsThumbFallback() => Container(
        width: 72,
        height: 72,
        color: const Color(0xFFECFDF5),
        child: const Icon(Symbols.newspaper, color: Color(0xFF059669)),
      );
}


class _KartuPortofolio extends StatefulWidget {
  @override
  State<_KartuPortofolio> createState() => _KartuPortofolioState();
}

class _KartuPortofolioState extends State<_KartuPortofolio> {
  final PortofolioApi _portofolioApi = PortofolioApi();
  double _total = 0;
  int _jumlahAset = 0;
  bool _loading = true;
  bool _fetching = false;
  bool _isHidden = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _fetch(silent: true));
    PortofolioSync.revision.addListener(_onPortofolioChanged);
  }

  @override
  void dispose() {
    PortofolioSync.revision.removeListener(_onPortofolioChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onPortofolioChanged() {
    _fetch(silent: false);
  }

  Future<void> _fetch({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (!AuthService.instance.sudahLogin) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _total = 0;
        _jumlahAset = 0;
      });
      _fetching = false;
      return;
    }
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final result = await _portofolioApi.fetchPortofolio();
      _total = result.totalNilai;
      _jumlahAset = result.items.length;
    } catch (_) {
      _total = 0;
      _jumlahAset = 0;
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPortofolio() async {
    await Get.toNamed(RuteAplikasi.portofolio);
    await _fetch(silent: false);
  }

  String _idr(double v) {
    final raw = v.toStringAsFixed(0);
    final sb = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      sb.write(raw[i]);
      final remain = raw.length - i - 1;
      if (remain > 0 && remain % 3 == 0) sb.write('.');
    }
    return 'Rp ${sb.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final totalLabel = _loading
        ? '...'
        : _isHidden
            ? 'Rp •••••••'
            : _idr(_total);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _BerandaUi.softLine),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white,
            AppColors.emeraldSoft,
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -16,
            top: -16,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5).withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.amberSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.5)),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Symbols.account_balance_wallet,
                          color: AppColors.amber,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Total Portfolio',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isHidden = !_isHidden),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _BerandaUi.softLine),
                      ),
                      child: Icon(
                        _isHidden ? Symbols.visibility : Symbols.visibility_off,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                height: 1,
                color: const Color(0xFFDCEFE8),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _loading
                        ? 'Memuat portofolio...'
                        : '$_jumlahAset aset kripto',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.emerald,
                    ),
                  ),
                  GestureDetector(
                    onTap: _openPortofolio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.emerald,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x220F766E),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Text(
                            'Lihat Portofolio',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Symbols.arrow_forward,
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
