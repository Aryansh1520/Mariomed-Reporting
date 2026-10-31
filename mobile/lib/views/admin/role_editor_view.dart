import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../models/role.dart';

/// Creates a role, or edits one. Each permission is a switch; a scoped one also takes a scope: all, self or assigned.
/// The server adds anything a permission needs and refuses a role that grants more than the caller holds.
class RoleEditorView extends StatefulWidget {
  const RoleEditorView({super.key});

  @override
  State<RoleEditorView> createState() => _RoleEditorViewState();
}

class _RoleEditorViewState extends State<RoleEditorView> {
  late final Role? _role = Get.arguments as Role?;
  late final AdminController _admin = Get.find<AdminController>();
  late final TextEditingController _name = TextEditingController(
    text: _role?.name ?? '',
  );
  late final Map<String, String?> _grants = {
    for (final grant in _role?.grants ?? const <RoleGrant>[])
      grant.code: grant.scope,
  };
  String? _problem;

  static const _scopes = {'all': 'All', 'self': 'Self', 'assigned': 'Assigned'};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _holds(String code) => _grants.containsKey(code);

  PermissionDef? _def(String code) {
    for (final def in _admin.permissions) {
      if (def.code == code) return def;
    }
    return null;
  }

  /// Switching a permission on also switches on what it needs, at the same scope.
  void _enable(PermissionDef def, {String? scope}) {
    _grants[def.code] = def.scoped
        ? (scope ?? _grants[def.code] ?? 'self')
        : null;
    final needed = def.requires == null ? null : _def(def.requires!);
    if (needed != null && !_holds(needed.code))
      _enable(needed, scope: _grants[def.code]);
  }

  /// Switching a permission off also switches off everything that needs it.
  void _disable(PermissionDef def) {
    _grants.remove(def.code);
    for (final other in _admin.permissions) {
      if (other.requires == def.code && _holds(other.code)) _disable(other);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _problem = 'Give the role a name.');
      return;
    }
    final problem = await _admin.saveRole(
      role: _role,
      name: name,
      grants: [
        for (final entry in _grants.entries)
          RoleGrant(code: entry.key, scope: entry.value),
      ],
    );
    if (!mounted) return;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Get.back<bool>(result: true);
  }

  Future<void> _delete() async {
    final role = _role;
    if (role == null) return;
    final confirmed = await AppDialogs.confirm(
      title: 'Delete ${role.name}?',
      message: 'A role with people in it cannot be deleted. Move them to another role first.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    final problem = await _admin.deleteRole(role);
    if (!mounted) return;
    if (problem != null) {
      await AppDialogs.error('Could not delete', problem);
      return;
    }
    Get.back<bool>(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final modules = <String, List<PermissionDef>>{};
    for (final def in _admin.permissions) {
      modules.putIfAbsent(def.module, () => []).add(def);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(_role == null ? 'New role' : _role.name)),
      body: Obx(() {
        final busy = _admin.isBusy.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.l,
            AppSpace.s,
            AppSpace.l,
            AppSpace.xxl,
          ),
          children: [
            TextField(
              controller: _name,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Role name'),
            ),
            const SizedBox(height: AppSpace.xl),
            for (final entry in modules.entries) ...[
              Text(
                entry.key,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpace.s),
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: AppRadius.lg,
                  boxShadow: AppEffects.card(p),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < entry.value.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: p.border),
                      _PermissionRow(
                        def: entry.value[i],
                        held: _holds(entry.value[i].code),
                        scope: _grants[entry.value[i].code],
                        scopes: _scopes,
                        onToggle: busy
                            ? null
                            : (on) => setState(
                                () => on
                                    ? _enable(entry.value[i])
                                    : _disable(entry.value[i]),
                              ),
                        onScope: busy
                            ? null
                            : (scope) => setState(
                                () => _grants[entry.value[i].code] = scope,
                              ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.l),
            ],
            if (_problem != null) ...[
              Text(_problem!, style: text.bodyMedium?.copyWith(color: p.alert)),
              const SizedBox(height: AppSpace.m),
            ],
            FilledButton(
              onPressed: busy ? null : _save,
              child: const Text('Save role'),
            ),
            if (_role != null) ...[
              const SizedBox(height: AppSpace.s),
              TextButton(
                onPressed: busy ? null : _delete,
                child: Text('Delete role', style: TextStyle(color: p.alert)),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.def,
    required this.held,
    required this.scope,
    required this.scopes,
    required this.onToggle,
    required this.onScope,
  });

  final PermissionDef def;
  final bool held;
  final String? scope;
  final Map<String, String> scopes;
  final ValueChanged<bool>? onToggle;
  final ValueChanged<String>? onScope;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.s,
        AppSpace.s,
        AppSpace.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  def.description,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Switch(value: held, onChanged: onToggle),
            ],
          ),
          if (held && def.scoped)
            Wrap(
              spacing: AppSpace.s,
              children: [
                for (final entry in scopes.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: scope == entry.key,
                    onSelected: onScope == null
                        ? null
                        : (_) => onScope!(entry.key),
                  ),
              ],
            ),
          Text(def.code, style: text.labelSmall?.copyWith(color: p.inkMuted)),
        ],
      ),
    );
  }
}
