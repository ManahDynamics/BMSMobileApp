// lib/widgets/battery_indicator.dart
//
// Reusable battery icon that fills based on a State-of-Charge (SOC) value
// (0-100), with three visual modes matching your existing status codes:
//
//   BatteryMode.charging      (statusCode 0x01) -> looping fill sweep +
//                                                    pulsing bolt overlay,
//                                                    always green
//   BatteryMode.idle          (statusCode 0x02) -> STATIC grey fill
//                                                    proportional to soc,
//                                                    with soc% text overlay,
//                                                    no animation
//   BatteryMode.loadConnected (else / 0x03)     -> bolt overlay, red fill
//                                                    below 30% soc, olive
//                                                    fill at/above 30% soc,
//                                                    animated fill transition
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
    this.width = 84,
    this.height = 40,
    this.fillAnimationDuration = const Duration(milliseconds: 400),
    this.lowColor = const Color(0xFFE53935),
    this.mediumColor = const Color(0xFFFFA726),
    this.highColor = const Color(0xFF4CAF50),
    this.loadConnectedColor = const Color(0xFF42A5F5),
    this.loadBelowColor = const Color(0xFFE53935),
    this.loadAboveColor = const Color(0xFFCDDC39),
    this.bodyColor = Colors.transparent,
    this.borderColor = Colors.white,
    this.idleColor = const Color(0xFF9AA5B1),
  });

  /// State of charge, 0-100. Values outside this range are clamped.
  final double soc;

  final BatteryMode mode;

  final double width;
  final double height;
  final Duration fillAnimationDuration;

  /// Fill color when soc <= 15 (applies in idle mode's soc-based coloring,
  /// though idle currently forces an empty fill regardless).
  final Color lowColor;

  /// Fill color when 15 < soc <= 40.
  final Color mediumColor;

  /// Fill color used while charging (always full green, regardless of soc).
  final Color highColor;

  /// Unused directly, kept for backwards compatibility.
  final Color loadConnectedColor;

  /// loadConnected fill color when soc < 30.
  final Color loadBelowColor;

  /// loadConnected fill color when soc >= 30.
  final Color loadAboveColor;

  final Color bodyColor;
  final Color borderColor;

  /// Fill color for idle mode (always grey, regardless of soc).
  final Color idleColor;

  @override
  State<BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator>
    with TickerProviderStateMixin {
  AnimationController? _pulseController;
  AnimationController? _fillSweepController;

  @override
  void initState() {
    super.initState();
    _syncPulseController();
    _syncFillSweepController();
  }

  @override
  void didUpdateWidget(covariant BatteryIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _syncPulseController();
      _syncFillSweepController();
    }
  }

  void _syncPulseController() {
    final needsPulse = widget.mode == BatteryMode.charging ||
        widget.mode == BatteryMode.loadConnected;
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

  void _syncFillSweepController() {
    final needsSweep = widget.mode == BatteryMode.charging;
    if (needsSweep && _fillSweepController == null) {
      _fillSweepController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      )..repeat();
    } else if (!needsSweep && _fillSweepController != null) {
      _fillSweepController!.dispose();
      _fillSweepController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _fillSweepController?.dispose();
    super.dispose();
  }

  Color _fillColorForSoc(double value) {
    switch (widget.mode) {
      case BatteryMode.charging:
        return const Color(0xFF34C759);

      case BatteryMode.loadConnected:
        return value < 30
            ? const Color(0xFFF44336)
            : const Color(0xFFB7C93A);

      case BatteryMode.idle:
        return widget.idleColor; // grey fill, proportional to soc
    }
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
        return Icon(
          Icons.bolt,
          size: iconSize,
          color: Colors.white,
        );
      case BatteryMode.idle:
        final socValue = widget.soc.clamp(0, 100).toInt();
        return Text(
          '$socValue%',
          style: TextStyle(
            fontSize: iconSize * 0.6,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Charging: looping fill sweep (0 -> 100, then resets), independent
    // of the actual soc value, with pulsing bolt overlay. ───────────────
    if (widget.mode == BatteryMode.charging) {
      return AnimatedBuilder(
        animation: _fillSweepController!,
        builder: (context, child) {
          final sweepSoc = _fillSweepController!.value * 100;
          final overlay = _buildOverlayIcon(widget.height * 0.55);
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _BatteryPainter(
                soc: sweepSoc,
                fillColor: widget.highColor,
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

    final clamped = widget.soc.clamp(0, 100).toDouble();

    // ── Idle: STATIC grey fill proportional to soc, with soc% overlay.
    // No animation needed here. ─────────────────────────────────────────
    if (widget.mode == BatteryMode.idle) {
      final overlay = _buildOverlayIcon(widget.height * 0.7);
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _BatteryPainter(
            soc: clamped,
            fillColor: _fillColorForSoc(clamped),
            bodyColor: widget.bodyColor,
            borderColor: widget.borderColor,
          ),
          child: overlay == null
              ? null
              : Align(alignment: Alignment.center, child: overlay),
        ),
      );
    }

    // ── loadConnected: animated fill transition, color depends on soc. ──
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
  const _BatteryPainter({
    required this.soc,
    required this.fillColor,
    required this.bodyColor,
    required this.borderColor,
  });

  final double soc;
  final Color fillColor;
  final Color bodyColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * 0.085;

    final bodyWidth = size.width * 0.94;
    final terminalWidth = size.width * 0.065;
    final terminalHeight = size.height * 0.40;

    final bodyRect = Rect.fromLTWH(
      stroke,
      stroke,
      bodyWidth - stroke,
      size.height - stroke * 2,
    );

    final body = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(size.height * 0.22),
    );

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3;

    canvas.drawRRect(body, borderPaint);

    // Battery terminal
    final terminalRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bodyWidth,
        (size.height - terminalHeight) / 2,
        terminalWidth,
        terminalHeight,
      ),
      Radius.circular(2),
    );

    canvas.drawRRect(
      terminalRect,
      Paint()..color = Colors.white,
    );

    // Idle battery
    if (soc <= 0) return;

    final padding = size.height * 0.11;

    final innerWidth = bodyRect.width - padding * 2;

    final fillWidth = innerWidth * (soc.clamp(0, 100) / 100);

    final fillRect = Rect.fromLTWH(
      bodyRect.left + padding,
      bodyRect.top + padding,
      fillWidth,
      bodyRect.height - padding * 2,
    );

    final fill = RRect.fromRectAndRadius(
      fillRect,
      Radius.circular(size.height * 0.12),
    );

    canvas.drawRRect(
      fill,
      Paint()..color = fillColor,
    );
  }

  @override
  bool shouldRepaint(_BatteryPainter oldDelegate) {
    return oldDelegate.soc != soc || oldDelegate.fillColor != fillColor;
  }
}