// // ignore_for_file: deprecated_member_use
// import 'package:flutter/material.dart';
// import 'package:bmsmobileapp/services/translation_service.dart';

// class EditProfileScreen extends StatefulWidget {
//   const EditProfileScreen({super.key});

//   @override
//   State<EditProfileScreen> createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _nameController = TextEditingController(text: 'Venkat Cherka');
//   final _emailController = TextEditingController(text: 'venkat.cherka@email.com');
//   final _phoneController = TextEditingController(text: '+91 9876543210');

//   String tr(String key) {
//     return TranslationService.t(key);
//   }

//   // ── Listen to TranslationService changes ─────────────────────────────────
//   @override
//   void initState() {
//     super.initState();
//     TranslationService.instance.addListener(_onTranslationsChanged);
//   }

//   void _onTranslationsChanged() {
//     if (mounted) setState(() {});
//   }

//   @override
//   void dispose() {
//     TranslationService.instance.removeListener(_onTranslationsChanged);
//     _nameController.dispose();
//     _emailController.dispose();
//     _phoneController.dispose();
//     super.dispose();
//   }
//   // ── END ───────────────────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF1B6B3A),
//         elevation: 0,
//         centerTitle: true,
//         title: Text(
//           tr('edit_profile'),
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           children: [
//             const SizedBox(height: 20),

//             // Avatar
//             Stack(
//               alignment: Alignment.bottomRight,
//               children: [
//                 CircleAvatar(
//                   radius: 52,
//                   backgroundColor: const Color(0xFF1B6B3A).withOpacity(0.12),
//                   child: const Icon(
//                     Icons.person_rounded,
//                     size: 60,
//                     color: Color(0xFF1B6B3A),
//                   ),
//                 ),
//                 Container(
//                   width: 32,
//                   height: 32,
//                   decoration: BoxDecoration(
//                     color: const Color(0xFF1B6B3A),
//                     shape: BoxShape.circle,
//                     border: Border.all(color: Colors.white, width: 2),
//                   ),
//                   child: const Icon(
//                     Icons.camera_alt_rounded,
//                     color: Colors.white,
//                     size: 16,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Text(
//               _nameController.text,
//               style: const TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               tr('bms_user'),
//               style: const TextStyle(fontSize: 13, color: Colors.grey),
//             ),

//             const SizedBox(height: 32),

//             // Form fields
//             _buildTextField(
//               controller: _nameController,
//               label: tr('full_name'),
//               icon: Icons.person_outline_rounded,
//             ),
//             const SizedBox(height: 16),
//             _buildTextField(
//               controller: _emailController,
//               label: tr('email_address'),
//               icon: Icons.email_outlined,
//               keyboardType: TextInputType.emailAddress,
//             ),
//             const SizedBox(height: 16),
//             _buildTextField(
//               controller: _phoneController,
//               label: tr('phone_number'),
//               icon: Icons.phone_outlined,
//               keyboardType: TextInputType.phone,
//             ),

//             const SizedBox(height: 36),

//             // Save button
//             SizedBox(
//               width: double.infinity,
//               height: 50,
//               child: ElevatedButton(
//                 onPressed: () {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(tr('profile_updated_success')),
//                       backgroundColor: const Color(0xFF1B6B3A),
//                       behavior: SnackBarBehavior.floating,
//                     ),
//                   );
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF3A6EAC),
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   elevation: 0,
//                 ),
//                 child: Text(
//                   tr('save_changes'),
//                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 12),

//             // Cancel button
//             SizedBox(
//               width: double.infinity,
//               height: 50,
//               child: OutlinedButton(
//                 onPressed: () => Navigator.pop(context),
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: Colors.grey[700],
//                   side: const BorderSide(color: Color(0xFFCCCCCC)),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//                 child: Text(
//                   tr('cancel'),
//                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     TextInputType? keyboardType,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w500,
//             color: Colors.black54,
//           ),
//         ),
//         const SizedBox(height: 6),
//         Container(
//           decoration: BoxDecoration(
//             color: const Color(0xFFF0F0F0),
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: TextField(
//             controller: controller,
//             keyboardType: keyboardType,
//             decoration: InputDecoration(
//               prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
//               border: InputBorder.none,
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 16,
//                 vertical: 14,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }