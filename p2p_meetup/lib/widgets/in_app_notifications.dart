import 'dart:async';

import 'package:flutter/material.dart';

enum NotificationVerticalEdge { top, bottom }

class InAppNotification {
  InAppNotification({
    required this.message,
    this.edge = NotificationVerticalEdge.top,
    this.onTap,
  });

  final String message;
  final NotificationVerticalEdge edge;
  final VoidCallback? onTap;
}

/// Toasts per edge: newest inserts at the top of the lane; excess entries are removed.
class InAppNotificationHost extends StatefulWidget {
  const InAppNotificationHost({super.key, required this.child});

  final Widget child;

  static InAppNotificationHostState of(BuildContext context) {
    final state = context.findAncestorStateOfType<InAppNotificationHostState>();
    assert(state != null, 'InAppNotificationHost not found in context');
    return state!;
  }

  @override
  State<InAppNotificationHost> createState() => InAppNotificationHostState();
}

class InAppNotificationHostState extends State<InAppNotificationHost> with TickerProviderStateMixin {
  static const int _max = 4;
  static const Duration _ttl = Duration(seconds: 4);

  final List<_ActiveNote> _top = [];
  final List<_ActiveNote> _bottom = [];

  void show(InAppNotification note) {
    final list = note.edge == NotificationVerticalEdge.top ? _top : _bottom;
    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    final active = _ActiveNote(note: note, controller: controller);
    setState(() {
      list.insert(0, active);
      while (list.length > _max) {
        final removed = list.removeLast();
        removed.controller.dispose();
      }
    });
    controller.forward();

    Timer(_ttl, () {
      if (!mounted) return;
      controller.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          list.remove(active);
        });
        controller.dispose();
      });
    });
  }

  @override
  void dispose() {
    for (final x in [..._top, ..._bottom]) {
      x.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        _lane(Alignment.topCenter, _top, fromAbove: true),
        _lane(Alignment.bottomCenter, _bottom, fromAbove: false),
      ],
    );
  }

  Widget _lane(Alignment align, List<_ActiveNote> notes, {required bool fromAbove}) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final live in notes)
              FadeTransition(
                opacity: CurvedAnimation(parent: live.controller, curve: Curves.easeOut),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: fromAbove ? const Offset(0, -0.1) : const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: live.controller, curve: Curves.easeOutCubic)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: live.note.onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.92),
                            child: Text(
                              live.note.message,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveNote {
  _ActiveNote({required this.note, required this.controller});

  final InAppNotification note;
  final AnimationController controller;
}
