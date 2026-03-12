import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/routes/app_routes.dart';
import '../../app/widgets/guest_guard.dart';
import '../edukasi/edukasi_page.dart';
import '../home/beranda_page.dart';
import '../profile/profile_page.dart';
import '../diskusi/diskusi_page.dart';
import '../reels/reels_page.dart';
import 'shell_controller.dart';

class HalamanShell extends StatelessWidget {
  const HalamanShell({super.key});

  @override
  Widget build(BuildContext context) {
    final ShellController controller = Get.put(ShellController());

    return Obx(
      () => Scaffold(
        body: IndexedStack(
          index: controller.tabIndex.value,
          children: const <Widget>[
            HalamanBeranda(),
            HalamanEdukasi(),
            HalamanReels(),
            HalamanDiskusi(),
            HalamanProfil(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 70,
          selectedIndex: controller.tabIndex.value,
          onDestinationSelected: (int index) {
            if (index == 1 && cekAksesGuest(context, RuteAplikasi.edukasi)) {
              return;
            }
            if (index == 3 && cekAksesGuest(context, RuteAplikasi.diskusi)) {
              return;
            }
            controller.pindahTab(index);
          },
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: const Icon(Symbols.home_rounded),
              label: 'tab_home'.tr,
            ),
            NavigationDestination(
              icon: const Icon(Symbols.menu_book_rounded),
              label: 'tab_education'.tr,
            ),
            NavigationDestination(
              icon: const Icon(Symbols.play_circle_rounded),
              label: 'tab_reels'.tr,
            ),
            NavigationDestination(
              icon: const Icon(Symbols.forum_rounded),
              label: 'tab_discussion'.tr,
            ),
            NavigationDestination(
              icon: const Icon(Symbols.person_rounded),
              label: 'tab_profile'.tr,
            ),
          ],
        ),
      ),
    );
  }
}
