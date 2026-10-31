import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Placeholder rows shown while a list loads.
class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Shimmer.fromColors(
      baseColor: p.surfaceRaised,
      highlightColor: p.surface,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.l),
        itemCount: count,
        itemBuilder: (_, _) => Container(
          height: 96,
          margin: const EdgeInsets.only(bottom: AppSpace.m),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.lg,
          ),
        ),
      ),
    );
  }
}
