import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_dio.dart';
import '../../app/services/auth_service.dart';

class HalamanZakat extends StatefulWidget {
  const HalamanZakat({super.key});

  @override
  State<HalamanZakat> createState() => _HalamanZakatState();
}

class _HalamanZakatState extends State<HalamanZakat> {
  bool _loading = true;
  double _totalAset = 0;
  double _nishab = 0;
  double _nilaiZakat = 0;
  bool _wajib = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AuthService.instance.sudahLogin) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    try {
      final dio = ApiDio.create();
      final res = await dio.get<dynamic>('${AppConfig.apiBaseUrl}/api/zakat/hitung');
      final raw = res.data;
      if (raw is Map<String, dynamic>) {
        final data = raw['data'];
        if (data is Map) {
          _totalAset = ((data['total_aset'] as num?)?.toDouble() ?? 0);
          _nishab = ((data['nishab'] as num?)?.toDouble() ?? 0);
          _nilaiZakat = ((data['nilai_zakat'] as num?)?.toDouble() ?? 0);
          _wajib = (data['wajib_zakat'] as bool?) ?? false;
        }
      }
    } catch (_) {
      // Keep zero values as fallback.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: <Widget>[
          CustomScrollView(
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
                            'zakat_title'.tr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const _IconCircleButton(icon: Symbols.help_outline),
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
                      _TabZakat(),
                      const SizedBox(height: 16),
                      _KartuInput(
                        totalAset: _totalAset,
                        nishab: _nishab,
                        wajibZakat: _wajib,
                        loading: _loading,
                      ),
                      const SizedBox(height: 16),
                      _KartuTotalZakat(
                        nilaiZakat: _nilaiZakat,
                        loading: _loading,
                      ),
                      const SizedBox(height: 16),
                      _KartuKetentuan(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBayar(),
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

class _TabZakat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<String> tabs = <String>['zakat_maal'.tr, 'zakat_trade'.tr, 'zakat_crypto'.tr];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs
            .asMap()
            .entries
            .map(
              (MapEntry<int, String> item) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: item.key == 0 ? const Color(0xFF064E3B) : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: item.key == 0
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x33064E3B),
                              blurRadius: 10,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 6,
                              offset: Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Text(
                    item.value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: item.key == 0 ? Colors.white : const Color(0xFF64748B),
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

class _KartuInput extends StatelessWidget {
  const _KartuInput({
    required this.totalAset,
    required this.nishab,
    required this.wajibZakat,
    required this.loading,
  });

  final double totalAset;
  final double nishab;
  final bool wajibZakat;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: <Widget>[
          _InputZakat(
            label: 'zakat_total_assets'.tr,
            placeholder: loading ? '...' : _nominal(totalAset),
          ),
          const SizedBox(height: 16),
          _InputZakat(
            label: 'zakat_debt'.tr,
            placeholder: '0',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0), style: BorderStyle.solid),
              ),
            ),
            child: Column(
              children: <Widget>[
                _InfoRow(
                  label: 'zakat_gold_price'.tr,
                  value: 'Rp 1.340.000/gr',
                  icon: Symbols.info,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'zakat_nisab'.tr,
                  value: loading ? '...' : _idr(nishab),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD1FAE5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'zakat_status'.tr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF064E3B),
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Symbols.check_circle,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            wajibZakat ? 'zakat_obligatory'.tr : 'zakat_not_obligatory'.tr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF064E3B),
                            ),
                          ),
                        ],
                      ),
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

  String _idr(double v) {
    return 'Rp ${_nominal(v)}';
  }

  String _nominal(double v) {
    final raw = v.toStringAsFixed(0);
    final sb = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      sb.write(raw[i]);
      final remain = raw.length - i - 1;
      if (remain > 0 && remain % 3 == 0) sb.write('.');
    }
    return sb.toString();
  }
}

class _InputZakat extends StatelessWidget {
  const _InputZakat({required this.label, required this.placeholder});

  final String label;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Text(
                'Rp',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  placeholder,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
            if (icon != null) ...<Widget>[
              const SizedBox(width: 6),
              Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
            ],
          ],
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _KartuTotalZakat extends StatelessWidget {
  const _KartuTotalZakat({required this.nilaiZakat, required this.loading});
  final double nilaiZakat;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33064E3B),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Symbols.payments,
              size: 120,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'zakat_total_paid'.tr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'Rp',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    loading ? '...' : _formatNominal(nilaiZakat),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Symbols.verified_user,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'zakat_baznas_info'.tr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNominal(double v) {
    final raw = v.toStringAsFixed(0);
    final sb = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      sb.write(raw[i]);
      final remain = raw.length - i - 1;
      if (remain > 0 && remain % 3 == 0) sb.write('.');
    }
    return sb.toString();
  }
}

class _KartuKetentuan extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Symbols.menu_book,
              color: Color(0xFF064E3B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'zakat_rules_title'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'zakat_rules_desc'.tr,
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
    );
  }
}

class _BottomBayar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x3310B981),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Symbols.account_balance_wallet,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'zakat_pay_now'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Symbols.lock,
                size: 12,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                'zakat_secure_tx'.tr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
