// Design tokens ported 1:1 from findme_app/theme/tokens.ts, which itself was ported
// 1:1 from the HTML mockup's CSS custom properties (findme_situation_room_mockup.html
// :root{}). Keep values identical across findme_app and findme_flutter so both stay
// visually consistent with the design reference.
import 'package:flutter/material.dart';

import 'app_colors_data.dart';

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

/// Tile-layer sources for the map (flutter_map / raster tiles), replacing
/// theme/tokens.ts's mapStyleDark (a Google Maps JSON style array). flutter_map has no
/// concept of a JSON map style since it renders raster/vector tiles directly, so instead
/// we use CartoDB's basemap tiles directly -- dark_all matches this look on iOS,
/// Android, AND web identically (the RN app could only apply its dark style on
/// Android; see findme_app/README.md's "iOS map styling doesn't match" known gap).
///
/// light_all is CARTO's Positron-family counterpart -- same tile provider/design
/// family as dark_all (so it stays visually coherent with the rest of the app rather
/// than switching providers), used when the map is shown in light mode: a permanently
/// dark map read as low-clarity/low-contrast for anyone who prefers a light interface,
/// and until this the Map screen ignored the user's theme preference entirely. Both
/// verified directly against CARTO's tile server before use (real PNG responses, not
/// guessed).
const mapTileUrlDark = 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}{r}.png';
const mapTileUrlLight = 'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}{r}.png';

/// Builds a full ThemeData from an [AppColorsData] palette, with that palette attached
/// as a ThemeExtension so migrated screens can read it via `context.colors`.
/// Un-migrated screens still reference the old static `AppColors` dark constants
/// directly and are wrapped in an explicit forced-dark Theme at the route level (see
/// core/router/app_router.dart) so they keep rendering consistently regardless of the
/// user's actual preference, rather than ending up with (say) light-themed buttons
/// sitting on a hardcoded-dark page.
ThemeData _buildTheme(AppColorsData colors, Brightness brightness) {
  final base = brightness == Brightness.dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: colors.page,
    colorScheme: base.colorScheme.copyWith(
      surface: colors.surface,
      primary: colors.accent,
      secondary: colors.accent,
      error: colors.critical,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
      fontFamily: 'monospace',
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.page,
      foregroundColor: colors.ink,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.hair),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.hair),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.hair),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.accent),
      ),
      hintStyle: TextStyle(color: colors.ink3),
      labelStyle: TextStyle(color: colors.ink2),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: colors.brandMarkForeground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colors.surface,
      selectedItemColor: colors.accent,
      unselectedItemColor: colors.ink3,
    ),
    extensions: [colors],
  );
}

ThemeData buildDarkTheme() => _buildTheme(AppColorsData.dark, Brightness.dark);

ThemeData buildLightTheme() => _buildTheme(AppColorsData.light, Brightness.light);
