import 'package:flutter/material.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/team_user.dart';
import '../../models/territory.dart';
import '../../services/app_exception.dart';

/// Picks the zones and subzones a person is assigned to. Each one is ticked on its own.
class UserTerritoriesSheet extends StatefulWidget {
  const UserTerritoriesSheet({
    super.key,
    required this.controller,
    required this.user,
  });

  final AdminController controller;
  final TeamUser user;

  @override
  State<UserTerritoriesSheet> createState() => _UserTerritoriesSheetState();
}

class _UserTerritoriesSheetState extends State<UserTerritoriesSheet> {
  final _selected = <int>{};
  List<Territory> _options = const [];
  bool _loading = true;
  bool _saving = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await widget.controller.loadAssignment(widget.user.id);
      if (!mounted) return;
      setState(() {
        _options = loaded.options;
        _selected.addAll(loaded.assigned);
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final problem = await widget.controller.saveAssignment(
      widget.user,
      _selected.toList()..sort(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
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
    final zones = _options.where((t) => t.kind == TerritoryKind.zone).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Zones and subzones',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              widget.user.fullName,
              style: text.bodySmall?.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: AppSpace.m),
            Flexible(child: _body(zones, p, text)),
            if (_problem != null) ...[
              const SizedBox(height: AppSpace.m),
              Text(_problem!, style: text.bodyMedium?.copyWith(color: p.alert)),
            ],
            const SizedBox(height: AppSpace.l),
            FilledButton(
              onPressed: _loading || _saving || _options.isEmpty ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(List<Territory> zones, AppPalette p, TextTheme text) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (zones.isEmpty) {
      return Text(
        'No zones yet. Create them on the Territories screen first.',
        style: text.bodyMedium?.copyWith(color: p.inkMuted),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final zone in zones) ...[
            _tile(zone, indent: false),
            for (final subzone in _subzonesOf(zone))
              _tile(subzone, indent: true),
          ],
        ],
      ),
    );
  }

  List<Territory> _subzonesOf(Territory zone) =>
      _options
          .where((t) => t.kind == TerritoryKind.subzone && t.parentId == zone.id)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Widget _tile(Territory territory, {required bool indent}) {
    return CheckboxListTile(
      value: _selected.contains(territory.id),
      contentPadding: EdgeInsets.only(left: indent ? AppSpace.xl : 0),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(territory.name),
      onChanged: _saving
          ? null
          : (checked) => setState(() {
              if (checked == true) {
                _selected.add(territory.id);
              } else {
                _selected.remove(territory.id);
              }
            }),
    );
  }
}
