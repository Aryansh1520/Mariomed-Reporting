import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Mesh hero: a diagonal base gradient, blurred colour blobs (grey-blue haze down the left,
/// brighter blue core, pale ice edges) and a fade into the canvas.
class MeshHero extends StatelessWidget {
  const MeshHero({super.key, required this.child});

  final Widget child;

  Color _stop(AppPalette p, int i) =>
      p.heroStops[min(i, p.heroStops.length - 1)];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: p.heroStops,
              ),
            ),
          ),
        ),
        // Grey-blue haze: top-left, then down the left edge.
        Positioned(
          left: -130,
          top: -70,
          child: _Blob(size: 340, color: p.heroCool, sigma: 70),
        ),
        Positioned(
          left: -100,
          top: 170,
          child: _Blob(size: 260, color: p.heroCool, sigma: 70),
        ),
        // Bright blue core, top-right.
        Positioned(
          right: -50,
          top: -30,
          child: _Blob(size: 300, color: _stop(p, 3), sigma: 80),
        ),
        Positioned(
          left: 70,
          top: 110,
          child: _Blob(size: 260, color: _stop(p, 5), sigma: 80),
        ),
        // Pale ice edges, bottom.
        Positioned(
          right: -60,
          bottom: 40,
          child: _Blob(size: 260, color: _stop(p, 6), sigma: 80),
        ),
        Positioned(
          left: 30,
          bottom: -10,
          child: _Blob(size: 220, color: _stop(p, 7), sigma: 70),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 70,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.background.withValues(alpha: 0), p.background],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color, required this.sigma});

  final double size;
  final Color color;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
