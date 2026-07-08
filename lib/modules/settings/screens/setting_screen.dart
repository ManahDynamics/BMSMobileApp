// lib/screens/settings_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import '../../../modules/scanner/screens/BMS_scanner_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/services/local_auth_db.dart';

class SettingsScreen extends StatefulWidget {
  final BMSBluetoothService service;

  const SettingsScreen({super.key, required this.service});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalAuthDB _localAuthDB = LocalAuthDB();

  bool isConnected = true;
  bool isLocked = true;

  // ── Tab state ──────────────────────────────────────────────────────────────
  int _selectedTab = 0; // 0 Battery, 1 Protection, 2 Temp, 3 Factory
  final List<String> _tabLabels = const [
    'Battery Settings',
    'Protection Settings',
    'Temp Settings',
    'Factory Settings',
  ];

  // ── Battery Settings ────────────────────────────────────────────────────────
  int batteryStringCount = 14; // "S"
  double ratedCapacity = 30.0; // AH
  int socSet = 99; // %
  int sleepWaitingTime = 3600; // ms
  double balancedStartDifferenceVolt = 0.03; // V
  double balancedStartVolt = 3.20; // V
  double nominalCellVolt = 3.0; // V
  String cellChemistry = 'Li-Ion';
  final List<String> _chemistryOptions = const ['Li-Ion', 'LiFePO4', 'NiMH', 'Lead Acid'];

  // ── Protection Settings ─────────────────────────────────────────────────────
  double singleCellHighVoltProtection = 3.200;
  double singleCellLowVoltProtection = 3.00;
  double sumVoltHighProtection = 58.8;
  double sumVoltLowProtection = 42.0;
  double chargeOverCurrentProtection = 40.0;
  double dischargeOverCurrentProtection = 60.0;

  // ── Temp Settings ────────────────────────────────────────────────────────────
  int noOfTempChannels = 4;
  int chargeHighTempProtection = 60;
  int chargeLowTempProtection = -10;
  int dischargeHighTempProtection = 70;
  int dischargeLowTempProtection = -10;
  int diffTempProtection = 15;

  // ── Factory Settings ─────────────────────────────────────────────────────────
  String batterySerialNo = 'CHP8510262400001';
  String bleDeviceName = 'MCH_BAT_1AF0001';

  // ── Offline-cache state ───────────────────────────────────────────────────
  bool _isOffline = false;
  bool _isLoadingCache = true;
  DateTime? _lastSync;

  String tr(String key) {
    return TranslationService.t(key);
  }

  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onTranslationsChanged);
    widget.service.addListener(_onServiceChanged);
    _loadCachedSettings();
  }

  void _onTranslationsChanged() {
    if (mounted) setState(() {});
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {
      _isOffline = widget.service.latestDashboard == null;
      isConnected = !_isOffline;
    });
  }

  @override
  void dispose() {
    TranslationService.instance.removeListener(_onTranslationsChanged);
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  // ── Offline cache: load / persist ─────────────────────────────────────────

  Future<void> _loadCachedSettings() async {
    final cached = await _localAuthDB.getCachedSettings();
    final syncTime = await _localAuthDB.getLastSyncTime();
    if (!mounted) return;

    if (cached != null) {
      setState(() {
        batteryStringCount = (cached['batteryStringCount'] as num?)?.toInt() ?? batteryStringCount;
        ratedCapacity = (cached['ratedCapacity'] as num?)?.toDouble() ?? ratedCapacity;
        socSet = (cached['socSet'] as num?)?.toInt() ?? socSet;
        sleepWaitingTime = (cached['sleepWaitingTime'] as num?)?.toInt() ?? sleepWaitingTime;
        balancedStartDifferenceVolt =
            (cached['balancedStartDifferenceVolt'] as num?)?.toDouble() ?? balancedStartDifferenceVolt;
        balancedStartVolt = (cached['balancedStartVolt'] as num?)?.toDouble() ?? balancedStartVolt;
        nominalCellVolt = (cached['nominalCellVolt'] as num?)?.toDouble() ?? nominalCellVolt;
        cellChemistry = (cached['cellChemistry'] as String?) ?? cellChemistry;

        singleCellHighVoltProtection =
            (cached['singleCellHighVoltProtection'] as num?)?.toDouble() ?? singleCellHighVoltProtection;
        singleCellLowVoltProtection =
            (cached['singleCellLowVoltProtection'] as num?)?.toDouble() ?? singleCellLowVoltProtection;
        sumVoltHighProtection = (cached['sumVoltHighProtection'] as num?)?.toDouble() ?? sumVoltHighProtection;
        sumVoltLowProtection = (cached['sumVoltLowProtection'] as num?)?.toDouble() ?? sumVoltLowProtection;
        chargeOverCurrentProtection =
            (cached['chargeOverCurrentProtection'] as num?)?.toDouble() ?? chargeOverCurrentProtection;
        dischargeOverCurrentProtection =
            (cached['dischargeOverCurrentProtection'] as num?)?.toDouble() ?? dischargeOverCurrentProtection;

        noOfTempChannels = (cached['noOfTempChannels'] as num?)?.toInt() ?? noOfTempChannels;
        chargeHighTempProtection = (cached['chargeHighTempProtection'] as num?)?.toInt() ?? chargeHighTempProtection;
        chargeLowTempProtection = (cached['chargeLowTempProtection'] as num?)?.toInt() ?? chargeLowTempProtection;
        dischargeHighTempProtection =
            (cached['dischargeHighTempProtection'] as num?)?.toInt() ?? dischargeHighTempProtection;
        dischargeLowTempProtection =
            (cached['dischargeLowTempProtection'] as num?)?.toInt() ?? dischargeLowTempProtection;
        diffTempProtection = (cached['diffTempProtection'] as num?)?.toInt() ?? diffTempProtection;

        batterySerialNo = (cached['batterySerialNo'] as String?) ?? batterySerialNo;
        bleDeviceName = (cached['bleDeviceName'] as String?) ?? bleDeviceName;
      });
    }

    setState(() {
      _lastSync = syncTime;
      _isOffline = widget.service.latestDashboard == null;
      isConnected = !_isOffline;
      _isLoadingCache = false;
    });
  }

  Future<void> _persistSettings() async {
    await _localAuthDB.saveSettings({
      'batteryStringCount': batteryStringCount,
      'ratedCapacity': ratedCapacity,
      'socSet': socSet,
      'sleepWaitingTime': sleepWaitingTime,
      'balancedStartDifferenceVolt': balancedStartDifferenceVolt,
      'balancedStartVolt': balancedStartVolt,
      'nominalCellVolt': nominalCellVolt,
      'cellChemistry': cellChemistry,
      'singleCellHighVoltProtection': singleCellHighVoltProtection,
      'singleCellLowVoltProtection': singleCellLowVoltProtection,
      'sumVoltHighProtection': sumVoltHighProtection,
      'sumVoltLowProtection': sumVoltLowProtection,
      'chargeOverCurrentProtection': chargeOverCurrentProtection,
      'dischargeOverCurrentProtection': dischargeOverCurrentProtection,
      'noOfTempChannels': noOfTempChannels,
      'chargeHighTempProtection': chargeHighTempProtection,
      'chargeLowTempProtection': chargeLowTempProtection,
      'dischargeHighTempProtection': dischargeHighTempProtection,
      'dischargeLowTempProtection': dischargeLowTempProtection,
      'diffTempProtection': diffTempProtection,
      'batterySerialNo': batterySerialNo,
      'bleDeviceName': bleDeviceName,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('disconnect'), textAlign: TextAlign.center),
        content: Text(tr('disconnect_confirmation'), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleDisconnect();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4621A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(tr('disconnect')),
          ),
        ],
      ),
    );
  }

  void _showUnlockDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('unlock_settings')),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: tr('password'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6B3A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() => isLocked = false);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('settings_unlocked'))),
              );
            },
            child: Text(tr('unlock')),
          ),
        ],
      ),
    );
  }

  void _handleLockSettings() {
    setState(() => isLocked = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings locked')),
    );
  }

  void _showDeviceDetails() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Device Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            _detailRow('Device Name', bleDeviceName),
            _detailRow('Serial No', batterySerialNo),
            _detailRow('Status', isConnected ? 'Connected' : 'Disconnected'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  void _showResetConfirmation(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B5FA5),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
  }

  // ── Generic edit dialogs ────────────────────────────────────────────────────
  void _editDoubleParam(String title, double current, String unit, Function(double) onSave) {
    final controller = TextEditingController(text: current.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: unit, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B6B3A), foregroundColor: Colors.white),
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) {
                onSave(val);
                _persistSettings();
                Navigator.pop(context);
              }
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  void _editIntParam(String title, int current, String unit, Function(int) onSave) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: unit, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B6B3A), foregroundColor: Colors.white),
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) {
                onSave(val);
                _persistSettings();
                Navigator.pop(context);
              }
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  void _editStringParam(String title, String current, Function(String) onSave) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B6B3A), foregroundColor: Colors.white),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSave(controller.text.trim());
                _persistSettings();
                Navigator.pop(context);
              }
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  void _pickCellChemistry() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _chemistryOptions.map((option) {
            return ListTile(
              title: Text(option),
              trailing: option == cellChemistry ? const Icon(Icons.check, color: Color(0xFF1B6B3A)) : null,
              onTap: () {
                setState(() => cellChemistry = option);
                _persistSettings();
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _handleSetNow(String context_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$context_ settings sent to device')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('settings'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              bleDeviceName,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                onPressed: () {},
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                  child: const Text(
                    '03',
                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (value) {
              if (value == 'disconnect') _showDisconnectDialog();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'disconnect', child: Text(tr('disconnect'))),
            ],
          ),
        ],
      ),
      drawer: AppDrawer(activeRoute: '/settings', service: widget.service),
      body: _isLoadingCache
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCachedSettings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isOffline) _buildOfflineBanner(),

                    // ── Unlock Settings / Device Details row ─────────────
                    // Equal-width tiles spanning the row, matching the screenshot.
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2B5FA5),
                              disabledForegroundColor: const Color(0xFF2B5FA5),
                              side: const BorderSide(color: Color(0xFF2B5FA5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: isLocked ? _showUnlockDialog : _handleLockSettings,
                            icon: Icon(isLocked ? Icons.lock_rounded : Icons.lock_open_rounded, size: 15),
                            label: Text(
                              isLocked ? tr('unlock_settings') : 'Lock Settings',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2B5FA5),
                              side: const BorderSide(color: Color(0xFF2B5FA5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _showDeviceDetails,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.shield_outlined, size: 15),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Device Details',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Tab bar ───────────────────────────────────────────
                    _buildTabBar(),
                    const SizedBox(height: 14),

                    // ── Tab content ───────────────────────────────────────
                    IndexedStack(
                      index: _selectedTab,
                      children: [
                        _buildBatterySettingsTab(),
                        _buildProtectionSettingsTab(),
                        _buildTempSettingsTab(),
                        _buildFactorySettingsTab(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Tab bar (segmented-control style, matches design) ──────────────────────
  Widget _buildTabBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(_tabLabels.length, (i) {
        final selected = _selectedTab == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTab = i),
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF16324F) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? const Color(0xFF16324F) : Colors.grey.shade300),
              ),
              child: Text(
                _tabLabels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
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
              'Offline — showing settings cached from ${_formatSyncTime(_lastSync)}',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  // ── Row widget shared across Battery / Protection / Temp tabs ─────────────
  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
    Widget? trailingOverride,
    Color iconColor = Colors.black54,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 26,
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ),
          if (trailingOverride != null)
            trailingOverride
          else ...[
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            SizedBox(
              width: 32,
              child: IconButton(
                icon: Icon(Icons.edit_rounded, size: 15, color: onEdit != null ? Colors.black54 : Colors.grey.shade300),
                onPressed: onEdit,
                splashRadius: 16,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetNowFooter(String sectionName) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6FA88A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => _handleSetNow(sectionName),
            child: Text(tr('save').isNotEmpty ? 'Set Now' : 'Set Now'),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '( Set here after parameter changes )',
              style: TextStyle(fontSize: 11, color: Colors.black45),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Battery Settings tab ─────────────────────────────────────────────────
  Widget _buildBatterySettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingRow(
          icon: Icons.battery_std_rounded,
          label: 'Battery String',
          value: '$batteryStringCount S',
          onEdit: isLocked
              ? null
              : () => _editIntParam('Battery String', batteryStringCount, 'S', (v) => setState(() => batteryStringCount = v)),
        ),
        _buildSettingRow(
          icon: Icons.battery_charging_full_rounded,
          label: 'Rated Capacity',
          value: '${ratedCapacity.toStringAsFixed(1)} AH',
          onEdit: isLocked
              ? null
              : () => _editDoubleParam('Rated Capacity', ratedCapacity, 'AH', (v) => setState(() => ratedCapacity = v)),
        ),
        _buildSettingRow(
          icon: Icons.battery_5_bar_rounded,
          label: 'SOC Set',
          value: '$socSet %',
          onEdit: isLocked ? null : () => _editIntParam('SOC Set', socSet, '%', (v) => setState(() => socSet = v)),
        ),
        _buildSettingRow(
          icon: Icons.access_time_rounded,
          label: 'Sleep Waiting Time',
          value: '$sleepWaitingTime ms',
          onEdit: isLocked
              ? null
              : () => _editIntParam('Sleep Waiting Time', sleepWaitingTime, 'ms', (v) => setState(() => sleepWaitingTime = v)),
        ),
        _buildSettingRow(
          icon: Icons.balance_rounded,
          label: 'Balanced Start Difference Volt',
          value: '${balancedStartDifferenceVolt.toStringAsFixed(2)} V',
          onEdit: isLocked
              ? null
              : () => _editDoubleParam('Balanced Start Difference Volt', balancedStartDifferenceVolt, 'V',
                  (v) => setState(() => balancedStartDifferenceVolt = v)),
        ),
        _buildSettingRow(
          icon: Icons.play_circle_outline_rounded,
          label: 'Balanced Start Volt',
          value: '${balancedStartVolt.toStringAsFixed(2)} V',
          onEdit: isLocked
              ? null
              : () => _editDoubleParam('Balanced Start Volt', balancedStartVolt, 'V', (v) => setState(() => balancedStartVolt = v)),
        ),
        _buildSettingRow(
          icon: Icons.bolt_rounded,
          label: 'Nominal Cell Volt',
          value: '${nominalCellVolt.toStringAsFixed(1)} V',
          onEdit: isLocked
              ? null
              : () => _editDoubleParam('Nominal Cell Volt', nominalCellVolt, 'V', (v) => setState(() => nominalCellVolt = v)),
        ),
        _buildSettingRow(
          icon: Icons.science_outlined,
          label: 'Cell Chemistry',
          value: cellChemistry,
          trailingOverride: GestureDetector(
            onTap: isLocked ? null : _pickCellChemistry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cellChemistry, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Icon(Icons.arrow_drop_down_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
        _buildSettingRow(
          icon: Icons.auto_graph_rounded,
          label: 'Zero Drift Current Calibration',
          value: '',
          trailingOverride: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B5FA5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: isLocked
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Zero drift current calibration started')),
                    );
                  },
            child: const Text('Calibrate Now', style: TextStyle(fontSize: 12)),
          ),
        ),
        _buildSetNowFooter('Battery'),
      ],
    );
  }

  // ── Protection Settings tab ──────────────────────────────────────────────
  Widget _buildProtectionSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingRow(
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFD4621A),
          label: 'Single Cell High Volt Protection',
          value: '${singleCellHighVoltProtection.toStringAsFixed(3)} V',
          onEdit: isLocked
              ? null
              : () => _editDoubleParam('Single Cell High Volt Protection', singleCellHighVoltProtection, 'V',
                  (v) => setState(() => singleCellHighVoltProtection = v)),
        ),
        _buildSettingRow(
          icon: Icons.battery_alert_rounded,
          iconColor: const Color(0xFF2B5FA5),
          label: 'Single Cell Low Volt Protection',
          value: '${singleCellLowVoltProtection.toStringAsFixed(2)} V',
          onEdit: isLocked
              ? null
              : () => _editDoubleParam('Single Cell Low Volt Protection', singleCellLowVoltProtection, 'V',
                  (v) => setState(() => singleCellLowVoltProtection = v)),
        ),
        _buildSettingRow(
          icon: Icons.show_chart_rounded,
          iconColor: const Color(0xFF2B5FA5),
          label: 'Sum Volt High Protection',
          value: '${sumVoltHighProtection.toStringAsFixed(1)} V',
          onEdit: isLocked
              ? null
              : () => _editDoubleParam('Sum Volt High Protection', sumVoltHighProtection, 'V', (v) => setState(() => sumVoltHighProtection = v)),
        ),
        _buildSettingRow(
          icon: Icons.stacked_line_chart_rounded,
          iconColor: const Color(0xFF2B5FA5),
          label: 'Sum Volt Low Protection',
          value: '${sumVoltLowProtection.toStringAsFixed(1)} V',
          onEdit: isLocked
              ? null
              : () => _editDoubleParam('Sum Volt Low Protection', sumVoltLowProtection, 'V', (v) => setState(() => sumVoltLowProtection = v)),
        ),
        _buildSettingRow(
          icon: Icons.battery_charging_full_rounded,
          iconColor: const Color(0xFFD4621A),
          label: 'Charge Over Current Protection',
          value: '${chargeOverCurrentProtection.toStringAsFixed(1)} A',
          onEdit: isLocked
              ? null
              : () => _editDoubleParam('Charge Over Current Protection', chargeOverCurrentProtection, 'A',
                  (v) => setState(() => chargeOverCurrentProtection = v)),
        ),
        _buildSettingRow(
          icon: Icons.electric_bolt_outlined,
          iconColor: Colors.redAccent.shade700,
          label: 'Discharge Over Current Protection',
          value: '${dischargeOverCurrentProtection.toStringAsFixed(1)} A',
          onEdit: isLocked
              ? null
              : () => _editDoubleParam('Discharge Over Current Protection', dischargeOverCurrentProtection, 'A',
                  (v) => setState(() => dischargeOverCurrentProtection = v)),
        ),
        _buildSetNowFooter('Protection'),
      ],
    );
  }

  // ── Temp Settings tab ─────────────────────────────────────────────────────
  Widget _buildTempSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingRow(
          icon: Icons.developer_board_rounded,
          iconColor: Colors.black54,
          label: 'No of Temp Channels',
          value: '$noOfTempChannels',
          onEdit: isLocked
              ? null
              : () => _editIntParam('No of Temp Channels', noOfTempChannels, '', (v) => setState(() => noOfTempChannels = v)),
        ),
        _buildSettingRow(
          icon: Icons.thermostat_rounded,
          iconColor: Colors.redAccent.shade700,
          label: 'Charge High Temp Protection',
          value: '$chargeHighTempProtection °C',
          onEdit: isLocked
              ? null
              : () => _editIntParam('Charge High Temp Protection', chargeHighTempProtection, '°C',
                  (v) => setState(() => chargeHighTempProtection = v)),
        ),
        _buildSettingRow(
          icon: Icons.ac_unit_rounded,
          iconColor: const Color(0xFF2B5FA5),
          label: 'Charge Low Temp Protection',
          value: '$chargeLowTempProtection °C',
          onEdit: isLocked
              ? null
              : () => _editIntParam('Charge Low Temp Protection', chargeLowTempProtection, '°C',
                  (v) => setState(() => chargeLowTempProtection = v)),
        ),
        _buildSettingRow(
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.redAccent.shade700,
          label: 'Discharge High Temp Protection',
          value: '$dischargeHighTempProtection °C',
          onEdit: isLocked
              ? null
              : () => _editIntParam('Discharge High Temp Protection', dischargeHighTempProtection, '°C',
                  (v) => setState(() => dischargeHighTempProtection = v)),
        ),
        _buildSettingRow(
          icon: Icons.severe_cold_rounded,
          iconColor: const Color(0xFF2B5FA5),
          label: 'Discharge Low Temp Protection',
          value: '$dischargeLowTempProtection °C',
          onEdit: isLocked
              ? null
              : () => _editIntParam('Discharge Low Temp Protection', dischargeLowTempProtection, '°C',
                  (v) => setState(() => dischargeLowTempProtection = v)),
        ),
        _buildSettingRow(
          icon: Icons.compare_arrows_rounded,
          iconColor: const Color(0xFFD4621A),
          label: 'Diff Temp Protection',
          value: '$diffTempProtection °C',
          onEdit: isLocked
              ? null
              : () => _editIntParam('Diff Temp Protection', diffTempProtection, '°C', (v) => setState(() => diffTempProtection = v)),
        ),
        _buildSetNowFooter('Temp'),
      ],
    );
  }

  // ── Factory Settings tab ─────────────────────────────────────────────────
  Widget _buildFactoryTextField({
    required String label,
    required String value,
    required VoidCallback onEdit,
    required VoidCallback onScan,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(
                  child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.black54),
                  onPressed: isLocked ? null : onEdit,
                  splashRadius: 16,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: Icon(Icons.qr_code_scanner_rounded, size: 19, color: Colors.grey.shade600),
                  onPressed: isLocked ? null : onScan,
                  splashRadius: 16,
                  tooltip: 'Scan',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the barcode/QR scanner and feeds the scanned code into [onResult].
  /// Wire this up to your actual scanner screen / package
  /// (e.g. push BluetoothDeviceScanPage-style scanner, or a package such as
  /// `mobile_scanner`) — this stub shows the flow and a manual fallback.
  Future<void> _scanCode(String title, Function(String) onResult) async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _BarcodeScanPlaceholder(title: title),
      ),
    );
    if (scanned != null && scanned.trim().isNotEmpty) {
      onResult(scanned.trim());
      _persistSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title scanned: $scanned')),
      );
    }
  }

  Widget _buildFactorySettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFactoryTextField(
          label: 'Battery Serial No',
          value: batterySerialNo,
          onEdit: () => _editStringParam('Battery Serial No', batterySerialNo, (v) => setState(() => batterySerialNo = v)),
          onScan: () => _scanCode('Battery Serial No', (v) => setState(() => batterySerialNo = v)),
        ),
        _buildFactoryTextField(
          label: 'BLE Device Name',
          value: bleDeviceName,
          onEdit: () => _editStringParam('BLE Device Name', bleDeviceName, (v) => setState(() => bleDeviceName = v)),
          onScan: () => _scanCode('BLE Device Name', (v) => setState(() => bleDeviceName = v)),
        ),
        Row(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6FA88A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => _handleSetNow('Factory'),
              child: const Text('Set Now'),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '( Set here after parameter changes )',
                style: TextStyle(fontSize: 11, color: Colors.black45),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Firmware upgrade card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.system_update_alt_rounded, size: 20, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BMS Firmware Upgrade', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    SizedBox(height: 2),
                    Text('Update the BMS firmware to the latest version.',
                        style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B5FA5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: isLocked
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Checking for firmware updates...')),
                        );
                      },
                child: const Text('Upgrade', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2B5FA5),
                  side: const BorderSide(color: Color(0xFF2B5FA5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: isLocked
                    ? null
                    : () => _showResetConfirmation(
                          'Restart',
                          'Are you sure you want to restart the BMS device?',
                          () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Device restarting...'))),
                        ),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Restart', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey.shade500),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2B5FA5),
                  side: const BorderSide(color: Color(0xFF2B5FA5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: isLocked
                    ? null
                    : () => _showResetConfirmation(
                          'Factory Data Reset',
                          'This will erase all settings and restore factory defaults. Continue?',
                          () {
                            setState(() {
                              batteryStringCount = 14;
                              ratedCapacity = 30.0;
                              socSet = 99;
                              sleepWaitingTime = 3600;
                              balancedStartDifferenceVolt = 0.03;
                              balancedStartVolt = 3.20;
                              nominalCellVolt = 3.0;
                              cellChemistry = 'Li-Ion';
                              singleCellHighVoltProtection = 3.200;
                              singleCellLowVoltProtection = 3.00;
                              sumVoltHighProtection = 58.8;
                              sumVoltLowProtection = 42.0;
                              chargeOverCurrentProtection = 40.0;
                              dischargeOverCurrentProtection = 60.0;
                              noOfTempChannels = 4;
                              chargeHighTempProtection = 60;
                              chargeLowTempProtection = -10;
                              dischargeHighTempProtection = 70;
                              dischargeLowTempProtection = -10;
                              diffTempProtection = 15;
                            });
                            _persistSettings();
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('Factory reset complete')));
                          },
                        ),
                icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
                label: const Text('Factory Data Reset', style: TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey.shade500),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Minimal placeholder scan screen so the "scan" buttons on the Factory
/// Settings tab are fully wired end-to-end. Swap the body of this widget
/// for a real camera scanner (e.g. the `mobile_scanner` package, or your
/// existing BMS scanner screen) when ready — it just needs to
/// `Navigator.pop(context, scannedValue)` with the decoded string.
class _BarcodeScanPlaceholder extends StatefulWidget {
  final String title;
  const _BarcodeScanPlaceholder({required this.title});

  @override
  State<_BarcodeScanPlaceholder> createState() => _BarcodeScanPlaceholderState();
}

class _BarcodeScanPlaceholderState extends State<_BarcodeScanPlaceholder> {
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        title: Text('Scan ${widget.title}', style: const TextStyle(color: Colors.white, fontSize: 15)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, size: 56, color: Colors.grey.shade500),
                  const SizedBox(height: 8),
                  Text(
                    'Camera scanner goes here\n(wire up mobile_scanner or your BMS scanner)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Or enter the code manually', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            TextField(
              controller: _manualController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B6B3A),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (_manualController.text.trim().isNotEmpty) {
                  Navigator.pop(context, _manualController.text.trim());
                }
              },
              child: const Text('Use this value'),
            ),
          ],
        ),
      ),
    );
  }
}