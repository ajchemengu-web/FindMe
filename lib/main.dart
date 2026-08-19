import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme_mode_controller.dart';
import 'features/auth/google_auth_service.dart';
import 'theme/tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initGoogleSignIn();
  } catch (e) {
    // Not fatal -- the app boots fine without Google sign-in configured, same as an
    // unset API_BASE_URL. The button just won't complete a sign-in until
    // GOOGLE_CLIENT_ID is set at build time.
    // ignore: avoid_print
    print('Google sign-in unavailable: $e');
  }
  runApp(const ProviderScope(child: FindMeApp()));
}

class FindMeApp extends ConsumerWidget {
  const FindMeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'FindMe',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
