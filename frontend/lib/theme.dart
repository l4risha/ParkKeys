import 'package:flutter/material.dart';

/// Single source for ParkKeys colors, radii, ug text styles.
/// Tricycle vibe: barangay green + taxi yellow, rounded cards.
class ParkKeysColors {
  ParkKeysColors._();

  static const Color green = Color(0xFF1B6B3A);
  static const Color greenDark = Color(0xFF0F3D22);
  static const Color greenSoft = Color(0xFFE4F3E8);
  static const Color yellow = Color(0xFFF5C518);
  static const Color yellowSoft = Color(0xFFFFF4C8);
  static const Color canvas = Color(0xFFF3F5EF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1C211D);
  static const Color muted = Color(0xFF5C665E);
  static const Color line = Color(0xFFD7DDD4);
  static const Color waiting = Color(0xFF1565C0);
  static const Color onDeck = Color(0xFFEF6C00);
  static const Color completed = Color(0xFF2E7D32);
  static const Color cancelled = Color(0xFF616161);
  static const Color skipped = Color(0xFF6A1B9A);
  static const Color removed = Color(0xFFC62828);
  static const Color demandHigh = Color(0xFFC62828);
  static const Color demandMedium = Color(0xFFEF6C00);
  static const Color demandLow = Color(0xFF2E7D32);
}

class ParkKeysRadii {
  ParkKeysRadii._();

  static const double card = 20;
  static const double control = 14;
  static const double chip = 20;
  static const double iconWell = 16;
}

class ParkKeysText {
  ParkKeysText._();

  static const TextTheme textTheme = TextTheme(
    displayMedium: TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
      height: 1.05,
      color: ParkKeysColors.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      height: 1.15,
      color: ParkKeysColors.ink,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.2,
      color: ParkKeysColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: ParkKeysColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: ParkKeysColors.ink,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: ParkKeysColors.ink,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: ParkKeysColors.ink,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: ParkKeysColors.ink,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: ParkKeysColors.muted,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: ParkKeysColors.ink,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: ParkKeysColors.muted,
    ),
  );
}

ColorScheme _parkKeysScheme() {
  return const ColorScheme(
    brightness: Brightness.light,
    primary: ParkKeysColors.green,
    onPrimary: Colors.white,
    primaryContainer: ParkKeysColors.greenSoft,
    onPrimaryContainer: ParkKeysColors.greenDark,
    secondary: ParkKeysColors.yellow,
    onSecondary: ParkKeysColors.ink,
    secondaryContainer: ParkKeysColors.yellowSoft,
    onSecondaryContainer: Color(0xFF3D3200),
    tertiary: ParkKeysColors.waiting,
    onTertiary: Colors.white,
    error: ParkKeysColors.removed,
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: ParkKeysColors.card,
    onSurface: ParkKeysColors.ink,
    onSurfaceVariant: ParkKeysColors.muted,
    outline: Color(0xFF8A9388),
    outlineVariant: ParkKeysColors.line,
    inverseSurface: ParkKeysColors.greenDark,
    onInverseSurface: Color(0xFFE8F0E9),
    inversePrimary: ParkKeysColors.yellow,
    surfaceTint: ParkKeysColors.green,
  );
}

ThemeData buildAppTheme() {
  final scheme = _parkKeysScheme();
  final radius = BorderRadius.circular(ParkKeysRadii.control);
  final cardRadius = BorderRadius.circular(ParkKeysRadii.card);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: ParkKeysText.textTheme,
    scaffoldBackgroundColor: ParkKeysColors.canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: ParkKeysColors.card,
      foregroundColor: ParkKeysColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: ParkKeysColors.ink,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: ParkKeysColors.card,
      shadowColor: ParkKeysColors.greenDark.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: cardRadius,
        side: const BorderSide(color: ParkKeysColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ParkKeysColors.canvas,
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: ParkKeysColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: ParkKeysColors.green, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        backgroundColor: ParkKeysColors.green,
        foregroundColor: Colors.white,
        textStyle: ParkKeysText.textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        foregroundColor: ParkKeysColors.green,
        textStyle: ParkKeysText.textTheme.labelLarge,
        side: const BorderSide(color: ParkKeysColors.line),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ParkKeysColors.green,
        textStyle: ParkKeysText.textTheme.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ParkKeysRadii.chip),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ParkKeysColors.greenDark,
      contentTextStyle: ParkKeysText.textTheme.bodyMedium?.copyWith(
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ParkKeysColors.card,
      shape: RoundedRectangleBorder(borderRadius: cardRadius),
    ),
    dividerColor: ParkKeysColors.line,
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ParkKeysColors.green,
    ),
  );
}

/// Rounded icon well. Gamiton sa cards para consistent spacing.
class BrandIconWell extends StatelessWidget {
  const BrandIconWell({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = 22,
    this.background = ParkKeysColors.greenSoft,
    this.foreground = ParkKeysColors.green,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ParkKeysRadii.iconWell),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}
