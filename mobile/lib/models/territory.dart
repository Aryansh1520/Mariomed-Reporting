import 'geo_point.dart';

enum TerritoryKind { zone, subzone }

/// A zone or subzone, as the server saved it. Its shape is already cut to the map.
class Territory {
  const Territory({
    required this.id,
    required this.name,
    required this.kind,
    required this.rings,
    required this.colorIndex,
    required this.parentId,
  });

  factory Territory.fromJson(Map<String, Object?> json) => Territory(
    id: json['id'] as int,
    name: json['name'] as String,
    kind: json['kind'] == 'zone' ? TerritoryKind.zone : TerritoryKind.subzone,
    rings: [
      for (final ring in json['rings'] as List<Object?>)
        [
          for (final point in ring as List<Object?>)
            GeoPoint(
              ((point as List<Object?>)[0] as num).toDouble(),
              (point[1] as num).toDouble(),
            ),
        ],
    ],
    colorIndex: json['color_index'] as int,
    parentId: json['parent_id'] as int?,
  );

  final int id;
  final String name;
  final TerritoryKind kind;

  /// The outer outline of each part of the shape.
  final List<List<GeoPoint>> rings;

  /// Which hue the territory is drawn in. A subzone shares its zone's hue.
  final int colorIndex;
  final int? parentId;
}
