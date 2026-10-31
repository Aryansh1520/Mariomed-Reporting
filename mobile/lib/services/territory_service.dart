import '../models/geo_point.dart';
import '../models/map_region.dart';
import '../models/territory.dart';
import 'api_service.dart';

/// The map outlines and the saved territories. The server cuts every shape to the map.
class TerritoryMapData {
  const TerritoryMapData({required this.regions, required this.territories});

  final List<MapFeature> regions;
  final List<Territory> territories;
}

class TerritoryService {
  TerritoryService(this._api);

  final ApiService _api;

  Future<TerritoryMapData> fetchMap() =>
      _api.getData<TerritoryMapData>('/territories/map', (data) {
        final json = ApiService.asJsonMap(data);
        return TerritoryMapData(
          regions: [
            for (final item in json['regions'] as List<Object?>)
              MapFeature.fromJson(ApiService.asJsonMap(item)),
          ],
          territories: [
            for (final item in json['territories'] as List<Object?>)
              Territory.fromJson(ApiService.asJsonMap(item)),
          ],
        );
      });

  /// Creates a zone or subzone by name. A shape is optional; without one the area has no outline yet.
  Future<Territory> createTerritory({
    required String name,
    required TerritoryKind kind,
    required int? parentId,
    List<GeoPoint>? points,
  }) => _api.postData<Territory>(
    '/territories',
    (data) => Territory.fromJson(ApiService.asJsonMap(data)),
    body: {
      'name': name,
      'kind': kind == TerritoryKind.zone ? 'zone' : 'subzone',
      'parent_id': parentId,
      'points': ?points?.map((point) => [point.lon, point.lat]).toList(),
    },
  );

  /// Renames, reshapes, or both. Only the fields given are sent.
  Future<Territory> updateTerritory(
    int territoryId, {
    String? name,
    List<GeoPoint>? points,
  }) => _api.patchData<Territory>(
    '/territories/$territoryId',
    (data) => Territory.fromJson(ApiService.asJsonMap(data)),
    body: {
      'name': ?name,
      'points': ?points?.map((point) => [point.lon, point.lat]).toList(),
    },
  );

  Future<void> deleteTerritory(int territoryId) =>
      _api.deleteData<void>('/territories/$territoryId', (_) {});
}
