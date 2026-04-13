import 'package:averroes_core/averroes_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/config/app_config.dart';
import '../../app/services/privy_wallet_service.dart';
import '../../app/services/wallet_link_service.dart';

class PrivyWalletSheet extends StatefulWidget {
  const PrivyWalletSheet({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<PrivyWalletSheet> createState() => _PrivyWalletSheetState();
}

class _PrivyWalletSheetState extends State<PrivyWalletSheet> {
  late final TextEditingController _emailController;
  final TextEditingController _otpController = TextEditingController();

  bool _loading = true;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _syncingWallet = false;
  bool _otpSent = false;
  bool _isPrivyAuthenticated = false;
  String? _statusMessage;
  List<Map<String, dynamic>> _wallets = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
    _loadState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadState({bool syncWallets = false}) async {
    setState(() => _loading = true);
    try {
      if (AppConfig.isPrivyConfigured) {
        final user = await PrivyWalletService.instance.getUser();
        _isPrivyAuthenticated = user != null;
        if (_isPrivyAuthenticated && syncWallets) {
          await PrivyWalletService.instance.syncCurrentUserWallets();
        }
      } else {
        _isPrivyAuthenticated = false;
      }
      final List<Map<String, dynamic>> wallets =
          await WalletLinkService.instance.listWallets();
      if (!mounted) {
        return;
      }
      setState(() {
        _wallets = wallets;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = _cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendCode() async {
    if (_sendingCode) {
      return;
    }
    final String email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _statusMessage =
            'Email akun belum siap dipakai untuk menghubungkan wallet';
      });
      return;
    }
    setState(() => _sendingCode = true);
    try {
      await PrivyWalletService.instance.sendEmailCode(email);
      if (!mounted) {
        return;
      }
      setState(() {
        _otpSent = true;
        _statusMessage = 'Kode verifikasi sudah dikirim ke email kamu';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = _cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _sendingCode = false);
      }
    }
  }

  Future<void> _connectWithCurrentSession() async {
    if (_syncingWallet) {
      return;
    }
    setState(() => _syncingWallet = true);
    try {
      final List<Map<String, dynamic>> wallets =
          await PrivyWalletService.instance.connectWithCurrentSession(
        ensureWallet: true,
      );
      final user = await PrivyWalletService.instance.getUser();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPrivyAuthenticated = user != null;
        _wallets = wallets;
        _statusMessage = 'Wallet berhasil dihubungkan ke akun ini';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = _cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _syncingWallet = false);
      }
    }
  }

  Future<void> _verifyAndCreateWallet() async {
    if (_verifyingCode) {
      return;
    }
    final String code = _otpController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _statusMessage = 'Masukkan kode verifikasi terlebih dahulu';
      });
      return;
    }
    setState(() => _verifyingCode = true);
    try {
      final List<Map<String, dynamic>> wallets =
          await PrivyWalletService.instance.loginWithEmailCodeAndSync(
        email: _emailController.text.trim(),
        code: code,
      );
      if (!mounted) {
        return;
      }
      final user = await PrivyWalletService.instance.getUser();
      setState(() {
        _isPrivyAuthenticated = user != null;
        _wallets = wallets;
        _otpSent = false;
        _otpController.clear();
        _statusMessage = 'Wallet berhasil dihubungkan dan siap dipakai';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = _cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _verifyingCode = false);
      }
    }
  }

  Future<void> _syncWallets() async {
    if (_syncingWallet) {
      return;
    }
    setState(() => _syncingWallet = true);
    try {
      final List<Map<String, dynamic>> wallets =
          await PrivyWalletService.instance.ensureEmbeddedWalletAndSync();
      if (!mounted) {
        return;
      }
      setState(() {
        _wallets = wallets;
        _statusMessage = wallets.isEmpty
            ? 'Belum ada wallet yang tersedia untuk akun ini'
            : 'Data wallet berhasil diperbarui';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = _cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _syncingWallet = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasWallets = _wallets.isNotEmpty;
    final String subtitle = _isPrivyAuthenticated
        ? 'Wallet akunmu sudah terhubung dan bisa diperbarui kapan saja'
        : 'Hubungkan wallet agar alamat dompetmu tersimpan rapi di profil';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Wallet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              if (!AppConfig.isPrivyConfigured) ...<Widget>[
                _InfoCard(
                  icon: Symbols.error_outline,
                  color: AppColors.warning,
                  title: 'Wallet belum tersedia',
                  message: 'Fitur wallet belum dibuka untuk build ini.',
                ),
              ] else ...<Widget>[
                _InfoCard(
                  icon: _isPrivyAuthenticated
                      ? Symbols.verified_user
                      : Symbols.mark_email_read,
                  color: _isPrivyAuthenticated
                      ? AppColors.emerald
                      : AppColors.emeraldBright,
                  title: _isPrivyAuthenticated
                      ? 'Wallet sudah terhubung'
                      : 'Hubungkan wallet',
                  message: _isPrivyAuthenticated
                      ? 'Sesi wallet aktif untuk akun ini.'
                      : 'Kamu bisa menghubungkan wallet langsung dari akun yang sedang dipakai.',
                ),
              ],
              const SizedBox(height: 14),
              CustomCard(
                hasShadow: true,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Email akun',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Symbols.mail_outline),
                      ),
                    ),
                    if (!_isPrivyAuthenticated) ...<Widget>[
                      const SizedBox(height: 14),
                      CustomButton(
                        text: _syncingWallet
                            ? 'Menghubungkan wallet...'
                            : 'Hubungkan otomatis',
                        onPressed:
                            (_syncingWallet || !AppConfig.isPrivyConfigured)
                                ? null
                                : _connectWithCurrentSession,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Kalau sambungan otomatis belum berhasil, gunakan kode verifikasi email di bawah.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      CustomButton(
                        text: _sendingCode
                            ? 'Mengirim kode...'
                            : 'Kirim kode email',
                        onPressed:
                            (_sendingCode || !AppConfig.isPrivyConfigured)
                                ? null
                                : _sendCode,
                      ),
                    ],
                    if (_otpSent && !_isPrivyAuthenticated) ...<Widget>[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Kode verifikasi',
                          prefixIcon: Icon(Symbols.password),
                        ),
                      ),
                      const SizedBox(height: 14),
                      CustomButton(
                        text: _verifyingCode
                            ? 'Memverifikasi...'
                            : 'Verifikasi dan hubungkan',
                        onPressed:
                            _verifyingCode ? null : _verifyAndCreateWallet,
                      ),
                    ],
                    if (_isPrivyAuthenticated) ...<Widget>[
                      const SizedBox(height: 14),
                      CustomButton(
                        text: _syncingWallet
                            ? 'Memperbarui wallet...'
                            : (hasWallets ? 'Perbarui wallet' : 'Buat wallet'),
                        onPressed: _syncingWallet ? null : _syncWallets,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_statusMessage != null && _statusMessage!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    _statusMessage!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emeraldDark,
                    ),
                  ),
                ),
              Text(
                'Wallet terhubung',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ))
              else if (!hasWallets)
                _InfoCard(
                  icon: Symbols.account_balance_wallet,
                  color: AppColors.muted,
                  title: 'Belum ada wallet',
                  message:
                      'Setelah wallet berhasil dihubungkan, alamatnya akan muncul di sini.',
                )
              else
                Column(
                  children: _wallets
                      .map(
                        (Map<String, dynamic> wallet) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _WalletCard(wallet: wallet),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isValidEmail(String value) =>
      value.contains('@') && value.contains('.');

  String _cleanError(Object error) {
    final String raw = error.toString().replaceFirst('Exception: ', '').trim();
    final String lower = raw.toLowerCase();
    if (lower.contains('network') || lower.contains('timeout')) {
      return 'Koneksi sedang bermasalah. Coba lagi sebentar.';
    }
    if (lower.contains('invalid') && lower.contains('code')) {
      return 'Kode verifikasi belum sesuai.';
    }
    if (lower.contains('privy')) {
      return 'Wallet belum bisa dihubungkan saat ini.';
    }
    if (lower.contains('supabase')) {
      return 'Data wallet belum bisa diperbarui saat ini.';
    }
    return raw;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      hasShadow: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.muted,
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

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet});

  final Map<String, dynamic> wallet;

  @override
  Widget build(BuildContext context) {
    final bool isPrimary = wallet['is_primary'] == true;
    final String address = (wallet['wallet_address'] ?? '').toString();
    final String walletType = (wallet['wallet_type'] ?? 'wallet').toString();
    final String chainType = (wallet['chain_type'] ?? 'evm').toString();
    final String walletClient = (wallet['wallet_client'] ?? 'privy').toString();

    return CustomCard(
      hasShadow: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.emeraldSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Symbols.account_balance_wallet,
              color: AppColors.emerald,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        _shortWallet(address),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate,
                        ),
                      ),
                    ),
                    if (isPrimary) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Utama',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraldDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_labelWalletClient(walletClient)} • ${_labelWalletType(walletType)} • ${chainType.toUpperCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortWallet(String address) {
    if (address.length <= 14) {
      return address;
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _labelWalletClient(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'privy') {
      return 'Averroes Wallet';
    }
    return value;
  }

  String _labelWalletType(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'embedded') {
      return 'Embedded';
    }
    if (normalized == 'wallet') {
      return 'Wallet';
    }
    return value;
  }
}
