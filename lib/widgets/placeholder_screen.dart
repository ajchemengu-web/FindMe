import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Temporary stand-in for tabs not yet ported (Map, Intel, People, Alerts, Privacy --
/// see findme_flutter porting tasks). Not present in the final app.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String note;
  const PlaceholderScreen({super.key, required this.title, required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(note, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.ink3, fontSize: 13, height: 1.4)),
        ),
      ),
    );
  }
}
