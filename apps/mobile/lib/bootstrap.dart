import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';

import 'app/app.dart';
import 'app/services/shalat_notification_service.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('dotenv load gagal: $error');
  }
  try {
    await ShalatNotificationService.instance.initialize();
  } catch (error) {
    debugPrint('init notifikasi shalat gagal: $error');
  }
  runApp(const AverroesApp());
}
