// lib/screens/settings_screen.dart// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'dart:async';
import 'package:bmsmobileapp/widgets/bar_code_scanner_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import '../../../modules/scanner/screens/BMS_scanner_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/services/local_auth_db.dart';
import 'package:bmsmobileapp/services/protocol.dart';
import 'package:bmsmobileapp/modules/settings/screens/packet_log_screen.dart';

class SettingsScreen extends StatefulWidget {
  final BMSBluetoothService service;

  const SettingsScreen({super.key, required this.service});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final LocalAuthDB _localAuthDB = LocalAuthDB();

  bool isConnected = true;
  bool isLocked = true;

  // ── App lifecycle tracking ──────────────────────────────────────────────
  // We ignore BLE-driven setState() calls while the app isn't in the
  // foreground / actively resumed. This avoids triggering a rebuild (and a
  // layout pass) on a view that isn't fully attached, which is what caused
  // the intermittent "RenderBox was not laid out" exception and the
  // associated blank-screen flash around background/foreground transitions.
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  // ── Tab state ──────────────────────────────────────────────────────────────
  int _selectedTab = 0; // 0 Battery, 1 Protection, 2 Temp, 3 Factory
  final List<String> _tabLabels = const [
    'Battery Settings',
    'Protection Settings',
    'Temp Settings',
    'Factory Settings',
  ];

  // ── One-shot read tracking ──────────────────────────────────────────────
  // Each tab should send its read request exactly once when the user opens
  // it, then stop — not keep polling every N seconds. These flags track
  // whether we've already received the first response for the tab that's
  // currently being read, so `_onServiceChanged` knows when to stop polling.
 bool _batteryLoadedOnce = false;
  bool _protectionLoadedOnce = false;
  bool _tempLoadedOnce = false;
  bool _factoryLoadedOnce = false;

  // ── Guards to guarantee the read request is sent only ONCE per tab visit.
  bool _batteryRequestSent = false;
  bool _protectionRequestSent = false;
  bool _tempRequestSent = false;
  bool _factoryRequestSent = false;

  void _pollForTab(int i) {
    // Reset the "loaded" flag for the tab being (re)entered so the very
    // next response we get for it is treated as the initial one-shot read.
    // The "_xRequestSent" guard ensures the BLE request itself is only
    // ever transmitted once per visit.
    switch (i) {
      case 0:
        _batteryLoadedOnce = false;
        if (_batteryRequestSent) return;
        _batteryRequestSent = true;
        widget.service.startBatterySettingsPolling();
        break;
      case 1:
        _protectionLoadedOnce = false;
        if (_protectionRequestSent) return;
        _protectionRequestSent = true;
        widget.service.startProtectionSettingsPolling();
        break;
      case 2:
        _tempLoadedOnce = false;
        if (_tempRequestSent) return;
        _tempRequestSent = true;
        widget.service.startTempSettingsPolling();
        break;
      case 3:
        _factoryLoadedOnce = false;
        if (_factoryRequestSent) return;
        _factoryRequestSent = true;
        widget.service.startFactorySettingsPolling();
         Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        widget.service.requestDeviceDetails();
      });
      break;
    }
  }
  // ── Battery Settings ────────────────────────────────────────────────────────
  int batteryStringCount = 0; // "S"
  double ratedCapacity = 0; // AH
  int socSet = 0; // %
  int sleepWaitingTime = 0; // ms
  double balancedStartDifferenceVolt = 0; // V
  double balancedStartVolt = 0; // V
  double nominalCellVolt = 0; // V
  String cellChemistry = ' ';
  final List<String> _chemistryOptions = const ['Li-Ion', 'LiHv', 'LipO', 'Solid State', 'LFP', 'NMC'];

  // ── Protection Settings ─────────────────────────────────────────────────────
  double singleCellHighVoltProtection =0;
  double singleCellLowVoltProtection = 0;
  double sumVoltHighProtection = 0;
  double sumVoltLowProtection = 0;
  double chargeOverCurrentProtection = 0;
  double dischargeOverCurrentProtection = 0;

  // ── Temp Settings ────────────────────────────────────────────────────────────
  int noOfTempChannels = 0;
  int chargeHighTempProtection = 0;
  int chargeLowTempProtection = 0;
  int dischargeHighTempProtection = 0;
  int dischargeLowTempProtection = 0;
  int diffTempProtection = 0;

  // ── Factory Settings ─────────────────────────────────────────────────────────
  String batterySerialNo = ' ';
  String bmsSerialNo = ' ';
  String bleDeviceName = ' ';

  // ── Device Details (read-only, shown on the Factory Settings tab) ──────────
  String bmssNo = ' ';
  String swVersionNo = ' ';
  String hwVersionNo = ' ';
  String fwVersionNo = ' ';
 

  // ── Offline-cache state ───────────────────────────────────────────────────
  bool _isOffline = false;
  bool _isLoadingCache = true;
  DateTime? _lastSync;

  // ── Validation ranges (per the device protocol spec) ───────────────────────
  static const int _kBatteryStringMin = 1, _kBatteryStringMax = 14;
  static const double _kRatedCapacityMin = 9.0, _kRatedCapacityMax = 100.0;
  static const int _kSocSetMin = 0, _kSocSetMax = 100;
  static const int _kSleepWaitMin = 0, _kSleepWaitMax = 65535;
  static const double _kBalStartDiffMin = 0.001, _kBalStartDiffMax = 4.300;
  static const double _kBalStartVoltMin = 0.001, _kBalStartVoltMax = 4.300;
  static const double _kNominalCellMin = 0.000, _kNominalCellMax = 9.999;

  static const double _kCellHighVoltMin = 2.000, _kCellHighVoltMax = 4.300;
  static const double _kCellLowVoltMin = 2.000, _kCellLowVoltMax = 4.300;
  static const double _kSumVoltHighMin = 20.0, _kSumVoltHighMax = 99.5;
  static const double _kSumVoltLowMin = 20.0, _kSumVoltLowMax = 99.5;
  static const double _kChargeOCMin = 0.0, _kChargeOCMax = 80.0;
  static const double _kDischargeOCMin = 0.0, _kDischargeOCMax = 160.0;

  static const int _kTempChannelsMin = 1, _kTempChannelsMax = 9;
  static const int _kChargeHighTempMin = 0, _kChargeHighTempMax = 200;
  static const int _kChargeLowTempMin = -60, _kChargeLowTempMax = 0;
  static const int _kDischargeHighTempMin = 0, _kDischargeHighTempMax = 200;
  static const int _kDischargeLowTempMin = -60, _kDischargeLowTempMax = 0;
  static const int _kDiffTempMin = 0, _kDiffTempMax = 200;

  // ── Field labels (used for change-tracking + the "unsaved changes" dialog) ─
  static const Map<String, String> _batteryFieldLabels = {
    'batteryStringCount': 'Battery String',
    'ratedCapacity': 'Rated Capacity',
    'socSet': 'SOC Set',
    'sleepWaitingTime': 'Sleep Waiting Time',
    'balancedStartDifferenceVolt': 'Balanced Start Difference Volt',
    'balancedStartVolt': 'Balanced Start Volt',
    'nominalCellVolt': 'Nominal Cell Volt',
    'cellChemistry': 'Cell Chemistry',
  };

  static const Map<String, String> _protectionFieldLabels = {
    'singleCellHighVoltProtection': 'Single Cell High Volt Protection',
    'singleCellLowVoltProtection': 'Single Cell Low Volt Protection',
    'sumVoltHighProtection': 'Sum Volt High Protection',
    'sumVoltLowProtection': 'Sum Volt Low Protection',
    'chargeOverCurrentProtection': 'Charge Over Current Protection',
    'dischargeOverCurrentProtection': 'Discharge Over Current Protection',
  };

  static const Map<String, String> _tempFieldLabels = {
    'noOfTempChannels': 'No of Temp Channels',
    'chargeHighTempProtection': 'Charge High Temp Protection',
    'chargeLowTempProtection': 'Charge Low Temp Protection',
    'dischargeHighTempProtection': 'Discharge High Temp Protection',
    'dischargeLowTempProtection': 'Discharge Low Temp Protection',
    'diffTempProtection': 'Diff Temp Protection',
  };

  static const Map<String, String> _factoryFieldLabels = {
    'batterySerialNo': 'Battery Serial No',
    'bmsSerialNo': 'BMS Serial No',
    'bleDeviceName': 'BLE Device Name',
  };

  // ── Dirty-tracking baselines (last known "saved" values per tab) ───────────
  // Empty map == baseline not established yet for that tab (no highlighting).
  Map<String, dynamic> _batteryBaseline = {};
  Map<String, dynamic> _protectionBaseline = {};
  Map<String, dynamic> _tempBaseline = {};
  Map<String, dynamic> _factoryBaseline = {};

  Map<String, dynamic> get _batteryCurrent => {
        'batteryStringCount': batteryStringCount,
        'ratedCapacity': ratedCapacity,
        'socSet': socSet,
        'sleepWaitingTime': sleepWaitingTime,
        'balancedStartDifferenceVolt': balancedStartDifferenceVolt,
        'balancedStartVolt': balancedStartVolt,
        'nominalCellVolt': nominalCellVolt,
        'cellChemistry': cellChemistry,
      };

  Map<String, dynamic> get _protectionCurrent => {
        'singleCellHighVoltProtection': singleCellHighVoltProtection,
        'singleCellLowVoltProtection': singleCellLowVoltProtection,
        'sumVoltHighProtection': sumVoltHighProtection,
        'sumVoltLowProtection': sumVoltLowProtection,
        'chargeOverCurrentProtection': chargeOverCurrentProtection,
        'dischargeOverCurrentProtection': dischargeOverCurrentProtection,
      };

  Map<String, dynamic> get _tempCurrent => {
        'noOfTempChannels': noOfTempChannels,
        'chargeHighTempProtection': chargeHighTempProtection,
        'chargeLowTempProtection': chargeLowTempProtection,
        'dischargeHighTempProtection': dischargeHighTempProtection,
        'dischargeLowTempProtection': dischargeLowTempProtection,
        'diffTempProtection': diffTempProtection,
      };

  Map<String, dynamic> get _factoryCurrent => {
        'batterySerialNo': batterySerialNo,
        'bmsSerialNo': bmsSerialNo,
        'bleDeviceName': bleDeviceName,
      };

    void _snapshotBaseline(int tabIndex) {
      switch (tabIndex) {
        case 0:
          _batteryBaseline = Map<String, dynamic>.of(_batteryCurrent);
          break;
        case 1:
          _protectionBaseline = Map<String, dynamic>.of(_protectionCurrent);
          break;
        case 2:
          _tempBaseline = Map<String, dynamic>.of(_tempCurrent);
          break;
        case 3:
          _factoryBaseline = Map<String, dynamic>.of(_factoryCurrent);
          break;
      }
    }

  Map<String, dynamic> _currentMapForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: return _batteryCurrent;
      case 1: return _protectionCurrent;
      case 2: return _tempCurrent;
      case 3: return _factoryCurrent;
      default: return {};
    }
  }

  Map<String, dynamic> _baselineForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: return _batteryBaseline;
      case 1: return _protectionBaseline;
      case 2: return _tempBaseline;
      case 3: return _factoryBaseline;
      default: return {};
    }
  }

  Map<String, String> _labelsForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: return _batteryFieldLabels;
      case 1: return _protectionFieldLabels;
      case 2: return _tempFieldLabels;
      case 3: return _factoryFieldLabels;
      default: return {};
    }
  }

  /// Keys whose current value differs from the last-saved baseline for [tabIndex].
  List<String> _changedFieldKeys(int tabIndex) {
    final baseline = _baselineForTab(tabIndex);
    if (baseline.isEmpty) return [];
    final current = _currentMapForTab(tabIndex);
    final changed = <String>[];
    current.forEach((k, v) {
      if (baseline.containsKey(k) && baseline[k] != v) changed.add(k);
    });
    return changed;
  }

  bool _isFieldChanged(int tabIndex, String key) => _changedFieldKeys(tabIndex).contains(key);

  void _discardChangesForTab(int tabIndex) {
    final baseline = _baselineForTab(tabIndex);
    if (baseline.isEmpty) return;
    setState(() {
      switch (tabIndex) {
        case 0:
          batteryStringCount = baseline['batteryStringCount'] as int;
          ratedCapacity = baseline['ratedCapacity'] as double;
          socSet = baseline['socSet'] as int;
          sleepWaitingTime = baseline['sleepWaitingTime'] as int;
          balancedStartDifferenceVolt = baseline['balancedStartDifferenceVolt'] as double;
          balancedStartVolt = baseline['balancedStartVolt'] as double;
          nominalCellVolt = baseline['nominalCellVolt'] as double;
          cellChemistry = baseline['cellChemistry'] as String;
          break;
        case 1:
          singleCellHighVoltProtection = baseline['singleCellHighVoltProtection'] as double;
          singleCellLowVoltProtection = baseline['singleCellLowVoltProtection'] as double;
          sumVoltHighProtection = baseline['sumVoltHighProtection'] as double;
          sumVoltLowProtection = baseline['sumVoltLowProtection'] as double;
          chargeOverCurrentProtection = baseline['chargeOverCurrentProtection'] as double;
          dischargeOverCurrentProtection = baseline['dischargeOverCurrentProtection'] as double;
          break;
        case 2:
          noOfTempChannels = baseline['noOfTempChannels'] as int;
          chargeHighTempProtection = baseline['chargeHighTempProtection'] as int;
          chargeLowTempProtection = baseline['chargeLowTempProtection'] as int;
          dischargeHighTempProtection = baseline['dischargeHighTempProtection'] as int;
          dischargeLowTempProtection = baseline['dischargeLowTempProtection'] as int;
          diffTempProtection = baseline['diffTempProtection'] as int;
          break;
        case 3:
          batterySerialNo = baseline['batterySerialNo'] as String;
          bmsSerialNo = baseline['bmsSerialNo'] as String;
          bleDeviceName = baseline['bleDeviceName'] as String;
          break;
      }
    });
    _persistSettings();
  }
FirmwareUpgradeStage _lastFwStage = FirmwareUpgradeStage.idle;
RestartStage _lastRestartStage = RestartStage.idle;
FactoryResetStage _lastFactoryResetStage = FactoryResetStage.idle;
Timer? _restartCountdownTimer;
Timer? _factoryResetCountdownTimer;
Timer? _fwUpgradeCountdownTimer;
bool _factoryResetDialogOpen = false;

Future<void> _startFirmwareUpgradeFlow() async {
  final confirmed = await _showContinueConfirmation();
  if (!confirmed) return;

  setState(() => _isSending = true);
  final ok = await widget.service.beginFirmwareUpgrade(); // sends 0xB5
  if (!ok) {
    if (!mounted) return;
    setState(() => _isSending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Firmware upgrade request failed — no response'),
        backgroundColor: Colors.red,
      ),
    );
  }
  // Everything from here on is driven by _onFirmwareUpgradeStageChanged
  // reacting to 0xC2 / 0xC3 arriving.
}

void _onFirmwareUpgradeStageChanged() {
  if (!mounted) return;
  final stage = widget.service.firmwareUpgradeStage;
  if (stage == _lastFwStage) return;
  _lastFwStage = stage;

  switch (stage) {
    case FirmwareUpgradeStage.waitingForFile:
  // 0xC2 received — show a dialog prompting the user to select the file,
  // instead of opening the native picker directly.
  _showSelectFirmwareFileDialog();
  break;

    case FirmwareUpgradeStage.upgrading:
      // 0xC3 received — show blocking "buffering" dialog + start 5 min timer.
      _showFirmwareUpgradingDialog();
      break;

    case FirmwareUpgradeStage.failed:
      setState(() => _isSending = false);
      if (Navigator.canPop(context)) Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firmware upgrade failed'), backgroundColor: Colors.red),
      );
      widget.service.resetFirmwareUpgradeState();
      break;

    default:
      break;
  }
}

Future<void> _startRestartFlow() async {
  setState(() => _isSending = true);
  final ok = await widget.service.beginRestart(); // sends 0xB6
  if (!ok) {
    if (!mounted) return;
    setState(() => _isSending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Restart request failed — no response'),
        backgroundColor: Colors.red,
      ),
    );
  }
  // Everything from here is driven by _onRestartStageChanged reacting to 0xC4.
}

void _onRestartStageChanged() {
  if (!mounted) return;
  final stage = widget.service.restartStage;
  if (stage == _lastRestartStage) return;
  _lastRestartStage = stage;

  switch (stage) {
    case RestartStage.restarting:
      // 0xC4 received — show blocking "restarting" dialog + 3 min timer.
      _showRestartingDialog();
      break;

    case RestartStage.failed:
      setState(() => _isSending = false);
      if (Navigator.canPop(context)) Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restart failed'), backgroundColor: Colors.red),
      );
      widget.service.resetRestartState();
      break;

    default:
      break;
  }
}
Future<void> _showAutoDismissMessageDialog({
  required IconData icon,
  required Color iconColor,
  required String title,
  String? subtitle,
  Duration duration = const Duration(seconds: 2),
}) async {
  if (!mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: iconColor),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Colors.black54), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    ),
  );

  await Future.delayed(duration);
  if (!mounted) return;
  Navigator.of(context, rootNavigator: true).maybePop();
}

void _showLoadingDialog(String title, {String? subtitle}) {
  if (!mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Colors.black54), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    ),
  );
}

void _showRestartingDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restarting…', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            SizedBox(height: 6),
            Text(
              'Please wait (1 min)',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );

  _restartCountdownTimer = Timer(const Duration(minutes: 1), () async {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).maybePop(); // close the dialog
    await widget.service.resetConnectionAfterRestart();
    if (!mounted) return;
    setState(() => _isSending = false);
    Navigator.pushAndRemoveUntil(
      context,
      SlideRoute(page: BluetoothDeviceScanPage(service: widget.service)),
      (route) => false,
    );
  });
}
void _showSelectFirmwareFileDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Firmware Upgrade',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1B6B3A)),
      ),
      content: const Text(
        'Select the firmware upgrade file (.bin / .hex) to continue.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.black54),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2B5FA5), 
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          onPressed: () {
            Navigator.of(ctx).pop();
            _pickAndUploadFirmware(); // NOW opens the native picker
          },
          child: const Text('Select'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            setState(() => _isSending = false);
            widget.service.resetFirmwareUpgradeState();
          },
          child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey)),
        ),
      ],
    ),
  );
}
Future<void> _pickAndUploadFirmware() async {
  const XTypeGroup firmwareTypeGroup = XTypeGroup(
    label: 'Firmware',
    extensions: ['bin', 'hex'],
  );

  final XFile? selectedFile = await openFile(
    acceptedTypeGroups: [firmwareTypeGroup],
  );

  if (selectedFile == null) {
    // User cancelled — reset so they can retry.
    if (mounted) {
      setState(() => _isSending = false);
    }
    widget.service.resetFirmwareUpgradeState();
    return;
  }

  // ── NEW: confirm the file was picked ──────────────────────────────
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File selected successfully'),
        backgroundColor: Color(0xFF1B6B3A),
      ),
    );
  }

  try {
    final file = File(selectedFile.path);
    final bytes = await file.readAsBytes();

    final ok = await widget.service.uploadFirmwareFile(bytes);

    if (!mounted) return;

    if (!ok) {
      setState(() => _isSending = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firmware upload failed'),
          backgroundColor: Colors.red,
        ),
      );  

      widget.service.resetFirmwareUpgradeState();
    } else {
      // ── NEW: confirm the upload itself finished ─────────────────────
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File uploaded successfully'),
          backgroundColor: Color(0xFF1B6B3A),
        ),
      );
    }

    // Success: wait for 0xC3 acknowledgement.
    // _onFirmwareUpgradeStageChanged() will continue the process.
  } catch (e) {
    if (!mounted) return;

    setState(() => _isSending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to read firmware file: $e'),
        backgroundColor: Colors.red,
      ),
    );

    widget.service.resetFirmwareUpgradeState();
  }
}

void _showFirmwareUpgradingDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Upgrading…',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Buffering (3 min)',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );

  _fwUpgradeCountdownTimer = Timer(const Duration(minutes: 3), () async {
    if (!mounted) return;

    // Close the "Upgrading… / Buffering" dialog.
    Navigator.of(context, rootNavigator: true).maybePop();

    // Step 1 — "Upgrade Successful" (auto-dismisses after ~2s).
    await _showAutoDismissMessageDialog(
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF1B6B3A),
      title: 'Upgrade Successful',
    );
    if (!mounted) return;

    // Step 2 — "Restarting…" while the BLE connection resets.
    _showLoadingDialog('Restarting…', subtitle: 'Please wait');
    await widget.service.resetConnectionAfterFirmwareUpgrade();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).maybePop(); // close "Restarting…"

    setState(() => _isSending = false);

    // Step 3 — show the scan page.
    Navigator.pushAndRemoveUntil(
      context,
      SlideRoute(page: BluetoothDeviceScanPage(service: widget.service)),
      (route) => false,
    );
  });
}
  /// Called when the user taps a different tab. Blocks the switch with a
  /// confirmation dialog if the current tab has unsaved edits.
  void _onTabTapped(int i) {
    if (i == _selectedTab) return;
    final fromTab = _selectedTab;
    final changedKeys = _changedFieldKeys(fromTab);

    if (changedKeys.isEmpty) {
      setState(() => _selectedTab = i);
      _pollForTab(i);
      return;
    }

    final labels = _labelsForTab(fromTab);
    final changedNames = changedKeys.map((k) => labels[k] ?? k).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unsaved Changes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'These values were changed but not sent to the device with "Set Now":',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            ...changedNames.map(
              (n) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle, size: 6, color: Color(0xFFD4621A)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(n, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Continue without saving?',
              style: TextStyle(color: Colors.black54, fontSize: 12.5),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4621A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _discardChangesForTab(fromTab);
              setState(() => _selectedTab = i);
              _pollForTab(i);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String tr(String key) {
    return TranslationService.t(key);
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      setState(fn);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(fn);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.service.stopAllPolling();
    TranslationService.instance.addListener(_onTranslationsChanged);
    widget.service.addListener(_onServiceChanged);
    _loadCachedSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollForTab(_selectedTab));
    widget.service.addListener(_onFirmwareUpgradeStageChanged);
    widget.service.addListener(_onRestartStageChanged);      
    widget.service.addListener(_onFactoryResetStageChanged);
  }

  void _onTranslationsChanged() {
    _safeSetState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Track lifecycle so BLE-driven updates can be safely ignored while the
    // app isn't in the foreground. We deliberately do NOT call setState()
    // here beyond what's needed — just record the state.
    _lifecycleState = state;
  }

  int _lastBatteryPulse = -1;
  int _lastProtectionPulse = -1;
  int _lastTempPulse = -1;
  int _lastFactoryPulse = -1;
  int _lastDeviceDetailsPulse = -1;
  bool _deviceDetailsRequested = false;

  void _onServiceChanged() {
    if (!mounted) return;

    // Ignore updates while the app isn't actively resumed in the
    // foreground (e.g. backgrounded, inactive, paused, detached). Calling
    // setState() during these transitions was triggering a layout pass on
    // a view that wasn't fully attached, which surfaced as:
    //   "RenderBox was not laid out: _RenderSingleChildViewport ..."
    // and showed up to the user as a brief blank screen.
    if (_lifecycleState != AppLifecycleState.resumed) return;

    // Compute what (if anything) actually changed before calling
    // setState(). The service notifies listeners on every BLE response,
    // including ones unrelated to whatever's on screen (e.g. dashboard
    // auto-refresh 0x93 while the Settings screen is open). Rebuilding the
    // whole screen — which mounts all 4 tabs inside an IndexedStack — on
    // every single one of those was unnecessary and made the "not laid
    // out" race far more likely to hit.
    final newOffline = widget.service.latestDashboard == null;

    final bs = widget.service.latestBatterySettings;
    final bsChanged = bs != null && widget.service.batterySettingsPulse != _lastBatteryPulse;

    final ps = widget.service.latestProtectionSettings;
    final psChanged = ps != null && widget.service.protectionSettingsPulse != _lastProtectionPulse;

    final ts = widget.service.latestTemperatureSettings;
    final tsChanged = ts != null && widget.service.temperatureSettingsPulse != _lastTempPulse;

    final fs = widget.service.latestFactorySettings;
    final fsChanged = fs != null && widget.service.factorySettingsPulse != _lastFactoryPulse;

    final dd = widget.service.latestDeviceDetails;
    final ddChanged = dd != null && widget.service.deviceDetailsPulse != _lastDeviceDetailsPulse;

    if (newOffline == _isOffline && !bsChanged && !psChanged && !tsChanged && !fsChanged && !ddChanged) {
      // Nothing relevant to this screen changed — skip the rebuild entirely.
      return;
    }

    _safeSetState(() {
      _isOffline = newOffline;
      isConnected = !_isOffline;

      if (bsChanged) {
        _lastBatteryPulse = widget.service.batterySettingsPulse;
        batteryStringCount = bs.batteryString ?? batteryStringCount;
        ratedCapacity = bs.ratedCapacity ?? ratedCapacity;
        socSet = bs.socSet ?? socSet;
        sleepWaitingTime = bs.sleepWaitingTime ?? sleepWaitingTime;
        balancedStartDifferenceVolt = bs.balancedStartDiffVolt ?? balancedStartDifferenceVolt;
        balancedStartVolt = bs.balancedStartVolt ?? balancedStartVolt;
        nominalCellVolt = bs.nominalCellVoltage ?? nominalCellVolt;
        if (bs.cellChemistry != null) cellChemistry = BMSProtocol.chemistryName(bs.cellChemistry!);
        _snapshotBaseline(0);
        _persistSettings();
        // One-shot read: stop polling as soon as the first response for
        // this tab has arrived instead of continuing to request it on an
        // interval.
       if (!_batteryLoadedOnce) {
          _batteryLoadedOnce = true;
          widget.service.stopSettingsPolling();
        }
        _batteryRequestSent = false;

      }

      if (psChanged) {
        _lastProtectionPulse = widget.service.protectionSettingsPulse;
        singleCellHighVoltProtection = ps.singleCellHighVoltProtection ?? singleCellHighVoltProtection;
        singleCellLowVoltProtection = ps.singleCellLowVoltProtection ?? singleCellLowVoltProtection;
        sumVoltHighProtection = ps.sumVoltHighProtection ?? sumVoltHighProtection;
        sumVoltLowProtection = ps.sumVoltLowProtection ?? sumVoltLowProtection;
        chargeOverCurrentProtection = ps.chargeOverCurrentProtection ?? chargeOverCurrentProtection;
        dischargeOverCurrentProtection = ps.dischargeOverCurrentProtection ?? dischargeOverCurrentProtection;
        _snapshotBaseline(1);
        _persistSettings();
        if (!_protectionLoadedOnce) {
          _protectionLoadedOnce = true;
          widget.service.stopSettingsPolling();
        }
        _protectionRequestSent = false;
      }

      if (tsChanged) {
        _lastTempPulse = widget.service.temperatureSettingsPulse;
        noOfTempChannels = ts.noOfTempChannels ?? noOfTempChannels;
        chargeHighTempProtection = ts.chargeHighTempProtection ?? chargeHighTempProtection;
        chargeLowTempProtection = ts.chargeLowTempProtection ?? chargeLowTempProtection;
        dischargeHighTempProtection = ts.dischargeHighTempProtection ?? dischargeHighTempProtection;
        dischargeLowTempProtection = ts.dischargeLowTempProtection ?? dischargeLowTempProtection;
        diffTempProtection = ts.diffTempProtection ?? diffTempProtection;
        _snapshotBaseline(2);
        _persistSettings();
       if (!_tempLoadedOnce) {
          _tempLoadedOnce = true;
          widget.service.stopSettingsPolling();
        }
        _tempRequestSent = false;
      }

      if (fsChanged) {
        _lastFactoryPulse = widget.service.factorySettingsPulse;
        batterySerialNo = fs.batterySlNo ?? batterySerialNo;
        bmsSerialNo = fs.bmsSerialNo ?? bmsSerialNo;
        bleDeviceName = fs.bleDeviceName ?? bleDeviceName;
        _snapshotBaseline(3);
        _persistSettings();
       if (!_factoryLoadedOnce) {
          _factoryLoadedOnce = true;
          widget.service.stopSettingsPolling();
        }
       _factoryRequestSent = false;
      }

      if (ddChanged) {
        _lastDeviceDetailsPulse = widget.service.deviceDetailsPulse;
        bmssNo = dd.batterySerial ?? bmssNo;
        swVersionNo = dd.softwareVersion ?? swVersionNo;
        hwVersionNo = dd.hardwareVersion ?? hwVersionNo;
        fwVersionNo = dd.firmwareVersion ?? fwVersionNo;
        _persistSettings();
      }
    });
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TranslationService.instance.removeListener(_onTranslationsChanged);
    widget.service.removeListener(_onServiceChanged);
    widget.service.removeListener(_onFirmwareUpgradeStageChanged); 
    widget.service.removeListener(_onRestartStageChanged);         
    widget.service.removeListener(_onFactoryResetStageChanged);    
    widget.service.stopSettingsPolling();
    _fwUpgradeCountdownTimer?.cancel();
    _restartCountdownTimer?.cancel();        
    _factoryResetCountdownTimer?.cancel();   
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
        bmsSerialNo = (cached['bmsSerialNo'] as String?) ?? bmsSerialNo;
        bleDeviceName = (cached['bleDeviceName'] as String?) ?? bleDeviceName;
        swVersionNo = (cached['swVersionNo'] as String?) ?? swVersionNo;
        hwVersionNo = (cached['hwVersionNo'] as String?) ?? hwVersionNo;
      });
    }

    setState(() {
      _lastSync = syncTime;
      _isOffline = widget.service.latestDashboard == null;
      isConnected = !_isOffline;
      _isLoadingCache = false;
      // Establish baselines from whatever we just loaded/started with, so
      // no field appears "changed" until the user actually edits something.
      _snapshotBaseline(0);
      _snapshotBaseline(1);
      _snapshotBaseline(2);
      _snapshotBaseline(3);
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
      'bmsSerialNo': bmsSerialNo,
      'bleDeviceName': bleDeviceName,
      'swVersionNo': swVersionNo,
      'hwVersionNo': hwVersionNo,
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

  void _openPacketLog() {
    Navigator.of(context).push(
      SlideRoute(page: PacketLogScreen(service: widget.service)),
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
    // Sends a fresh device-details read to the BMS the moment the sheet is
    // opened, and closes the request once the first response arrives (see
    // _DeviceDetailsSheet below) instead of leaving anything polling.
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _DeviceDetailsSheet(service: widget.service),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B5FA5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // ── "Do you want to continue?" confirmation before sending a Set Now ────
  Future<bool> _showContinueConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Do You Want To Continue?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B5FA5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── "Parameters changed successfully" popup shown after a successful send ─
  Future<void> _showSuccessDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6B3A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Generic edit dialogs (with range validation) ────────────────────────────
  void _editDoubleParam(
    String title,
    double current,
    String unit,
    Function(double) onSave, {
    double? min,
    double? max,
  }) {
    final controller = TextEditingController(text: current.toStringAsFixed(3));
    String? errorText;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    suffixText: unit,
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                ),
                if (min != null && max != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Allowed range: ${min.toStringAsFixed(3)} - ${max.toStringAsFixed(3)} $unit',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B6B3A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final val = double.tryParse(controller.text);
                  if (val == null) {
                    setDialogState(() => errorText = 'Enter a valid number');
                    return;
                  }
                  if (min != null && max != null && (val < min || val > max)) {
                    setDialogState(
                      () => errorText = 'Must be between ${min.toStringAsFixed(3)} and ${max.toStringAsFixed(3)}',
                    );
                    return;
                  }
                  onSave(val);
                  _persistSettings();
                  Navigator.pop(context);
                },
                child: Text(tr('save')),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey))),
            ],
          );
        },
      ),
    );
  }

  void _editIntParam(
    String title,
    int current,
    String unit,
    Function(int) onSave, {
    int? min,
    int? max,
  }) {
    final controller = TextEditingController(text: current.toString());
    String? errorText;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    suffixText: unit,
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                ),
                if (min != null && max != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Allowed range: $min - $max $unit',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B6B3A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final val = int.tryParse(controller.text);
                  if (val == null) {
                    setDialogState(() => errorText = 'Enter a valid whole number');
                    return;
                  }
                  if (min != null && max != null && (val < min || val > max)) {
                    setDialogState(() => errorText = 'Must be between $min and $max');
                    return;
                  }
                  onSave(val);
                  _persistSettings();
                  Navigator.pop(context);
                },
                child: Text(tr('save')),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey))),
            ],
          );
        },
      ),
    );
  }

  void _editStringParam(String title, String current, Function(String) onSave) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, textAlign: TextAlign.center),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6B3A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSave(controller.text.trim());
                _persistSettings();
                Navigator.pop(context);
              }
            },
            child: Text(tr('save')),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey))),
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

  Future<void> _handleSetNow(String context_, Future<bool> Function() onSetNow, {int? tabIndex}) async {
    // Step 1 — confirm with the user before sending anything to the device.
    final confirmed = await _showContinueConfirmation();
    if (!confirmed) return;

    setState(() => _isSending = true);
    bool ok = false;
    try {
      ok = await onSetNow();
    } catch (e) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _isSending = false;
      // On a successful send, the values just sent become the new "saved"
      // baseline, so they stop showing up as unsaved/changed (and the Set
      // Now button disables itself again since nothing is dirty anymore).
      if (ok && tabIndex != null) _snapshotBaseline(tabIndex);
    });
if (ok) {
      if (tabIndex != null) {
        if (tabIndex == 3) {
          // Factory write (0xB4) has no ack — give the BMS time to persist
          // to flash before re-reading, or the read-back races the write
          // and returns stale data, silently reverting the edit.
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
        }
        _pollForTab(tabIndex);
      }
      // Step 2 — confirm success with a dedicated popup rather than only a
      // snackbar, per the requested flow.
      await _showSuccessDialog('$context_ parameters changed successfully.');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$context_ settings failed — no ACK received'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Calibrate Now is intentionally kept simple: no "Do You Want To
  /// Continue?" gate and no success popup — just send it and show a plain
  /// snackbar, same as before.
  Future<void> _handleCalibration() async {
    setState(() => _isSending = true);
    bool ok = false;
    try {
      ok = await widget.service.sendCalibration();
    } catch (e) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _isSending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Zero drift current calibration sent successfully'
            : 'Zero drift current calibration failed — no ACK received'),
        backgroundColor: ok ? const Color(0xFF1B6B3A) : Colors.red,
      ),
    );
  }

  /// Generic action runner used by Firmware Upgrade, Restart, etc.
  /// By default it shows the same "Do You Want To Continue?" gate used
  /// by Set Now before sending anything, and — on success — the same
  /// "…successful" popup instead of just a snackbar. Pass
  /// [confirmFirst]: false when the caller already showed its own
  /// confirmation dialog (e.g. Restart's "Are you sure…" prompt) so the
  /// user isn't asked to confirm twice.
  Future<void> _handleAction(
    String actionName,
    Future<bool> Function() action, {
    bool confirmFirst = true,
  }) async {
    if (confirmFirst) {
      final confirmed = await _showContinueConfirmation();
      if (!confirmed) return;
    }

    setState(() => _isSending = true);
    bool ok = false;
    try {
      ok = await action();
    } catch (e) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _isSending = false);

    if (ok) {
      await _showSuccessDialog('$actionName sent successfully.');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$actionName failed — no ACK received'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startFactoryResetFlow() async {
  setState(() => _isSending = true);
  final ok = await widget.service.beginFactoryReset(); // sends 0xB7
  if (!ok) {
    if (!mounted) return;
    setState(() => _isSending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Factory data reset request failed — no response'),
        backgroundColor: Colors.red,
      ),
    );
  }
  // Everything from here is driven by _onFactoryResetStageChanged reacting to 0xC5.
}

void _onFactoryResetStageChanged() {
  if (!mounted) return;
  final stage = widget.service.factoryResetStage;
  if (stage == _lastFactoryResetStage) return;
  _lastFactoryResetStage = stage;

    switch (stage) {
    case FactoryResetStage.resetting:
      // 0xC5 received — show blocking "resetting" dialog + 2 min timer.
      if (!_factoryResetDialogOpen) _showFactoryResettingDialog();
      break;

    case FactoryResetStage.failed:
      setState(() => _isSending = false);
      if (Navigator.canPop(context)) Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factory data reset failed'), backgroundColor: Colors.red),
      );
      widget.service.resetFactoryResetState();
      break;

    default:
      break;
  }
}

void _showFactoryResettingDialog() {
  // Guard against this being triggered twice (duplicate 0xC5 / stage
  // notification), which previously stacked two dialogs + two timers and
  // left the spinner stuck on screen even after the reset had completed.
  if (_factoryResetDialogOpen) return;
  _factoryResetDialogOpen = true;
  _factoryResetCountdownTimer?.cancel();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Resetting…', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            SizedBox(height: 6),
            Text(
              'Resetting to default values (30 sec)',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  ).then((_) {
    // Keeps the flag accurate no matter how the dialog route ends up closed.
    _factoryResetDialogOpen = false;
  });

  _factoryResetCountdownTimer = Timer(const Duration(seconds: 30), () async {
    if (!mounted) return;

    if (_factoryResetDialogOpen && Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop(); // close resetting dialog
    }
    _factoryResetDialogOpen = false;
    widget.service.resetFactoryResetState();

    // BMS is still connected — resume the heartbeat we paused on 0xC5.
    widget.service.startLiveStatusMonitor();

    _batteryRequestSent = false;
    _protectionRequestSent = false;
    _tempRequestSent = false;
    _factoryRequestSent = false;

    // Re-request whichever tab's settings the user is currently on — the
    // device now responds with its post-reset default values (0x52).
    _pollForTab(_selectedTab);

    // Also refresh Device Details after a reset, no matter which tab is
    // active — Factory Settings already triggers this via _pollForTab(3),
    // but the other tabs don't request it as part of their normal flow.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      widget.service.requestDeviceDetails();
    });

    setState(() => _isSending = false);

    await _showSuccessDialog('Factory data reset completed.');
  });
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
              if (value == 'disconnect') {
                _showDisconnectDialog();
              } else if (value == 'packet_log') {
                _openPacketLog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'packet_log', child: Text('Packet Log')),
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
      // NOTE: Do NOT use CrossAxisAlignment.stretch here. This Row lives
      // inside a Column inside a SingleChildScrollView, which gives it an
      // unbounded (0..Infinity) height constraint. `stretch` forces every
      // child to be given the Row's own height as a tight constraint —
      // when that height is unbounded, Flutter throws
      // "BoxConstraints forces an infinite height" during layout. This was
      // the real cause of the settings screen going blank: it's a
      // layout-time assertion, so Flutter can't fall back to a red error
      // screen — the whole body subtree just fails to paint.
      // Each tab item already sets its own explicit height (48) on its
      // Container below, so no cross-axis alignment is needed here.
      children: List.generate(_tabLabels.length, (i) {
        final selected = _selectedTab == i;
        final hasUnsaved = _changedFieldKeys(i).isNotEmpty;
        return Expanded(
          child: GestureDetector(
            onTap: () => _onTabTapped(i),
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF16324F) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? const Color(0xFF16324F) : Colors.grey.shade300),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
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
                  if (hasUnsaved)
                    Positioned(
                      top: -2,
                      right: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFFD4621A), shape: BoxShape.circle),
                      ),
                    ),
                ],
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
    bool changed = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: changed ? const Color(0xFFFFF3E6) : Colors.grey.shade50,
        border: Border.all(color: changed ? const Color(0xFFD4621A) : Colors.grey.shade300, width: changed ? 1.4 : 1),
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
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                ),
                if (changed) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.circle, size: 7, color: Color(0xFFD4621A)),
                ],
              ],
            ),
          ),
          if (trailingOverride != null)
            trailingOverride
          else ...[
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: changed ? const Color(0xFFD4621A) :  Colors.black87,
              ),
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

bool _isSending = false;

  Widget _buildSetNowFooter(String sectionName, Future<bool> Function() onSetNow, {int? tabIndex}) {
    // The Set Now button is only enabled when this tab actually has unsaved
    // changes — otherwise there's nothing to send, so it stays disabled.
    final bool isDirty = tabIndex == null || _changedFieldKeys(tabIndex).isNotEmpty;
    final bool enabled = !isLocked && !_isSending && isDirty;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6FA88A),
              disabledBackgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey.shade500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: enabled ? () => _handleSetNow(sectionName, onSetNow, tabIndex: tabIndex) : null,
            child: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Set Now'),
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
          changed: _isFieldChanged(0, 'batteryStringCount'),
          onEdit: isLocked
              ? null
              : () => _editIntParam(
                    'Battery String',
                    batteryStringCount,
                    'S',
                    (v) => setState(() => batteryStringCount = v),
                    min: _kBatteryStringMin,
                    max: _kBatteryStringMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.battery_charging_full_rounded,
          label: 'Rated Capacity',
          value: '${ratedCapacity.toStringAsFixed(1)} AH',
          changed: _isFieldChanged(0, 'ratedCapacity'),
          onEdit: isLocked
              ? null
              : () => _editDoubleParam(
                    'Rated Capacity',
                    ratedCapacity,
                    'AH',
                    (v) => setState(() => ratedCapacity = v),
                    min: _kRatedCapacityMin,
                    max: _kRatedCapacityMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.battery_5_bar_rounded,
          label: 'SOC Set',
          value: '$socSet %',
          changed: _isFieldChanged(0, 'socSet'),
          onEdit: isLocked
              ? null
              : () => _editIntParam(
                    'SOC Set',
                    socSet,
                    '%',
                    (v) => setState(() => socSet = v),
                    min: _kSocSetMin,
                    max: _kSocSetMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.access_time_rounded,
          label: 'Sleep Waiting Time',
          value: '$sleepWaitingTime ms',
          changed: _isFieldChanged(0, 'sleepWaitingTime'),
          onEdit: isLocked
              ? null
              : () => _editIntParam(
                    'Sleep Waiting Time',
                    sleepWaitingTime,
                    'ms',
                    (v) => setState(() => sleepWaitingTime = v),
                    min: _kSleepWaitMin,
                    max: _kSleepWaitMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.balance_rounded,
          label: 'Balanced Start Difference Volt',
          value: '${balancedStartDifferenceVolt.toStringAsFixed(3)} V',
          changed: _isFieldChanged(0, 'balancedStartDifferenceVolt'),
          onEdit: isLocked
              ? null
              : () => _editDoubleParam(
                    'Balanced Start Difference Volt',
                    balancedStartDifferenceVolt,
                    'V',
                    (v) => setState(() => balancedStartDifferenceVolt = v),
                    min: _kBalStartDiffMin,
                    max: _kBalStartDiffMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.play_circle_outline_rounded,
          label: 'Balanced Start Volt',
          value: '${balancedStartVolt.toStringAsFixed(3)} V',
          changed: _isFieldChanged(0, 'balancedStartVolt'),
          onEdit: isLocked
              ? null
              : () => _editDoubleParam(
                    'Balanced Start Volt',
                    balancedStartVolt,
                    'V',
                    (v) => setState(() => balancedStartVolt = v),
                    min: _kBalStartVoltMin,
                    max: _kBalStartVoltMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.bolt_rounded,
          label: 'Nominal Cell Volt',
          value: '${nominalCellVolt.toStringAsFixed(3)} V',
          changed: _isFieldChanged(0, 'nominalCellVolt'),
          onEdit: isLocked
              ? null
              : () => _editDoubleParam(
                    'Nominal Cell Volt',
                    nominalCellVolt,
                    'V',
                    (v) => setState(() => nominalCellVolt = v),
                    min: _kNominalCellMin,
                    max: _kNominalCellMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.science_outlined,
          label: 'Cell Chemistry',
          value: cellChemistry,
          changed: _isFieldChanged(0, 'cellChemistry'),
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
            onPressed: (isLocked || _isSending)
              ? null
              : () => _handleCalibration(),
            child: const Text('Calibrate Now', style: TextStyle(fontSize: 12)),
          ),
        ),
        _buildSetNowFooter(
          'Battery',
          () => widget.service.sendBatterySettingsWrite(
            batteryString: batteryStringCount,
            ratedCapacityAh: ratedCapacity,
            socSetPercent: socSet,
            sleepWaitingTime: sleepWaitingTime,
            balancedStartDiffVolt: balancedStartDifferenceVolt,
            balancedStartVolt: balancedStartVolt,
            nominalCellVolt: nominalCellVolt,
            cellChemistry: BMSProtocol.chemistryCode(cellChemistry),
          ),
          tabIndex: 0,
        ),
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
          changed: _isFieldChanged(1, 'singleCellHighVoltProtection'),
          onEdit: isLocked
              ? null
              : () => _editDoubleParam(
                    'Single Cell High Volt Protection',
                    singleCellHighVoltProtection,
                    'V',
                    (v) => setState(() => singleCellHighVoltProtection = v),
                    min: _kCellHighVoltMin,
                    max: _kCellHighVoltMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.battery_alert_rounded,
          iconColor: const Color(0xFF2B5FA5),
          label: 'Single Cell Low Volt Protection',
          value: '${singleCellLowVoltProtection.toStringAsFixed(3)} V',
          changed: _isFieldChanged(1, 'singleCellLowVoltProtection'),
          onEdit: isLocked
              ? null
              : () => _editDoubleParam(
                    'Single Cell Low Volt Protection',
                    singleCellLowVoltProtection,
                    'V',
                    (v) => setState(() => singleCellLowVoltProtection = v),
                    min: _kCellLowVoltMin,
                    max: _kCellLowVoltMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.show_chart_rounded,
          iconColor: const Color(0xFF2B5FA5),
          label: 'Sum Volt High Protection',
          value: '${sumVoltHighProtection.toStringAsFixed(1)} V',
          changed: _isFieldChanged(1, 'sumVoltHighProtection'),
          onEdit: isLocked
              ? null
              : () => _editDoubleParam(
                    'Sum Volt High Protection',
                    sumVoltHighProtection,
                    'V',
                    (v) => setState(() => sumVoltHighProtection = v),
                    min: _kSumVoltHighMin,
                    max: _kSumVoltHighMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.stacked_line_chart_rounded,
          iconColor: const Color(0xFF2B5FA5),
          label: 'Sum Volt Low Protection',
          value: '${sumVoltLowProtection.toStringAsFixed(1)} V',
          changed: _isFieldChanged(1, 'sumVoltLowProtection'),
          onEdit: isLocked
              ? null
              : () => _editDoubleParam(
                    'Sum Volt Low Protection',
                    sumVoltLowProtection,
                    'V',
                    (v) => setState(() => sumVoltLowProtection = v),
                    min: _kSumVoltLowMin,
                    max: _kSumVoltLowMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.battery_charging_full_rounded,
          iconColor: const Color(0xFFD4621A),
          label: 'Charge Over Current Protection',
          value: '${chargeOverCurrentProtection.toStringAsFixed(1)} A',
          changed: _isFieldChanged(1, 'chargeOverCurrentProtection'),
          onEdit: isLocked
              ? null
              : () => _editDoubleParam(
                    'Charge Over Current Protection',
                    chargeOverCurrentProtection,
                    'A',
                    (v) => setState(() => chargeOverCurrentProtection = v),
                    min: _kChargeOCMin,
                    max: _kChargeOCMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.electric_bolt_outlined,
          iconColor: Colors.redAccent.shade700,
          label: 'Discharge Over Current Protection',
          value: '${dischargeOverCurrentProtection.toStringAsFixed(1)} A',
          changed: _isFieldChanged(1, 'dischargeOverCurrentProtection'),
          onEdit: isLocked
              ? null
              : () => _editDoubleParam(
                    'Discharge Over Current Protection',
                    dischargeOverCurrentProtection,
                    'A',
                    (v) => setState(() => dischargeOverCurrentProtection = v),
                    min: _kDischargeOCMin,
                    max: _kDischargeOCMax,
                  ),
        ),
        _buildSetNowFooter(
          'Protection',
          () => widget.service.sendProtectionSettingsWrite(
            singleCellHighVolt: singleCellHighVoltProtection,
            singleCellLowVolt: singleCellLowVoltProtection,
            sumVoltHigh: sumVoltHighProtection,
            sumVoltLow: sumVoltLowProtection,
            chargeOverCurrent: chargeOverCurrentProtection,
            dischargeOverCurrent: dischargeOverCurrentProtection,
          ),
          tabIndex: 1,
        ),
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
          changed: _isFieldChanged(2, 'noOfTempChannels'),
          onEdit: isLocked
              ? null
              : () => _editIntParam(
                    'No of Temp Channels',
                    noOfTempChannels,
                    '',
                    (v) => setState(() => noOfTempChannels = v),
                    min: _kTempChannelsMin,
                    max: _kTempChannelsMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.thermostat_rounded,
          iconColor: Colors.redAccent.shade700,
          label: 'Charge High Temp Protection',
          value: '$chargeHighTempProtection °C',
          changed: _isFieldChanged(2, 'chargeHighTempProtection'),
          onEdit: isLocked
              ? null
              : () => _editIntParam(
                    'Charge High Temp Protection',
                    chargeHighTempProtection,
                    '°C',
                    (v) => setState(() => chargeHighTempProtection = v),
                    min: _kChargeHighTempMin,
                    max: _kChargeHighTempMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.ac_unit_rounded,
          iconColor: const Color(0xFF2B5FA5),
          label: 'Charge Low Temp Protection',
          value: '$chargeLowTempProtection °C',
          changed: _isFieldChanged(2, 'chargeLowTempProtection'),
          onEdit: isLocked
              ? null
              : () => _editIntParam(
                    'Charge Low Temp Protection',
                    chargeLowTempProtection,
                    '°C',
                    (v) => setState(() => chargeLowTempProtection = v),
                    min: _kChargeLowTempMin,
                    max: _kChargeLowTempMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.redAccent.shade700,
          label: 'Discharge High Temp Protection',
          value: '$dischargeHighTempProtection °C',
          changed: _isFieldChanged(2, 'dischargeHighTempProtection'),
          onEdit: isLocked
              ? null
              : () => _editIntParam(
                    'Discharge High Temp Protection',
                    dischargeHighTempProtection,
                    '°C',
                    (v) => setState(() => dischargeHighTempProtection = v),
                    min: _kDischargeHighTempMin,
                    max: _kDischargeHighTempMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.severe_cold_rounded,
          iconColor: const Color(0xFF2B5FA5),
          label: 'Discharge Low Temp Protection',
          value: '$dischargeLowTempProtection °C',
          changed: _isFieldChanged(2, 'dischargeLowTempProtection'),
          onEdit: isLocked
              ? null
              : () => _editIntParam(
                    'Discharge Low Temp Protection',
                    dischargeLowTempProtection,
                    '°C',
                    (v) => setState(() => dischargeLowTempProtection = v),
                    min: _kDischargeLowTempMin,
                    max: _kDischargeLowTempMax,
                  ),
        ),
        _buildSettingRow(
          icon: Icons.compare_arrows_rounded,
          iconColor: const Color(0xFFD4621A),
          label: 'Diff Temp Protection',
          value: '$diffTempProtection °C',
          changed: _isFieldChanged(2, 'diffTempProtection'),
          onEdit: isLocked
              ? null
              : () => _editIntParam(
                    'Diff Temp Protection',
                    diffTempProtection,
                    '°C',
                    (v) => setState(() => diffTempProtection = v),
                    min: _kDiffTempMin,
                    max: _kDiffTempMax,
                  ),
        ),
        _buildSetNowFooter(
          'Temp',
          () => widget.service.sendTemperatureSettingsWrite(
            noOfTempChannels: noOfTempChannels,
            chargeHighTemp: chargeHighTempProtection,
            chargeLowTemp: chargeLowTempProtection,
            dischargeHighTemp: dischargeHighTempProtection,
            dischargeLowTemp: dischargeLowTempProtection,
            diffTempProtection: diffTempProtection,
          ),
          tabIndex: 2,
        ),
      ],
    );
  }

  // ── Factory Settings tab ─────────────────────────────────────────────────
 Widget _buildFactoryTextField({
  required String label,
  required String value,
  required VoidCallback onEdit,
  required VoidCallback onScan,
  bool changed = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w500)),
            if (changed) ...[
              const SizedBox(width: 6),
              const Icon(Icons.circle, size: 7, color: Color(0xFFD4621A)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Value box (text + edit only) ──────────────────────
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: changed ? const Color(0xFFFFF3E6) : Colors.grey.shade50,
                  border: Border.all(
                    color: changed ? const Color(0xFFD4621A) : Colors.grey.shade300,
                    width: changed ? 1.4 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: changed ? const Color(0xFFD4621A) : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.black54),
                      onPressed: isLocked ? null : onEdit,
                      splashRadius: 16,
                      tooltip: 'Edit',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ── Scan button — separate box outside the field ──────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.qr_code_scanner_rounded, size: 19, color: Colors.grey.shade600),
                onPressed: isLocked ? null : onScan,
                splashRadius: 20,
                tooltip: 'Scan',
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  /// Opens the barcode/QR scanner and feeds the scanned code into [onResult].
  /// Wire this up to your actual scanner screen / package
  /// (e.g. push BluetoothDeviceScanPage-style scanner, or a package such as
  /// `mobile_scanner`) — this stub shows the flow and a manual fallback.
 Future<void> _scanCode(
  String title,
  Function(String) onResult,
) async {

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const BarcodeScannerDialog(),
  );

  if (result != null) {
    onResult(result);
    _persistSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$title scanned successfully"),
      ),
    );
  }
}

  /// Single row inside the read-only "Device Details" card at the bottom of
  /// the Factory Settings tab — a small coloured status dot, a label, and
  /// its value (e.g. "BMS Serial No - CHB14SA262400001").
  Widget _buildDeviceDetailDotRow(Color dotColor, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                children: [
                  TextSpan(text: '$label - ', style: const TextStyle(fontWeight: FontWeight.w500)),
                  TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Read-only "Device Details" summary card shown at the bottom of the
  /// Factory Settings tab: BMS Serial No, SW Version No, HW Version No.
  Widget _buildDeviceDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Device Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 8),
          _buildDeviceDetailDotRow(const Color(0xFF2B5FA5), 'BMS Serial No', bmssNo),
          _buildDeviceDetailDotRow(const Color(0xFF1B6B3A), 'SW Version No', swVersionNo),
          _buildDeviceDetailDotRow(const Color(0xFFD4A017), 'HW Version No', hwVersionNo),
          _buildDeviceDetailDotRow(const Color(0xFF8B5CF6), 'FW Version No', fwVersionNo),
        ],
      ),
    );
  }

  Widget _buildFactorySettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFactoryTextField(
          label: 'Battery Serial No',
          value: batterySerialNo,
          changed: _isFieldChanged(3, 'batterySerialNo'),
          onEdit: () => _editStringParam('Battery Serial No', batterySerialNo, (v) => setState(() => batterySerialNo = v)),
          onScan: () => _scanCode('Battery Serial No', (v) => setState(() => batterySerialNo = v)),
        ),
        _buildFactoryTextField(
          label: 'BMS Serial No',
          value: bmsSerialNo,
          changed: _isFieldChanged(3, 'bmsSerialNo'),
          onEdit: () => _editStringParam('BMS Serial No', bmsSerialNo, (v) => setState(() => bmsSerialNo = v)),
          onScan: () => _scanCode('BMS Serial No', (v) => setState(() => bmsSerialNo = v)),
        ),
        _buildFactoryTextField(
          label: 'BLE Device Name',
          value: bleDeviceName,
          changed: _isFieldChanged(3, 'bleDeviceName'),
          onEdit: () => _editStringParam('BLE Device Name', bleDeviceName, (v) => setState(() => bleDeviceName = v)),
          onScan: () => _scanCode('BLE Device Name', (v) => setState(() => bleDeviceName = v)),
        ),
        _buildSetNowFooter(
          'Factory',
          () => widget.service.sendFactorySettingsWrite(
            batterySlNo: batterySerialNo,
            bmsSerialNo: bmsSerialNo,
            bleDeviceName: bleDeviceName,
          ),
          tabIndex: 3,
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
                onPressed: (isLocked || _isSending)
                    ? null
                    : _startFirmwareUpgradeFlow,
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
                onPressed: (isLocked || _isSending)
                    ? null
                    : () => _showResetConfirmation(
                          'Restart',
                          'Are you sure you want to restart the BMS device?',
                          _startRestartFlow,        // was: () => _handleAction('Restart', ...)
                        ),
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Restart', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2B5FA5),
                  side: const BorderSide(color: Color(0xFF2B5FA5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: (isLocked || _isSending)
    ? null
    : () => _showResetConfirmation(
          'Factory Data Reset',
          'Are you sure you want to reset the BMS to factory defaults? This cannot be undone.',
          _startFactoryResetFlow,   // was: _handleFactoryReset
        ),
                icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
                label: const Text('Factory Data Reset',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5), overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Device Details summary (BMS Serial No / SW Version / HW Version) ──
        _buildDeviceDetailsCard(),

        const SizedBox(height: 24),
      ],
    );
  }
}

/// Bottom sheet shown from the "Device Details" button in the app bar row.
/// Unlike the old version (which just echoed whatever was already cached in
/// the parent screen's fields), this actively requests a fresh read from
/// the BMS the moment it opens, shows a loading spinner while waiting, and
/// stops the request as soon as the first response arrives — it does not
/// keep polling in the background.
class _DeviceDetailsSheet extends StatefulWidget {
  final BMSBluetoothService service;
  const _DeviceDetailsSheet({required this.service});

  @override
  State<_DeviceDetailsSheet> createState() => _DeviceDetailsSheetState();
}

class _DeviceDetailsSheetState extends State<_DeviceDetailsSheet> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
    widget.service.requestDeviceDetails();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    if (widget.service.latestDeviceDetails != null && !_loaded) {
      setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    widget.service.stopSettingsPolling();
    
    super.dispose();
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dd = widget.service.latestDeviceDetails;
    final connected = widget.service.latestDashboard != null;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Device Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          if (!_loaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
           _row('BMS Serial No', dd?.batterySerial ?? '-'),
            _row('SW Version', dd?.softwareVersion ?? '-'),
            _row('HW Version', dd?.hardwareVersion ?? '-'),
            _row('FW Version', dd?.firmwareVersion ?? '-'),
            _row('Status', connected ? 'Connected' : 'Disconnected'),
          ],
          const SizedBox(height: 8),
        ],
      ),
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