import '../../core/api/api_client.dart';

class ReferralStats {
  final String referralCode;
  final int totalReferrals;
  final int payingReferrals;
  final int pendingCommissionCents;
  final int paidCommissionCents;

  ReferralStats({
    required this.referralCode,
    required this.totalReferrals,
    required this.payingReferrals,
    required this.pendingCommissionCents,
    required this.paidCommissionCents,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> j) => ReferralStats(
        referralCode: j['referral_code'] as String,
        totalReferrals: j['total_referrals'] as int,
        payingReferrals: j['paying_referrals'] as int,
        pendingCommissionCents: j['pending_commission_cents'] as int,
        paidCommissionCents: j['paid_commission_cents'] as int,
      );
}

/// No corresponding screen existed in findme_app -- GET /referrals/stats was
/// backend-ready but never wired up client-side (a gap flagged during porting). Small
/// enough to add directly rather than leave unbuilt: surfaced as a section in the
/// Privacy Center, the natural home for account-level info.
class ReferralsRepository {
  final _api = ApiClient.instance;

  Future<ReferralStats> fetchStats() async {
    final json = await _api.request<Map<String, dynamic>>('/referrals/stats');
    return ReferralStats.fromJson(json!);
  }
}
