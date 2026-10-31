import 'package:flutter/material.dart';

import '../../models/dashboard.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Calls per day as bars, one per day, scaled to the busiest day. The first, middle and last days are labelled.
class DailyBars extends StatelessWidget {
  const DailyBars({super.key, required this.days});

  final List<DayCount> days;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final labels = days.isEmpty
        ? const <String>[]
        : [
            _day(days.first.date),
            _day(days[days.length ~/ 2].date),
            _day(days.last.date),
          ];

    return Column(
      children: [
        SizedBox(
          height: 120,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarsPainter(days: days, bar: p.primary, track: p.border),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Row(
          children: [
            for (final label in labels) ...[
              Expanded(
                child: Text(
                  label,
                  textAlign: label == labels.first
                      ? TextAlign.left
                      : (label == labels.last
                            ? TextAlign.right
                            : TextAlign.center),
                  style: text.labelSmall?.copyWith(color: p.inkMuted),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String _day(DateTime date) => '${date.day}/${date.month}';
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.days, required this.bar, required this.track});

  final List<DayCount> days;
  final Color bar;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final busiest = days
        .map((day) => day.count)
        .fold<int>(1, (a, b) => a > b ? a : b);
    final slot = size.width / days.length;
    final barWidth = slot * 0.6;
    final baseline = Paint()..color = track;
    canvas.drawRect(Rect.fromLTWH(0, size.height - 1, size.width, 1), baseline);
    for (var i = 0; i < days.length; i++) {
      final count = days[i].count;
      final height = count == 0 ? 2.0 : (size.height - 12) * count / busiest;
      final left = i * slot + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - height - 1, barWidth, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = count == 0 ? track : bar);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.bar != bar;
}
