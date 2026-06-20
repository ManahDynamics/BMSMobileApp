// lib/widgets/debug_log_overlay.dart
//
// Drop-in, on-screen debug log viewer for BMSBluetoothService.
//
// USAGE:
//   1. Make sure BMSBluetoothService.addDebugLog() actually stores logs
//      (see the updated bluetooth_service.dart snippet provided alongside
//      this file — _debugLogs list + public getter `debugLogs`).
//   2. Wrap your scan screen's body (or just float it on top) with this:
//
//        Stack(
//          children: [
//            yourExistingScanScreenBody,
//            DebugLogOverlay(service: widget.service),
//          ],
//        )
//
//      It renders as a small collapsible panel pinned to the bottom of the
//      screen so it doesn't block your existing UI.

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';

class DebugLogOverlay extends StatefulWidget {
  final BMSBluetoothService service;
  final double collapsedHeight;
  final double expandedHeight;

  const DebugLogOverlay({
    super.key,
    required this.service,
    this.collapsedHeight = 36,
    this.expandedHeight = 260,
  });

  @override
  State<DebugLogOverlay> createState() => _DebugLogOverlayState();
}

class _DebugLogOverlayState extends State<DebugLogOverlay> {
  bool _expanded = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {});
    // Auto-scroll to bottom (newest log) on every update.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _colorForLog(String log) {
    if (log.contains('❌')) return Colors.redAccent;
    if (log.contains('✅') || log.contains('🚀')) return Colors.greenAccent;
    if (log.contains('⚠️')) return Colors.orangeAccent;
    if (log.contains('📊') || log.contains('🔋')) return Colors.cyanAccent;
    if (log.contains('📥')) return Colors.blueAccent;
    if (log.contains('📤')) return Colors.purpleAccent;
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    final logs = widget.service.debugLogs;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.black.withValues(alpha: 0.92),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _expanded ? widget.expandedHeight : widget.collapsedHeight,
          child: Column(
            children: [
              // ── Header bar (always visible, tap to expand/collapse) ──
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  height: widget.collapsedHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: Colors.grey.shade900,
                  child: Row(
                    children: [
                      Icon(
                        _expanded ? Icons.expand_more : Icons.expand_less,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Debug Log',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${logs.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ),
                      const Spacer(),
                      // Current connection state, always visible at a glance
                      Text(
                        widget.service.state.name,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => widget.service.clearDebugLogs(),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white54, size: 16),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Log list (only when expanded) ──
              if (_expanded)
                Expanded(
                  child: logs.isEmpty
                      ? const Center(
                          child: Text(
                            'No logs yet — connect to a device',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          itemCount: logs.length,
                          itemBuilder: (_, i) {
                            final log = logs[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                              child: Text(
                                log,
                                style: TextStyle(
                                  color: _colorForLog(log),
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  height: 1.3,
                                ),
                              ),
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}