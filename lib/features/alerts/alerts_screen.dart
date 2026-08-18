import 'package:flutter/material.dart';
import '../../widgets/placeholder_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        title: 'Alerts',
        note: 'Consent requests, geofence enter/exit events -- coming next.',
      );
}
