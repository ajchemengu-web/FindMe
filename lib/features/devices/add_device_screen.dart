import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../theme/tokens.dart';
import '../consent/consent_repository.dart';
import 'devices_repository.dart';

enum _Step { choose, self, other, done }

/// Ported 1:1 from findme_app/app/add-device.tsx. Two paths: a device you own (added
/// immediately, no consent needed) or someone else's (creates a pending consent
/// request and stops there -- the other person approves it for real on their own
/// People & Devices screen).
class AddDeviceScreen extends ConsumerStatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  ConsumerState<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends ConsumerState<AddDeviceScreen> {
  _Step _step = _Step.choose;
  String _doneMessage = '';
  String? _error;
  bool _submitting = false;

  final _nickname = TextEditingController();
  final _contact = TextEditingController();
  String _scope = 'precise';

  Future<void> _addSelfDevice() async {
    if (_nickname.text.trim().isEmpty) {
      setState(() => _error = 'Give the device a nickname.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await DevicesRepository().createDevice(CreateDeviceInput(nickname: _nickname.text.trim(), isSelfOwned: true));
      setState(() {
        _doneMessage = "Since this is your own device, no consent request was needed -- it's tracked immediately.";
        _step = _Step.done;
      });
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : 'Something went wrong adding the device.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendRequest() async {
    if (_contact.text.trim().isEmpty) {
      setState(() => _error = 'Enter their phone number, email, or username.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ConsentRepository();
      final found = await repo.findProfileForInvite(_contact.text.trim());
      if (found == null) {
        setState(() {
          _error = "No FindMe account found for that contact. They'll need to sign up first before you can send a request.";
          _submitting = false;
        });
        return;
      }
      await repo.requestConsent(found.id, scope: _scope);
      setState(() {
        _doneMessage =
            "Request sent to ${found.displayName ?? found.username}. Nothing will appear on your map until they approve it from their own People & Devices screen.";
        _step = _Step.done;
      });
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : 'Something went wrong sending the request.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xD9040608),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
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
                  const Expanded(
                    child: Text('ADD TO WATCH LIST', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: AppColors.ink3, size: 18)),
                ],
              ),
              Flexible(child: SingleChildScrollView(child: _buildStep())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.choose:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChoiceCard(
              title: '📱 A device I own',
              body: "Your own phone, laptop, or router. No consent request needed -- it's already yours.",
              onTap: () => setState(() => _step = _Step.self),
            ),
            const SizedBox(height: 10),
            _ChoiceCard(
              title: '👤 Someone else',
              body: "Family, friend, or colleague. They'll receive a consent request and must explicitly approve it before you can see anything.",
              onTap: () => setState(() => _step = _Step.other),
            ),
          ],
        );

      case _Step.self:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FieldLabel('Device nickname'),
            TextField(controller: _nickname, decoration: const InputDecoration(hintText: 'e.g. iPad, Work Laptop')),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 12))],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => setState(() => _step = _Step.choose), child: const Text('← Back')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _addSelfDevice,
                    child: _submitting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Add Device'),
                  ),
                ),
              ],
            ),
          ],
        );

      case _Step.other:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FieldLabel('Their phone, email, or username'),
            TextField(controller: _contact, decoration: const InputDecoration(hintText: 'Used to find their FindMe account'), autocorrect: false),
            const SizedBox(height: 14),
            const _FieldLabel("What you're asking to see"),
            Row(
              children: [
                Expanded(child: _ScopeOption(label: 'Precise location', active: _scope == 'precise', onTap: () => setState(() => _scope = 'precise'))),
                const SizedBox(width: 8),
                Expanded(child: _ScopeOption(label: 'City-level only', active: _scope == 'city', onTap: () => setState(() => _scope = 'city'))),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x0F3987E5),
                border: Border.all(color: const Color(0x403987E5)),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Text(
                "🔒 Nothing is shared until they approve. They'll see exactly what you selected here, can deny it, and can revoke access at any time afterward from their own Privacy Center.",
                style: TextStyle(color: AppColors.ink2, fontSize: 11.5, height: 1.4),
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 12))],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = _Step.choose), child: const Text('← Back'))),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _sendRequest,
                    child: _submitting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send Request'),
                  ),
                ),
              ],
            ),
          ],
        );

      case _Step.done:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              const Text('✅', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text(_doneMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.ink2, fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
            ],
          ),
        );
    }
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(), style: const TextStyle(color: AppColors.ink3, fontSize: 10.5, letterSpacing: 1)),
      );
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  const _ChoiceCard({required this.title, required this.body, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: Colors.white.withValues(alpha: 0.02),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: AppColors.ink3, fontSize: 11.5, height: 1.35)),
          ],
        ),
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ScopeOption({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: active ? AppColors.accent : AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: active ? AppColors.accentDim : Colors.transparent,
        ),
        child: Text(label, style: TextStyle(color: active ? AppColors.accent : AppColors.ink2, fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}
