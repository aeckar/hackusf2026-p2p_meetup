import 'package:flutter/material.dart';

/// USF Bulls mark (`bulls.png` in project root).
const String kUsfBullsLogoAsset = 'bulls.png';

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
    final title = titleOverride ?? 'USF Meet';
    final logoSize = compact ? 36.0 : 44.0;
    final fontSize = compact ? 18.0 : 22.0;
    final flareSize = compact ? 14.0 : 18.0;

    // Split title around "Meet" to insert flare images inline.
    // Falls back to plain text if the title doesn't contain "Meet".
    final meetIndex = title.indexOf('Meet');
    final titleWidget = meetIndex == -1
        ? Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 0.5,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (meetIndex > 0)
                Text(
                  title.substring(0, meetIndex),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                    letterSpacing: 0.5,
                  ),
                ),
              Image.asset(
                'flare-open.png',
                height: flareSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              Text(
                'Meet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                  letterSpacing: 0.5,
                ),
              ),
              Image.asset(
                'flare-close.png',
                height: flareSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              if (meetIndex + 4 < title.length)
                Text(
                  title.substring(meetIndex + 4),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16, vertical: compact ? 6 : 12),
      child: Row(
        children: [
          Image.asset(
            kUsfBullsLogoAsset,
            height: logoSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 10),
          Flexible(child: titleWidget),
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
              padding: const EdgeInsets.only(left: 4, right: 8, top: 4, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  kUsfBullsLogoAsset,
                  height: 40,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  filterQuality: FilterQuality.high,
                ),
              ),
            )
          : const BrandHeader(key: ValueKey('brand'), compact: true),
    );
  }
}
