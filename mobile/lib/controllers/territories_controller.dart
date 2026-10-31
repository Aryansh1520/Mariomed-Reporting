import 'package:get/get.dart';

import '../core/utils/geo.dart';
import '../core/widgets/app_dialogs.dart';
import '../models/geo_point.dart';
import '../models/map_region.dart';
import '../models/territory.dart';
import '../services/app_exception.dart';
import '../services/territory_service.dart';

/// The territory map: the service-area outlines, and the zones and subzones saved on the server.
/// The points a user places are sent as drawn. The server cuts each shape to the map and checks it.
class TerritoriesController extends GetxController {
  TerritoriesController(this._service);

  final TerritoryService _service;
  final _features = <MapFeature>[].obs;
  final _territories = <Territory>[].obs;
  final _draft = <GeoPoint>[].obs;
  final _drawKind = Rxn<TerritoryKind>();
  final _draftParentId = RxnInt();
  final _editing = Rxn<Territory>();
  final _focusRings = Rxn<List<List<GeoPoint>>>();
  final _focusToken = 0.obs;
  final _freehand = false.obs;
  final _isLoading = true.obs;
  final _loadError = RxnString();
  MapBounds? _bounds;

  List<MapFeature> get features => _features;

  List<Territory> get territories => _territories;

  List<GeoPoint> get draft => _draft;

  TerritoryKind? get drawKind => _drawKind.value;

  /// The outline the map should zoom to. Set when a zone is chosen to hold a subzone.
  List<List<GeoPoint>>? get focusRings => _focusRings.value;

  /// Changes each time the map should zoom to the outline, so choosing the same zone again still zooms.
  int get focusToken => _focusToken.value;

  /// The territory being reshaped, or null when a new one is drawn.
  Territory? get editing => _editing.value;

  /// The territories to draw on the map. The one being reshaped is hidden, so only its outline in progress shows.
  List<Territory> get visibleTerritories => [
    for (final territory in _territories)
      if (territory.id != _editing.value?.id) territory,
  ];

  bool get isDrawing => _drawKind.value != null;

  bool get freehand => _freehand.value;

  bool get isLoading => _isLoading.value;

  String? get loadError => _loadError.value;

  /// The map rectangle, from the outlines. Falls back to Mumbai's rough extent until they load.
  MapBounds get bounds =>
      _bounds ??
      const MapBounds(west: 72.6, south: 18.9, east: 73.8, north: 20.23);

  List<Territory> get zones => [
    for (final territory in _territories)
      if (territory.kind == TerritoryKind.zone) territory,
  ];

  List<Territory> subzonesOf(int zoneId) => [
    for (final territory in _territories)
      if (territory.parentId == zoneId) territory,
  ];

  @override
  void onInit() {
    super.onInit();
    loadMap();
  }

  Future<void> loadMap() async {
    _isLoading.value = true;
    _loadError.value = null;
    try {
      final data = await _service.fetchMap();
      _features.assignAll(data.regions);
      _territories.assignAll(data.territories);
      _bounds = _boundsOf(data.regions);
      _fitToTerritories();
    } on AppException catch (e) {
      _loadError.value = e.message;
    } finally {
      _isLoading.value = false;
    }
  }

  void setFreehand(bool value) => _freehand.value = value;

  /// Zooms the map to the territories the user can see: their own area, or the whole service area for an admin.
  /// Falls back to the full map when nothing is drawn yet.
  void _fitToTerritories() {
    final rings = [for (final territory in _territories) ...territory.rings];
    if (rings.isEmpty) return;
    _focusRings.value = rings;
    _focusToken.value++;
  }

  void startDrawing(TerritoryKind kind, {int? parentId}) {
    _draft.clear();
    _drawKind.value = kind;
    _draftParentId.value = parentId;
    final parent = parentId == null
        ? null
        : _territories.where((item) => item.id == parentId).firstOrNull;
    _focusRings.value = parent?.rings;
    if (parent != null) _focusToken.value++;
  }

  /// A point placed outside the map is brought to the nearest edge of the map, so rough drawing still lands on the boundary.
  void addPoint(GeoPoint point) {
    if (!isDrawing) return;
    final rings = [for (final feature in _features) ...feature.rings];
    _draft.add(
      insideAnyRing(point, rings) ? point : nearestOnRings(point, rings),
    );
  }

  void undoPoint() {
    if (_draft.isNotEmpty) _draft.removeLast();
  }

  /// Starts reshaping a saved territory: its outline is loaded as the draft, ready to change.
  void beginEdit(Territory territory) {
    startDrawing(territory.kind, parentId: territory.parentId);
    _draft.assignAll(territory.rings.first);
    _editing.value = territory;
  }

  void cancelDrawing() {
    _draft.clear();
    _drawKind.value = null;
    _draftParentId.value = null;
    _editing.value = null;
  }

  /// Names the drawn area and saves it. Crossing lines are tidied first. The server cuts the shape to the map and checks a subzone.
  Future<void> finishDrawing() async {
    final kind = _drawKind.value;
    if (kind == null) return;
    final shape = untangleRing(_draft);
    if (shape.length < 3) {
      await AppDialogs.info(
        'Add more points',
        'An area needs at least three points.',
      );
      return;
    }
    final label = kind == TerritoryKind.zone ? 'zone' : 'subzone';
    final editing = _editing.value;
    if (editing != null) {
      await _saveEdit(editing, shape, label);
      return;
    }
    final name = await AppDialogs.prompt(
      title: 'Name this $label',
      label: '$label name',
    );
    if (name == null) return;
    try {
      final saved = await _service.createTerritory(
        name: name,
        kind: kind,
        parentId: _draftParentId.value,
        points: shape,
      );
      _territories.add(saved);
      cancelDrawing();
    } on AppException catch (e) {
      await AppDialogs.info('Could not save', e.message);
    }
  }

  Future<void> _saveEdit(
    Territory territory,
    List<GeoPoint> shape,
    String label,
  ) async {
    final name = await AppDialogs.prompt(
      title: 'Rename this $label',
      label: '$label name',
      initial: territory.name,
    );
    if (name == null) return;
    final subzones = territory.kind == TerritoryKind.zone
        ? subzonesOf(territory.id)
        : <Territory>[];
    if (subzones.isNotEmpty) {
      final confirmed = await AppDialogs.confirm(
        title:
            'Delete ${subzones.length} subzone${subzones.length == 1 ? '' : 's'}?',
        message: 'Editing a zone removes its subzones, because they were drawn inside the old outline.',
        confirmLabel: 'Save and delete',
        destructive: true,
      );
      if (!confirmed) return;
    }
    try {
      final saved = await _service.updateTerritory(
        territory.id,
        name: name,
        points: shape,
      );
      final removed = {for (final child in subzones) child.id};
      _territories.removeWhere((item) => removed.contains(item.id));
      final index = _territories.indexWhere((item) => item.id == territory.id);
      if (index != -1) _territories[index] = saved;
      cancelDrawing();
    } on AppException catch (e) {
      await AppDialogs.info('Could not save', e.message);
    }
  }

  /// Creates a zone or subzone by name. The map is not used, so the area has no outline.
  Future<void> createByName({
    required TerritoryKind kind,
    int? parentId,
  }) async {
    final label = kind == TerritoryKind.zone ? 'zone' : 'subzone';
    final name = await AppDialogs.prompt(
      title: 'Name this $label',
      label: '$label name',
    );
    if (name == null) return;
    try {
      final saved = await _service.createTerritory(
        name: name,
        kind: kind,
        parentId: parentId,
      );
      _territories.add(saved);
    } on AppException catch (e) {
      await AppDialogs.info('Could not save', e.message);
    }
  }

  Future<void> renameTerritory(Territory territory) async {
    final label = territory.kind == TerritoryKind.zone ? 'zone' : 'subzone';
    final name = await AppDialogs.prompt(
      title: 'Rename this $label',
      label: '$label name',
      initial: territory.name,
    );
    if (name == null || name == territory.name) return;
    try {
      final saved = await _service.updateTerritory(territory.id, name: name);
      final index = _territories.indexWhere((item) => item.id == territory.id);
      if (index != -1) _territories[index] = saved;
    } on AppException catch (e) {
      await AppDialogs.info('Could not save', e.message);
    }
  }

  /// Deleting is a soft delete: the area and its subzones stop appearing, and their contacts cannot be visited.
  Future<void> deleteTerritory(Territory territory) async {
    final children = territory.kind == TerritoryKind.zone
        ? subzonesOf(territory.id)
        : <Territory>[];
    final confirmed = await AppDialogs.confirm(
      title: 'Delete ${territory.name}?',
      message: children.isEmpty
          ? 'Its contacts stop appearing and cannot be visited. Nothing is erased.'
          : 'Its ${children.length} subzone${children.length == 1 ? '' : 's'} and their contacts are removed too. Nothing is erased.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _service.deleteTerritory(territory.id);
      final removed = {territory.id, for (final child in children) child.id};
      _territories.removeWhere((item) => removed.contains(item.id));
    } on AppException catch (e) {
      await AppDialogs.info('Could not delete', e.message);
    }
  }

  MapBounds _boundsOf(List<MapFeature> features) {
    final points = [
      for (final feature in features)
        for (final ring in feature.rings) ...ring,
    ];
    if (points.isEmpty) return bounds;
    return MapBounds(
      west: points.map((p) => p.lon).reduce((a, b) => a < b ? a : b),
      east: points.map((p) => p.lon).reduce((a, b) => a > b ? a : b),
      south: points.map((p) => p.lat).reduce((a, b) => a < b ? a : b),
      north: points.map((p) => p.lat).reduce((a, b) => a > b ? a : b),
    );
  }
}
