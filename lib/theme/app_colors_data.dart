import 'package:flutter/material.dart';

import 'tokens.dart';

/// Theme-reactive color palette -- new, alongside the original always-dark `AppColors`
/// static class in tokens.dart. Screens ported so far keep using the static class
/// (unchanged, still dark-only, zero regression risk); screens migrated to respect the
/// user's light/dark preference read colors from here instead, via `context.colors`.
///
/// Rolled out incrementally rather than all at once: every static `AppColors.x`
/// reference in this app was written as a compile-time `const`, which a
/// theme-dependent value fundamentally can't be, so switching a screen over means
/// removing `const` from every widget that touches a color, not just renaming a
/// field. Doing that safely across every screen in one pass risked leaving something
/// broken; migrating screen-by-screen (starting with auth, Situation Room, the app
/// shell, and Privacy Center, where the toggle itself lives) keeps every already-shipped
/// screen working throughout.
@immutable
class AppColorsData extends ThemeExtension<AppColorsData> {
  final Color page;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color hair;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color accent;
  final Color accentDim;
  final Color catAqua;
  final Color catYellow;
  final Color catViolet;
  final Color catOrange;
  final Color catMagenta;
  final Color good;
  final Color warning;
  final Color serious;
  final Color critical;
  final Color brandMarkForeground;

  const AppColorsData({
    required this.page,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.hair,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accent,
    required this.accentDim,
    required this.catAqua,
    required this.catYellow,
    required this.catViolet,
    required this.catOrange,
    required this.catMagenta,
    required this.good,
    required this.warning,
    required this.serious,
    required this.critical,
    required this.brandMarkForeground,
  });

  /// Identical to the original always-dark palette in tokens.dart -- the app's
  /// existing look is unchanged when the user picks (or system default resolves to)
  /// dark.
  static const dark = AppColorsData(
    page: AppColors.page,
    surface: AppColors.surface,
    surface2: AppColors.surface2,
    line: AppColors.line,
    hair: AppColors.hair,
    ink: AppColors.ink,
    ink2: AppColors.ink2,
    ink3: AppColors.ink3,
    accent: AppColors.accent,
    accentDim: AppColors.accentDim,
    catAqua: AppColors.catAqua,
    catYellow: AppColors.catYellow,
    catViolet: AppColors.catViolet,
    catOrange: AppColors.catOrange,
    catMagenta: AppColors.catMagenta,
    good: AppColors.good,
    warning: AppColors.warning,
    serious: AppColors.serious,
    critical: AppColors.critical,
    brandMarkForeground: Color(0xFF04101F),
  );

  /// New -- no light palette existed anywhere before (not in the RN app, not in the
  /// original HTML mockup, both were dark-only "CIA dashboard" designs). Derived from
  /// the dark palette's structure (same accent/category/severity hues, so the two
  /// modes still read as the same product) with surfaces and ink inverted for a light
  /// page.
  static const light = AppColorsData(
    page: Color(0xFFF6F6F3),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF0F0EC),
    line: Color(0x14000000),
    hair: Color(0xFFDCDCD7),
    ink: Color(0xFF14181D),
    ink2: Color(0xFF44464A),
    ink3: Color(0xFF75756F),
    accent: Color(0xFF2A6DC4),
    accentDim: Color(0x1A2A6DC4),
    catAqua: Color(0xFF148058),
    catYellow: Color(0xFFA36C00),
    catViolet: Color(0xFF6E63C9),
    catOrange: Color(0xFFB3481C),
    catMagenta: Color(0xFFB03D68),
    good: Color(0xFF0A8A0A),
    warning: Color(0xFFB37A00),
    serious: Color(0xFFC65E36),
    critical: Color(0xFFB92E2E),
    brandMarkForeground: Color(0xFFFFFFFF),
  );

  Color severity(Severity s) => switch (s) {
        Severity.good => good,
        Severity.warning => warning,
        Severity.serious => serious,
        Severity.critical => critical,
      };

  Color devicePrecision(DevicePrecision p) => switch (p) {
        DevicePrecision.owner => accent,
        DevicePrecision.precise => good,
        DevicePrecision.city => warning,
      };

  @override
  AppColorsData copyWith() => this;

  @override
  AppColorsData lerp(ThemeExtension<AppColorsData>? other, double t) {
    if (other is! AppColorsData) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppColorsContext on BuildContext {
  AppColorsData get colors => Theme.of(this).extension<AppColorsData>()!;
}
