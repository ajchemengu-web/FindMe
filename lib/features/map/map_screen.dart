import 'package:flutter/material.dart';
import '../../widgets/placeholder_screen.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        title: 'Map',
        note: 'Live device pins, threat zone circles, and geofences -- coming next (flutter_map, dark tile layer, no API key needed).',
      );
}
