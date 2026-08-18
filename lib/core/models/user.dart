/// Ported 1:1 from findme_backend_fastapi's UserOut schema (app/schemas/auth.py).
class AppUser {
  final String id;
  final String email;
  final String username;
  final String? phone;
  final bool phoneVerified;
  final String? displayName;
  final String? avatarUrl;
  final String planTier;
  final DateTime? planRenewsAt;
  final String referralCode;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    required this.username,
    required this.phone,
    required this.phoneVerified,
    required this.displayName,
    required this.avatarUrl,
    required this.planTier,
    required this.planRenewsAt,
    required this.referralCode,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        phone: json['phone'] as String?,
        phoneVerified: json['phone_verified'] as bool,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        planTier: json['plan_tier'] as String,
        planRenewsAt: json['plan_renews_at'] != null ? DateTime.parse(json['plan_renews_at'] as String) : null,
        referralCode: json['referral_code'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
