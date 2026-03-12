import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:averroes_core/theme/app_theme.dart';

import 'localization/app_locale_service.dart';
import 'localization/app_translations.dart';
import 'bindings/ikatan_awal.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'services/auth_service.dart';

class AverroesApp extends StatelessWidget {
  const AverroesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeService = Get.isRegistered<AppLocaleService>()
        ? Get.find<AppLocaleService>()
        : Get.put(AppLocaleService(), permanent: true);

    return GetBuilder<AppLocaleService>(
      init: localeService,
      builder: (service) => GetMaterialApp(
        title: 'app_name'.tr,
        theme: TemaAverroes.temaUtama,
        translations: AppTranslations(),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        locale: service.locale,
        fallbackLocale: AppLocaleService.localeId,
        supportedLocales: AppLocaleService.supportedLocales,
        initialBinding: IkatanAwal(),
        initialRoute: AuthService.instance.sudahLogin
            ? RuteAplikasi.beranda
            : RuteAplikasi.login,
        getPages: HalamanAplikasi.halaman,
      ),
    );
  }
}
