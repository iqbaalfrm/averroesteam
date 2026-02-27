import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/services/auth_service.dart';
import '../profile/profile_api.dart';

class HalamanEditProfil extends StatefulWidget {
  const HalamanEditProfil({super.key});

  @override
  State<HalamanEditProfil> createState() => _HalamanEditProfilState();
}

class _HalamanEditProfilState extends State<HalamanEditProfil> {
  final _formKey = GlobalKey<FormState>();
  final _namaC = TextEditingController();
  final _emailC = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = AuthService.instance.user;
    _namaC.text = ((data?['nama'] ?? data?['Nama']) ?? '').toString();
    _emailC.text = (data?['email'] ?? '').toString();
  }

  @override
  void dispose() {
    _namaC.dispose();
    _emailC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ProfileApi().updateMe(
        nama: _namaC.text,
        email: _emailC.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal simpan profil: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ((AuthService.instance.user?['role'] ?? AuthService.instance.user?['Role']) ?? 'user')
        .toString()
        .toLowerCase();
    final roleBadge = role == 'admin' ? 'ADMIN' : 'USER';
    final roleLabel = role == 'admin' ? 'Administrator' : 'Pengguna Terdaftar';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              automaticallyImplyLeading: false,
              backgroundColor: const Color(0xFFF6F8F8).withValues(alpha: 0.92),
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CircleIconButton(
                      icon: Symbols.arrow_back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    Text(
                      'Profil Pengguna',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D1B18),
                      ),
                    ),
                    const _CircleIconButton(icon: Symbols.settings),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: _HeroSection(
                      name: _namaC.text.trim().isEmpty ? 'Pengguna' : _namaC.text.trim(),
                      roleBadge: roleBadge,
                      roleLabel: roleLabel,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Symbols.local_fire_department,
                                iconColor: Color(0xFFF97316),
                                value: '12',
                                label: 'Hari Streak',
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Symbols.bolt,
                                iconColor: Color(0xFFEAB308),
                                value: '4500',
                                label: 'Total XP',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const _SectionTitle('Edit Profil'),
                        const SizedBox(height: 10),
                        _Card(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              _InputField(
                                label: 'Nama Lengkap',
                                icon: Symbols.person_outline,
                                controller: _namaC,
                                hint: 'Masukkan nama lengkap',
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Nama wajib diisi'
                                    : null,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 12),
                              _InputField(
                                label: 'Email',
                                icon: Symbols.alternate_email,
                                controller: _emailC,
                                hint: 'Masukkan email',
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty) return null;
                                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                                  return ok ? null : 'Format email tidak valid';
                                },
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: const Color(0xFF13ECB9),
                                    foregroundColor: const Color(0xFF0D1B18),
                                    minimumSize: const Size.fromHeight(50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    _saving ? 'Menyimpan...' : 'Simpan Perubahan',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Card(
                          child: Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEAFBF4), Color(0xFFD7F8EE)],
                                  ),
                                ),
                                child: const Icon(
                                  Symbols.workspace_premium,
                                  size: 28,
                                  color: Color(0xFF4C9A88),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sertifikat Saya',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Akan terupdate dari progres belajar kamu.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Symbols.chevron_right, color: Color(0xFFCBD5E1)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: Color(0xFFFECACA)),
                            foregroundColor: const Color(0xFFEF4444),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.name,
    required this.roleBadge,
    required this.roleLabel,
  });

  final String name;
  final String roleBadge;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: -90,
          child: Container(
            width: 360,
            height: 230,
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
            opacity: 0.14,
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x3313ECB9),
                        blurRadius: 16,
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
                      _initials(name),
                      style: GoogleFonts.inter(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D6B56),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF13ECB9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF6F8F8), width: 3),
                    ),
                    child: const Icon(Symbols.edit, size: 18, color: Color(0xFF0D1B18)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 30 / 1.25,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0D1B18),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F3F0),
                    border: Border.all(color: const Color(0xFFD1FAE5)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    roleBadge,
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
                  roleLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF286B5C),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.onChanged,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0D1B18),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF0EB58E)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF13ECB9), width: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0D1B18),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      padding: const EdgeInsets.symmetric(vertical: 14),
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
      width: double.infinity,
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
