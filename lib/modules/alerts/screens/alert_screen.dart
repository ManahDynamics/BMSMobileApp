// lib/screens/alerts_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import '../../../modules/scanner/screens/BMS_scanner_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/services/local_auth_db.dart';

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
  return const Color(0xFF1B6B3A);
}

IconData _statusIcon(String raw) {
  if (raw == 'Active') return Icons.warning_amber_rounded;
  if (raw == 'Warning') return Icons.info_outline_rounded;
  return Icons.check_circle_outline_rounded;
}

/// Converts a cached alert map (saved by DashboardScreen via
/// `LocalAuthDB.saveAlerts`) into an [AlertItem] so it can be rendered using
/// the same card/list widgets as the static demo alerts below.
AlertItem _cachedMapToAlertItem(Map<String, dynamic> m) {
  final title = (m['title'] ?? 'Alert').toString();
  final time = (m['time'] ?? '').toString();

  // Slightly higher severity for thermal / battery-critical events.
  final lower = title.toLowerCase();
  final isHigh = lower.contains('over temperature') ||
      lower.contains('under temperature') ||
      lower.contains('low battery');

  return AlertItem(
    titleKey: title, // raw text — TranslationService falls back to the key
    descriptionKey: 'live_alert_from_device',
    time: time,
    severityKey: isHigh ? 'severity_high' : 'severity_medium',
    severityRaw: isHigh ? 'High' : 'Medium',
    statusKey: 'status_active',
    statusRaw: 'Active',
    dateGroupKey: 'date_today',
    dateGroupLabel: 'Today',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared alert card (kept for AlertHistoryScreen)
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
// ALERTS SCREEN — redesigned to match mockup
// (device id header · bell badge · overflow menu · "Last Fetched On" row ·
//  4-card filter bar · flat icon/dot/chevron rows)
// ─────────────────────────────────────────────────────────────────────────────
class AlertsScreen extends StatefulWidget {
  final BMSBluetoothService service;

  const AlertsScreen({super.key, required this.service});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

enum _AlertFilter { total, warnings, faults, cleared }

class _AlertsScreenState extends State<AlertsScreen> {
  final LocalAuthDB _localAuthDB = LocalAuthDB();

  String tr(String key) => TranslationService.t(key);

  // ── Cached / live alert state ────────────────────────────────────────────
  List<AlertItem> _liveAlerts = [];
  DateTime? _lastSync;
  bool _isOffline = false;
  bool _isLoadingCache = true;
  _AlertFilter _selectedFilter = _AlertFilter.total;

  // Listen to translation + BLE service changes
  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onTranslationsChanged);
    widget.service.addListener(_onServiceChanged);
    _loadCachedAlerts();
  }

  void _onTranslationsChanged() {
    if (mounted) setState(() {});
  }

  void _onServiceChanged() {
    if (!mounted) return;
    // Whenever fresh BLE data arrives, refresh from the latest cache too,
    // since DashboardScreen writes new alerts into LocalAuthDB as data changes.
    _loadCachedAlerts();
  }

  @override
  void dispose() {
    TranslationService.instance.removeListener(_onTranslationsChanged);
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  /// Pulls cached alerts (written by DashboardScreen) + last sync time from
  /// LocalAuthDB, and figures out whether we're currently showing stale
  /// (offline) data based on whether the BLE service has live dashboard data.
  Future<void> _loadCachedAlerts() async {
    final cached = await _localAuthDB.getCachedAlerts();
    final syncTime = await _localAuthDB.getLastSyncTime();
    if (!mounted) return;

    setState(() {
      _liveAlerts = (cached ?? []).map(_cachedMapToAlertItem).toList();
      _lastSync = syncTime;
      _isOffline = widget.service.latestDashboard == null;
      _isLoadingCache = false;
    });
  }

  String _formatSyncTime(DateTime? dt) {
    if (dt == null) return 'unknown time';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatSyncDate(DateTime? dt) {
    final d = dt ?? DateTime.now();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd-$mm-$yyyy';
  }

  // Real (live/cached) alerts take priority; static demo data fills in the rest.
  List<AlertItem> get _combined => [..._liveAlerts, ..._allAlerts];
  List<AlertItem> get _faults =>
      _combined.where((a) => a.statusRaw == 'Active').toList();
  List<AlertItem> get _warnings =>
      _combined.where((a) => a.statusRaw == 'Warning').toList();
  List<AlertItem> get _cleared =>
      _combined.where((a) => a.statusRaw == 'Cleared').toList();

  List<AlertItem> get _filteredAlerts {
    switch (_selectedFilter) {
      case _AlertFilter.faults:
        return _faults;
      case _AlertFilter.warnings:
        return _warnings;
      case _AlertFilter.cleared:
        return _cleared;
      case _AlertFilter.total:
        return _combined;
    }
  }

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

  // ── AppBar: title + device id, bell badge, overflow menu ────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final badgeCount = _faults.length + _warnings.length;

    return AppBar(
      backgroundColor: const Color(0xFF1B6B3A),
      elevation: 0,
      centerTitle: true,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('alerts').toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          const Text(
            'BMS_001',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
              onPressed: () {},
            ),
            if (badgeCount > 0)
              Positioned(
                right: 6,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4621A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1B6B3A), width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    badgeCount.toString().padLeft(2, '0'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onSelected: (value) {
            if (value == 'disconnect') _showDisconnectDialog(context);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'disconnect', child: Text(tr('disconnect'))),
          ],
        ),
      ],
    );
  }

  // ── "Last Fetched On …" row ──────────────────────────────────────────────
  Widget _buildLastFetchedRow() {
    return Row(
      children: [
        Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          '${tr('last_fetched_on')} ${_formatSyncDate(_lastSync)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    if (_isLoadingCache || !_isOffline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 14, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — showing alerts from ${_formatSyncTime(_lastSync)}',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4-card filter bar (Total / Warnings / Faults / Cleared) ─────────────
  Widget _buildFilterBar() {
    final items = <_FilterCardData>[
      _FilterCardData(
        filter: _AlertFilter.total,
        icon: Icons.notifications_none_rounded,
        label: tr('total_alerts'),
        count: _combined.length,
      ),
      _FilterCardData(
        filter: _AlertFilter.warnings,
        icon: Icons.info_outline_rounded,
        label: tr('warnings'),
        count: _warnings.length,
      ),
      _FilterCardData(
        filter: _AlertFilter.faults,
        icon: Icons.warning_amber_rounded,
        label: tr('faults'),
        count: _faults.length,
      ),
      _FilterCardData(
        filter: _AlertFilter.cleared,
        icon: Icons.check_circle_outline_rounded,
        label: tr('cleared_alerts'),
        count: _cleared.length,
      ),
    ];

    return Row(
      children: items
          .map((item) => Expanded(child: _buildFilterCard(item)))
          .toList(),
    );
  }

  Widget _buildFilterCard(_FilterCardData item) {
    final bool selected = _selectedFilter == item.filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = item.filter),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3A6EAC) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: selected ? null : Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon,
                size: 20, color: selected ? Colors.white : const Color(0xFF3A6EAC)),
            const SizedBox(height: 6),
            Text(
              item.count.toString().padLeft(2, '0'),
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5,
                  color: selected ? Colors.white70 : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Flat alert row: icon · title/time · status dot · chevron ────────────
  Widget _buildAlertRow(AlertItem alert) {
    final statusColor = _statusColor(alert.statusRaw);
    final statusIcon = _statusIcon(alert.statusRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Icon(statusIcon, size: 17, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(alert.titleKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                const SizedBox(height: 3),
                Text(
                  alert.time,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[400]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAlerts;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(activeRoute: '/alerts', service: widget.service),
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _loadCachedAlerts,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLastFetchedRow(),
                  _buildOfflineBanner(),
                  const SizedBox(height: 14),
                  _buildFilterBar(),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingCache
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            const SizedBox(height: 40),
                            Center(
                              child: Text(
                                tr('no_alerts_found'),
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _buildAlertRow(filtered[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterCardData {
  final _AlertFilter filter;
  final IconData icon;
  final String label;
  final int count;

  _FilterCardData({
    required this.filter,
    required this.icon,
    required this.label,
    required this.count,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT HISTORY SCREEN (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class AlertHistoryScreen extends StatefulWidget {
  final BMSBluetoothService service;

  const AlertHistoryScreen({super.key, required this.service});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  final LocalAuthDB _localAuthDB = LocalAuthDB();

  String tr(String key) => TranslationService.t(key);

  List<AlertItem> _liveAlerts = [];

  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onTranslationsChanged);
    _loadCachedAlerts();
  }

  void _onTranslationsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCachedAlerts() async {
    final cached = await _localAuthDB.getCachedAlerts();
    if (!mounted) return;
    setState(() {
      _liveAlerts = (cached ?? []).map(_cachedMapToAlertItem).toList();
    });
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

  List<AlertItem> get _combinedAlerts => [..._liveAlerts, ..._allAlerts];

  List<AlertItem> get _filtered {
    var list = List<AlertItem>.from(_combinedAlerts);
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
