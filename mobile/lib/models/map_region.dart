import 'geo_point.dart';

/// One outlined area of the region map: the city, a district or a sub-district.
class MapFeature {
  const MapFeature({
    required this.name,
    required this.kind,
    required this.rings,
  });

  factory MapFeature.fromJson(Map<String, Object?> json) => MapFeature(
    name: json['name'] as String,
    kind: json['kind'] as String,
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
  );

  final String name;

  /// city, suburb, subdistrict or district.
  final String kind;

  /// Each ring is one closed outline. The city has islands, so a feature can have several.
  final List<List<GeoPoint>> rings;
}
