import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:averroes_core/theme/app_theme.dart';

import 'bindings/ikatan_awal.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

class AverroesApp extends StatelessWidget {
  const AverroesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Averroes',
      theme: TemaAverroes.temaUtama,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      locale: const Locale('id', 'ID'),
      fallbackLocale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      initialBinding: IkatanAwal(),
      initialRoute: RuteAplikasi.awal,
      getPages: HalamanAplikasi.halaman,
    );
  }
}
