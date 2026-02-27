import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/routes/app_routes.dart';
import '../../app/services/auth_service.dart';
import 'profile_api.dart';

class HalamanProfil extends StatefulWidget {
  const HalamanProfil({super.key});

  @override
  State<HalamanProfil> createState() => _HalamanProfilState();
}

class _HalamanProfilState extends State<HalamanProfil> {
  final ProfileApi _api = ProfileApi();
  ProfileUser? _user;
  ProfileLearningSummary _learning = const ProfileLearningSummary.empty();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _hydrateLocal();
    _refresh();
  }

  void _hydrateLocal() {
    final data = AuthService.instance.user;
    if (data != null) {
      _user = ProfileUser.fromJson(data);
    }
  }

  Future<void> _refresh() async {
    if (!AuthService.instance.sudahLogin) return;
    setState(() => _loading = true);
    try {
      final user = await _api.fetchMe();
      final learning = await _api.fetchLearningSummary();
      if (!mounted) return;
      setState(() {
        _user = user;
        _learning = learning;
      });
    } catch (_) {
      // fallback: keep local cache
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEdit() async {
    await Get.toNamed(RuteAplikasi.editProfil);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final nama = (_user?.nama.trim().isNotEmpty ?? false)
        ? _user!.nama
        : AuthService.instance.namaUser;
    final role = (_user?.role ?? AuthService.instance.role ?? 'user').toLowerCase();
    final email = (_user?.email?.trim().isNotEmpty ?? false)
        ? _user!.email!
        : 'email belum diatur';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF6F8F8).withValues(alpha: 0.92),
            elevation: 0,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (canPop)
                    _CircleIconButton(
                      icon: Symbols.arrow_back,
                      onTap: () => Navigator.of(context).maybePop(),
                    )
                  else
                    const SizedBox(width: 40, height: 40),
                  Text(
                    'Profil Pengguna',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D1B18),
                    ),
                  ),
                  _CircleIconButton(
                    icon: _loading ? Symbols.sync : Symbols.settings,
                    onTap: _loading ? null : _refresh,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _HeroSection(
                  nama: nama,
                  role: role,
                  email: email,
                  onEdit: _openEdit,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    children: [
                      _StatsGrid(learning: _learning),
                      const SizedBox(height: 22),
                      _SectionHeader(
                        title: 'Sertifikat Saya',
                        action: 'Lihat Semua',
                        onTap: () => Get.toNamed(RuteAplikasi.sertifikat),
                      ),
                      const SizedBox(height: 10),
                      _SertifikatCard(learning: _learning),
                      const SizedBox(height: 22),
                      const _SectionHeader(title: 'Riwayat Pembelajaran'),
                      const SizedBox(height: 10),
                      _RiwayatCard(learning: _learning),
                      const SizedBox(height: 22),
                      const _SectionHeader(title: 'Pengaturan Akun'),
                      const SizedBox(height: 10),
                      _PengaturanList(onEdit: _openEdit),
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: () async {
                          await AuthService.instance.logout();
                          if (!mounted) return;
                          Get.offAllNamed(RuteAplikasi.login);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFEE2E2)),
                          foregroundColor: const Color(0xFFEF4444),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Keluar',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Versi Aplikasi 2.4.0',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
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

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.nama,
    required this.role,
    required this.email,
    required this.onEdit,
  });

  final String nama;
  final String role;
  final String email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final badge = role == 'admin' ? 'ADMIN' : 'USER';
    final label = role == 'admin' ? 'Administrator' : 'Pengguna Terdaftar';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -170,
            child: Container(
              width: 420,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x2413ECB9), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: CustomPaint(painter: _DotPatternPainter()),
            ),
          ),
          Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 132,
                    height: 132,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3313ECB9),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFE7F7F2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(nama),
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0D6B56),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: InkWell(
                      onTap: onEdit,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF13ECB9),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF6F8F8), width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3313ECB9),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Symbols.edit, size: 18, color: Color(0xFF0D1B18)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                nama,
                style: GoogleFonts.inter(
                  fontSize: 34 / 1.4,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D1B18),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F3F0),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD1FAE5)),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: const Color(0xFF4C9A88),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF286B5C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.learning});

  final ProfileLearningSummary learning;

  @override
  Widget build(BuildContext context) {
    final streak = learning.completedMateri;
    final xp = learning.completedMateri * 150;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Symbols.local_fire_department,
            iconColor: const Color(0xFFF97316),
            value: '$streak',
            label: 'Hari Streak',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Symbols.bolt,
            iconColor: const Color(0xFFEAB308),
            value: '$xp',
            label: 'Total XP',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 6),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D1B18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0D1B18),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onTap,
            child: Text(
              action!,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF13A88A),
              ),
            ),
          ),
      ],
    );
  }
}

class _SertifikatCard extends StatelessWidget {
  const _SertifikatCard({required this.learning});

  final ProfileLearningSummary learning;

  @override
  Widget build(BuildContext context) {
    final ready = learning.certificateEligible;
    return _Card(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEAFBF4), Color(0xFFD7F8EE)],
              ),
            ),
            child: const Icon(Symbols.workspace_premium, size: 30, color: Color(0xFF4C9A88)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? learning.kelasJudul : 'Belum ada sertifikat',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  ready ? 'Skor ${learning.scorePercent}%' : 'Selesaikan materi dan kuis (>=70)',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Symbols.star, size: 14, color: Color(0xFFEAB308)),
                    const SizedBox(width: 5),
                    Text(
                      ready ? 'Siap klaim sertifikat' : 'Belum memenuhi syarat',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Symbols.chevron_right, color: Color(0xFFCBD5E1)),
        ],
      ),
    );
  }
}

class _RiwayatCard extends StatelessWidget {
  const _RiwayatCard({required this.learning});

  final ProfileLearningSummary learning;

  @override
  Widget build(BuildContext context) {
    final title = learning.lastMateriJudul ?? 'Belum ada materi dipelajari';
    final subtitle = learning.totalMateri > 0
        ? 'Materi ${learning.nextMateriIndex}/${learning.totalMateri}'
        : 'Mulai dari kelas utama';
    final progress = (learning.progressMateriPercent.clamp(0, 100)) / 100.0;
    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Color(0x1A13ECB9), shape: BoxShape.circle),
                child: const Icon(Symbols.school, color: Color(0xFF0EB58E), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF13ECB9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Lanjut',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0D1B18)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0EB58E)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progres', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF))),
              Text('${learning.progressMateriPercent}%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PengaturanList extends StatelessWidget {
  const _PengaturanList({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SettingRow(icon: Symbols.person_outline, label: 'Edit Profil', onTap: onEdit),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _SettingRow(icon: Symbols.notifications_none, label: 'Notifikasi', onTap: () => Get.toNamed(RuteAplikasi.notifikasi)),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _SettingRow(icon: Symbols.help_outline, label: 'Bantuan & Dukungan', onTap: () => Get.toNamed(RuteAplikasi.bantuan)),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF64748B), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0D1B18)),
              ),
            ),
            const Icon(Symbols.chevron_right, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF0D1B18)),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEFF5)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF13ECB9)
      ..style = PaintingStyle.fill;
    const spacing = 24.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
