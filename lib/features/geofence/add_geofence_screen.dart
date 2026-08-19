import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Placeholder -- full geofence-drawing UI ports alongside the Map tab (needs the same
/// flutter_map picker). Takes deviceId/nickname via go_router's `extra` so the real
/// implementation's signature is already correct when it lands.
class AddGeofenceScreen extends StatelessWidget {
  final String? deviceId;
  final String? nickname;
  const AddGeofenceScreen({super.key, this.deviceId, this.nickname});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xD9040608),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nickname != null ? 'GEOFENCES · ${nickname!.toUpperCase()}' : 'GEOFENCES',
                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: AppColors.ink3, size: 18)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Drawing and managing geofences on a map -- coming alongside the Map tab.',
                style: TextStyle(color: AppColors.ink3, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
