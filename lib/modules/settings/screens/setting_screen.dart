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

  double chargeCutoffVoltage = 3.65;
  double dischargeCutoffVoltage = 2.80;
  int tempMin = -10;
  int tempMax = 60;
  int chargeCurrentLimit = 50;
  int dischargeCurrentLimit = 100;
  int shortCircuitDelay = 100;
  double cellBalancingVoltage = 0.03;

  // ── Offline-cache state ───────────────────────────────────────────────────
  bool _isOffline = false;
  bool _isLoadingCache = true;
  DateTime? _lastSync;

  String _selectedLanguage = 'English';
  final Map<String, String> _langCodeMap = {
    'English': 'en',
    'Telugu': 'te',
    'Hindi': 'hi',
  };
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  String tr(String key) {
    return TranslationService.t(key);
  }

  // ── Listen to TranslationService + BLE service changes ───────────────────
  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onTranslationsChanged);
    widget.service.addListener(_onServiceChanged);
    _selectedLanguage = _languageDisplayName(TranslationService.language);
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
    _removeOverlay();
    super.dispose();
  }
  // ── END ───────────────────────────────────────────────────────────────────

  // ── Offline cache: load / persist ─────────────────────────────────────────

  /// Loads previously cached protection-parameter settings from LocalAuthDB
  /// (if any) so the screen still shows the user's last-known configuration
  /// when the device is offline / not yet connected over BLE.
  Future<void> _loadCachedSettings() async {
    final cached = await _localAuthDB.getCachedSettings();
    final syncTime = await _localAuthDB.getLastSyncTime();
    if (!mounted) return;

    if (cached != null) {
      setState(() {
        chargeCutoffVoltage =
            (cached['chargeCutoffVoltage'] as num?)?.toDouble() ?? chargeCutoffVoltage;
        dischargeCutoffVoltage =
            (cached['dischargeCutoffVoltage'] as num?)?.toDouble() ?? dischargeCutoffVoltage;
        tempMin = (cached['tempMin'] as num?)?.toInt() ?? tempMin;
        tempMax = (cached['tempMax'] as num?)?.toInt() ?? tempMax;
        chargeCurrentLimit =
            (cached['chargeCurrentLimit'] as num?)?.toInt() ?? chargeCurrentLimit;
        dischargeCurrentLimit =
            (cached['dischargeCurrentLimit'] as num?)?.toInt() ?? dischargeCurrentLimit;
        shortCircuitDelay =
            (cached['shortCircuitDelay'] as num?)?.toInt() ?? shortCircuitDelay;
        cellBalancingVoltage =
            (cached['cellBalancingVoltage'] as num?)?.toDouble() ?? cellBalancingVoltage;
      });
    }

    setState(() {
      _lastSync = syncTime;
      _isOffline = widget.service.latestDashboard == null;
      isConnected = !_isOffline;
      _isLoadingCache = false;
    });
  }

  /// Persists the current protection-parameter settings to LocalAuthDB so
  /// they survive app restarts and remain available offline.
  Future<void> _persistSettings() async {
    await _localAuthDB.saveSettings({
      'chargeCutoffVoltage': chargeCutoffVoltage,
      'dischargeCutoffVoltage': dischargeCutoffVoltage,
      'tempMin': tempMin,
      'tempMax': tempMax,
      'chargeCurrentLimit': chargeCurrentLimit,
      'dischargeCurrentLimit': dischargeCurrentLimit,
      'shortCircuitDelay': shortCircuitDelay,
      'cellBalancingVoltage': cellBalancingVoltage,
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

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showLanguageOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 44),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                  child: SizedBox(
                    width: 150,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _langCodeMap.keys.map((lang) {
                        final isSelected = lang == _selectedLanguage;
                        return InkWell(
                          onTap: () async {
                            setState(() => _selectedLanguage = lang);
                            await _changeLanguage(_langCodeMap[lang]!);
                            _removeOverlay();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.grey.shade200
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              lang,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  String _languageDisplayName(String code) {
    return code == 'hi'
        ? 'Hindi'
        : code == 'te'
            ? 'Telugu'
            : 'English';
  }

  // ── Change Language ───────────────────────────────────────────────────────
  Future<void> _changeLanguage(String languageCode) async {
    await TranslationService.setLanguage(languageCode);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('language_changed')),
        duration: const Duration(seconds: 2),
      ),
    );
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

  void _showResetConfirmation(
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
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

  void _editDoubleParam(
    String title,
    double current,
    String unit,
    Function(double) onSave,
  ) {
    final controller = TextEditingController(text: current.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: unit,
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

  void _editIntParam(
    String title,
    int current,
    String unit,
    Function(int) onSave,
  ) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: unit,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        title: Text(
          tr('settings'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: AppDrawer(activeRoute: '/settings', service: widget.service),
      body: _isLoadingCache
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCachedSettings,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeviceCard(),
                    const SizedBox(height: 12),
                    _buildOfflineBanner(),

                    // Language Selector
                    Row(
                      children: [
                        Text(
                          tr('change_language'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        CompositedTransformTarget(
                          link: _layerLink,
                          child: GestureDetector(
                            onTap: _showLanguageOverlay,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.language, size: 20, color: Colors.black87),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedLanguage,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                  ),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    if (isLocked) _buildLockBanner(),
                    if (isLocked) const SizedBox(height: 16),

                    Text(
                      tr('protection_parameters'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildParameterCard(
                      icon: Icons.battery_charging_full_rounded,
                      title: tr('charge_cutoff_voltage'),
                      subtitle: tr('charge_cutoff_voltage_desc'),
                      value: '${chargeCutoffVoltage.toStringAsFixed(2)} V',
                      onTap: isLocked
                          ? null
                          : () => _editDoubleParam(
                              tr('charge_cutoff_voltage'),
                              chargeCutoffVoltage,
                              'V',
                              (v) => setState(() => chargeCutoffVoltage = v),
                            ),
                    ),
                    _buildParameterCard(
                      icon: Icons.battery_alert_rounded,
                      title: tr('discharge_cutoff_voltage'),
                      subtitle: tr('discharge_cutoff_voltage_desc'),
                      value: '${dischargeCutoffVoltage.toStringAsFixed(2)} V',
                      onTap: isLocked
                          ? null
                          : () => _editDoubleParam(
                              tr('discharge_cutoff_voltage'),
                              dischargeCutoffVoltage,
                              'V',
                              (v) => setState(() => dischargeCutoffVoltage = v),
                            ),
                    ),
                    _buildParameterCard(
                      icon: Icons.thermostat_rounded,
                      title: tr('temperature_limit'),
                      subtitle: tr('temperature_limit_desc'),
                      value: '$tempMin   $tempMax °C',
                      onTap: isLocked ? null : () {},
                    ),
                    _buildParameterCard(
                      icon: Icons.electric_bolt_rounded,
                      title: tr('charge_current_limit'),
                      subtitle: tr('charge_current_limit_desc'),
                      value: '$chargeCurrentLimit A',
                      onTap: isLocked
                          ? null
                          : () => _editIntParam(
                              tr('charge_current_limit'),
                              chargeCurrentLimit,
                              'A',
                              (v) => setState(() => chargeCurrentLimit = v),
                            ),
                    ),
                    _buildParameterCard(
                      icon: Icons.electric_bolt_outlined,
                      title: tr('discharge_current_limit'),
                      subtitle: tr('discharge_current_limit_desc'),
                      value: '$dischargeCurrentLimit A',
                      onTap: isLocked
                          ? null
                          : () => _editIntParam(
                              tr('discharge_current_limit'),
                              dischargeCurrentLimit,
                              'A',
                              (v) => setState(() => dischargeCurrentLimit = v),
                            ),
                    ),
                    _buildParameterCard(
                      icon: Icons.timer_rounded,
                      title: tr('short_circuit_delay'),
                      subtitle: tr('short_circuit_delay_desc'),
                      value: '$shortCircuitDelay ms',
                      onTap: isLocked
                          ? null
                          : () => _editIntParam(
                              tr('short_circuit_delay'),
                              shortCircuitDelay,
                              'ms',
                              (v) => setState(() => shortCircuitDelay = v),
                            ),
                    ),
                    _buildParameterCard(
                      icon: Icons.balance_rounded,
                      title: tr('cell_balancing_voltage'),
                      subtitle: tr('cell_balancing_voltage_desc'),
                      value: '${cellBalancingVoltage.toStringAsFixed(2)} V',
                      onTap: isLocked
                          ? null
                          : () => _editDoubleParam(
                              tr('cell_balancing_voltage'),
                              cellBalancingVoltage,
                              'V',
                              (v) => setState(() => cellBalancingVoltage = v),
                            ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      tr('reset_options'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _buildResetButton(
                            icon: Icons.refresh_rounded,
                            label: tr('reset_warnings'),
                            sublabel: tr('reset_warnings_desc'),
                            onTap: () => _showResetConfirmation(
                              tr('reset_warnings'),
                              tr('reset_warnings_confirm'),
                              () => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(tr('warnings_cleared'))),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildResetButton(
                            icon: Icons.check_circle_outline_rounded,
                            label: tr('reset_counters'),
                            sublabel: tr('reset_counters_desc'),
                            onTap: () => _showResetConfirmation(
                              tr('reset_counters'),
                              tr('reset_counters_confirm'),
                              () => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(tr('counters_reset'))),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 190,
                      child: _buildResetButton(
                        icon: Icons.settings_backup_restore_rounded,
                        label: tr('factory_reset'),
                        sublabel: tr('factory_reset_desc'),
                        onTap: () => _showResetConfirmation(
                          tr('factory_reset'),
                          tr('factory_reset_confirm'),
                          () {
                            setState(() {
                              chargeCutoffVoltage = 3.65;
                              dischargeCutoffVoltage = 2.80;
                              tempMin = -10;
                              tempMax = 60;
                              chargeCurrentLimit = 50;
                              dischargeCurrentLimit = 100;
                              shortCircuitDelay = 100;
                              cellBalancingVoltage = 0.03;
                            });
                            _persistSettings();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('factory_reset_complete'))),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.grey.shade600, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('settings_warning'),
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Widget Builders ────────────────────────────────────────────────────────

  /// Banner shown when settings are being displayed from local cache because
  /// the BLE device isn't currently connected / providing live data.
  Widget _buildOfflineBanner() {
    if (!_isOffline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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

  Widget _buildDeviceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.battery_full_rounded,
              size: 28,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BMS_001',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isConnected ? tr('connected') : tr('disconnected'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isConnected ? const Color(0xFF1B6B3A) : Colors.red,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: isConnected ? const Color(0xFF1B6B3A) : Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4621A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            onPressed: _showDisconnectDialog,
            child: Text(
              tr('disconnect'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2B5FA5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('protection_locked'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              tr('protection_locked_desc'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _showUnlockDialog,
            icon: const Icon(Icons.lock_open_rounded, size: 16),
            label: Text(
              tr('unlock_settings'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: Icon(icon, size: 20, color: Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black45, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: onTap != null ? Colors.black54 : Colors.grey.shade300,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2B5FA5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    sublabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}