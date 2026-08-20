import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors_data.dart';
import '../../theme/tokens.dart';
import 'auth_controller.dart';

const _resendCooldownS = 60;

/// Ported 1:1 from findme_app/app/verify-phone.tsx. Two-step modal: stage the number
/// (POST /auth/phone/send-otp), then confirm the code (POST /auth/phone/confirm-otp).
/// Theme-reactive -- only ever pushed from the (migrated) Privacy Center.
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  late final TextEditingController _phone;
  final _code = TextEditingController();
  bool _codeStep = false;
  String? _error;
  bool _submitting = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    _phone = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = _resendCooldownS;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _onSendCode() async {
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Enter a phone number first.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final repo = ref.read(authRepositoryProvider);
    final error = await repo.sendPhoneVerification(_phone.text.trim());
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (error != null) {
        _error = error;
      } else {
        _codeStep = true;
        _startCooldown();
      }
    });
  }

  Future<void> _onVerify() async {
    if (_code.text.trim().isEmpty) {
      setState(() => _error = 'Enter the code you received.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final repo = ref.read(authRepositoryProvider);
    final error = await repo.confirmPhoneVerification(_phone.text.trim(), _code.text.trim());
    if (error != null) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    await ref.read(authControllerProvider.notifier).refreshProfile();
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // This is a bare fullscreenDialog page (see app_router.dart's '/verify-phone' route),
    // not a Scaffold -- which normally supplies the Material ancestor TextField needs for
    // its input decoration/selection handles. Without this wrapper, tapping into either
    // TextField below crashes with "No Material widget found." `type: transparency` means
    // it paints nothing of its own, just provides the ancestor the fields need.
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
                    child: Text(
                      'VERIFY PHONE NUMBER',
                      style: TextStyle(color: colors.ink, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close, color: colors.ink3, size: 18)),
                ],
              ),
              const SizedBox(height: 4),
              if (!_codeStep) ...[
                Text(
                  "We'll text a one-time code to confirm this number. It's what people search for when they invite you "
                  'to watch their device, so it\'s worth getting right.',
                  style: TextStyle(color: colors.ink2, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                _label(colors, 'Phone number'),
                TextField(controller: _phone, decoration: const InputDecoration(hintText: '+1 555 010 1234'), keyboardType: TextInputType.phone),
                if (_error != null) _errorText(colors),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _submitting ? null : _onSendCode,
                  child: _submitting ? const _Spinner() : const Text('Send Code'),
                ),
              ] else ...[
                Text('Enter the code we sent to ${_phone.text}.', style: TextStyle(color: colors.ink2, fontSize: 12.5, height: 1.4)),
                const SizedBox(height: 12),
                _label(colors, '6-digit code'),
                TextField(
                  controller: _code,
                  decoration: const InputDecoration(hintText: '123456'),
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                ),
                if (_error != null) _errorText(colors),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: _submitting ? null : _onVerify,
                  child: _submitting ? const _Spinner() : const Text('Verify'),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _codeStep = false;
                        _code.clear();
                        _error = null;
                      }),
                      child: Text('Change number', style: TextStyle(color: colors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: (_cooldown > 0 || _submitting) ? null : _onSendCode,
                      child: Text(
                        _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend code',
                        style: TextStyle(color: _cooldown > 0 ? colors.ink3 : colors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
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

  Widget _errorText(AppColorsData colors) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(_error!, style: TextStyle(color: colors.critical, fontSize: 12, height: 1.3)),
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2));
}
