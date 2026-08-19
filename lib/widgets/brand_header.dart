import 'package:flutter/material.dart';

import '../theme/app_colors_data.dart';
import '../theme/tokens.dart';

/// Ported from the repeated brandRow/tag markup in sign-in.tsx and sign-up.tsx.
/// Theme-reactive.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(AppRadius.md)),
              alignment: Alignment.center,
              child: Text('FM', style: TextStyle(color: colors.brandMarkForeground, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Text('FINDME', style: TextStyle(color: colors.ink, fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'SECURE ACCESS · CONSENT-FIRST TRACKING NETWORK',
          style: TextStyle(color: colors.ink3, fontSize: 10.5, letterSpacing: 1),
        ),
      ],
    );
  }
}
