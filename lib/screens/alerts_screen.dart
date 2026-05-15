// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class AlertItem {
  final String title;
  final String description;
  final String time;
  final String severity;   // 'High' | 'Medium' | 'Low'
  final String status;     // 'Active' | 'Warning' | 'Cleared'
  final String dateGroup;  // e.g. 'Today - 20 May 2026'

  const AlertItem({
    required this.title,
    required this.description,
    required this.time,
    required this.severity,
    required this.status,
    required this.dateGroup,
  });
}

const List<AlertItem> _allAlerts = [
  AlertItem(
    title: 'Over Temperature',
    description: 'Battery Temperature is too high',
    time: '10:24 AM',
    severity: 'High',
    status: 'Active',
    dateGroup: 'Today - 20 May 2026',
  ),
  AlertItem(
    title: 'Call Imbalance',
    description: 'Cells are imbalanced. Check cell details.',
    time: '10:15 AM',
    severity: 'Medium',
    status: 'Active',
    dateGroup: 'Today - 20 May 2026',
  ),
  AlertItem(
    title: 'Low Voltage',
    description: 'Pack voltage is below warning level.',
    time: '09:15 AM',
    severity: 'Medium',
    status: 'Warning',
    dateGroup: 'Yesterday - 19 May 2026',
  ),
  AlertItem(
    title: 'High Voltage',
    description: 'Pack voltage is above warning level.',
    time: '09:13 AM',
    severity: 'Medium',
    status: 'Warning',
    dateGroup: 'Yesterday - 19 May 2026',
  ),
  AlertItem(
    title: 'Over Current(Charge)',
    description: 'Charging current exceeded limit.',
    time: '07:15 AM',
    severity: 'High',
    status: 'Cleared',
    dateGroup: 'Yesterday - 19 May 2026',
  ),
  AlertItem(
    title: 'Short Circuit',
    description: 'Short circuit condition cleared.',
    time: '06:24 AM',
    severity: 'High',
    status: 'Cleared',
    dateGroup: '18 May 2026',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
Color _severityColor(String s) {
  if (s == 'High') return const Color(0xFF1B6B3A);
  if (s == 'Medium') return const Color(0xFFB8860B);
  return Colors.grey;
}

Color _statusColor(String s) {
  if (s == 'Active') return const Color(0xFFD4621A);
  if (s == 'Warning') return const Color(0xFFB8860B);
  return const Color(0xFF3A6EAC);
}

IconData _statusIcon(String s) {
  if (s == 'Active') return Icons.warning_amber_rounded;
  if (s == 'Warning') return Icons.info_outline_rounded;
  return Icons.check_circle_outline_rounded;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared: device header + disconnect
// ─────────────────────────────────────────────────────────────────────────────
Widget buildDeviceHeader(BuildContext context, VoidCallback onDisconnect) {
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
            const Text('Connected',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1B6B3A),
                    fontWeight: FontWeight.w500)),
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
        onPressed: onDisconnect,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4621A),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: const Text('DISCONNECT',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                )),
      ),
    ],
  );
}

void showDisconnectDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Disconnect',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: const Text(
        'Are you sure you want to disconnect from BMS_001?',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            Navigator.pushAndRemoveUntil(
              context,
              SlideRoute(page: const BluetoothDeviceScanPage()),
              (route) => false,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4621A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('Disconnect'),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Alert card (shared between both screens)
// ─────────────────────────────────────────────────────────────────────────────
Widget buildAlertCard(AlertItem alert, {bool showStatus = false}) {
  final severityColor = _severityColor(alert.severity);
  final statusColor = _statusColor(alert.status);
  final statusIcon = _statusIcon(alert.status);

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
        // Status icon
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(statusIcon, color: statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        // Title + desc
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alert.title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 3),
              Text(alert.description,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Right column: status dot + time + severity badge
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Status dot + label (only in history screen)
            if (showStatus)
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(alert.status,
                    style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                Text(alert.time,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600])),
              ])
            else
              Text(alert.time,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 6),
            // Severity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: severityColor),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                alert.severity,
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
// ALERTS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  List<AlertItem> get _active =>
      _allAlerts.where((a) => a.status == 'Active').toList();
  List<AlertItem> get _warnings =>
      _allAlerts.where((a) => a.status == 'Warning').toList();
  List<AlertItem> get _cleared =>
      _allAlerts.where((a) => a.status == 'Cleared').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(activeRoute: '/alerts'),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        title: const Text('ALERTS',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,)),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon:
                const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device header
            buildDeviceHeader(
                context, () => showDisconnectDialog(context)),
            const SizedBox(height: 16),

            // ── Summary bar ──────────────────────────────────────────
            _buildSummaryBar(),
            const SizedBox(height: 20),

            // ── Active Alerts ────────────────────────────────────────
            _buildSectionHeader('Active Alerts (${_active.length})',
                showViewAll: true, context: context),
            const SizedBox(height: 10),
            ..._active.map((a) => buildAlertCard(a)),
            const SizedBox(height: 10),

            // ── Warnings ─────────────────────────────────────────────
            _buildSectionHeader('Warnings (${_warnings.length})'),
            const SizedBox(height: 10),
            ..._warnings.map((a) => buildAlertCard(a)),
            const SizedBox(height: 10),

            // ── Cleared Alerts ───────────────────────────────────────
            _buildSectionHeader('Cleared Alerts (${_cleared.length})'),
            const SizedBox(height: 10),
            ..._cleared.map((a) => buildAlertCard(a)),
            const SizedBox(height: 16),

            // ── Alert History button ─────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  SlideRoute(page: const AlertHistoryScreen()),
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
                label: const Text('Alert History',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Info note ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.grey[500], size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'If any alert persist, please check your battery and contact support.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
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
            _summaryItem(Icons.notifications_outlined, 'Alerts',
                _allAlerts.length.toString()),
            _divider(),
            _summaryItem(Icons.warning_amber_rounded, 'Active',
                _active.length.toString()),
            _divider(),
            _summaryItem(Icons.info_outline_rounded, 'Warnings',
                _warnings.length.toString()),
            _divider(),
            _summaryItem(Icons.check_circle_outline_rounded, 'Cleared',
                _cleared.length.toString()),
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
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 2),
            Text(count,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500)),
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

  Widget _buildSectionHeader(String title,
      {bool showViewAll = false, BuildContext? context}) {
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
              SlideRoute(page: const AlertHistoryScreen()),
            ),
            child: Row(children: const [
              Text('View All',
                  style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4F4F4F),
                      fontWeight: FontWeight.w500)),
              SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFF4F4F4F)),
            ]),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT HISTORY SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  String _selectedTab = 'All';
  String _selectedFilter = 'All Severity';

  final List<String> _tabs = ['All', 'Active', 'Warnings', 'Cleared'];
  final List<String> _filterOptions = [
    'All Severity', 'High', 'Medium', 'Low'
  ];

  List<AlertItem> get _filtered {
    var list = List<AlertItem>.from(_allAlerts);
    if (_selectedTab != 'All') {
      final map = {
        'Active': 'Active',
        'Warnings': 'Warning',
        'Cleared': 'Cleared'
      };
      list = list.where((a) => a.status == map[_selectedTab]).toList();
    }
    if (_selectedFilter != 'All Severity') {
      list =
          list.where((a) => a.severity == _selectedFilter).toList();
    }
    return list;
  }

  // Group alerts by dateGroup
  Map<String, List<AlertItem>> get _grouped {
    final map = <String, List<AlertItem>>{};
    for (final a in _filtered) {
      map.putIfAbsent(a.dateGroup, () => []).add(a);
    }
    return map;
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
      items: _filterOptions
          .map((f) => PopupMenuItem<String>(
                value: f,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(f, style: const TextStyle(fontSize: 14)),
                    if (_selectedFilter == f)
                      const Icon(Icons.check,
                          color: Color(0xFF1B6B3A), size: 18),
                  ],
                ),
              ))
          .toList(),
    );
    if (result != null) setState(() => _selectedFilter = result);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final dateGroups = grouped.keys.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        title: const Text('ALERT HISTORY',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,)),
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
                buildDeviceHeader(context, () => showDisconnectDialog(context)),
                const SizedBox(height: 16),

                // Tabs
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                    children: _tabs.map((tab) => _buildTab(tab)).toList(),
                    ),
                ),
                const Divider(height: 15),

                // Filter right-aligned below divider
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
                                _selectedFilter == 'All Severity' ? 'Filter' : _selectedFilter,
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
                const SizedBox(height: 1),
                ],
            ),
            ),

          // ── Scrollable grouped list ────────────────────────────
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                itemCount: dateGroups.length,
                itemBuilder: (context, gi) {
                  final group = dateGroups[gi];
                  final items = grouped[group]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      ...items.map(
                          (a) => buildAlertCard(a, showStatus: true)),
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

  Widget _buildTab(String label) {
    final isActive = _selectedTab == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = label),
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