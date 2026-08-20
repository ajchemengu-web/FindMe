import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors_data.dart';

/// Static content describing what FindMe actually does with data -- written against
/// the real feature set (consent-gated location sharing, phone OTP via Twilio, Google
/// Sign-In, M-Pesa billing, the public conflict/news intel feed), not a generic
/// boilerplate template. Doubles as the URL Google's OAuth consent screen requires for
/// "Continue with Google" to leave testing mode.
///
/// Update `_contactEmail` and `_lastUpdated` when either changes -- both are used
/// verbatim in the body text below, not just as constants.
const _contactEmail = 'ajchemengu@gmail.com';
const _lastUpdated = 'August 2026';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Last updated: $_lastUpdated', style: TextStyle(color: colors.ink3, fontSize: 11.5)),
          const SizedBox(height: 18),
          _Section(
            title: 'The short version',
            body: 'FindMe only shows a device\'s location to people that device\'s owner has explicitly '
                'approved, for exactly the precision level (precise or city-only) they chose. Nothing about '
                'you is visible to anyone else -- not other users, not the public -- until you approve a '
                'request. You can revoke access at any time, and revoking takes effect immediately.',
          ),
          _Section(
            title: 'Information we collect',
            body: '• Account info: email, username, display name, and (optionally) phone number, when you '
                'sign up or sign in with Google.\n'
                '• Location data: only for devices you explicitly add, and only when a location is reported '
                '(a one-tap action, not continuous background tracking). This is never collected for a '
                'device unless you or its owner added it in the app.\n'
                '• Consent records: who you\'ve requested to see, who\'s requested to see you, and the '
                'precision level agreed to -- this is the access-control ledger the whole app runs on.\n'
                '• Payment records: for M-Pesa (Safaricom) subscription payments, we store the transaction '
                'reference and amount, never your M-Pesa PIN or full account details -- those are handled '
                'entirely by Safaricom\'s own systems.\n'
                '• Device push token: so we can deliver alerts (consent requests, geofence enter/exit) to '
                'your phone.',
          ),
          _Section(
            title: 'How we use it',
            body: 'To run the features you\'d expect: showing approved devices on the map, sending consent-request '
                'and geofence alerts, verifying your phone number via a one-time SMS code, processing '
                'subscription payments, and tracking referral commissions if you share your invite code. We '
                'don\'t sell your data, and we don\'t use your location data for advertising.',
          ),
          _Section(
            title: 'Who we share it with',
            body: '• Other FindMe users: only a device\'s location, and only with people that device\'s owner '
                'has explicitly granted access to, at the precision level chosen. Nobody else sees it.\n'
                '• Service providers we rely on to run the app: our hosting providers (Render for the backend, '
                'Vercel for the web app), our database provider, Twilio (sending SMS verification codes), '
                'Safaricom/M-Pesa (processing payments), and Google (Sign-In authentication, if you use it). '
                'Each only receives what it needs to do its specific job.\n'
                '• The Map tab\'s search bar sends your search text to OpenStreetMap\'s Nominatim service and '
                'your current location to OSRM (both free, independent open-source routing services) to '
                'compute directions -- neither is affiliated with FindMe and neither receives any other '
                'account information.\n'
                '• We don\'t share data with advertisers, and we don\'t sell it to anyone.',
          ),
          _Section(
            title: 'The global threat map and news feed',
            body: 'The conflict-zone and news data shown on the Situation Room globe and Intel Feed comes from '
                'public sources (ACLED, GDELT, UCDP, and news APIs) and isn\'t personal data at all -- it\'s '
                'the same public information for every user, unrelated to your account.',
          ),
          _Section(
            title: 'Your controls',
            body: '• Revoke access: remove anyone\'s ability to see a device you own at any time, from Privacy '
                'Center or People & Devices -- takes effect immediately.\n'
                '• Edit or delete your account: change your profile, username, or email from Privacy Center. '
                'To delete your account entirely, contact us at $_contactEmail.\n'
                '• Location history: device location pings are kept only as long as needed to show current '
                'position and geofence history; removing a device removes its location history with it.',
          ),
          _Section(
            title: 'Children',
            body: 'FindMe isn\'t directed at children under 13, and we don\'t knowingly collect data from them.',
          ),
          _Section(
            title: 'Changes to this policy',
            body: 'If this policy changes in a way that affects how your data is used, we\'ll update the date '
                'at the top of this page.',
          ),
          _Section(
            title: 'Contact',
            body: 'Questions about this policy, or a request to delete your account or data: $_contactEmail',
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => launchUrl(Uri.parse('mailto:$_contactEmail'), mode: LaunchMode.externalApplication),
            child: Text('Email $_contactEmail', style: TextStyle(color: colors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: colors.ink, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: colors.ink2, fontSize: 12.5, height: 1.5)),
        ],
      ),
    );
  }
}
