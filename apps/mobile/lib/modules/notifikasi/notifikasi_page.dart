import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class HalamanNotifikasi extends StatefulWidget {
  const HalamanNotifikasi({super.key});

  @override
  State<HalamanNotifikasi> createState() => _HalamanNotifikasiState();
}

class _HalamanNotifikasiState extends State<HalamanNotifikasi> {
  bool waktuSholat = true;
  bool beritaCrypto = true;
  bool updatePortofolio = true;
  bool aktivitasDiskusi = false;
  bool pushNotif = true;
  bool whatsapp = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF8FAF9).withOpacity(0.8),
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: <Widget>[
                  _IconCircleButton(
                    icon: Symbols.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Pengaturan Notifikasi',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D1B18),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SectionTitle(title: 'Jenis Pemberitahuan'),
                  const SizedBox(height: 12),
                  _ToggleCard(
                    icon: Symbols.mosque,
                    title: 'Waktu Sholat',
                    subtitle: 'Peringatan adzan & iqomah',
                    iconBg: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF064E3B),
                    value: waktuSholat,
                    onChanged: (bool value) => setState(() => waktuSholat = value),
                  ),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Symbols.currency_bitcoin,
                    title: 'Berita Crypto Syariah',
                    subtitle: 'Update fatwa & pasar crypto',
                    iconBg: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFCA8A04),
                    value: beritaCrypto,
                    onChanged: (bool value) => setState(() => beritaCrypto = value),
                  ),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Symbols.pie_chart,
                    title: 'Update Portofolio',
                    subtitle: 'Laporan performa harian',
                    iconBg: const Color(0xFFDBEAFE),
                    iconColor: const Color(0xFF2563EB),
                    value: updatePortofolio,
                    onChanged: (bool value) => setState(() => updatePortofolio = value),
                  ),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Symbols.forum,
                    title: 'Aktivitas Diskusi',
                    subtitle: 'Balasan & mention komunitas',
                    iconBg: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF7C3AED),
                    value: aktivitasDiskusi,
                    onChanged: (bool value) => setState(() => aktivitasDiskusi = value),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(title: 'Metode Pengiriman'),
                  const SizedBox(height: 12),
                  _ToggleRow(
                    icon: Symbols.notifications_active,
                    title: 'Push Notification',
                    iconColor: const Color(0xFF9CA3AF),
                    value: pushNotif,
                    onChanged: (bool value) => setState(() => pushNotif = value),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _ToggleRow(
                    icon: Symbols.chat,
                    title: 'WhatsApp',
                    iconColor: const Color(0xFF22C55E),
                    value: whatsapp,
                    onChanged: (bool value) => setState(() => whatsapp = value),
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(),
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
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF0D1B18)),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: const Color(0xFF94A3B8),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBg;
  final Color iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D1B18),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF064E3B),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E7EB),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final Color iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0D1B18),
                ),
              ),
            ],
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF064E3B),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E7EB),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13ECB9).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF13ECB9).withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Symbols.info,
            size: 18,
            color: Color(0xFF0EB58E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pengaturan akan disimpan secara otomatis. Beberapa notifikasi mungkin tertunda berdasarkan pengaturan penghemat baterai perangkat Anda.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0EB58E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
