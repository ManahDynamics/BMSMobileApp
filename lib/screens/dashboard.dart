// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/login_screen.dart';
import 'package:bmsmobileapp/screens/editprofile_screen.dart';
import 'package:bmsmobileapp/screens/forgotpassword_screen.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';
import 'package:bmsmobileapp/screens/cells_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart'; // ← ADD THIS

class DashboardScreen extends StatefulWidget {
  final BMSBluetoothService service; // ← ADD THIS

  const DashboardScreen({super.key, required this.service}); // ← ADD THIS

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Mock BMS data ─────────────────────────────────────────────────────────
  final String deviceName = 'BMS_001';
  final bool isConnected = true;
  final double soc = 82;
  final String batteryStatus = 'Discharging';
  final String remainingTime = '04h 35m';
  final String health = 'Good';
  final double voltage = 48.5;
  final double current = -12.3;
  final double temperature = 32.0;
  final double power = -591;
  final double minCell = 3.215;
  final double maxCell = 3.298;
  final List<double> cellValues = [
    3.24, 3.28, 3.22, 3.29, 3.25, 3.27, 3.21, 3.30, 3.26, 3.23
  ];

  // ── Disconnect ─────────────────────────────────────────────────────────────
  // Sends disconnect packet to BMS, then navigates back to scan screen
  Future<void> _handleDisconnect() async {
    await widget.service.disconnect(); // ← sends CC 05 91 crc DD to BMS first
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      SlideRoute(
        page: BluetoothDeviceScanPage(service: widget.service),
      ),
      (route) => false,
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text(
          'Disconnect',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        content: Text(
          'Are you sure you want to disconnect?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
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
              _handleDisconnect(); // ← calls service.disconnect() then navigates
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

  // ── Logout dialog ─────────────────────────────────────────────────────────
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Logout',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to logout?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black87, fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushAndRemoveUntil(
                context,
                SlideRoute(page: const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A6EAC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ── Kebab menu ────────────────────────────────────────────────────────────
  void _showKebabMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context)
        .overlay!
        .context
        .findRenderObject() as RenderBox;

    final Offset buttonOffset =
        button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;

    final RelativeRect position = RelativeRect.fromLTRB(
      overlay.size.width,
      buttonOffset.dy + buttonSize.height + 1,
      8,
      0,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        PopupMenuItem<String>(
          value: 'edit_profile',
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
          child: _menuItem(
              Icons.person_outline_rounded, 'Edit Profile', Colors.black87),
        ),
        const PopupMenuDivider(
            height: 0.5, color: Color(0xFFEEEEEE)),
        PopupMenuItem<String>(
          value: 'forgot_password',
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
          child: _menuItem(Icons.lock_reset_rounded, 'Forget Password',
              Colors.black87),
        ),
        const PopupMenuDivider(
            height: 0.5, color: Color(0xFFEEEEEE)),
        PopupMenuItem<String>(
          value: 'logout',
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
          child:
              _menuItem(Icons.logout_rounded, 'Logout', Colors.red),
        ),
      ],
    );

    if (result == 'edit_profile') {
      Navigator.push(context, SlideRoute(page: const EditProfileScreen()));
    } else if (result == 'forgot_password') {
      Navigator.push(
          context, SlideRoute(page: const ForgotPasswordScreen()));
    } else if (result == 'logout') {
      _showLogoutDialog();
    }
  }

  Widget _menuItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: color,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(activeRoute: '/dashboard', service: widget.service), // ← pass service
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded,
                color: Colors.white, size: 26),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'DASHBOARD',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.more_vert,
                    color: Colors.white, size: 22),
              ),
              onPressed: () => _showKebabMenu(ctx),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceHeader(),
            const SizedBox(height: 16),
            _buildBatteryStatusCard(),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: _buildMetricCard(
                    icon: Icons.circle_outlined,
                    iconLabel: 'V',
                    label: 'Voltage',
                    value: '$voltage V',
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildMetricCard(
                    icon: Icons.circle_outlined,
                    iconLabel: 'A',
                    label: 'Current',
                    value: '$current A',
                    subtitle: 'Discharging',
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: _buildMetricCard(
                    icon: Icons.thermostat_rounded,
                    label: 'Temperature',
                    value: '$temperature C',
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildMetricCard(
                    icon: Icons.power_outlined,
                    label: 'Power',
                    value: '${power.toInt()} W',
                  )),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildCellSummary(),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                   SlideRoute(page: CellsScreen(service: widget.service)),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'View Cell Details',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildAlertsCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Device header ──────────────────────────────────────────────────────────
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
            Text(
              deviceName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Text(
                  'Connected',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1B6B3A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B6B3A),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _showDisconnectDialog, // ← clean, uses _showDisconnectDialog
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4621A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            elevation: 1,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: const Text(
            'DISCONNECT',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ── Battery status card ────────────────────────────────────────────────────
  Widget _buildBatteryStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3A6EAC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: soc / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${soc.toInt()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: '%',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'SOC',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 30),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Battery Status',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(batteryStatus,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const Icon(Icons.battery_3_bar_rounded,
                        color: Colors.white, size: 30),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Remaining Time',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(remainingTime,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Health',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(health,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const Icon(Icons.verified_user_outlined,
                        color: Colors.white, size: 30),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Metric card ────────────────────────────────────────────────────────────
  Widget _buildMetricCard({
    required IconData icon,
    String? iconLabel,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.grey.shade400, width: 1.5),
            ),
            child: Center(
              child: iconLabel != null
                  ? Text(iconLabel,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600]))
                  : Icon(icon, size: 18, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF575757))),
              if (subtitle != null)
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  // ── Cell Summary ───────────────────────────────────────────────────────────
  Widget _buildCellSummary() {
    final maxVal = cellValues.reduce((a, b) => a > b ? a : b);
    final minVal = cellValues.reduce((a, b) => a < b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cell Summary',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Min. Cell',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text('$minCell v',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: cellValues.map((val) {
                    final heightRatio = (val - minVal) /
                        ((maxVal - minVal) == 0 ? 1 : (maxVal - minVal));
                    final barHeight = 20 + (heightRatio * 40);
                    return Container(
                      width: 14,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B6B3A),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Max. Cell',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text('$maxCell v',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Active Alerts ──────────────────────────────────────────────────────────
  Widget _buildAlertsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.notifications_none_rounded,
                      color: Colors.black87, size: 22),
                  SizedBox(width: 10),
                  Text('Active Alerts',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3A3939))),
                ],
              ),
              Text('No Active Alerts',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF1B6B3A), size: 20),
              SizedBox(width: 10),
              Text('All Systems Normal',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}