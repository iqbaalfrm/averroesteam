import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart' as dio;

import '../../app/services/api_dio.dart';
import '../../presentation/common/content_ui.dart';

class HalamanZakat extends StatefulWidget {
  const HalamanZakat({super.key});

  @override
  State<HalamanZakat> createState() => _HalamanZakatState();
}

class _HalamanZakatState extends State<HalamanZakat> {
  static const double _troyOunceToGrams = 31.1034768;

  final TextEditingController _asetController = TextEditingController();
  final TextEditingController _utangController = TextEditingController();

  bool _loading = true;
  bool _isFormattingInput = false;
  double _totalAset = 0;
  double _utangJatuhTempo = 0;
  double _asetBersih = 0;
  double _nishab = 0;
  double _nishabGrams = 85;
  double _hargaEmasPerGram = 0;
  double _nilaiZakat = 0;
  bool _wajib = false;
  String _baznasUrl = 'https://bayarzakat.baznas.go.id/zakat';

  @override
  void initState() {
    super.initState();
    _asetController.addListener(
        () => _handleCurrencyInput(_asetController, isDebt: false));
    _utangController.addListener(
        () => _handleCurrencyInput(_utangController, isDebt: true));
    _load();
  }

  @override
  void dispose() {
    _asetController.dispose();
    _utangController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dio = ApiDio.create(attachAuthToken: false);
      final res = await dio.get<dynamic>('/api/zakat/nishab');
      final raw = res.data;
      if (raw is Map<String, dynamic>) {
        final data = raw['data'];
        if (data is Map) {
          _nishab = ((data['nishab'] as num?)?.toDouble() ?? 0);
          _nishabGrams = ((data['nishab_grams'] as num?)?.toDouble() ?? 85);
          _hargaEmasPerGram =
              ((data['harga_emas_per_gram'] as num?)?.toDouble() ?? 0);
          if (_hargaEmasPerGram <= 0 && _nishab > 0 && _nishabGrams > 0) {
            _hargaEmasPerGram = _nishab / _nishabGrams;
          }
          _baznasUrl =
              (data['baznas_url'] as String?)?.trim().isNotEmpty == true
                  ? (data['baznas_url'] as String).trim()
                  : _baznasUrl;
        }
      }
    } catch (_) {
      // Keep zero values as fallback.
      if (_hargaEmasPerGram <= 0) {
        await _loadLiveGoldPriceFallback();
        if (_nishab <= 0 && _hargaEmasPerGram > 0 && _nishabGrams > 0) {
          _nishab = _hargaEmasPerGram * _nishabGrams;
        }
      }
    } finally {
      _recalculate();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLiveGoldPriceFallback() async {
    try {
      final dio.Dio client = dio.Dio(
        dio.BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 15),
          headers: const <String, dynamic>{
            'Accept': 'application/json',
            'User-Agent': 'Averroes/1.0',
          },
        ),
      );

      final dio.Response<dynamic> goldRes = await client.get<dynamic>(
        'https://api.gold-api.com/price/XAU',
      );
      final dio.Response<dynamic> fxRes = await client.get<dynamic>(
        'https://open.er-api.com/v6/latest/USD',
      );

      final dynamic goldRaw = goldRes.data;
      final dynamic fxRaw = fxRes.data;
      if (goldRaw is! Map || fxRaw is! Map) {
        return;
      }

      final double xauUsdPerOunce =
          ((goldRaw['price'] as num?)?.toDouble() ?? 0);
      final Map<dynamic, dynamic>? rates = fxRaw['rates'] as Map?;
      final double usdIdrRate = ((rates?['IDR'] as num?)?.toDouble() ?? 0);

      if (xauUsdPerOunce <= 0 || usdIdrRate <= 0) {
        return;
      }

      _hargaEmasPerGram = (xauUsdPerOunce * usdIdrRate) / _troyOunceToGrams;
    } catch (_) {
      // Keep current fallback values when direct live fetch fails.
    }
  }

  void _handleCurrencyInput(
    TextEditingController controller, {
    required bool isDebt,
  }) {
    if (_isFormattingInput) return;

    final String digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double value = double.tryParse(digits) ?? 0;
    final String formatted = digits.isEmpty ? '' : _formatNominal(value);

    _isFormattingInput = true;
    if (controller.text != formatted) {
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    if (mounted) {
      setState(() {
        if (isDebt) {
          _utangJatuhTempo = value;
        } else {
          _totalAset = value;
        }
        _recalculate();
      });
    }
    _isFormattingInput = false;
  }

  void _recalculate() {
    _asetBersih = (_totalAset - _utangJatuhTempo).clamp(0, double.infinity);
    _wajib = _nishab > 0 && _asetBersih >= _nishab;
    _nilaiZakat = _wajib ? _asetBersih * 0.025 : 0;
  }

  Future<void> _openBaznas() async {
    final Uri? uri = Uri.tryParse(_baznasUrl);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL pembayaran BAZNAS tidak valid')),
      );
      return;
    }
    final bool launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Gagal membuka halaman pembayaran BAZNAS')),
      );
    }
  }

  Future<void> _showHelpDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            'Cara Pakai Kalkulator Zakat',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _HelpStep(
                number: '1',
                text: 'Isi total harta yang kamu miliki secara manual.',
              ),
              const SizedBox(height: 10),
              const _HelpStep(
                number: '2',
                text:
                    'Isi hutang jatuh tempo yang harus dibayar dalam waktu dekat.',
              ),
              const SizedBox(height: 10),
              const _HelpStep(
                number: '3',
                text:
                    'Aplikasi akan menghitung aset bersih, membandingkannya dengan nisab 85 gram emas, lalu menentukan wajib zakat atau belum.',
              ),
              const SizedBox(height: 10),
              const _HelpStep(
                number: '4',
                text:
                    'Jika sudah wajib, nilai zakat dihitung sebesar 2,5% dari aset bersih.',
              ),
              const SizedBox(height: 14),
              Text(
                'Catatan: harga emas diambil otomatis sebagai acuan nisab. Hasil ini bersifat kalkulasi awal untuk memudahkan estimasi zakat maal.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF064E3B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Mengerti',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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
                backgroundColor: const Color(0xFFF8FAFC).withValues(alpha: 0.8),
                elevation: 0,
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                title: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      _IconCircleButton(
                        icon: Symbols.help_outline,
                        onTap: _showHelpDialog,
                      ),
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
                      _KartuInput(
                        asetController: _asetController,
                        utangController: _utangController,
                        asetBersih: _asetBersih,
                        hargaEmasPerGram: _hargaEmasPerGram,
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
            child: _BottomBayar(
              onTap: _openBaznas,
              enabled: _baznasUrl.isNotEmpty,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNominal(double v) {
    final String raw = v.toStringAsFixed(0);
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      sb.write(raw[i]);
      final int remain = raw.length - i - 1;
      if (remain > 0 && remain % 3 == 0) sb.write('.');
    }
    return sb.toString();
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

class _HelpStep extends StatelessWidget {
  const _HelpStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFECFDF5),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF064E3B),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _KartuInput extends StatelessWidget {
  const _KartuInput({
    required this.asetController,
    required this.utangController,
    required this.asetBersih,
    required this.hargaEmasPerGram,
    required this.nishab,
    required this.wajibZakat,
    required this.loading,
  });

  final TextEditingController asetController;
  final TextEditingController utangController;
  final double asetBersih;
  final double hargaEmasPerGram;
  final double nishab;
  final bool wajibZakat;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final String manualHint = _trOr(
      'zakat_manual_hint',
      'Isi total harta dan hutang jatuh tempo secara manual untuk menghitung zakat maal.',
    );

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
            controller: asetController,
          ),
          const SizedBox(height: 16),
          _InputZakat(
            label: 'zakat_debt'.tr,
            controller: utangController,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              manualHint,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: Color(0xFFE2E8F0), style: BorderStyle.solid),
              ),
            ),
            child: Column(
              children: <Widget>[
                _InfoRow(
                  label: 'Aset Bersih',
                  value: loading ? '...' : _idr(asetBersih),
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'zakat_gold_price'.tr,
                  value: loading ? '...' : '${_idr(hargaEmasPerGram)}/gr',
                  icon: Symbols.info,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'zakat_nisab'.tr,
                  value: loading ? '...' : _idr(nishab),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          Icon(
                            wajibZakat ? Symbols.check_circle : Symbols.info,
                            size: 16,
                            color: wajibZakat
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            wajibZakat
                                ? 'zakat_obligatory'.tr
                                : 'zakat_not_obligatory'.tr,
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
    final String raw = v.toStringAsFixed(0);
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      sb.write(raw[i]);
      final int remain = raw.length - i - 1;
      if (remain > 0 && remain % 3 == 0) sb.write('.');
    }
    return 'Rp ${sb.toString()}';
  }

  String _trOr(String key, String fallback) {
    final String translated = key.tr;
    return translated == key ? fallback : translated;
  }
}

class _InputZakat extends StatelessWidget {
  const _InputZakat({
    required this.label,
    required this.controller,
  });

  final String label;
  final TextEditingController controller;

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFCBD5E1),
                    ),
                    border: InputBorder.none,
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
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
              color: Colors.white.withValues(alpha: 0.1),
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
                  color: Colors.white.withValues(alpha: 0.8),
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
                      color: Colors.white.withValues(alpha: 0.6),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
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
    final String raw = v.toStringAsFixed(0);
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      sb.write(raw[i]);
      final int remain = raw.length - i - 1;
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
  const _BottomBayar({
    required this.onTap,
    required this.enabled,
  });

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: Opacity(
              opacity: enabled ? 1 : 0.6,
              child: AppPrimaryButton(
                onPressed: enabled ? onTap : null,
                icon: Symbols.account_balance_wallet,
                label: 'zakat_pay_now'.tr,
              ),
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
