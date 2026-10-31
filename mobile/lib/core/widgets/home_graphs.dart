import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/dashboard.dart';

/// A ring that fills with a percentage: 0 is empty, 1 is full.
class CoverageRing extends StatelessWidget {
  const CoverageRing({
    super.key,
    required this.percent,
    required this.color,
    required this.track,
    this.size = 84,
  });

  final double percent;
  final Color color;
  final Color track;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          percent: percent.clamp(0, 1),
          color: color,
          track: track,
        ),
        child: Center(
          child: Text(
            '${(percent.clamp(0, 1) * 100).round()}%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.22,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.percent,
    required this.color,
    required this.track,
  });

  final double percent;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, base);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * percent, false, fill);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.percent != percent ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

/// Calls per day as a line with a soft area beneath it. Compact enough to sit in the hero.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.days, required this.color});

  final List<DayCount> days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(days: days, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.days, required this.color});

  final List<DayCount> days;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.length < 2) return;
    final busiest = days
        .map((day) => day.count)
        .fold<int>(1, (a, b) => a > b ? a : b);
    final step = size.width / (days.length - 1);
    final points = [
      for (var i = 0; i < days.length; i++)
        Offset(
          i * step,
          size.height - 6 - (size.height - 12) * days[i].count / busiest,
        ),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.color != color;
}

/// One tile per contact, six to a row. The tiles for visited contacts are lit; the rest are muted.
class CoverageTiles extends StatelessWidget {
  const CoverageTiles({
    super.key,
    required this.visited,
    required this.total,
    required this.lit,
    required this.muted,
    required this.tile,
  });

  final int visited;
  final int total;
  final Color lit;
  final Color muted;
  final Color tile;

  static const _columns = 6;
  static const _maxTiles = 36;

  @override
  Widget build(BuildContext context) {
    final count = total.clamp(0, _maxTiles);
    final litCount = total == 0 ? 0 : (visited * count / total).round();
    final rows = (count / _columns).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var column = 0; column < _columns; column++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: row * _columns + column < count
                          ? AspectRatio(
                              aspectRatio: 1,
                              child: _Tile(
                                lit: row * _columns + column < litCount,
                                litColour: lit,
                                tileColour: tile,
                                personColour: muted,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.lit,
    required this.litColour,
    required this.tileColour,
    required this.personColour,
  });

  final bool lit;
  final Color litColour;
  final Color tileColour;
  final Color personColour;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: lit ? litColour : tileColour,
        borderRadius: BorderRadius.circular(6),
      ),
      child: CustomPaint(
        painter: _PersonPainter(color: lit ? Colors.white : personColour),
      ),
    );
  }
}

class _PersonPainter extends CustomPainter {
  _PersonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(Offset(w / 2, h * 0.36), w * 0.17, paint);
    final shoulders = Path()
      ..moveTo(w * 0.22, h * 0.78)
      ..quadraticBezierTo(w * 0.22, h * 0.56, w / 2, h * 0.56)
      ..quadraticBezierTo(w * 0.78, h * 0.56, w * 0.78, h * 0.78)
      ..close();
    canvas.drawPath(shoulders, paint);
  }

  @override
  bool shouldRepaint(covariant _PersonPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Calls per day as rounded bars. Darker bars are busier days. Every other day is labelled with its weekday and date.
class CallBars extends StatelessWidget {
  const CallBars({
    super.key,
    required this.days,
    required this.color,
    required this.muted,
    required this.empty,
    this.barHeight = 96,
  });

  final List<DayCount> days;
  final Color color;
  final Color muted;
  final Color empty;
  final double barHeight;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final labelStyle =
        Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 11);
    final busiest = days.fold<int>(
      1,
      (best, day) => day.count > best ? day.count : best,
    );
    return Column(
      children: [
        SizedBox(
          height: barHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: _Bar(
                      fraction: day.count / busiest,
                      colour: day.count == 0
                          ? empty
                          : Color.lerp(
                              color.withValues(alpha: 0.35),
                              color,
                              day.count / busiest,
                            )!,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: i.isEven
                    ? Column(
                        children: [
                          Text(
                            _weekdays[days[i].date.weekday - 1],
                            style: labelStyle.copyWith(color: muted),
                          ),
                          Text(
                            '${days[i].date.day}',
                            style: labelStyle.copyWith(color: muted),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.colour});

  final double fraction;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: fraction < 0.12 ? 0.12 : fraction,
        child: Container(
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
