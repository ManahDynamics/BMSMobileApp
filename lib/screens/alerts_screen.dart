// lib/screens/alerts_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';
// import '../../../modules/scanner/screens/bluetooth_device_scan_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class AlertItem {
  final String titleKey;
  final String descriptionKey;
  final String time;
  final String severityKey;
  final String severityRaw;
  final String statusKey;
  final String statusRaw;
  final String dateGroupKey;
  final String dateGroupLabel;

  const AlertItem({
    required this.titleKey,
    required this.descriptionKey,
    required this.time,
    required this.severityKey,
    required this.severityRaw,
    required this.statusKey,
    required this.statusRaw,
    required this.dateGroupKey,
    required this.dateGroupLabel,
  });
}

const List<AlertItem> _allAlerts = [
  // ... (your alert data remains unchanged)
  AlertItem(
    titleKey: 'alert_over_temperature',
    descriptionKey: 'alert_over_temperature_desc',
    time: '10:24 AM',
    severityKey: 'severity_high',
    severityRaw: 'High',
    statusKey: 'status_active',
    statusRaw: 'Active',
    dateGroupKey: 'date_today',
    dateGroupLabel: 'Today - 20 May 2026',
  ),
  AlertItem(
    titleKey: 'alert_cell_imbalance',
    descriptionKey: 'alert_cell_imbalance_desc',
    time: '10:15 AM',
    severityKey: 'severity_medium',
    severityRaw: 'Medium',
    statusKey: 'status_active',
    statusRaw: 'Active',
    dateGroupKey: 'date_today',
    dateGroupLabel: 'Today - 20 May 2026',
  ),
  AlertItem(
    titleKey: 'alert_low_voltage',
    descriptionKey: 'alert_low_voltage_desc',
    time: '09:15 AM',
    severityKey: 'severity_medium',
    severityRaw: 'Medium',
    statusKey: 'status_warning',
    statusRaw: 'Warning',
    dateGroupKey: 'date_yesterday',
    dateGroupLabel: 'Yesterday - 19 May 2026',
  ),
  AlertItem(
    titleKey: 'alert_high_voltage',
    descriptionKey: 'alert_high_voltage_desc',
    time: '09:13 AM',
    severityKey: 'severity_medium',
    severityRaw: 'Medium',
    statusKey: 'status_warning',
    statusRaw: 'Warning',
    dateGroupKey: 'date_yesterday',
    dateGroupLabel: 'Yesterday - 19 May 2026',
  ),
  AlertItem(
    titleKey: 'alert_over_current_charge',
    descriptionKey: 'alert_over_current_charge_desc',
    time: '07:15 AM',
    severityKey: 'severity_high',
    severityRaw: 'High',
    statusKey: 'status_cleared',
    statusRaw: 'Cleared',
    dateGroupKey: 'date_yesterday',
    dateGroupLabel: 'Yesterday - 19 May 2026',
  ),
  AlertItem(
    titleKey: 'alert_short_circuit',
    descriptionKey: 'alert_short_circuit_desc',
    time: '06:24 AM',
    severityKey: 'severity_high',
    severityRaw: 'High',
    statusKey: 'status_cleared',
    statusRaw: 'Cleared',
    dateGroupKey: 'date_18_may',
    dateGroupLabel: '18 May 2026',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
Color _severityColor(String raw) {
  if (raw == 'High') return const Color(0xFF1B6B3A);
  if (raw == 'Medium') return const Color(0xFFB8860B);
  return Colors.grey;
}

Color _statusColor(String raw) {
  if (raw == 'Active') return const Color(0xFFD4621A);
  if (raw == 'Warning') return const Color(0xFFB8860B);
  return const Color(0xFF3A6EAC);
}

IconData _statusIcon(String raw) {
  if (raw == 'Active') return Icons.warning_amber_rounded;
  if (raw == 'Warning') return Icons.info_outline_rounded;
  return Icons.check_circle_outline_rounded;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared alert card
// ─────────────────────────────────────────────────────────────────────────────
Widget buildAlertCard(AlertItem alert, {bool showStatus = false, required String Function(String) tr}) {
  final severityColor = _severityColor(alert.severityRaw);
  final statusColor = _statusColor(alert.statusRaw);
  final statusIcon = _statusIcon(alert.statusRaw);

  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(statusIcon, color: statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(alert.titleKey),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 3),
              Text(
                tr(alert.descriptionKey),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showStatus)
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  tr(alert.statusKey),
                  style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                Text(alert.time,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ])
            else
              Text(alert.time,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: severityColor),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tr(alert.severityKey),
                style: TextStyle(
                    fontSize: 12,
                    color: severityColor,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERTS SCREEN (Now Stateful)
// ─────────────────────────────────────────────────────────────────────────────
class AlertsScreen extends StatefulWidget {
  final BMSBluetoothService service;

  const AlertsScreen({super.key, required this.service});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String tr(String key) => TranslationService.t(key);

  // Listen to translation changes
  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onTranslationsChanged);
  }

  void _onTranslationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    TranslationService.instance.removeListener(_onTranslationsChanged);
    super.dispose();
  }

  List<AlertItem> get _active =>
      _allAlerts.where((a) => a.statusRaw == 'Active').toList();
  List<AlertItem> get _warnings =>
      _allAlerts.where((a) => a.statusRaw == 'Warning').toList();
  List<AlertItem> get _cleared =>
      _allAlerts.where((a) => a.statusRaw == 'Cleared').toList();

  // ── Disconnect ─────────────────────────────────────────────────────────────
  Future<void> _handleDisconnect(BuildContext context) async {
    await widget.service.disconnect();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      SlideRoute(page: BluetoothDeviceScanPage(service: widget.service)),
      (route) => false,
    );
  }

  void _showDisconnectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr('disconnect'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          tr('disconnect_confirmation'),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleDisconnect(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4621A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(tr('disconnect')),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.battery_4_bar_rounded, color: Colors.black54, size: 32),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BMS_001',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 3),
            Row(children: [
              Text(
                tr('connected'),
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1B6B3A),
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF1B6B3A), shape: BoxShape.circle)),
            ]),
          ],
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () => _showDisconnectDialog(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4621A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            tr('disconnect').toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(activeRoute: '/alerts', service: widget.service),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        title: Text(
          tr('alerts').toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceHeader(context),
            const SizedBox(height: 16),
            _buildSummaryBar(),
            const SizedBox(height: 20),
            _buildSectionHeader(
              '${tr('active_alerts')} (${_active.length})',
              showViewAll: true,
              context: context,
            ),
            const SizedBox(height: 10),
            ..._active.map((a) => buildAlertCard(a, tr: tr)),
            const SizedBox(height: 10),
            _buildSectionHeader('${tr('warnings')} (${_warnings.length})'),
            const SizedBox(height: 10),
            ..._warnings.map((a) => buildAlertCard(a, tr: tr)),
            const SizedBox(height: 10),
            _buildSectionHeader('${tr('cleared_alerts')} (${_cleared.length})'),
            const SizedBox(height: 10),
            ..._cleared.map((a) => buildAlertCard(a, tr: tr)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  SlideRoute(page: AlertHistoryScreen(service: widget.service)),
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
                label: Text(
                  tr('alert_history'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.grey[500], size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('alerts_support_note'),
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ... (_buildSummaryBar, _summaryItem, _divider, _buildSectionHeader remain same)
  Widget _buildSummaryBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF3A6EAC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _summaryItem(Icons.notifications_outlined, tr('alerts_label'), _allAlerts.length.toString()),
            _divider(),
            _summaryItem(Icons.warning_amber_rounded, tr('status_active'), _active.length.toString()),
            _divider(),
            _summaryItem(Icons.info_outline_rounded, tr('warnings'), _warnings.length.toString()),
            _divider(),
            _summaryItem(Icons.check_circle_outline_rounded, tr('status_cleared'), _cleared.length.toString()),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(IconData icon, String label, String count) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 2),
            Text(count, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white.withOpacity(0.25),
    );
  }

  Widget _buildSectionHeader(String title, {bool showViewAll = false, BuildContext? context}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        if (showViewAll && context != null)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              SlideRoute(page: AlertHistoryScreen(service: widget.service)),
            ),
            child: Row(children: [
              Text(tr('view_all'),
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4F4F4F),
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF4F4F4F)),
            ]),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT HISTORY SCREEN (Also Updated)
// ─────────────────────────────────────────────────────────────────────────────
class AlertHistoryScreen extends StatefulWidget {
  final BMSBluetoothService service;

  const AlertHistoryScreen({super.key, required this.service});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  String tr(String key) => TranslationService.t(key);

  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onTranslationsChanged);
  }

  void _onTranslationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    TranslationService.instance.removeListener(_onTranslationsChanged);
    super.dispose();
  }

  // ... rest of your existing logic for tabs and filters remains the same
  static const String _tabAll = 'All';
  static const String _tabActive = 'Active';
  static const String _tabWarnings = 'Warnings';
  static const String _tabCleared = 'Cleared';

  String _selectedTabRaw = _tabAll;
  String _selectedFilterRaw = 'All Severity';

  Map<String, String> get _tabLabels => {
        _tabAll: tr('filter_all'),
        _tabActive: tr('status_active'),
        _tabWarnings: tr('warnings'),
        _tabCleared: tr('status_cleared'),
      };

  Map<String, String> get _filterLabels => {
        'All Severity': tr('filter_all_severity'),
        'High': tr('severity_high'),
        'Medium': tr('severity_medium'),
        'Low': tr('severity_low'),
      };

  List<AlertItem> get _filtered {
    var list = List<AlertItem>.from(_allAlerts);
    if (_selectedTabRaw != _tabAll) {
      final map = {
        _tabActive: 'Active',
        _tabWarnings: 'Warning',
        _tabCleared: 'Cleared',
      };
      list = list.where((a) => a.statusRaw == map[_selectedTabRaw]).toList();
    }
    if (_selectedFilterRaw != 'All Severity') {
      list = list.where((a) => a.severityRaw == _selectedFilterRaw).toList();
    }
    return list;
  }

  Map<String, List<AlertItem>> get _grouped {
    final map = <String, List<AlertItem>>{};
    for (final a in _filtered) {
      map.putIfAbsent(a.dateGroupLabel, () => []).add(a);
    }
    return map;
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────
  Future<void> _handleDisconnect() async {
    await widget.service.disconnect();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      SlideRoute(page: BluetoothDeviceScanPage(service: widget.service)),
      (route) => false,
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr('disconnect'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          tr('disconnect_confirmation'),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel'),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleDisconnect();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4621A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(tr('disconnect')),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.battery_4_bar_rounded,
              color: Colors.black54, size: 32),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BMS_001',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 3),
            Row(children: [
              Text(
                tr('connected'),
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1B6B3A),
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF1B6B3A), shape: BoxShape.circle)),
            ]),
          ],
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _showDisconnectDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4621A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            tr('disconnect').toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showFilterMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context)
        .overlay!
        .context
        .findRenderObject() as RenderBox;
    final Offset off =
        button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size sz = button.size;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        off.dx,
        off.dy + sz.height + 4,
        overlay.size.width - off.dx - sz.width,
        0,
      ),
      elevation: 6,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: _filterLabels.entries
          .map((entry) => PopupMenuItem<String>(
                value: entry.key,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.value,
                        style: const TextStyle(fontSize: 14)),
                    if (_selectedFilterRaw == entry.key)
                      const Icon(Icons.check,
                          color: Color(0xFF1B6B3A), size: 18),
                  ],
                ),
              ))
          .toList(),
    );
    if (result != null) setState(() => _selectedFilterRaw = result);
  }

  @override
  Widget build(BuildContext context) {
    final grouped   = _grouped;
    final dateKeys  = grouped.keys.toList(); // stable dateGroupLabel keys

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        title: Text(
          tr('alert_history').toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDeviceHeader(),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _tabLabels.entries
                        .map((e) => _buildTab(e.key, e.value))
                        .toList(),
                  ),
                ),
                const Divider(height: 15),
                Align(
                  alignment: Alignment.centerRight,
                  child: Builder(
                    builder: (ctx) => GestureDetector(
                      onTap: () => _showFilterMenu(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCCCCCC)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedFilterRaw == 'All Severity'
                                  ? tr('filter')
                                  : _filterLabels[_selectedFilterRaw]!,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: dateKeys.length,
                itemBuilder: (context, gi) {
                  final groupLabel = dateKeys[gi];
                  final items = grouped[groupLabel]!;
                  final translatedDate = tr(items.first.dateGroupKey);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translatedDate,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ...items.map((a) => buildAlertCard(a, showStatus: true, tr: tr)),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String rawKey, String label) {
    final isActive = _selectedTabRaw == rawKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabRaw = rawKey),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF3A6EAC)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                isActive ? FontWeight.bold : FontWeight.w400,
            color: isActive ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}