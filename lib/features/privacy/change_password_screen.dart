import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors_data.dart';
import '../../theme/tokens.dart';
import '../auth/auth_controller.dart';

/// Current password + new password (with confirmation), calling the new
/// POST /auth/change-password endpoint. Separate from EditProfileScreen -- a
/// password change is a more sensitive action than editing display fields, worth its
/// own explicit confirmation step (re-typing the new password) rather than bundled in.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _submitting = false;
  bool _done = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    if (_next.text.length < 10) {
      setState(() => _error = 'New password needs to be at least 10 characters.');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = "New passwords don't match.");
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final repo = ref.read(authRepositoryProvider);
    final error = await repo.changePassword(currentPassword: _current.text, newPassword: _next.text);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (error != null) {
        _error = error;
      } else {
        _done = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: const Color(0xD9040608),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('CHANGE PASSWORD', style: TextStyle(color: colors.ink, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close, color: colors.ink3, size: 18)),
                ],
              ),
              const SizedBox(height: 4),
              if (_done) ...[
                const SizedBox(height: 8),
                const Text('✅', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                Text('Password changed.', textAlign: TextAlign.center, style: TextStyle(color: colors.ink2, fontSize: 13, height: 1.4)),
                const SizedBox(height: 14),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
              ] else ...[
                _label(colors, 'Current password'),
                TextField(controller: _current, decoration: const InputDecoration(hintText: 'Current password'), obscureText: true),
                const SizedBox(height: 12),
                _label(colors, 'New password'),
                TextField(controller: _next, decoration: const InputDecoration(hintText: 'At least 10 characters'), obscureText: true),
                const SizedBox(height: 12),
                _label(colors, 'Confirm new password'),
                TextField(controller: _confirm, decoration: const InputDecoration(hintText: 'Type it again'), obscureText: true),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: colors.critical, fontSize: 12, height: 1.3)),
                ],
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Change Password'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(AppColorsData colors, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(), style: TextStyle(color: colors.ink3, fontSize: 10.5, letterSpacing: 1)),
      );
}
