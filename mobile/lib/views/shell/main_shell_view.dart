import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/shell_controller.dart';
import '../../services/auth_service.dart';
import '../admin/admin_view.dart';
import '../home/home_view.dart';
import '../profile/profile_view.dart';
import '../tasks/tasks_view.dart';
import '../territories/territories_view.dart';

/// The bottom tabs. Which ones appear follows the caller's permissions, never their role name:
/// Zones needs territory access, Tasks needs task access plus visit or plan access, Admin needs team or role access.
class MainShellView extends GetView<ShellController> {
  const MainShellView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    // Rebuilds whenever the permissions reload, so a changed role changes the tabs without a sign-in.
    return Obx(() {
      auth.permissionsRevision.value;
      final tabs = _tabs(auth);
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _index(tabs.length),
          children: [for (final tab in tabs) tab.page],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index(tabs.length),
          onDestinationSelected: controller.selectTab,
          destinations: [
            for (final tab in tabs)
              NavigationDestination(icon: Icon(tab.icon), label: tab.label),
          ],
        ),
      );
    });
  }

  List<_Tab> _tabs(AuthService auth) => [
    _Tab(icon: Iconsax.home_2, label: 'Home', page: const HomeView()),
    if (auth.can('territories.read'))
      _Tab(
        icon: Iconsax.location,
        label: 'Zones',
        page: const TerritoriesView(),
      ),
    if (_showsTasks(auth))
      _Tab(icon: Iconsax.task_square, label: 'Tasks', page: const TasksView()),
    if (auth.can('users.read') ||
        auth.can('roles.manage') ||
        auth.can('admin.dashboard'))
      _Tab(icon: Iconsax.setting_2, label: 'Admin', page: const AdminView()),
    _Tab(icon: Iconsax.user, label: 'Profile', page: const ProfileView()),
  ];

  /// The selected tab, kept within the tabs this user has.
  int _index(int tabCount) => controller.tabIndex.clamp(0, tabCount - 1);

  bool _showsTasks(AuthService auth) =>
      auth.can('tasks.read') &&
      (auth.can('visits.read') || auth.can('plans.read'));
}

class _Tab {
  const _Tab({required this.icon, required this.label, required this.page});

  final IconData icon;
  final String label;
  final Widget page;
}
