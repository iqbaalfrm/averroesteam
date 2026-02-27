import 'package:get_storage/get_storage.dart';

/// Service untuk mengelola otentikasi — menyimpan dan mengambil token JWT.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  final GetStorage _box = GetStorage();

  /// Simpan token JWT setelah login berhasil.
  Future<void> simpanToken(String token) async {
    await _box.write(_tokenKey, token);
  }

  /// Simpan data user setelah login berhasil.
  Future<void> simpanUser(Map<String, dynamic> user) async {
    await _box.write(_userKey, user);
  }

  /// Simpan semua data auth sekaligus (token + user).
  Future<void> simpanAuth(String token, Map<String, dynamic> user) async {
    await _box.write(_tokenKey, token);
    await _box.write(_userKey, user);
  }

  /// Ambil token JWT yang tersimpan.
  String? get token => _box.read<String>(_tokenKey);

  /// Ambil data user yang tersimpan.
  Map<String, dynamic>? get user {
    final dynamic data = _box.read(_userKey);
    if (data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }

  /// Ambil role user: 'user', 'guest', 'admin', atau null.
  String? get role {
    final Map<String, dynamic>? u = user;
    if (u == null) {
      return null;
    }
    return u['Role'] as String? ?? u['role'] as String?;
  }

  /// Ambil nama user.
  String get namaUser {
    final Map<String, dynamic>? u = user;
    if (u == null) {
      return 'Pengguna';
    }
    final String nama =
        (u['Nama'] as String? ?? u['nama'] as String?) ?? '';
    return nama.isNotEmpty ? nama : 'Pengguna';
  }

  /// Cek apakah user sudah login.
  bool get sudahLogin => token != null && token!.isNotEmpty;

  /// Cek apakah user adalah tamu (guest).
  bool get adalahTamu => role == 'guest';

  /// Cek apakah user adalah user terdaftar (bukan guest, bukan null).
  bool get adalahUserTerdaftar =>
      sudahLogin && (role == 'user' || role == 'admin');

  /// Hapus semua data auth (logout).
  Future<void> logout() async {
    await _box.remove(_tokenKey);
    await _box.remove(_userKey);
  }
}
