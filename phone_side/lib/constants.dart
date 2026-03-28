import 'package:flutter/material.dart';

// ============ COLOR CONSTANTS ============
class AppColors {
  // Neon accent colors (cyberpunk theme)
  static const Color cyan = Color(0xFF00FFFF); // Primary accent
  static const Color yellow = Color(0xFFFFFF00); // Secondary accent
  static const Color magenta = Color(0xFFFF00FF); // Debug/status accent
  static const Color neonGreen = Color(0xFF00FF41); // Connected/active/hacker
  static const Color neonRed = Color(0xFFFF0055); // Disconnected/error/defender
  static const Color orange = Color(0xFFFF6600); // Defender turn

  // Base colors
  static const Color background = Colors.black;
  static const Color text = Colors.white;
  static const Color border = Colors.cyan;

  // State colors
  static const Color connected = neonGreen;
  static const Color disconnected = neonRed;
  static const Color hackerTurn = neonGreen;
  static const Color defenderTurn = orange;
}

// ============ SPACING CONSTANTS ============
class AppSpacing {
  // Standard spacing increments
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;

  // Padding/margin combinations
  static const EdgeInsets paddingXSmall = EdgeInsets.symmetric(
    horizontal: xs,
    vertical: xs,
  );
  static const EdgeInsets paddingSmall = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: sm,
  );
  static const EdgeInsets paddingMedium = EdgeInsets.symmetric(
    horizontal: md,
    vertical: md,
  );
  static const EdgeInsets paddingLarge = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: lg,
  );

  // Button padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 6,
  );
  static const EdgeInsets toolButtonPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 8,
  );
  static const EdgeInsets panelPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  );

  // Common SizedBox sizes
  static const SizedBox spacerXSmall = SizedBox(height: xs);
  static const SizedBox spacerSmall = SizedBox(height: sm);
  static const SizedBox spacerMedium = SizedBox(height: md);
  static const SizedBox spacerLarge = SizedBox(height: lg);
  static const SizedBox spacerXLarge = SizedBox(height: xl);

  static const SizedBox spacerWidthSmall = SizedBox(width: sm);
  static const SizedBox spacerWidthMedium = SizedBox(width: md);
  static const SizedBox spacerWidthLarge = SizedBox(width: lg);
}

// ============ TEXT STYLE CONSTANTS ============
class AppTextStyles {
  // Base text style with Courier New font (no glow)
  static TextStyle _baseCourierStyle(
    Color color, {
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontFamily: 'Courier New',
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  // Device name / connection text
  static TextStyle deviceName = _baseCourierStyle(
    AppColors.neonGreen,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // Button/label text
  static TextStyle buttonLabel = _baseCourierStyle(
    AppColors.cyan,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );

  static TextStyle statusButtonLabel = _baseCourierStyle(
    AppColors.yellow,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );

  static TextStyle debugButtonLabel = _baseCourierStyle(
    AppColors.magenta,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );

  // Large panel text
  static TextStyle panelTitle = _baseCourierStyle(
    AppColors.cyan,
    fontSize: 14,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  // Standard panel text
  static TextStyle panelText = _baseCourierStyle(
    AppColors.cyan,
    fontSize: 11,
    letterSpacing: 0.5,
  );

  // Timer text
  static TextStyle timerText = _baseCourierStyle(
    AppColors.cyan,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );

  // Turn indicator text
  static TextStyle turnIndicator({required Color color}) => _baseCourierStyle(
    color,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );

  // Error message text
  static TextStyle errorText = TextStyle(
    color: AppColors.neonRed,
    fontSize: 11,
    fontFamily: 'Courier New',
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );

  // Success message text
  static TextStyle successText = TextStyle(
    color: AppColors.neonGreen,
    fontSize: 11,
    fontFamily: 'Courier New',
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );
}

// ============ DECORATION CONSTANTS ============
class AppDecorations {
  // Standard border style
  static BoxBorder standardBorder(Color color, {double width = 2}) =>
      Border.all(color: color, width: width);

  // Container decoration factory (clean borders, no glow)
  static BoxDecoration glowContainer({
    required Color color,
    double borderRadius = 4,
  }) {
    return BoxDecoration(
      border: Border.all(color: color, width: 2),
      borderRadius: BorderRadius.circular(borderRadius),
      color: color.withOpacity(0.05),
    );
  }

  // Top bar decoration
  static BoxDecoration topBarDecoration = BoxDecoration(
    color: AppColors.background,
    border: Border(bottom: BorderSide(color: AppColors.cyan, width: 2)),
  );

  // Panel background decoration
  static BoxDecoration panelDecoration = BoxDecoration(
    color: AppColors.background,
    border: Border.all(color: AppColors.cyan, width: 2),
    borderRadius: BorderRadius.circular(8),
  );
}

// ============ SIZE CONSTANTS ============
class AppSizes {
  // Connection indicator sizes
  static const double indicatorSize = 12;

  // Border radius
  static const double borderRadiusSmall = 4;
  static const double borderRadiusMedium = 8;
  static const double borderRadiusLarge = 12;

  // Shadow/glow radius
  static const double shadowRadiusSmall = 4;
  static const double shadowRadiusMedium = 8;
  static const double shadowRadiusLarge = 12;

  // Node tap area
  static const double nodeHitRadius = 30.0;
  static const double topBarHeight = 90.0;
}

// ============ ANIMATION CONSTANTS ============
class AppAnimation {
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 500);
  static const Duration long = Duration(milliseconds: 1000);
}
