import '../../core/api/api_client.dart';

class PlanFeatures {
  final int? maxOwnDevices; // null = unlimited
  final int? maxActiveWatches;
  final bool geofencingAllowed;
  final bool preciseScopeAllowed;
  final bool intelWatchlistAllowed;

  PlanFeatures({
    required this.maxOwnDevices,
    required this.maxActiveWatches,
    required this.geofencingAllowed,
    required this.preciseScopeAllowed,
    required this.intelWatchlistAllowed,
  });

  factory PlanFeatures.fromJson(Map<String, dynamic> j) => PlanFeatures(
        maxOwnDevices: j['max_own_devices'] as int?,
        maxActiveWatches: j['max_active_watches'] as int?,
        geofencingAllowed: j['geofencing_allowed'] as bool,
        preciseScopeAllowed: j['precise_scope_allowed'] as bool,
        intelWatchlistAllowed: j['intel_watchlist_allowed'] as bool,
      );
}

class BillingStatus {
  final String planTier;
  final String effectivePlanTier;
  final DateTime? planRenewsAt;
  final int ownDeviceCount;
  final int activeWatchCount;
  final PlanFeatures features;

  BillingStatus({
    required this.planTier,
    required this.effectivePlanTier,
    required this.planRenewsAt,
    required this.ownDeviceCount,
    required this.activeWatchCount,
    required this.features,
  });

  factory BillingStatus.fromJson(Map<String, dynamic> j) => BillingStatus(
        planTier: j['plan_tier'] as String,
        effectivePlanTier: j['effective_plan_tier'] as String,
        planRenewsAt: j['plan_renews_at'] != null ? DateTime.parse(j['plan_renews_at'] as String) : null,
        ownDeviceCount: j['own_device_count'] as int,
        activeWatchCount: j['active_watch_count'] as int,
        features: PlanFeatures.fromJson(j['features'] as Map<String, dynamic>),
      );
}

class StkPushResult {
  final String transactionId;
  StkPushResult({required this.transactionId});
  factory StkPushResult.fromJson(Map<String, dynamic> j) => StkPushResult(transactionId: j['transaction_id'] as String);
}

class MpesaTransaction {
  final String id;
  final String tier;
  final int amountKes;
  final String status; // pending | success | failed
  MpesaTransaction({required this.id, required this.tier, required this.amountKes, required this.status});
  factory MpesaTransaction.fromJson(Map<String, dynamic> j) =>
      MpesaTransaction(id: j['id'] as String, tier: j['tier'] as String, amountKes: j['amount_kes'] as int, status: j['status'] as String);
}

/// Ported 1:1 from findme_app/lib/billing.ts, except FREE_PLAN_LIMITS' hardcoded
/// display constants are dropped -- GET /billing/status already returns the real
/// server-computed limits, so there's nothing to keep in sync by hand (the original
/// RN app's hardcoded maxOwnDevices: 1 had drifted from the backend's actual
/// FREE_MAX_OWN_DEVICES = 3; this port just doesn't have a second copy to drift).
class BillingRepository {
  final _api = ApiClient.instance;

  Future<BillingStatus> fetchBillingStatus() async {
    final json = await _api.request<Map<String, dynamic>>('/billing/status');
    return BillingStatus.fromJson(json!);
  }

  Future<StkPushResult> initiateMpesaPayment(String tier, String phone) async {
    final json = await _api.request<Map<String, dynamic>>('/billing/mpesa/stk-push', method: 'POST', body: {'tier': tier, 'phone': phone});
    return StkPushResult.fromJson(json!);
  }

  Future<MpesaTransaction> getMpesaTransaction(String transactionId) async {
    final json = await _api.request<Map<String, dynamic>>('/billing/mpesa/transactions/$transactionId');
    return MpesaTransaction.fromJson(json!);
  }
}
