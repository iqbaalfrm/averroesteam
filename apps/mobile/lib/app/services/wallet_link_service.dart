import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'api_dio.dart';
import 'supabase_native_service.dart';

class WalletLinkService {
  WalletLinkService._();
  static final WalletLinkService instance = WalletLinkService._();

  Dio _dio() => ApiDio.create();

  Future<List<Map<String, dynamic>>> listWallets() async {
    if (AppConfig.isSupabaseNativeEnabled) {
      final String profileId = await SupabaseNativeService.ensureProfileId();
      final List<dynamic> rows = await Supabase.instance.client
          .from('user_wallets')
          .select(
            'id,user_id,supabase_user_id,privy_user_id,wallet_address,wallet_type,wallet_client,chain_type,is_primary,created_at,updated_at',
          )
          .eq('user_id', profileId)
          .order('is_primary', ascending: false)
          .order('created_at', ascending: false);
      return rows
          .whereType<Map>()
          .map((Map row) => row.cast<String, dynamic>())
          .toList();
    }

    final Response<dynamic> response =
        await _dio().get<dynamic>('/api/auth/wallets');
    final dynamic data = response.data;
    final dynamic payload = data is Map<String, dynamic> ? data['data'] : null;
    if (payload is! List) {
      return const <Map<String, dynamic>>[];
    }
    return payload
        .whereType<Map>()
        .map((Map item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> linkWallet({
    required String walletAddress,
    required String privyUserId,
    String walletType = 'embedded',
    String walletClient = 'privy',
    String chainType = 'evm',
    bool isPrimary = true,
  }) async {
    final String normalizedWalletAddress = walletAddress.trim().toLowerCase();
    final String normalizedPrivyUserId = privyUserId.trim();

    if (AppConfig.isSupabaseNativeEnabled) {
      final Map<String, dynamic> profile =
          await SupabaseNativeService.ensureProfile();
      final String profileId = (profile['id'] ?? '').toString();
      final String supabaseUserId =
          (profile['auth_user_id'] ?? Supabase.instance.client.auth.currentUser?.id ?? '')
              .toString();

      final Map<String, dynamic> payload = <String, dynamic>{
        'user_id': profileId,
        'supabase_user_id': supabaseUserId.isEmpty ? null : supabaseUserId,
        'privy_user_id':
            normalizedPrivyUserId.isEmpty ? null : normalizedPrivyUserId,
        'wallet_address': normalizedWalletAddress,
        'wallet_type': walletType,
        'wallet_client': walletClient,
        'chain_type': chainType,
        'is_primary': isPrimary,
      };

      if (isPrimary) {
        await Supabase.instance.client
            .from('user_wallets')
            .update(<String, dynamic>{'is_primary': false}).eq('user_id', profileId);
      }

      final List<dynamic> existing = await Supabase.instance.client
          .from('user_wallets')
          .select('id')
          .eq('user_id', profileId)
          .eq('wallet_address', normalizedWalletAddress)
          .limit(1);

      dynamic raw;
      if (existing.isNotEmpty && existing.first is Map) {
        raw = await Supabase.instance.client
            .from('user_wallets')
            .update(payload)
            .eq('id', (existing.first as Map)['id'])
            .select()
            .single();
      } else {
        raw = await Supabase.instance.client
            .from('user_wallets')
            .insert(payload)
            .select()
            .single();
      }

      if (isPrimary) {
        await Supabase.instance.client
            .from('profiles')
            .update(<String, dynamic>{
              'privy_user_id': privyUserId.trim().isEmpty ? null : privyUserId.trim(),
              'primary_wallet_address': normalizedWalletAddress,
            }).eq('id', profileId);
      }

      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is Map) {
        return raw.cast<String, dynamic>();
      }
      throw Exception('Respons wallet Supabase tidak valid');
    }

    final Response<dynamic> response = await _dio().post<dynamic>(
      '/api/auth/wallets/link',
      data: <String, dynamic>{
        'wallet_address': normalizedWalletAddress,
        'privy_user_id': normalizedPrivyUserId,
        'wallet_type': walletType,
        'wallet_client': walletClient,
        'chain_type': chainType,
        'is_primary': isPrimary,
      },
    );
    final dynamic data = response.data;
    final dynamic payload = data is Map<String, dynamic> ? data['data'] : null;
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return payload.cast<String, dynamic>();
    }
    throw Exception('Respons wallet tidak valid');
  }
}
