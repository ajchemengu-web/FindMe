import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Ported from the repeated brandRow/tag markup in sign-in.tsx and sign-up.tsx.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.md)),
              alignment: Alignment.center,
              child: const Text('FM', style: TextStyle(color: Color(0xFF04101F), fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            const Text('FINDME', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'SECURE ACCESS · CONSENT-FIRST TRACKING NETWORK',
          style: TextStyle(color: AppColors.ink3, fontSize: 10.5, letterSpacing: 1),
        ),
      ],
    );
  }
}
