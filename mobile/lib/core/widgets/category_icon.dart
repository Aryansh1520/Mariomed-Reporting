import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// The icon for a contact category, drawn in the primary colour on a soft tile.
/// Doctors, chemists and stockists have their own marks; any other category gets the generic person.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.categoryName, this.size = 40});

  final String categoryName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.12),
        borderRadius: AppRadius.md,
      ),
      child: CustomPaint(
        painter: _CategoryPainter(
          kind: _kindOf(categoryName),
          color: p.primary,
        ),
      ),
    );
  }
}

enum _CategoryKind { doctor, chemist, stockist, generic }

/// Matches the start of the name, so "Doctor" and "Doctors" both get the doctor mark.
_CategoryKind _kindOf(String name) {
  final key = name.trim().toLowerCase();
  if (key.startsWith('doctor')) return _CategoryKind.doctor;
  if (key.startsWith('chemist')) return _CategoryKind.chemist;
  if (key.startsWith('stockist')) return _CategoryKind.stockist;
  return _CategoryKind.generic;
}

class _CategoryPainter extends CustomPainter {
  _CategoryPainter({required this.kind, required this.color});

  final _CategoryKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fill = Paint()..color = color;

    switch (kind) {
      case _CategoryKind.doctor:
        _paintCross(canvas, size, fill);
      case _CategoryKind.chemist:
        _paintCapsule(canvas, size, stroke);
      case _CategoryKind.stockist:
        _paintBox(canvas, size, stroke);
      case _CategoryKind.generic:
        _paintPerson(canvas, size, stroke);
    }
  }

  void _paintCross(Canvas canvas, Size size, Paint fill) {
    final arm = size.width * 0.22;
    final half = size.width * 0.36;
    final c = size.center(Offset.zero);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: arm, height: half * 2),
          Radius.circular(arm * 0.3),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: half * 2, height: arm),
          Radius.circular(arm * 0.3),
        ),
      );
    canvas.drawPath(path, fill);
  }

  void _paintCapsule(Canvas canvas, Size size, Paint stroke) {
    final length = size.width * 0.84;
    final thickness = size.width * 0.36;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: length, height: thickness),
      Radius.circular(thickness / 2),
    );
    canvas.drawRRect(body, stroke);
    canvas.drawLine(
      Offset.zero.translate(0, -thickness / 2),
      Offset.zero.translate(0, thickness / 2),
      stroke,
    );
    canvas.restore();
  }

  void _paintBox(Canvas canvas, Size size, Paint stroke) {
    final w = size.width;
    final h = size.height;
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.2, w * 0.72, h * 0.16),
      Radius.circular(w * 0.03),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.36, w * 0.6, h * 0.46),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(lid, stroke);
    canvas.drawRRect(body, stroke);
    canvas.drawLine(Offset(w / 2, h * 0.36), Offset(w / 2, h * 0.52), stroke);
  }

  void _paintPerson(Canvas canvas, Size size, Paint stroke) {
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(Offset(w / 2, h * 0.34), w * 0.15, stroke);
    final shoulders = Path()
      ..moveTo(w * 0.22, h * 0.8)
      ..quadraticBezierTo(w * 0.22, h * 0.56, w / 2, h * 0.56)
      ..quadraticBezierTo(w * 0.78, h * 0.56, w * 0.78, h * 0.8);
    canvas.drawPath(shoulders, stroke);
  }

  @override
  bool shouldRepaint(covariant _CategoryPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
