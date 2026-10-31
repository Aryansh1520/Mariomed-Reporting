import 'dart:math' as math;
import 'dart:ui';

import '../../models/geo_point.dart';

/// The rectangle of the map in degrees, west to east and south to north.
class MapBounds {
  const MapBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;
}

/// Turns longitude and latitude into canvas pixels and back. The map keeps its proportions and
/// sits centred in the box it is given.
class MapProjection {
  MapProjection({required this.bounds, required this.size}) {
    final midLat = (bounds.south + bounds.north) / 2;
    _lonFactor = math.cos(midLat * math.pi / 180);
    final spanX = (bounds.east - bounds.west) * _lonFactor;
    final spanY = bounds.north - bounds.south;
    _scale = math.min(size.width / spanX, size.height / spanY);
    _offset = Offset(
      (size.width - spanX * _scale) / 2,
      (size.height - spanY * _scale) / 2,
    );
  }

  final MapBounds bounds;
  final Size size;
  late final double _lonFactor;
  late final double _scale;
  late final Offset _offset;

  Offset toCanvas(GeoPoint point) => Offset(
    (point.lon - bounds.west) * _lonFactor * _scale + _offset.dx,
    (bounds.north - point.lat) * _scale + _offset.dy,
  );

  GeoPoint toGeo(Offset canvas) => GeoPoint(
    (canvas.dx - _offset.dx) / (_scale * _lonFactor) + bounds.west,
    bounds.north - (canvas.dy - _offset.dy) / _scale,
  );
}

/// Ray casting: true when the point lies inside the closed outline.
bool pointInRing(GeoPoint point, List<GeoPoint> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    final crosses = (a.lat > point.lat) != (b.lat > point.lat);
    if (crosses &&
        point.lon <
            (b.lon - a.lon) * (point.lat - a.lat) / (b.lat - a.lat) + a.lon) {
      inside = !inside;
    }
  }
  return inside;
}

/// The centre of the outline's bounding box, for placing a label.
GeoPoint centreOf(List<GeoPoint> ring) {
  var west = ring.first.lon, east = ring.first.lon;
  var south = ring.first.lat, north = ring.first.lat;
  for (final point in ring) {
    west = math.min(west, point.lon);
    east = math.max(east, point.lon);
    south = math.min(south, point.lat);
    north = math.max(north, point.lat);
  }
  return GeoPoint((west + east) / 2, (south + north) / 2);
}

/// Removes the loops from a drawn outline that crosses itself. Where two edges cross, the outline splits in two;
/// the larger part is kept and the smaller loop is dropped. Repeats until no edge crosses another.
List<GeoPoint> untangleRing(List<GeoPoint> ring) {
  var current = List.of(ring);
  while (true) {
    final crossing = _firstCrossing(current);
    if (crossing == null) return current;
    final (i, j, at) = crossing;
    final n = current.length;
    final first = [at, for (var k = i + 1; k <= j; k++) current[k]];
    final second = [
      at,
      for (var k = j + 1; k < n; k++) current[k],
      for (var k = 0; k <= i; k++) current[k],
    ];
    current = _ringArea(first).abs() >= _ringArea(second).abs()
        ? first
        : second;
    if (current.length < 3) return current;
  }
}

/// The first pair of edges that cross, as the indexes of their start points and the crossing point.
(int, int, GeoPoint)? _firstCrossing(List<GeoPoint> ring) {
  final n = ring.length;
  for (var i = 0; i < n; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % n];
    for (var j = i + 2; j < n; j++) {
      if (i == 0 && j == n - 1) continue;
      final c = ring[j];
      final d = ring[(j + 1) % n];
      if (_properlyCrosses(a, b, c, d))
        return (i, j, _crossingPoint(a, b, c, d));
    }
  }
  return null;
}

GeoPoint _crossingPoint(GeoPoint a, GeoPoint b, GeoPoint c, GeoPoint d) {
  final rx = b.lon - a.lon, ry = b.lat - a.lat;
  final sx = d.lon - c.lon, sy = d.lat - c.lat;
  final denominator = rx * sy - ry * sx;
  final t = ((c.lon - a.lon) * sy - (c.lat - a.lat) * sx) / denominator;
  return GeoPoint(a.lon + t * rx, a.lat + t * ry);
}

/// Signed area of the outline (shoelace formula). Only its size matters for choosing the larger loop.
double _ringArea(List<GeoPoint> ring) {
  var sum = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    sum += a.lon * b.lat - b.lon * a.lat;
  }
  return sum / 2;
}

bool _properlyCrosses(GeoPoint a, GeoPoint b, GeoPoint c, GeoPoint d) {
  final d1 = _turn(c, d, a);
  final d2 = _turn(c, d, b);
  final d3 = _turn(a, b, c);
  final d4 = _turn(a, b, d);
  return d1 * d2 < 0 && d3 * d4 < 0;
}

double _turn(GeoPoint p, GeoPoint q, GeoPoint r) =>
    (q.lon - p.lon) * (r.lat - p.lat) - (q.lat - p.lat) * (r.lon - p.lon);

/// True when the point lies inside any of the outlines.
bool insideAnyRing(GeoPoint point, Iterable<List<GeoPoint>> rings) {
  for (final ring in rings) {
    if (pointInRing(point, ring)) return true;
  }
  return false;
}

/// The point on the outlines nearest to [point]. Used to bring a point drawn outside the map back to its edge.
/// Longitude is scaled by the cosine of the latitude, so distances are roughly even in every direction.
GeoPoint nearestOnRings(GeoPoint point, Iterable<List<GeoPoint>> rings) {
  final scale = math.cos(point.lat * math.pi / 180);
  GeoPoint? best;
  var bestDistance = double.infinity;
  for (final ring in rings) {
    for (var i = 0; i < ring.length - 1; i++) {
      final candidate = _nearestOnSegment(point, ring[i], ring[i + 1], scale);
      final distance = _scaledDistance(point, candidate, scale);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }
  }
  return best ?? point;
}

GeoPoint _nearestOnSegment(GeoPoint p, GeoPoint a, GeoPoint b, double scale) {
  final ax = a.lon * scale, ay = a.lat;
  final bx = b.lon * scale, by = b.lat;
  final px = p.lon * scale, py = p.lat;
  final dx = bx - ax, dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  final t = lengthSquared == 0
      ? 0.0
      : (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
  return GeoPoint(a.lon + (b.lon - a.lon) * t, a.lat + (b.lat - a.lat) * t);
}

double _scaledDistance(GeoPoint a, GeoPoint b, double scale) {
  final dx = (a.lon - b.lon) * scale;
  final dy = a.lat - b.lat;
  return math.sqrt(dx * dx + dy * dy);
}
