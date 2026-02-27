import 'package:flutter/foundation.dart';

class PortofolioSync {
  PortofolioSync._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void markChanged() {
    revision.value = revision.value + 1;
  }
}
