import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/shell_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
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
      return PopScope(
        canPop: controller.tabIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) controller.selectTab(0);
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(
            index: _index(tabs.length),
            children: [for (final tab in tabs) tab.page],
          ),
          bottomNavigationBar: _BottomTabs(
            tabs: tabs,
            selected: _index(tabs.length),
            onSelected: controller.selectTab,
          ),
        ),
      );
    });
  }

  List<_Tab> _tabs(AuthService auth) => [
    _Tab(icon: Iconsax.home_2, label: 'Home', page: const HomeView()),
    if (auth.can('territories.read'))
      _Tab(
        icon: Iconsax.location,
        label: 'Headquarters',
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

/// The bottom tabs, with every slot the same width. A label that is too long for its slot shrinks to fit
/// instead of wrapping onto a second line, so the bar keeps one row on narrow phones.
class _BottomTabs extends StatelessWidget {
  const _BottomTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<_Tab> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.xs,
          ),
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: _BottomTab(
                    tab: tabs[index],
                    selected: index == selected,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.press,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.m,
                vertical: AppSpace.xs,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? p.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: AppRadius.pill,
              ),
              child: Icon(
                tab.icon,
                size: 22,
                color: selected ? p.primary : p.inkMuted,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tab.label,
                maxLines: 1,
                style: text.labelSmall?.copyWith(
                  color: selected ? p.ink : p.inkMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
