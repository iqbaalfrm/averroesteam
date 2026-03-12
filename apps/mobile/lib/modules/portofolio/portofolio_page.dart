import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'portofolio_api.dart';
import 'portofolio_sync.dart';

class HalamanPortofolio extends StatefulWidget {
  const HalamanPortofolio({super.key});

  @override
  State<HalamanPortofolio> createState() => _HalamanPortofolioState();
}

class _HalamanPortofolioState extends State<HalamanPortofolio> {
  final PortofolioApi _api = PortofolioApi();
  bool _loading = true;
  String? _error;
  List<PortofolioItem> _items = const <PortofolioItem>[];
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.fetchPortofolio();
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _total = res.totalNilai;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'portofolio_load_error'.tr;
        _loading = false;
      });
    }
  }

  Future<void> _openForm({PortofolioItem? item}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PortofolioFormSheet(api: _api, item: item),
    );
    if (changed == true) _load();
  }

  Future<void> _confirmDelete(PortofolioItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('portofolio_delete_asset'.tr),
        content: Text('portofolio_delete_confirm'.trParams({'asset': '${item.namaAset} (${item.simbol})'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('portofolio_cancel'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('portofolio_delete'.tr)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deletePortofolio(item.id);
      PortofolioSync.markChanged();
      if (!mounted) return;
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('portofolio_delete_failed'.tr)),
      );
    }
  }

  Future<void> _openRiwayat() async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RiwayatPortofolioSheet(api: _api),
    );
  }

  String _idr(double v) {
    final parts = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      buf.write(parts[i]);
      final remain = parts.length - i - 1;
      if (remain > 0 && remain % 3 == 0) buf.write('.');
    }
    return 'Rp ${buf.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFCF9F6),
              Color(0xFFF5F7F9),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              backgroundColor: const Color(0xFFFCF9F6).withValues(alpha: 0.85),
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
                          icon: Symbols.chevron_left,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'portofolio_title'.tr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    _IconCircleButton(
                      icon: Symbols.insights,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _RingkasanSaldo(total: _total, jumlahAset: _items.length),
                    const SizedBox(height: 20),
                    _AksiCepat(
                      onTambah: () => _openForm(),
                      onRiwayat: _openRiwayat,
                    ),
                    const SizedBox(height: 20),
                    _KartuAlokasiAset(items: _items, totalNilai: _total),
                    const SizedBox(height: 24),
                    _JudulBagian(
                      judul: 'portofolio_asset_list'.tr,
                      aksi: 'portofolio_filter'.tr,
                      ikon: Symbols.sort,
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _PortofolioError(message: _error!, onRetry: _load)
                    else if (_items.isEmpty)
                      _PortofolioKosong(onTambah: () => _openForm())
                    else
                      ..._items.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(bottom: i == _items.length - 1 ? 0 : 12),
                          child: _KartuAset(
                            judul: '${item.namaAset} (${item.simbol})',
                            subjudul: 'portofolio_crypto_manual'.tr,
                            nilai: _idr(item.nilai),
                            perubahan: '${item.jumlah} @ ${_idr(item.hargaBeli)}',
                            naik: null,
                            icon: item.simbol == 'BTC'
                                ? Symbols.currency_bitcoin
                                : Symbols.token,
                            warna: const Color(0xFFE0E7FF),
                            warnaIcon: const Color(0xFF6366F1),
                            onTap: () => _openForm(item: item),
                            onLongPress: () => _confirmDelete(item),
                          ),
                        );
                      }),
                    const SizedBox(height: 40),
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF334155)),
      ),
    );
  }
}

class _RingkasanSaldo extends StatelessWidget {
  const _RingkasanSaldo({required this.total, required this.jumlahAset});

  final double total;
  final int jumlahAset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          'portofolio_est_balance'.tr,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatIdr(total),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFD1FAE5).withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Symbols.trending_up,
                size: 18,
                color: Color(0xFF10B981),
              ),
              const SizedBox(width: 6),
              Text(
                'portofolio_crypto_asset_count'.trParams({'count': '$jumlahAset'}),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF047857),
                ),
              ),
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: const Color(0xFFBBF7D0),
              ),
              Text(
                'portofolio_manual_coin'.tr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatIdr(double v) {
    final raw = v.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      b.write(raw[i]);
      final r = raw.length - i - 1;
      if (r > 0 && r % 3 == 0) b.write('.');
    }
    return 'Rp ${b.toString()}';
  }
}

class _AksiCepat extends StatelessWidget {
  const _AksiCepat({required this.onTambah, required this.onRiwayat});

  final VoidCallback onTambah;
  final VoidCallback onRiwayat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _AksiButton(
            label: 'portofolio_add'.tr,
            icon: Symbols.add,
            warnaIcon: const Color(0xFF10B981),
            warnaLatar: const Color(0xFFECFDF5),
            onTap: onTambah,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AksiButton(
            label: 'portofolio_history'.tr,
            icon: Symbols.history,
            warnaIcon: const Color(0xFF6366F1),
            warnaLatar: const Color(0xFFE0E7FF),
            onTap: onRiwayat,
          ),
        ),
      ],
    );
  }
}

class _AksiButton extends StatelessWidget {
  const _AksiButton({
    required this.label,
    required this.icon,
    required this.warnaIcon,
    required this.warnaLatar,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color warnaIcon;
  final Color warnaLatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: warnaLatar,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: warnaIcon),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuAlokasiAset extends StatelessWidget {
  const _KartuAlokasiAset({required this.items, required this.totalNilai});
  final List<PortofolioItem> items;
  final double totalNilai;
  @override
  Widget build(BuildContext context) {
    final topItems = [...items]..sort((a, b) => b.nilai.compareTo(a.nilai));
    final visibleItems = topItems.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'portofolio_asset_allocation'.tr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items.isEmpty
                        ? 'portofolio_no_assets'.tr
                        : 'portofolio_active_coins'.trParams({'count': '${items.length}'}),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const Icon(
                Symbols.pie_chart,
                color: Color(0xFFCBD5F5),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              _DonatAset(totalAset: items.length),
              const SizedBox(width: 20),
              Expanded(
                child: _DetailAset(
                  items: visibleItems,
                  totalNilai: totalNilai,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonatAset extends StatelessWidget {
  const _DonatAset({required this.totalAset});
  final int totalAset;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: <Color>[
            Color(0xFF4F46E5),
            Color(0xFF4F46E5),
            Color(0xFF10B981),
            Color(0xFF10B981),
            Color(0xFFF59E0B),
            Color(0xFFF59E0B),
            Color(0xFFEC4899),
            Color(0xFFEC4899),
          ],
          stops: <double>[0, 0.45, 0.45, 0.75, 0.75, 0.9, 0.9, 1],
        ),
      ),
      child: Center(
        child: Container(
          width: 90,
          height: 90,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '$totalAset',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Text(
                'portofolio_coin'.tr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailAset extends StatelessWidget {
  const _DetailAset({required this.items, required this.totalNilai});
  final List<PortofolioItem> items;
  final double totalNilai;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || totalNilai <= 0) {
      return Text(
        'portofolio_add_to_see'.tr,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8),
        ),
      );
    }
    const colors = <Color>[
      Color(0xFF4F46E5),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
    ];
    return Column(
      children: items.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final pct = totalNilai <= 0 ? 0.0 : (item.nilai / totalNilai);
        return Padding(
          padding: EdgeInsets.only(bottom: idx == items.length - 1 ? 0 : 10),
          child: _BarDistribusi(
            label: item.simbol,
            persen: '${(pct * 100).toStringAsFixed(0)}%',
            warna: colors[idx % colors.length],
            lebar: pct.clamp(0.0, 1.0),
          ),
        );
      }).toList(),
    );
  }
}

class _BarDistribusi extends StatelessWidget {
  const _BarDistribusi({
    required this.label,
    required this.persen,
    required this.warna,
    required this.lebar,
  });

  final String label;
  final String persen;
  final Color warna;
  final double lebar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: warna,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            Text(
              persen,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: FractionallySizedBox(
            widthFactor: lebar,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: warna,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _JudulBagian extends StatelessWidget {
  const _JudulBagian({required this.judul, required this.aksi, required this.ikon});

  final String judul;
  final String aksi;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          judul,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
        Row(
          children: <Widget>[
            Icon(ikon, size: 18, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              aksi,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KartuAset extends StatelessWidget {
  const _KartuAset({
    required this.judul,
    required this.subjudul,
    required this.nilai,
    required this.perubahan,
    required this.icon,
    required this.warna,
    required this.warnaIcon,
    this.naik,
    this.onTap,
    this.onLongPress,
  });

  final String judul;
  final String subjudul;
  final String nilai;
  final String perubahan;
  final IconData icon;
  final Color warna;
  final Color warnaIcon;
  final bool? naik;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color warnaPerubahan = naik == null
        ? const Color(0xFF94A3B8)
        : (naik! ? const Color(0xFF10B981) : const Color(0xFFF43F5E));

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF8FAFC)),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 26, color: warnaIcon),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    judul,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subjudul.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                nilai,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Text(
                    perubahan,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: warnaPerubahan,
                    ),
                  ),
                  if (naik != null) ...<Widget>[
                    const SizedBox(width: 4),
                    Icon(
                      naik! ? Symbols.trending_up : Symbols.trending_down,
                      size: 14,
                      color: warnaPerubahan,
                    ),
                  ],
                ],
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }
}

class _PortofolioError extends StatelessWidget {
  const _PortofolioError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _PortofolioKosong extends StatelessWidget {
  const _PortofolioKosong({required this.onTambah});
  final VoidCallback onTambah;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Symbols.token, size: 36, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text('Belum ada aset crypto', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          FilledButton(onPressed: onTambah, child: const Text('Tambah Aset')),
        ],
      ),
    );
  }
}

class _PortofolioFormSheet extends StatefulWidget {
  const _PortofolioFormSheet({required this.api, this.item});
  final PortofolioApi api;
  final PortofolioItem? item;

  @override
  State<_PortofolioFormSheet> createState() => _PortofolioFormSheetState();
}

class _PortofolioFormSheetState extends State<_PortofolioFormSheet> {
  final TextEditingController _searchC = TextEditingController();
  final TextEditingController _namaC = TextEditingController();
  final TextEditingController _simbolC = TextEditingController();
  final TextEditingController _jumlahC = TextEditingController();
  final TextEditingController _hargaC = TextEditingController();
  bool _saving = false;
  bool _searching = false;
  List<CryptoSearchItem> _results = const [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _namaC.text = item.namaAset;
      _simbolC.text = item.simbol;
      _jumlahC.text = item.jumlah.toString();
      _hargaC.text = item.hargaBeli.toStringAsFixed(0);
      _searchC.text = '${item.namaAset} (${item.simbol})';
    }
    _searchC.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchC.removeListener(_onSearchChanged);
    _searchC.dispose();
    _namaC.dispose();
    _simbolC.dispose();
    _jumlahC.dispose();
    _hargaC.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchC.text.trim();
    _searchDebounce?.cancel();
    if (q.length < 2) {
      if (_results.isNotEmpty || _searching) {
        setState(() {
          _results = const [];
          _searching = false;
        });
      }
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 450), _searchCoin);
  }

  Future<void> _searchCoin() async {
    final q = _searchC.text.trim();
    if (q.length < 2) return;
    setState(() => _searching = true);
    try {
      final rows = await widget.api.searchCrypto(q);
      if (!mounted) return;
      if (_searchC.text.trim() != q) return;
      setState(() => _results = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = const []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal cari koin dari CoinGecko')),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    final nama = _namaC.text.trim();
    final simbol = _simbolC.text.trim().toUpperCase();
    final jumlah = double.tryParse(_jumlahC.text.replaceAll(',', '.'));
    final harga = double.tryParse(_hargaC.text.replaceAll('.', '').replaceAll(',', '.')) ??
        double.tryParse(_hargaC.text.replaceAll(',', '.'));
    if (nama.isEmpty || simbol.isEmpty || jumlah == null || harga == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi nama, simbol, jumlah, harga beli')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.item == null) {
        await widget.api.createPortofolio(
          namaAset: nama,
          simbol: simbol,
          jumlah: jumlah,
          hargaBeli: harga,
        );
      } else {
        await widget.api.updatePortofolio(
          id: widget.item!.id,
          namaAset: nama,
          simbol: simbol,
          jumlah: jumlah,
          hargaBeli: harga,
        );
      }
      PortofolioSync.markChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan aset')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item == null ? 'Tambah Aset Crypto' : 'Edit Aset Crypto',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchC,
                  decoration: InputDecoration(
                    labelText: 'Cari coin (CoinGecko)',
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            onPressed: _searchCoin,
                            icon: const Icon(Icons.search),
                          ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (_) => _searchCoin(),
                ),
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = _results[i];
                        return ListTile(
                          dense: true,
                          leading: c.thumb.isEmpty
                              ? const Icon(Symbols.token)
                              : CircleAvatar(backgroundImage: NetworkImage(c.thumb)),
                          title: Text(c.nama),
                          subtitle: Text(c.simbol),
                          trailing: c.marketCapRank == null ? null : Text('#${c.marketCapRank}'),
                          onTap: () {
                            setState(() {
                              _namaC.text = c.nama;
                              _simbolC.text = c.simbol;
                              _searchC.text = '${c.nama} (${c.simbol})';
                              _results = const [];
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _Field(label: 'Nama Coin', controller: _namaC),
                const SizedBox(height: 10),
                _Field(label: 'Symbol', controller: _simbolC),
                const SizedBox(height: 10),
                _Field(label: 'Jumlah', controller: _jumlahC, keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                _Field(
                  label: 'Harga Beli (IDR)',
                  controller: _hargaC,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        child: Text('portofolio_cancel'.tr),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tips: tap item list di portofolio untuk edit, long-press untuk hapus.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _RiwayatPortofolioSheet extends StatefulWidget {
  const _RiwayatPortofolioSheet({required this.api});
  final PortofolioApi api;

  @override
  State<_RiwayatPortofolioSheet> createState() => _RiwayatPortofolioSheetState();
}

class _RiwayatPortofolioSheetState extends State<_RiwayatPortofolioSheet> {
  bool _loading = true;
  List<PortofolioRiwayatItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.api.fetchRiwayat();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _aksiLabel(String aksi) {
    switch (aksi) {
      case 'create':
        return 'portofolio_add'.tr;
      case 'update':
        return 'Ubah';
      case 'delete':
        return 'portofolio_delete'.tr;
      default:
        return aksi;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Text(
                'Riwayat Portofolio',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                        ? const Center(child: Text('Belum ada riwayat transaksi.'))
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final item = _items[i];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0E7FF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Symbols.history, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_aksiLabel(item.aksi)} ${item.namaAset} (${item.simbol})',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.jumlah} @ Rp ${item.hargaBeli.toStringAsFixed(0)}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      item.createdAt == null
                                          ? '-'
                                          : '${item.createdAt!.day}/${item.createdAt!.month} ${item.createdAt!.hour.toString().padLeft(2, '0')}:${item.createdAt!.minute.toString().padLeft(2, '0')}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
