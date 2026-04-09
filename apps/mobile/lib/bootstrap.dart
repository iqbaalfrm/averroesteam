import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'app/app.dart';
import 'app/services/auth_service.dart';
import 'app/services/privy_wallet_service.dart';
import 'app/services/shalat_notification_service.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _ensureWebViewPlatform();
  await GetStorage.init();
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('dotenv load gagal: $error');
  }
  try {
    await AuthService.instance.initialize();
  } catch (error) {
    debugPrint('init auth service gagal: $error');
  }
  try {
    await PrivyWalletService.instance.initialize(
      tokenProvider: () async => AuthService.instance.token,
    );
  } catch (error) {
    debugPrint('init privy wallet service gagal: $error');
  }
  try {
    await ShalatNotificationService.instance.initialize();
  } catch (error) {
    debugPrint('init notifikasi shalat gagal: $error');
  }
  runApp(const AverroesApp());
}

void _ensureWebViewPlatform() {
  if (WebViewPlatform.instance != null) {
    return;
  }

  if (Platform.isAndroid) {
    WebViewPlatform.instance = AndroidWebViewPlatform();
    return;
  }

  if (Platform.isIOS || Platform.isMacOS) {
    WebViewPlatform.instance = WebKitWebViewPlatform();
  }
}
