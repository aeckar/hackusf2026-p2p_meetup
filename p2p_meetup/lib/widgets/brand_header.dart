import 'package:flutter/material.dart';

import '../theme/usf_theme.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.compact = false,
    this.titleOverride,
  });

  final bool compact;
  final String? titleOverride;

  @override
  Widget build(BuildContext context) {
    final title = titleOverride ?? 'USF Meat';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16, vertical: compact ? 6 : 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sports_rugby, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 18 : 22,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BrandHeaderDashboard extends StatelessWidget {
  const BrandHeaderDashboard({super.key, required this.showDashboardTitle});

  final bool showDashboardTitle;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: showDashboardTitle
          ? Padding(
              key: const ValueKey('dash'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'dashboard',
                  style: TextStyle(
                    color: UsfTheme.goldAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            )
          : const BrandHeader(key: ValueKey('brand'), compact: true),
    );
  }
}
