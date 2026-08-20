import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors_data.dart';
import '../../theme/tokens.dart';
import '../auth/auth_controller.dart';

/// Display name, username, and email -- the fields update_profile() actually accepts.
/// Same fullscreenDialog-modal shape as verify_phone_screen.dart -- needs the same
/// Material-ancestor wrapper add_device_screen.dart needed, since its TextFields require
/// one too (not just InkWell).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _email;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    _displayName = TextEditingController(text: user?.displayName ?? '');
    _username = TextEditingController(text: user?.username ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _username.text.trim();
    final email = _email.text.trim();
    if (username.length < 3) {
      setState(() => _error = 'Username needs to be at least 3 characters.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final error = await ref.read(authControllerProvider.notifier).updateProfile(
          displayName: _displayName.text.trim().isEmpty ? null : _displayName.text.trim(),
          username: username,
          email: email,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // This is a bare fullscreenDialog page (see app_router.dart's '/edit-profile' route),
    // not a Scaffold -- which normally supplies the Material ancestor TextField needs for
    // its input decoration/selection handles. Without this wrapper, tapping into any of the
    // three TextFields below crashes with "No Material widget found." `type: transparency`
    // means it paints nothing of its own, just provides the ancestor the fields need.
    return Material(
      type: MaterialType.transparency,
      child: Container(
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
                    child: Text('EDIT PROFILE', style: TextStyle(color: colors.ink, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close, color: colors.ink3, size: 18)),
                ],
              ),
              const SizedBox(height: 4),
              _label(colors, 'Display name'),
              TextField(controller: _displayName, decoration: const InputDecoration(hintText: 'What people see')),
              const SizedBox(height: 12),
              _label(colors, 'Username'),
              TextField(controller: _username, decoration: const InputDecoration(hintText: 'username'), autocorrect: false),
              const SizedBox(height: 12),
              _label(colors, 'Email'),
              TextField(controller: _email, decoration: const InputDecoration(hintText: 'you@example.com'), keyboardType: TextInputType.emailAddress, autocorrect: false),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: colors.critical, fontSize: 12, height: 1.3)),
              ],
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _submitting ? null : _save,
                child: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Changes'),
              ),
            ],
          ),
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
