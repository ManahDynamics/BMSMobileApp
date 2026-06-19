// // lib/screens/forgotpassword_screen.dart
// import 'package:flutter/material.dart';

// import 'package:bmsmobileapp/core/theme/app_colors.dart';
// // import 'package:bmsmobileapp/core/theme/app_spacing.dart';
// import 'package:bmsmobileapp/services/translation_service.dart';

// class ForgotPasswordScreen extends StatefulWidget {
//   const ForgotPasswordScreen({super.key});

//   @override
//   State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
// }

// class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
//   final _emailController = TextEditingController();
//   bool _isLoading = false;
//   bool _emailSent = false;

//   String tr(String key) => TranslationService.t(key);

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
//     _emailController.dispose();
//     super.dispose();
//   }

//   Future<void> _handleSendLink() async {
//     if (_emailController.text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(tr('fp_enter_email_error')),
//           backgroundColor: AppColors.error,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     // Simulate API call
//     await Future.delayed(const Duration(seconds: 2));

//     if (mounted) {
//       setState(() {
//         _isLoading = false;
//         _emailSent = true;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: AppColors.primaryGreen,
//         elevation: 0,
//         centerTitle: true,
//         title: Text(
//           tr('fp_title').toUpperCase(),
//           style: theme.textTheme.titleLarge?.copyWith(
//             color: Colors.white,
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
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const SizedBox(height: 32),

//             Center(
//               child: Container(
//                 width: 90,
//                 height: 90,
//                 decoration: BoxDecoration(
//                   color: AppColors.primaryGreen.withValues(alpha: 0.1),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   Icons.lock_reset_rounded,
//                   size: 46,
//                   color: AppColors.primaryGreen,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 28),

//             Center(
//               child: Text(
//                 tr('fp_reset_password'),
//                 style: theme.textTheme.headlineMedium?.copyWith(
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),

//             Center(
//               child: Text(
//                 _emailSent
//                     ? tr('fp_link_sent_message')
//                     : tr('fp_subtitle'),
//                 textAlign: TextAlign.center,
//                 style: theme.textTheme.bodyMedium?.copyWith(
//                   color: Colors.grey,
//                   height: 1.5,
//                 ),
//               ),
//             ),

//             const SizedBox(height: 36),

//             if (!_emailSent) ...[
//               Text(
//                 tr('fp_email_label'),
//                 style: theme.textTheme.labelLarge?.copyWith(
//                   color: Colors.black54,
//                 ),
//               ),
//               const SizedBox(height: 8),

//               Container(
//                 decoration: BoxDecoration(
//                   color: AppColors.inputBackground,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: TextField(
//                   controller: _emailController,
//                   keyboardType: TextInputType.emailAddress,
//                   decoration: InputDecoration(
//                     hintText: tr('fp_email_hint'),
//                     prefixIcon: Icon(Icons.email_outlined,
//                         color: Colors.grey[600], size: 20),
//                     border: InputBorder.none,
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 14,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 28),

//               SizedBox(
//                 width: double.infinity,
//                 height: 52,
//                 child: ElevatedButton(
//                   onPressed: _isLoading ? null : _handleSendLink,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.primaryBlue,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     elevation: 0,
//                   ),
//                   child: _isLoading
//                       ? const SizedBox(
//                           width: 24,
//                           height: 24,
//                           child: CircularProgressIndicator(
//                             color: Colors.white,
//                             strokeWidth: 2.5,
//                           ),
//                         )
//                       : Text(
//                           tr('fp_send_reset_link'),
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                 ),
//               ),
//               const SizedBox(height: 16),

//               SizedBox(
//                 width: double.infinity,
//                 height: 52,
//                 child: OutlinedButton(
//                   onPressed: () => Navigator.pop(context),
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: Colors.grey[700],
//                     side: BorderSide(color: Colors.grey.shade300),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                   child: Text(
//                     tr('fp_back'),
//                     style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                   ),
//                 ),
//               ),
//             ] else ...[
//               Center(
//                 child: Container(
//                   padding: const EdgeInsets.all(20),
//                   decoration: BoxDecoration(
//                     color: AppColors.primaryGreen.withValues(alpha: 0.08),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Column(
//                     children: [
//                       Icon(
//                         Icons.mark_email_read_rounded,
//                         color: AppColors.primaryGreen,
//                         size: 48,
//                       ),
//                       const SizedBox(height: 12),
//                       Text(
//                         _emailController.text.trim(),
//                         style: theme.textTheme.bodyLarge?.copyWith(
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         tr('fp_check_inbox'),
//                         style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 28),

//               SizedBox(
//                 width: double.infinity,
//                 height: 52,
//                 child: ElevatedButton(
//                   onPressed: () => Navigator.pop(context),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.primaryGreen,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     elevation: 0,
//                   ),
//                   child: Text(
//                     tr('fp_back_to_dashboard'),
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }