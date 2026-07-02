import 'package:flutter/material.dart';

/// Wrap any screen body with this widget. Whenever [pulseValue] changes,
/// a brief translucent flash sweeps across the whole screen to let the
/// user know fresh data just arrived.
class ScreenPulseOverlay extends StatefulWidget {
  final int pulseValue;
  final Widget child;
  final Color color;

  const ScreenPulseOverlay({
    super.key,
    required this.pulseValue,
    required this.child,
    this.color = const Color(0xFF1B6B3A),
  });

  @override
  State<ScreenPulseOverlay> createState() => _ScreenPulseOverlayState();
}

class _ScreenPulseOverlayState extends State<ScreenPulseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.12), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.12, end: 0.0), weight: 70),
  ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant ScreenPulseOverlay old) {
    super.didUpdateWidget(old);
    if (old.pulseValue != widget.pulseValue) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _opacity,
            builder: (_, _) => Container(
              color: widget.color.withOpacity(_opacity.value),
            ),
          ),
        ),
      ],
    );
  }
}