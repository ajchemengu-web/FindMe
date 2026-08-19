import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/alerts_screen.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/billing/billing_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/auth/verify_phone_screen.dart';
import '../../features/consent/people_screen.dart';
import '../../features/devices/add_device_screen.dart';
import '../../features/devices/situation_room_screen.dart';
import '../../features/geofence/add_geofence_screen.dart';
import '../../features/intel/intel_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/privacy/privacy_screen.dart';
import '../../theme/tokens.dart';
import 'app_shell.dart';
import 'router_refresh_notifier.dart';

/// Ported from findme_app/app/_layout.tsx's RootNavigator: (auth) group vs (app) group
/// gated on session presence, using go_router's `redirect` instead of Stack.Protected.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier(ref, authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggedIn = auth.valueOrNull != null;
      final isLoading = auth.isLoading && !auth.hasValue;
      final onSplash = state.matchedLocation == '/splash';
      final onAuthRoute = state.matchedLocation == '/sign-in' || state.matchedLocation == '/sign-up';

      if (isLoading) return onSplash ? null : '/splash';
      if (onSplash) return loggedIn ? '/' : '/sign-in';
      if (!loggedIn && !onAuthRoute) return '/sign-in';
      if (loggedIn && onAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (context, state) => const SignUpScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const SituationRoomScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/map', builder: (context, state) => const MapScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/intel', builder: (context, state) => const IntelScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/people', builder: (context, state) => const PeopleScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/privacy', builder: (context, state) => const PrivacyScreen())]),
        ],
      ),
      GoRoute(
        path: '/verify-phone',
        pageBuilder: (context, state) => const MaterialPage(fullscreenDialog: true, child: VerifyPhoneScreen()),
      ),
      GoRoute(
        path: '/add-device',
        pageBuilder: (context, state) => const MaterialPage(fullscreenDialog: true, child: AddDeviceScreen()),
      ),
      GoRoute(
        path: '/billing',
        pageBuilder: (context, state) => const MaterialPage(fullscreenDialog: true, child: BillingScreen()),
      ),
      GoRoute(
        path: '/add-geofence',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return MaterialPage(
            fullscreenDialog: true,
            child: AddGeofenceScreen(deviceId: extra?['deviceId'] as String?, nickname: extra?['nickname'] as String?),
          );
        },
      ),
    ],
  );
});

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.page,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
}
