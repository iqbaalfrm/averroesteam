import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:averroes_core/averroes_core.dart';

import '../chatbot/chatbot_page.dart';
import '../edukasi/edukasi_page.dart';
import '../home/beranda_page.dart';
import '../profile/profile_page.dart';
import '../diskusi/diskusi_page.dart';
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
            HalamanChatbot(),
            HalamanDiskusi(),
            HalamanProfil(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 70,
          selectedIndex: controller.tabIndex.value,
          onDestinationSelected: controller.pindahTab,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Symbols.home_rounded),
              selectedIcon: Icon(Symbols.home_rounded, color: AppColors.emerald),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Symbols.menu_book_rounded),
              selectedIcon: Icon(Symbols.menu_book_rounded, color: AppColors.emerald),
              label: 'Edukasi',
            ),
            NavigationDestination(
              icon: Icon(Symbols.smart_toy_rounded),
              selectedIcon: Icon(Symbols.smart_toy_rounded, color: AppColors.emerald),
              label: 'Chatbot',
            ),
            NavigationDestination(
              icon: Icon(Symbols.forum_rounded),
              selectedIcon: Icon(Symbols.forum_rounded, color: AppColors.emerald),
              label: 'Diskusi',
            ),
            NavigationDestination(
              icon: Icon(Symbols.person_rounded),
              selectedIcon: Icon(Symbols.person_rounded, color: AppColors.emerald),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
