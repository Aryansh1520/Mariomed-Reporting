import 'package:get/get.dart';

/// Which bottom tab is showing.
class ShellController extends GetxController {
  final _tabIndex = 0.obs;

  int get tabIndex => _tabIndex.value;

  void selectTab(int index) => _tabIndex.value = index;
}
