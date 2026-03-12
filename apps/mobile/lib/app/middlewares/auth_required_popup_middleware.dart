import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../widgets/guest_guard.dart';

class AuthRequiredPopupMiddleware extends GetMiddleware {
  AuthRequiredPopupMiddleware();

  static bool _isPopupShowing = false;

  @override
  RouteSettings? redirect(String? route) {
    final String targetRoute = route ?? '';
    final AuthService auth = AuthService.instance;
    final bool unauthorized = !auth.sudahLogin || auth.adalahTamu;

    if (!fiturTerbatasGuest.contains(targetRoute) || !unauthorized) {
      return null;
    }

    _showPopup();

    final String current = Get.currentRoute;
    if (current.isNotEmpty && !fiturTerbatasGuest.contains(current)) {
      return RouteSettings(name: current);
    }
    return const RouteSettings(name: RuteAplikasi.awal);
  }

  void _showPopup() {
    if (_isPopupShowing) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final BuildContext? context = Get.context;
      if (context == null || _isPopupShowing) {
        return;
      }
      _isPopupShowing = true;
      try {
        await tampilkanDialogDaftar(context);
      } finally {
        _isPopupShowing = false;
      }
    });
  }
}
