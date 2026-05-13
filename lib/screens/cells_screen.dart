import 'package:flutter/material.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';

class CellsScreen extends StatelessWidget {
  const CellsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'CELLS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.3,
          ),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: const AppDrawer(activeRoute: '/cells'),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.battery_full_rounded, size: 64, color: Color(0xFF1B6B3A)),
            SizedBox(height: 16),
            Text(
              'Cells Screen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 8),
            Text('Coming soon...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}