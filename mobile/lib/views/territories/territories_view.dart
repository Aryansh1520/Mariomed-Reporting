import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../app/routes/app_routes.dart';
import '../../controllers/territories_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_list.dart';
// import '../../core/widgets/territory_map.dart';  // map is commented out
import '../../models/territory.dart';
import '../../services/auth_service.dart';

/// While zones are being browsed the map is a strip at the top and the zone list takes the rest.
/// Drawing or reshaping hands the map the full height.
// const _compactMapHeight = 260.0;

class TerritoriesView extends GetView<TerritoriesController> {
  const TerritoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    final canManage = Get.find<AuthService>().can('territories.manage');
    final size = AppLayout.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Zones'),
        actions: [
          if (canManage)
            _HeaderActions(onNewSubzone: () => _pickZoneForSubzone(context)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(size),
          ),
          child: Obx(() => _body(context, canManage, AppLayout.gutter(size))),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, bool canManage, double gutter) {
    if (controller.isLoading) return const LoadingList(count: 2);
    final error = controller.loadError;
    if (error != null) {
      return EmptyState(
        icon: Iconsax.warning_2,
        title: 'Map unavailable',
        message: error,
      );
    }
    // The map is commented out for now. Zones and subzones are created, renamed and deleted from this list.
    // final drawing = controller.isDrawing;
    // if (drawing) Expanded(child: _MapCard(canManage: canManage)) else SizedBox(height: _compactMapHeight, child: _MapCard(canManage: canManage)),
    return Padding(
      padding: EdgeInsets.all(gutter),
      child: Column(
        children: [Expanded(child: _TerritoryPanel(canManage: canManage))],
      ),
    );
  }

  /// A subzone is drawn inside an existing zone, so the user picks the zone first.
  Future<void> _pickZoneForSubzone(BuildContext context) async {
    if (controller.zones.isEmpty) {
      await AppDialogs.info(
        'Draw a zone first',
        'A subzone sits inside a zone. Create a zone, then its subzones.',
      );
      return;
    }
    final zoneId = await AppDialogs.choose<int>(
      title: 'Which zone?',
      choices: [
        for (final zone in controller.zones)
          AppChoice<int>(
            value: zone.id,
            label: zone.name,
            icon: Iconsax.location,
            description: '${controller.subzonesOf(zone.id).length} subzones',
          ),
      ],
    );
    if (zoneId != null)
      await controller.createByName(
        kind: TerritoryKind.subzone,
        parentId: zoneId,
      );
  }
}

/* The map is commented out for now.
/// The map and its hint. Rebuilt whenever the draft, the drawing mode or the territories change.
class _MapCard extends GetView<TerritoriesController> {
  const _MapCard({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Obx(
      () => Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: p.surface, borderRadius: AppRadius.lg),
              child: ClipRRect(
                borderRadius: AppRadius.lg,
                child: TerritoryMap(
                  features: controller.features,
                  territories: controller.visibleTerritories,
                  draft: controller.draft.toList(),
                  bounds: controller.bounds,
                  isDrawing: controller.isDrawing && canManage,
                  freehand: controller.freehand,
                  onPoint: controller.addPoint,
                  focusRings: controller.focusRings,
                  focusToken: controller.focusToken,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            controller.isDrawing ? _drawHint() : 'Pinch to zoom. Zones are cut to the map boundary.',
            style: text.bodySmall?.copyWith(color: p.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xs),
          Text('© OpenStreetMap contributors', style: text.labelSmall?.copyWith(color: p.inkMuted)),
        ],
      ),
    );
  }

  String _drawHint() {
    final kind = controller.drawKind == TerritoryKind.zone ? 'zone' : 'subzone';
    final how = controller.freehand ? 'Drag on the map to draw.' : 'Tap the map to place points.';
    final editing = controller.editing;
    if (editing != null) return 'Reshaping ${editing.name}. Change its outline, then Finish.';
    return 'Drawing a $kind. $how';
  }
}

*/

/// The actions on the right of the header, as icons. Creating a shape shows the new-zone and new-subzone icons;
/// while a shape is being placed, the draw controls take their place.
class _HeaderActions extends GetView<TerritoriesController> {
  const _HeaderActions({required this.onNewSubzone});

  final VoidCallback onNewSubzone;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isDrawing) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'New zone',
              onPressed: () =>
                  controller.createByName(kind: TerritoryKind.zone),
              icon: const Icon(Iconsax.add_square),
            ),
            IconButton(
              tooltip: 'New subzone',
              onPressed: onNewSubzone,
              icon: const Icon(Iconsax.grid_1),
            ),
          ],
        );
      }
      final canFinish = controller.draft.length >= 3;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: controller.freehand ? 'Freehand: on' : 'Tap points',
            onPressed: () => controller.setFreehand(!controller.freehand),
            icon: Icon(
              controller.freehand ? Iconsax.edit : Iconsax.mouse_circle,
            ),
          ),
          IconButton(
            tooltip: 'Undo',
            onPressed: controller.draft.isEmpty ? null : controller.undoPoint,
            icon: const Icon(Iconsax.undo),
          ),
          IconButton(
            tooltip: 'Finish',
            onPressed: canFinish ? controller.finishDrawing : null,
            icon: const Icon(Iconsax.tick_circle),
          ),
          IconButton(
            tooltip: 'Cancel',
            onPressed: controller.cancelDrawing,
            icon: const Icon(Iconsax.close_circle),
          ),
        ],
      );
    });
  }
}

/// Every zone, with its subzones listed under it. The panel takes the space left under the map.
class _TerritoryPanel extends GetView<TerritoriesController> {
  const _TerritoryPanel({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final rows = _rows();
      return Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.lg,
          boxShadow: AppEffects.card(p),
          border: AppEffects.hairline(p),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.l,
                  AppSpace.l,
                  AppSpace.l,
                  AppSpace.m,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Zones',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${controller.zones.length}',
                      style: text.labelLarge?.copyWith(color: p.inkMuted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.l,
                          0,
                          AppSpace.l,
                          AppSpace.l,
                        ),
                        child: Text(
                          'Nothing drawn yet.',
                          style: text.bodyMedium?.copyWith(color: p.inkMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: rows.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1, color: p.border),
                        itemBuilder: (context, index) => rows[index],
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }

  List<Widget> _rows() => [
    for (final zone in controller.zones) ...[
      _TerritoryRow(
        territory: zone,
        canManage: canManage,
        onEdit: controller.renameTerritory,
        onDelete: controller.deleteTerritory,
      ),
      for (final subzone in controller.subzonesOf(zone.id))
        _TerritoryRow(
          territory: subzone,
          canManage: canManage,
          onEdit: controller.renameTerritory,
          onDelete: controller.deleteTerritory,
        ),
    ],
  ];
}

/// One zone or subzone. Tapping the row opens its contacts. A zone carries a bar in its colour; a subzone is indented under it.
class _TerritoryRow extends StatelessWidget {
  const _TerritoryRow({
    required this.territory,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final Territory territory;
  final bool canManage;
  final ValueChanged<Territory> onEdit;
  final ValueChanged<Territory> onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final isZone = territory.kind == TerritoryKind.zone;
    final colour = territoryHue(territory.colorIndex);

    return InkWell(
      onTap: () =>
          Get.toNamed(AppRoutes.territoryContacts, arguments: territory),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isZone ? AppSpace.l : AppSpace.xl + AppSpace.m,
          AppSpace.m,
          AppSpace.xs,
          AppSpace.m,
        ),
        child: Row(
          children: [
            if (isZone)
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius: AppRadius.pill,
                ),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    territory.name,
                    style: isZone
                        ? text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          )
                        : text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    isZone ? 'Zone' : 'Subzone',
                    style: text.labelSmall?.copyWith(color: p.inkMuted),
                  ),
                ],
              ),
            ),
            if (canManage)
              IconButton(
                tooltip: 'Edit',
                onPressed: () => onEdit(territory),
                icon: Icon(Iconsax.edit_2, size: 18, color: p.primary),
              ),
            if (canManage)
              IconButton(
                tooltip: 'Delete',
                onPressed: () => onDelete(territory),
                icon: Icon(Iconsax.trash, size: 18, color: p.alert),
              ),
            Icon(Iconsax.arrow_right_3, size: 18, color: p.inkMuted),
          ],
        ),
      ),
    );
  }
}
