import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Scales its child down slightly while pressed, for tactile feedback.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, required this.onTap});

  final Widget child;

  /// Null draws the child dimmed and inert: the control stays visible but cannot be used.
  final VoidCallback? onTap;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return Opacity(opacity: 0.4, child: widget.child);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppMotion.press,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}
