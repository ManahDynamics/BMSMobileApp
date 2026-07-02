// lib/widgets/battery_indicator.dart
//
// Reusable battery icon that fills based on a State-of-Charge (SOC) value
// (0-100), with three visual modes matching your existing status codes:
//
//   BatteryMode.charging      (statusCode 0x01) -> pulsing bolt overlay
//   BatteryMode.idle          (statusCode 0x02) -> plain fill, no overlay
//   BatteryMode.loadConnected (else / 0x03)     -> load/discharge overlay
//
// Whenever `soc` changes, the fill animates smoothly to the new level
// instead of snapping instantly (the "autoincrement" effect). Whenever
// `mode` changes, drop this widget straight into your existing
// AnimatedSwitcher with a ValueKey(mode) and it will crossfade as before.
//
// Usage:
//   BatteryIndicator(
//     key: ValueKey(widget.statusCode),
//     soc: liveSoc,               // 0-100
//     mode: widget.statusCode == 0x01
//         ? BatteryMode.charging
//         : widget.statusCode == 0x02
//             ? BatteryMode.idle
//             : BatteryMode.loadConnected,
//     width: 60,
//     height: 30,
//   )

import 'package:flutter/material.dart';

enum BatteryMode { charging, idle, loadConnected }

class BatteryIndicator extends StatefulWidget {
  const BatteryIndicator({
    super.key,
    required this.soc,
    required this.mode,
    this.width = 60,
    this.height = 30,
    this.fillAnimationDuration = const Duration(milliseconds: 700),
    this.lowColor = const Color(0xFFE53935),
    this.mediumColor = const Color(0xFFFFA726),
    this.highColor = const Color(0xFF4CAF50),
    this.loadConnectedColor = const Color(0xFF42A5F5),
    this.bodyColor = const Color(0xFFBDBDBD),
    this.borderColor = const Color(0xFF9E9E9E),
  });

  /// State of charge, 0-100. Values outside this range are clamped.
  final double soc;

  final BatteryMode mode;

  final double width;
  final double height;
  final Duration fillAnimationDuration;

  /// Fill color when soc <= 15 (applies in charging/idle modes).
  final Color lowColor;

  /// Fill color when 15 < soc <= 40.
  final Color mediumColor;

  /// Fill color when soc > 40.
  final Color highColor;

  /// Fill color override used for loadConnected mode, regardless of soc
  /// band, so the "discharging under load" state reads visually distinct.
  final Color loadConnectedColor;

  final Color bodyColor;
  final Color borderColor;

  @override
  State<BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _syncPulseController();
  }

  @override
  void didUpdateWidget(covariant BatteryIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _syncPulseController();
    }
  }

  void _syncPulseController() {
    final needsPulse = widget.mode == BatteryMode.charging;
    if (needsPulse && _pulseController == null) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
    } else if (!needsPulse && _pulseController != null) {
      _pulseController!.dispose();
      _pulseController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  Color _fillColorForSoc(double value) {
    if (widget.mode == BatteryMode.loadConnected) {
      return widget.loadConnectedColor;
    }
    if (value <= 15) return widget.lowColor;
    if (value <= 40) return widget.mediumColor;
    return widget.highColor;
  }

  Widget? _buildOverlayIcon(double iconSize) {
    switch (widget.mode) {
      case BatteryMode.charging:
        final controller = _pulseController!;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final opacity = 0.45 + (controller.value * 0.55);
            return Opacity(opacity: opacity, child: child);
          },
          child: Icon(
            Icons.bolt,
            size: iconSize,
            color: Colors.white,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
          ),
        );
      case BatteryMode.loadConnected:
        // Placeholder icon for "load connected / discharging under load" —
        // swap for whatever matches load_connect.png's intent.
        return Icon(
          Icons.arrow_circle_down_outlined,
          size: iconSize,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
        );
      case BatteryMode.idle:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clamped = widget.soc.clamp(0, 100).toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: clamped),
      duration: widget.fillAnimationDuration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedSoc, child) {
        final overlay = _buildOverlayIcon(widget.height * 0.7);
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: CustomPaint(
            painter: _BatteryPainter(
              soc: animatedSoc,
              fillColor: _fillColorForSoc(animatedSoc),
              bodyColor: widget.bodyColor,
              borderColor: widget.borderColor,
            ),
            child: overlay == null
                ? null
                : Align(alignment: Alignment.center, child: overlay),
          ),
        );
      },
    );
  }
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter({
    required this.soc,
    required this.fillColor,
    required this.bodyColor,
    required this.borderColor,
  });

  final double soc; // 0-100, already animated/interpolated
  final Color fillColor;
  final Color bodyColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final nubWidth = size.width * 0.06;
    final nubHeight = size.height * 0.4;
    final bodyWidth = size.width - nubWidth;
    final cornerRadius = size.height * 0.28;
    const strokePad = 1.5;

    // ── Battery body (outline + background) ──────────────────────────
    final bodyRect = Rect.fromLTWH(
      strokePad,
      strokePad,
      bodyWidth - strokePad * 2,
      size.height - strokePad * 2,
    );
    final bodyRRect =
        RRect.fromRectAndRadius(bodyRect, Radius.circular(cornerRadius));

    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bodyRRect, bodyPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokePad * 1.4;
    canvas.drawRRect(bodyRRect, borderPaint);

    // ── Terminal nub on the right ─────────────────────────────────────
    final nubRect = Rect.fromLTWH(
      bodyWidth - 1,
      (size.height - nubHeight) / 2,
      nubWidth,
      nubHeight,
    );
    final nubRRect = RRect.fromRectAndCorners(
      nubRect,
      topRight: Radius.circular(nubHeight * 0.3),
      bottomRight: Radius.circular(nubHeight * 0.3),
    );
    canvas.drawRRect(nubRRect, Paint()..color = borderColor);

    // ── Fill, inset from the body, width proportional to soc ──────────
    final inset = size.height * 0.16;
    final innerRect = Rect.fromLTWH(
      strokePad + inset,
      strokePad + inset,
      bodyWidth - strokePad * 2 - inset * 2,
      size.height - strokePad * 2 - inset * 2,
    );
    final fillWidth = innerRect.width * (soc / 100).clamp(0.0, 1.0);

    if (fillWidth > 0) {
      final fillRect = Rect.fromLTWH(
        innerRect.left,
        innerRect.top,
        fillWidth,
        innerRect.height,
      );
      final fillRadius = Radius.circular((cornerRadius - inset).clamp(0, 999));
      final fillRRect = RRect.fromRectAndRadius(fillRect, fillRadius);
      canvas.drawRRect(fillRRect, Paint()..color = fillColor);
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return oldDelegate.soc != soc ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.bodyColor != bodyColor ||
        oldDelegate.borderColor != borderColor;
  }
}