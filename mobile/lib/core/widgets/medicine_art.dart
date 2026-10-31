import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vector medicine art for card backgrounds: a pill bottle with a cross on its label and two
/// capsules. It takes one colour, so it reads on light and dark surfaces. It fits the box at bottom right.
class MedicineArt extends StatelessWidget {
  const MedicineArt({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MedicinePainter(color), size: Size.infinite);
  }
}

class _MedicinePainter extends CustomPainter {
  _MedicinePainter(this.color);

  /// The drawing's own coordinates. Everything below is written in this space.
  static const _width = 320.0;
  static const _height = 440.0;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / _width, size.height / _height);
    canvas.translate(
      size.width - _width * scale,
      size.height - _height * scale,
    );
    canvas.scale(scale);

    final fill = Paint()..color = color;
    canvas.drawPath(_bottle(), fill);
    _capsule(canvas, fill, const Offset(40, 380), -0.5, 92, 36);
    _capsule(
      canvas,
      fill..color = color.withValues(alpha: 0.6),
      const Offset(270, 150),
      0.5,
      70,
      28,
    );
  }

  /// Cap, neck and body as one path. The label is a hole in the body, and the cross sits inside
  /// the hole, so the even-odd rule fills the cross again.
  Path _bottle() {
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(92, 40, 136, 44),
        const Radius.circular(8),
      ),
    );
    path.addRect(const Rect.fromLTWH(118, 84, 84, 16));
    path.addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(80, 100, 160, 300),
        const Radius.circular(22),
      ),
    );
    path.addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(104, 170, 112, 130),
        const Radius.circular(10),
      ),
    );
    path.addPath(_cross(), Offset.zero);
    return path;
  }

  Path _cross() {
    return Path()
      ..moveTo(147, 195)
      ..lineTo(173, 195)
      ..lineTo(173, 221)
      ..lineTo(199, 221)
      ..lineTo(199, 247)
      ..lineTo(173, 247)
      ..lineTo(173, 273)
      ..lineTo(147, 273)
      ..lineTo(147, 247)
      ..lineTo(121, 247)
      ..lineTo(121, 221)
      ..lineTo(147, 221)
      ..close();
  }

  void _capsule(
    Canvas canvas,
    Paint paint,
    Offset at,
    double angle,
    double length,
    double thickness,
  ) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: length, height: thickness),
        Radius.circular(thickness / 2),
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MedicinePainter oldDelegate) =>
      oldDelegate.color != color;
}
