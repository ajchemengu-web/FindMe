import 'package:flutter/material.dart';
import '../../widgets/placeholder_screen.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        title: 'People & Devices',
        note: 'Device list, add-device flow, and consent requests -- coming next.',
      );
}
