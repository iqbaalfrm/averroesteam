import 'package:get/get.dart';

class ShellController extends GetxController {
  final RxInt tabIndex = 0.obs;

  void pindahTab(int index) {
    tabIndex.value = index;
  }
}
