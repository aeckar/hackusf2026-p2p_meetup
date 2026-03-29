import 'package:flutter/material.dart';

/// Full-screen route that slides in from the right (use for auth ↔ app).
class SlideFromRightPage extends Page<void> {
  const SlideFromRightPage({required super.key, required this.child});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) {
    return PageRouteBuilder(
      settings: this,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    );
  }
}
