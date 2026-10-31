import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../app/routes/app_routes.dart';
import '../../controllers/admin_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_list.dart';
import '../../core/widgets/pill_tabs.dart';
import '../../models/team_user.dart';
import '../../services/auth_service.dart';
import 'performance_view.dart';

enum _AdminSection { team, roles, performance }

/// The admin tab. Its sections follow the caller's permissions: Team needs users.read, Roles needs roles.manage.
/// A section the caller may not see is not offered at all.
class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  _AdminSection? _section;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final sections = [
      if (auth.can('users.read')) _AdminSection.team,
      if (auth.can('roles.manage')) _AdminSection.roles,
      if (auth.can('users.read') && auth.can('visits.read'))
        _AdminSection.performance,
    ];
    final current = _section != null && sections.contains(_section)
        ? _section!
        : sections.first;
    final controller = Get.find<AdminController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Admin')),
      body: Obx(() {
        if (controller.isLoading.value) return const LoadingList(count: 3);
        return Column(
          children: [
            if (sections.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.l,
                  AppSpace.s,
                  AppSpace.l,
                  AppSpace.m,
                ),
                child: PillTabs<_AdminSection>(
                  items: [
                    if (sections.contains(_AdminSection.team))
                      (_AdminSection.team, 'Team'),
                    if (sections.contains(_AdminSection.roles))
                      (_AdminSection.roles, 'Roles'),
                    if (sections.contains(_AdminSection.performance))
                      (_AdminSection.performance, 'Performance'),
                  ],
                  selected: current,
                  onSelected: (value) => setState(() => _section = value),
                ),
              ),
            Expanded(
              child: switch (current) {
                _AdminSection.team => const _TeamList(),
                _AdminSection.roles => const _RoleList(),
                _AdminSection.performance => const PerformanceView(),
              },
            ),
          ],
        );
      }),
    );
  }
}

/// The team: everyone in the company, with an activation switch for those who may change it.
class _TeamList extends GetView<AdminController> {
  const _TeamList();

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final canManage = auth.can('users.manage');
    final me = auth.currentUser?.id;

    return Obx(() {
      final users = controller.users;
      return Column(
        children: [
          if (canManage && controller.roles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.l,
                0,
                AppSpace.l,
                AppSpace.m,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: controller.isBusy.value
                      ? null
                      : () => _addPerson(context),
                  icon: const Icon(Iconsax.user_add, size: 18),
                  label: const Text('Add person'),
                ),
              ),
            ),
          Expanded(
            child: users.isEmpty
                ? const EmptyState(
                    icon: Iconsax.profile_2user,
                    title: 'No one here yet',
                    message: 'People you add appear here.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.l,
                      0,
                      AppSpace.l,
                      AppSpace.xxl,
                    ),
                    itemCount: users.length,
                    itemBuilder: (context, index) => _UserRow(
                      user: users[index],
                      canManage: canManage && users[index].id != me,
                      p: p,
                      text: text,
                    ),
                  ),
          ),
        ],
      );
    });
  }

  Future<void> _addPerson(BuildContext context) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddPersonSheet(controller: controller),
    );
    if (added == true && context.mounted) {
      await AppDialogs.success(
        'Person added',
        'They can sign in with the details you set.',
      );
    }
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.canManage,
    required this.p,
    required this.text,
  });

  final TeamUser user;
  final bool canManage;
  final AppPalette p;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.l,
          AppSpace.m,
          AppSpace.s,
          AppSpace.m,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.lg,
          boxShadow: AppEffects.card(p),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: user.isActive ? p.ink : p.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    '${user.roleName}  ·  ${user.email}',
                    style: text.bodySmall?.copyWith(color: p.inkMuted),
                  ),
                ],
              ),
            ),
            if (canManage)
              Obx(
                () => Switch(
                  value: user.isActive,
                  onChanged: controller.isBusy.value
                      ? null
                      : (value) async {
                          final problem = await controller.setActive(
                            user,
                            isActive: value,
                          );
                          if (problem != null) {
                            await AppDialogs.error(
                              'Could not change access',
                              problem,
                            );
                          }
                        },
                ),
              )
            else
              Text(
                user.isActive ? 'Active' : 'Inactive',
                style: text.labelMedium?.copyWith(color: p.inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}

/// The roles: each one a name and the permissions it holds. A locked role is shown but cannot be opened.
class _RoleList extends GetView<AdminController> {
  const _RoleList();

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final canEdit = auth.can('roles.manage');

    return Obx(() {
      final roles = controller.roles;
      return Column(
        children: [
          if (canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.l,
                0,
                AppSpace.l,
                AppSpace.m,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Get.toNamed(AppRoutes.roleEditor),
                  icon: const Icon(Iconsax.add, size: 18),
                  label: const Text('New role'),
                ),
              ),
            ),
          Expanded(
            child: roles.isEmpty
                ? const EmptyState(
                    icon: Iconsax.shield_tick,
                    title: 'No roles yet',
                    message: 'Roles you create appear here.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.l,
                      0,
                      AppSpace.l,
                      AppSpace.xxl,
                    ),
                    itemCount: roles.length,
                    itemBuilder: (context, index) {
                      final role = roles[index];
                      final tappable = canEdit && !role.isLocked;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.lg,
                            boxShadow: AppEffects.card(p),
                          ),
                          child: Material(
                            color: p.surface,
                            borderRadius: AppRadius.lg,
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              onTap: tappable
                                  ? () => Get.toNamed(
                                      AppRoutes.roleEditor,
                                      arguments: role,
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.l,
                              ),
                              title: Text(
                                role.name,
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                role.isLocked
                                    ? 'Every permission, always'
                                    : '${role.grants.length} permissions',
                                style: text.bodySmall?.copyWith(
                                  color: p.inkMuted,
                                ),
                              ),
                              trailing: role.isLocked
                                  ? Text(
                                      'Locked',
                                      style: text.labelMedium?.copyWith(
                                        color: p.inkMuted,
                                      ),
                                    )
                                  : (tappable
                                        ? const Icon(
                                            Iconsax.arrow_right_3,
                                            size: 16,
                                          )
                                        : null),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

/// A bottom sheet to add a person. The role is picked from the roles the caller can see.
class _AddPersonSheet extends StatefulWidget {
  const _AddPersonSheet({required this.controller});

  final AdminController controller;

  @override
  State<_AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<_AddPersonSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  String? _roleCode;
  String? _problem;

  @override
  void dispose() {
    for (final field in [_name, _email, _mobile, _password]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final roleCode = _roleCode;
    if (roleCode == null) {
      setState(() => _problem = 'Choose a role for this person.');
      return;
    }
    final problem = await widget.controller.createUser(
      fullName: _name.text.trim(),
      email: _email.text.trim(),
      mobile: _mobile.text.trim(),
      password: _password.text,
      roleCode: roleCode,
    );
    if (!mounted) return;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final roles = widget.controller.roles;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.l,
          0,
          AppSpace.l,
          MediaQuery.viewInsetsOf(context).bottom + AppSpace.l,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add person',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpace.l),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: AppSpace.m),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: AppSpace.m),
              TextField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile'),
              ),
              const SizedBox(height: AppSpace.m),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Starting password',
                ),
              ),
              const SizedBox(height: AppSpace.l),
              Text(
                'Role',
                style: text.labelLarge?.copyWith(
                  color: p.inkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Wrap(
                spacing: AppSpace.s,
                runSpacing: AppSpace.s,
                children: [
                  for (final role in roles)
                    ChoiceChip(
                      label: Text(role.name),
                      selected: _roleCode == role.code,
                      onSelected: (_) => setState(() => _roleCode = role.code),
                    ),
                ],
              ),
              if (_problem != null) ...[
                const SizedBox(height: AppSpace.m),
                Text(
                  _problem!,
                  style: text.bodyMedium?.copyWith(color: p.alert),
                ),
              ],
              const SizedBox(height: AppSpace.l),
              FilledButton(
                onPressed: widget.controller.isBusy.value ? null : _save,
                child: const Text('Add person'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
