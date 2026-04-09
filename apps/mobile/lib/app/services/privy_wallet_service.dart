import 'package:privy_flutter/privy_flutter.dart';

import '../config/app_config.dart';
import 'wallet_link_service.dart';

class PrivyWalletService {
  PrivyWalletService._();
  static final PrivyWalletService instance = PrivyWalletService._();

  Privy? _privy;
  bool _initialized = false;
  Future<String?> Function()? _tokenProvider;

  bool get isConfigured =>
      (AppConfig.privyAppId?.isNotEmpty ?? false) &&
      (AppConfig.privyClientId?.isNotEmpty ?? false);

  Future<void> initialize({
    Future<String?> Function()? tokenProvider,
  }) async {
    _tokenProvider = tokenProvider ?? _tokenProvider;

    if (_initialized) {
      return;
    }

    if (!isConfigured) {
      _initialized = true;
      return;
    }

    _privy = Privy.init(
      config: PrivyConfig(
        appId: AppConfig.privyAppId!,
        appClientId: AppConfig.privyClientId!,
        logLevel: PrivyLogLevel.none,
        customAuthConfig: _tokenProvider == null
            ? null
            : LoginWithCustomAuthConfig(
                tokenProvider: _tokenProvider!,
              ),
      ),
    );

    try {
      await _privy!.getAuthState();
    } catch (_) {}

    _initialized = true;
  }

  Future<AuthState> getAuthState() async {
    await initialize();
    final Privy? privy = _privy;
    if (privy == null) {
      return const Unauthenticated();
    }
    return privy.getAuthState();
  }

  Future<PrivyUser?> getUser() async {
    await initialize();
    return _privy?.getUser();
  }

  Future<void> sendEmailCode(String email) async {
    final Privy privy = await _requirePrivy();
    _unwrapVoid(
      await privy.email.sendCode(email.trim()),
      fallbackMessage: 'Gagal mengirim kode verifikasi Privy',
    );
  }

  Future<List<Map<String, dynamic>>> loginWithEmailCodeAndSync({
    required String email,
    required String code,
  }) async {
    final Privy privy = await _requirePrivy();
    final PrivyUser user = _unwrap(
      await privy.email.loginWithCode(
        email: email.trim(),
        code: code.trim(),
      ),
      fallbackMessage: 'Verifikasi Privy gagal',
    );
    return _syncUserWallets(user);
  }

  Future<List<Map<String, dynamic>>> connectWithCurrentSession({
    bool ensureWallet = true,
  }) async {
    final Privy privy = await _requirePrivy();
    final PrivyUser user = _unwrap(
      await privy.customAuth.loginWithCustomAccessToken(),
      fallbackMessage: 'Gagal menghubungkan Privy dengan akun Averroes',
    );

    if (ensureWallet && user.embeddedEthereumWallets.isEmpty) {
      _unwrap(
        await user.createEthereumWallet(),
        fallbackMessage: 'Gagal membuat wallet Privy',
      );
      _unwrapVoid(
        await user.refresh(),
        fallbackMessage: 'Gagal menyegarkan wallet Privy',
      );
    }

    return syncCurrentUserWallets();
  }

  Future<void> connectWithCurrentSessionSilently({
    bool ensureWallet = true,
  }) async {
    try {
      await connectWithCurrentSession(ensureWallet: ensureWallet);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> ensureEmbeddedWalletAndSync() async {
    final PrivyUser user = await _requireAuthenticatedUser();
    if (user.embeddedEthereumWallets.isEmpty) {
      _unwrap(
        await user.createEthereumWallet(),
        fallbackMessage: 'Gagal membuat wallet Privy',
      );
      _unwrapVoid(
        await user.refresh(),
        fallbackMessage: 'Gagal menyegarkan wallet Privy',
      );
    }
    final PrivyUser refreshedUser = await _requireAuthenticatedUser();
    return _syncUserWallets(refreshedUser);
  }

  Future<List<Map<String, dynamic>>> syncCurrentUserWallets() async {
    final PrivyUser user = await _requireAuthenticatedUser();
    return _syncUserWallets(user);
  }

  Future<void> logout({bool silent = false}) async {
    await initialize();
    final Privy? privy = _privy;
    if (privy == null) {
      return;
    }
    try {
      await privy.logout();
    } catch (_) {
      if (!silent) {
        rethrow;
      }
    }
  }

  Future<List<Map<String, dynamic>>> _syncUserWallets(PrivyUser user) async {
    final Map<String, _WalletSyncPayload> uniqueWallets =
        <String, _WalletSyncPayload>{};

    for (final EmbeddedEthereumWallet wallet in user.embeddedEthereumWallets) {
      uniqueWallets[_normalizeAddress(wallet.address)] = _WalletSyncPayload(
        walletAddress: wallet.address,
        walletType: 'embedded',
        walletClient: 'privy',
        chainType: 'evm',
      );
    }

    for (final EmbeddedSolanaWallet wallet in user.embeddedSolanaWallets) {
      uniqueWallets[_normalizeAddress(wallet.address)] = _WalletSyncPayload(
        walletAddress: wallet.address,
        walletType: 'embedded',
        walletClient: 'privy',
        chainType: 'solana',
      );
    }

    for (final LinkedAccounts account in user.linkedAccounts) {
      if (account is ExternalWalletAccount) {
        uniqueWallets[_normalizeAddress(account.address)] = _WalletSyncPayload(
          walletAddress: account.address,
          walletType: 'external',
          walletClient: account.walletClientType ?? 'privy',
          chainType: account.chainType.name,
        );
      }
    }

    if (uniqueWallets.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    bool isPrimary = true;
    for (final _WalletSyncPayload wallet in uniqueWallets.values) {
      await WalletLinkService.instance.linkWallet(
        walletAddress: wallet.walletAddress,
        privyUserId: user.id,
        walletType: wallet.walletType,
        walletClient: wallet.walletClient,
        chainType: wallet.chainType,
        isPrimary: isPrimary,
      );
      isPrimary = false;
    }

    return WalletLinkService.instance.listWallets();
  }

  Future<Privy> _requirePrivy() async {
    await initialize();
    final Privy? privy = _privy;
    if (privy == null) {
      throw Exception(
        'Privy belum dikonfigurasi. Isi PRIVY_APP_ID dan PRIVY_CLIENT_ID terlebih dahulu',
      );
    }
    return privy;
  }

  Future<PrivyUser> _requireAuthenticatedUser() async {
    final AuthState authState = await getAuthState();
    if (authState case Authenticated(user: final PrivyUser user)) {
      return user;
    }
    throw Exception('Sesi Privy belum terhubung');
  }

  T _unwrap<T>(
    Result<T> result, {
    required String fallbackMessage,
  }) {
    switch (result) {
      case Success<T>(value: final T value):
        return value;
      case Failure<T>(error: final PrivyException error):
        throw Exception(error.message.isNotEmpty ? error.message : fallbackMessage);
    }
  }

  void _unwrapVoid(
    Result<void> result, {
    required String fallbackMessage,
  }) {
    switch (result) {
      case Success<void>():
        return;
      case Failure<void>(error: final PrivyException error):
        throw Exception(error.message.isNotEmpty ? error.message : fallbackMessage);
    }
  }

  String _normalizeAddress(String address) => address.trim().toLowerCase();
}

class _WalletSyncPayload {
  const _WalletSyncPayload({
    required this.walletAddress,
    required this.walletType,
    required this.walletClient,
    required this.chainType,
  });

  final String walletAddress;
  final String walletType;
  final String walletClient;
  final String chainType;
}
