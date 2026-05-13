import 'package:flutter/material.dart';

class SlideRoute extends PageRouteBuilder {
  final Widget page;

  SlideRoute({required this.page})
      : super(
          transitionDuration: const Duration(milliseconds:200),
          reverseTransitionDuration: const Duration(milliseconds:200),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Forward: slide in from right
            // Back: slide out to right (Flutter handles this automatically)
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
}