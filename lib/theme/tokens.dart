// Design tokens ported 1:1 from findme_app/theme/tokens.ts, which itself was ported
// 1:1 from the HTML mockup's CSS custom properties (findme_situation_room_mockup.html
// :root{}). Keep values identical across findme_app and findme_flutter so both stay
// visually consistent with the design reference.
import 'package:flutter/material.dart';

enum Severity { good, warning, serious, critical }

enum DevicePrecision { owner, precise, city }

enum NewsCategory { politics, business, markets, security }

class AppColors {
  AppColors._();

  static const page = Color(0xFF0D0D0D);
  static const surface = Color(0xFF14181D);
  static const surface2 = Color(0xFF181C22);
  static const line = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const hair = Color(0xFF2C2C2A);
  static const ink = Color(0xFFFFFFFF);
  static const ink2 = Color(0xFFC3C2B7);
  static const ink3 = Color(0xFF898781);

  static const accent = Color(0xFF3987E5);
  static const accentDim = Color(0x293987E5); // rgba(57,135,229,0.16)
  static const catAqua = Color(0xFF199E70);
  static const catYellow = Color(0xFFC98500);
  static const catViolet = Color(0xFF9085E9);
  static const catOrange = Color(0xFFD95926);
  static const catMagenta = Color(0xFFD55181);

  static const good = Color(0xFF0CA30C);
  static const warning = Color(0xFFFAB219);
  static const serious = Color(0xFFEC835A);
  static const critical = Color(0xFFD03B3B);

  static Color severity(Severity s) => switch (s) {
        Severity.good => good,
        Severity.warning => warning,
        Severity.serious => serious,
        Severity.critical => critical,
      };

  static Color devicePrecision(DevicePrecision p) => switch (p) {
        DevicePrecision.owner => accent,
        DevicePrecision.precise => good,
        DevicePrecision.city => warning,
      };

  static ({Color bg, Color fg}) newsCategory(NewsCategory c) => switch (c) {
        NewsCategory.politics => (bg: const Color(0x293987E5), fg: const Color(0xFF7FB1EE)),
        NewsCategory.business => (bg: const Color(0x2E199E70), fg: const Color(0xFF4FD6A6)),
        NewsCategory.markets => (bg: const Color(0x2EC98500), fg: const Color(0xFFE9B34A)),
        NewsCategory.security => (bg: const Color(0x2E9085E9), fg: const Color(0xFFB3A9F5)),
      };
}

class AppRadius {
  AppRadius._();
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const pill = 999.0;
}

double spacing(double n) => n * 4;

/// Dark tile-layer styling for the map (flutter_map / raster tiles), replacing
/// theme/tokens.ts's mapStyleDark (a Google Maps JSON style array). flutter_map has no
/// concept of a JSON map style since it renders raster/vector tiles directly, so instead
/// we use a dark tile provider (CartoDB Dark Matter) and apply a ColorFilter tuned to
/// this palette so the look matches on iOS, Android, AND web identically -- unlike the
/// RN app, which could only apply mapStyleDark on Android (see findme_app/README.md's
/// "iOS map styling doesn't match" known gap). See features/map for usage.
const mapTileUrlDark = 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}{r}.png';

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.page,
    colorScheme: base.colorScheme.copyWith(
      surface: AppColors.surface,
      primary: AppColors.accent,
      secondary: AppColors.accent,
      error: AppColors.critical,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
      fontFamily: 'monospace',
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.page,
      foregroundColor: AppColors.ink,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.hair),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.hair),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.hair),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
      hintStyle: const TextStyle(color: AppColors.ink3),
      labelStyle: const TextStyle(color: AppColors.ink2),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.ink3,
    ),
  );
}
