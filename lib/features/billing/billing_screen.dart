import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../theme/tokens.dart';
import '../auth/auth_controller.dart';
import 'billing_repository.dart';

const _tierRank = {'free': 0, 'plus': 1, 'pro': 2};
const _pollInterval = Duration(seconds: 3);
const _pollTimeout = Duration(seconds: 120);

class _PlanCard {
  final String tier;
  final String label;
  final String price;
  final List<String> features;
  const _PlanCard({required this.tier, required this.label, required this.price, required this.features});
}

const _planCards = [
  _PlanCard(
    tier: 'free',
    label: 'Free',
    price: 'KES 0',
    features: ['Up to 3 devices you own', 'Watch up to 2 people', 'City-level location only', 'No geofencing', 'Intel headlines only (no watchlist)'],
  ),
  _PlanCard(
    tier: 'plus',
    label: 'Plus',
    price: 'KES 650/mo',
    features: ['Unlimited devices', 'Unlimited watches', 'Precise location', 'Geofencing', 'Full Intel watchlist'],
  ),
  _PlanCard(
    tier: 'pro',
    label: 'Pro',
    price: 'KES 1300/mo',
    features: ['Everything in Plus', 'Priority alert delivery -- not yet built'],
  ),
];

/// Ported 1:1 from findme_app/app/billing.tsx. Was Stripe Checkout; the backend never
/// carried Stripe forward, so this is M-Pesa STK Push -- enter a Safaricom number,
/// trigger a push prompt, approve it on that phone, and this screen polls the
/// transaction until Safaricom's callback resolves it (no external redirect to bounce
/// back from). Every limit shown is a *display* of what the backend already enforces.
class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final _repo = BillingRepository();
  BillingStatus? _status;
  String? _payingTier;
  final _phone = TextEditingController();
  ({String tier, String transactionId})? _pending;
  String? _error;
  bool _refreshing = false;
  Timer? _pollTimer;
  DateTime? _pollDeadline;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _repo.fetchBillingStatus();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Swallowed in the original (console.warn only) -- ported as-is.
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _beginPolling(String transactionId) {
    _pollDeadline = DateTime.now().add(_pollTimeout);
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      if (DateTime.now().isAfter(_pollDeadline!)) {
        _stopPolling();
        if (mounted) {
          setState(() {
            _error = "Didn't hear back from M-Pesa in time. Check your phone for the prompt, or try again.";
            _pending = null;
          });
        }
        return;
      }
      try {
        final txn = await _repo.getMpesaTransaction(transactionId);
        if (txn.status == 'success') {
          _stopPolling();
          if (mounted) setState(() => _pending = null);
          await _loadStatus();
          await ref.read(authControllerProvider.notifier).refreshProfile();
        } else if (txn.status == 'failed') {
          _stopPolling();
          if (mounted) {
            setState(() {
              _pending = null;
              _error = 'Payment was not completed on M-Pesa.';
            });
          }
        }
      } catch (_) {
        // Transient network hiccup -- keep polling until the timeout above.
      }
    });
  }

  Future<void> _onRefreshStatus() async {
    setState(() => _refreshing = true);
    await Future.wait([ref.read(authControllerProvider.notifier).refreshProfile(), _loadStatus()]);
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _onPay(String tier) async {
    setState(() => _error = null);
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Enter the Safaricom number to charge (e.g. 07XX XXX XXX).');
      return;
    }
    setState(() => _payingTier = tier);
    try {
      final result = await _repo.initiateMpesaPayment(tier, _phone.text.trim());
      setState(() => _pending = (tier: tier, transactionId: result.transactionId));
      _beginPolling(result.transactionId);
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : "Couldn't start the M-Pesa payment.");
    } finally {
      if (mounted) setState(() => _payingTier = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final currentTier = _status?.planTier ?? user?.planTier ?? 'free';
    final currentRank = _tierRank[currentTier] ?? 0;

    return Container(
      color: const Color(0xD9040608),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 700),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('PLAN & BILLING', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1))),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: AppColors.ink3, size: 18)),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_pending != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x14FAB219),
                            border: Border.all(color: const Color(0x4DFAB219)),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Check your phone for the M-Pesa prompt and enter your PIN to complete the '
                                '${_pending!.tier == 'plus' ? 'Plus' : 'Pro'} upgrade. This updates automatically once Safaricom confirms it.',
                                style: const TextStyle(color: AppColors.ink2, fontSize: 12, height: 1.4),
                              ),
                              const SizedBox(height: 8),
                              const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                            ],
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CURRENT PLAN', style: TextStyle(color: AppColors.ink3, fontSize: 10.5, letterSpacing: 1)),
                            const SizedBox(height: 2),
                            Text(
                              _planCards.firstWhere((p) => p.tier == currentTier, orElse: () => _planCards[0]).label,
                              style: const TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            if (_status?.planRenewsAt != null) ...[
                              const SizedBox(height: 2),
                              Text('Renews ${DateFormat.yMMMd().format(_status!.planRenewsAt!)}', style: const TextStyle(color: AppColors.ink3, fontSize: 11)),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  'Devices: ${_status?.ownDeviceCount ?? "…"}${_status?.features.maxOwnDevices != null ? " / ${_status!.features.maxOwnDevices}" : " / unlimited"}',
                                  style: const TextStyle(color: AppColors.ink2, fontSize: 12),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Watching: ${_status?.activeWatchCount ?? "…"}${_status?.features.maxActiveWatches != null ? " / ${_status!.features.maxActiveWatches}" : " / unlimited"}',
                                  style: const TextStyle(color: AppColors.ink2, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.accent),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              onPressed: _refreshing ? null : _onRefreshStatus,
                              child: _refreshing
                                  ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                                  : const Text('Refresh status', style: TextStyle(color: AppColors.accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      if (currentRank < 2) ...[
                        const _FieldLabel('M-Pesa phone number'),
                        TextField(controller: _phone, decoration: const InputDecoration(hintText: '07XX XXX XXX'), keyboardType: TextInputType.phone),
                        const SizedBox(height: 14),
                      ],
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 12)),
                        const SizedBox(height: 10),
                      ],
                      for (final plan in _planCards) ...[
                        _PlanCardWidget(
                          plan: plan,
                          isCurrent: plan.tier == currentTier,
                          isDowngradeOrSame: (_tierRank[plan.tier] ?? 0) <= currentRank,
                          paying: _payingTier == plan.tier,
                          disabled: _payingTier != null || _pending != null,
                          onPay: () => _onPay(plan.tier),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 4),
                      const Text(
                        'Upgrading sends an STK push prompt to the phone number above. Your plan updates automatically once Safaricom confirms the payment -- this app never marks itself as upgraded on its own.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.ink3, fontSize: 10.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

class _PlanCardWidget extends StatelessWidget {
  final _PlanCard plan;
  final bool isCurrent;
  final bool isDowngradeOrSame;
  final bool paying;
  final bool disabled;
  final VoidCallback onPay;

  const _PlanCardWidget({
    required this.plan,
    required this.isCurrent,
    required this.isDowngradeOrSame,
    required this.paying,
    required this.disabled,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: isCurrent ? AppColors.accent : AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(plan.label, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(plan.price, style: const TextStyle(color: AppColors.ink3, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('· $f', style: const TextStyle(color: AppColors.ink2, fontSize: 11.5, height: 1.3)),
            ),
          if (isCurrent)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: AppColors.accent), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: const Text('Current plan', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
            )
          else if (plan.tier != 'free')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDowngradeOrSame ? AppColors.line : AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: (isDowngradeOrSame || disabled) ? null : onPay,
                child: paying
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isDowngradeOrSame ? 'Included' : 'Pay with M-Pesa', style: const TextStyle(fontSize: 12.5)),
              ),
            ),
        ],
      ),
    );
  }
}
