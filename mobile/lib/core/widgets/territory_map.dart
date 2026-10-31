import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/geo.dart';
import '../../models/geo_point.dart';
import '../../models/map_region.dart';
import '../../models/territory.dart';

/// The map: the region outline, zones and subzones as tinted areas in their own colours, cut to the map's boundary, and the shape being drawn.
/// Pinch to zoom. Tap places a point; freehand turns a drag into points. Lines stay thin as the map zooms in.
class TerritoryMap extends StatefulWidget {
  const TerritoryMap({
    super.key,
    required this.features,
    required this.territories,
    required this.draft,
    required this.bounds,
    required this.isDrawing,
    required this.freehand,
    required this.onPoint,
    this.focusRings,
    this.focusToken = 0,
  });

  final List<MapFeature> features;
  final List<Territory> territories;
  final List<GeoPoint> draft;
  final MapBounds bounds;
  final bool isDrawing;
  final bool freehand;
  final ValueChanged<GeoPoint> onPoint;

  /// When set, the map zooms so these outlines fill most of it. A new [focusToken] triggers the zoom.
  final List<List<GeoPoint>>? focusRings;
  final int focusToken;

  @override
  State<TerritoryMap> createState() => _TerritoryMapState();
}

class _TerritoryMapState extends State<TerritoryMap>
    with SingleTickerProviderStateMixin {
  final _zoom = TransformationController();
  Offset? _lastFreehand;
  late final AnimationController _focusAnimation =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      )..addListener(() {
        final tween = _focusTween;
        if (tween != null) _zoom.value = tween.evaluate(_focusAnimation);
      });
  Matrix4Tween? _focusTween;

  /// Spacing between freehand points, in pixels on screen. Closer points give a finer outline.
  static const _freehandStep = 6.0;

  @override
  void initState() {
    super.initState();
    // The first layout is when the map knows its size, so the initial focus waits for it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rings = widget.focusRings;
      if (mounted && rings != null) _focusOn(rings);
    });
  }

  @override
  void didUpdateWidget(covariant TerritoryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rings = widget.focusRings;
    if (rings != null && widget.focusToken != oldWidget.focusToken)
      _focusOn(rings);
  }

  /// Zooms so the outlines fill most of the map and sit in its centre. Used when a zone is chosen to hold a subzone.
  void _focusOn(List<List<GeoPoint>> rings) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    final projection = MapProjection(bounds: widget.bounds, size: size);
    final points = [
      for (final ring in rings)
        for (final point in ring) projection.toCanvas(point),
    ];
    final left = points.map((p) => p.dx).reduce(math.min);
    final right = points.map((p) => p.dx).reduce(math.max);
    final top = points.map((p) => p.dy).reduce(math.min);
    final bottom = points.map((p) => p.dy).reduce(math.max);
    final width = right - left;
    final height = bottom - top;
    if (width <= 0 || height <= 0) return;
    const fill = 0.9;
    final scale = (math.min(size.width / width, size.height / height) * fill)
        .clamp(1.0, 8.0);
    final centre = Offset((left + right) / 2, (top + bottom) / 2);
    final target = Matrix4.identity()
      ..translateByDouble(
        size.width / 2 - scale * centre.dx,
        size.height / 2 - scale * centre.dy,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
    _focusTween = Matrix4Tween(begin: _zoom.value, end: target);
    _focusAnimation
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _focusAnimation.dispose();
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final labelStyle =
        Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 11);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final projection = MapProjection(bounds: widget.bounds, size: size);
        return InteractiveViewer(
          transformationController: _zoom,
          minScale: 1,
          maxScale: 8,
          panEnabled: !(widget.isDrawing && widget.freehand),
          child: SizedBox.fromSize(
            size: size,
            child: ValueListenableBuilder<Matrix4>(
              valueListenable: _zoom,
              builder: (context, matrix, _) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _tapHandler(projection),
                onPanStart: _freehandActive
                    ? (details) => _addFreehand(
                        projection,
                        details.localPosition,
                        first: true,
                      )
                    : null,
                onPanUpdate: _freehandActive
                    ? (details) => _addFreehand(
                        projection,
                        details.localPosition,
                        first: false,
                      )
                    : null,
                onPanEnd: (_) => _lastFreehand = null,
                child: CustomPaint(
                  size: size,
                  painter: _TerritoryPainter(
                    region: _regionPath(projection),
                    features: widget.features,
                    territories: widget.territories,
                    draft: widget.draft,
                    projection: projection,
                    palette: p,
                    labelStyle: labelStyle,
                    zoom: matrix.getMaxScaleOnAxis(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The union of every outline, so drawn areas can be cut to the map's boundary.
  Path _regionPath(MapProjection projection) {
    Path? union;
    for (final feature in widget.features) {
      for (final ring in feature.rings) {
        final path = Path()
          ..addPolygon([
            for (final point in ring) projection.toCanvas(point),
          ], true);
        union = union == null
            ? path
            : Path.combine(PathOperation.union, union, path);
      }
    }
    return union ?? Path();
  }

  GestureTapUpCallback? _tapHandler(MapProjection projection) {
    if (!widget.isDrawing || widget.freehand) return null;
    return (details) => widget.onPoint(projection.toGeo(details.localPosition));
  }

  bool get _freehandActive => widget.isDrawing && widget.freehand;

  void _addFreehand(
    MapProjection projection,
    Offset at, {
    required bool first,
  }) {
    final last = _lastFreehand;
    if (!first && last != null && (at - last).distance < _freehandStep) return;
    _lastFreehand = at;
    widget.onPoint(projection.toGeo(at));
  }
}

class _TerritoryPainter extends CustomPainter {
  _TerritoryPainter({
    required this.region,
    required this.features,
    required this.territories,
    required this.draft,
    required this.projection,
    required this.palette,
    required this.labelStyle,
    required this.zoom,
  });

  final Path region;
  final List<MapFeature> features;
  final List<Territory> territories;
  final List<GeoPoint> draft;
  final MapProjection projection;
  final AppPalette palette;
  final TextStyle labelStyle;

  /// How far the map is zoomed in. Line widths are divided by it, so lines keep their thickness on screen.
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRegion(canvas);
    // Zones and subzones are cut to the map's boundary: the part of an area outside the map does not count.
    canvas.save();
    canvas.clipPath(region);
    for (final territory in territories) {
      if (territory.kind == TerritoryKind.zone)
        _paintTerritory(canvas, territory);
    }
    for (final territory in territories) {
      if (territory.kind == TerritoryKind.subzone)
        _paintTerritory(canvas, territory);
    }
    canvas.restore();
    _paintLabels(canvas);
    _paintDraft(canvas);
  }

  double _width(double base) => base / zoom;

  /// The region outline, drawn faint with no names: the user creates the territories.
  void _paintRegion(Canvas canvas) {
    final line = (palette.isDark ? palette.accent : palette.primary).withValues(
      alpha: palette.isDark ? 0.5 : 0.7,
    );
    final land = Paint()
      ..color = palette.primary.withValues(alpha: palette.isDark ? 0 : 0.07);
    for (final feature in features) {
      for (final ring in feature.rings) {
        canvas.drawPath(_path(ring), land);
      }
    }
    for (final feature in features) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = _width(feature.kind == 'city' ? 1.4 : 0.9)
        ..color = line;
      for (final ring in feature.rings) {
        canvas.drawPath(_path(ring), stroke);
      }
    }
  }

  void _paintTerritory(Canvas canvas, Territory territory) {
    final isZone = territory.kind == TerritoryKind.zone;
    final colour = territoryHue(territory.colorIndex);
    final paths = [for (final ring in territory.rings) _path(ring)];
    final zoneAlpha = palette.isDark ? 0.22 : 0.3;
    final subzoneAlpha = palette.isDark ? 0.34 : 0.45;
    final fill = Paint()
      ..color = colour.withValues(alpha: isZone ? zoneAlpha : subzoneAlpha);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = _width(isZone ? 2.0 : 1.4)
      ..color = colour;
    for (final path in paths) {
      canvas.drawPath(path, fill);
    }
    for (final path in paths) {
      canvas.drawPath(path, outline);
    }
  }

  /// Names are drawn after the shapes and outside their clip, so a name near the boundary is never cut.
  /// Zones are named first; a name that would overlap one already drawn is left off rather than printed over it.
  void _paintLabels(Canvas canvas) {
    final placed = <Rect>[];
    final zones = territories.where(
      (territory) => territory.kind == TerritoryKind.zone,
    );
    final subzones = territories.where(
      (territory) => territory.kind == TerritoryKind.subzone,
    );
    for (final territory in [...zones, ...subzones]) {
      final isZone = territory.kind == TerritoryKind.zone;
      _label(
        canvas,
        territory.name,
        centreOf(territory.rings.first),
        palette.ink,
        bold: isZone,
        avoid: placed,
      );
    }
  }

  /// The shape being drawn: an outline through the placed points, with a dot on each point.
  void _paintDraft(Canvas canvas) {
    if (draft.isEmpty) return;
    final points = [for (final point in draft) projection.toCanvas(point)];
    final colour = palette.warning;
    if (points.length >= 3) {
      canvas.drawPath(
        Path()..addPolygon(points, true),
        Paint()..color = colour.withValues(alpha: 0.15),
      );
    }
    canvas.drawPath(
      Path()..addPolygon(points, false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = _width(2.0)
        ..color = colour,
    );
    final dot = Paint()..color = colour;
    for (final point in points) {
      canvas.drawCircle(point, 4 / zoom, dot);
    }
  }

  Path _path(List<GeoPoint> ring) {
    final points = [for (final point in ring) projection.toCanvas(point)];
    return Path()..addPolygon(points, true);
  }

  /// Draws a label centred on [at]. When [avoid] is given, the label is skipped if it would overlap a label already drawn,
  /// and otherwise is added to it. Dense areas keep their most readable names this way.
  void _label(
    Canvas canvas,
    String text,
    GeoPoint at,
    Color colour, {
    bool bold = false,
    List<Rect>? avoid,
  }) {
    final size = (bold ? 12 : 10) / zoom;
    final weight = bold ? FontWeight.w700 : FontWeight.w500;
    final fontFamily = labelStyle.fontFamily;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          color: colour,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final centre = projection.toCanvas(at);
    final origin = centre - Offset(painter.width / 2, painter.height / 2);
    final box = origin & Size(painter.width, painter.height);
    if (avoid != null) {
      if (avoid.any((other) => other.overlaps(box))) return;
      avoid.add(box);
    }
    if (!palette.isDark) {
      // A white edge keeps the name readable over the coloured shapes and the outline.
      TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: size,
              fontWeight: weight,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3 / zoom
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, origin);
    }
    painter.paint(canvas, origin);
  }

  @override
  bool shouldRepaint(covariant _TerritoryPainter oldDelegate) => true;
}
