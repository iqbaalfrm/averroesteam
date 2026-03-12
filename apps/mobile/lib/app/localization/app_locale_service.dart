import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AppLocaleService extends GetxController {
  AppLocaleService() : _locale = _loadInitialLocale();

  static const String _storageKey = 'app_locale';

  static const Locale localeId = Locale('id', 'ID');
  static const Locale localeEn = Locale('en', 'US');
  static const Locale localeAr = Locale('ar');

  static const List<Locale> supportedLocales = <Locale>[
    localeId,
    localeEn,
    localeAr,
  ];

  final GetStorage _box = GetStorage();
  Locale _locale;

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  String get currentLanguageLabel {
    switch (_locale.languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      default:
        return 'Indonesia';
    }
  }

  Future<void> changeLocale(Locale locale) async {
    if (_locale == locale) {
      return;
    }

    _locale = locale;
    await _box.write(_storageKey, _localeTag(locale));
    update();
    await Get.updateLocale(locale);
  }

  static Locale _loadInitialLocale() {
    final String? raw = GetStorage().read<String>(_storageKey);
    return _fromTag(raw);
  }

  static Locale _fromTag(String? tag) {
    switch (tag) {
      case 'en_US':
      case 'en':
        return localeEn;
      case 'ar':
      case 'ar_SA':
        return localeAr;
      case 'id':
      case 'id_ID':
      default:
        return localeId;
    }
  }

  static String _localeTag(Locale locale) {
    final countryCode = locale.countryCode;
    if (countryCode == null || countryCode.isEmpty) {
      return locale.languageCode;
    }
    return '${locale.languageCode}_$countryCode';
  }
}
