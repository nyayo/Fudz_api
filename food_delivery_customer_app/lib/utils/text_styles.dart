import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';

/// Responsive text scaling utility
/// Base reference: 375px width (iPhone SE / small phone)
class ResponsiveText {
  // Base width for scaling calculations (iPhone SE width)
  static const double _baseWidth = 375.0;
  
  // Maximum scale factor to prevent text from becoming too large on tablets
  static const double _maxScaleFactor = 1.3;
  
  // Minimum scale factor to prevent text from becoming too small
  static const double _minScaleFactor = 0.85;

  /// Calculate scale factor based on screen width
  static double _scaleFactor(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / _baseWidth;
    
    // Clamp the scale factor to prevent extreme sizes
    return scale.clamp(_minScaleFactor, _maxScaleFactor);
  }

  /// Get responsive font size
  static double fontSize(BuildContext context, double baseSize) {
    return baseSize * _scaleFactor(context);
  }

  // ============ HEADING STYLES ============

  /// Heading 1 - Large titles (28px base)
  static TextStyle heading1(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 28),
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color ?? TColor.primaryText,
    );
  }

  /// Heading 2 - Section titles (22px base)
  static TextStyle heading2(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 22),
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color ?? TColor.primaryText,
    );
  }

  /// Heading 3 - Sub-section titles (18px base)
  static TextStyle heading3(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 18),
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color ?? TColor.primaryText,
    );
  }

  /// Heading 4 - Small headings (16px base)
  static TextStyle heading4(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 16),
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color ?? TColor.primaryText,
    );
  }

  // ============ BODY TEXT STYLES ============

  /// Body text - Standard readable text (16px base)
  static TextStyle body(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 16),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? TColor.primaryText,
    );
  }

  /// Body small - Secondary text (14px base)
  static TextStyle bodySmall(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 14),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? TColor.secondaryText,
    );
  }

  /// Caption - Small descriptive text (12px base)
  static TextStyle caption(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 12),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? TColor.secondaryText,
    );
  }

  /// Tiny - Very small text like badges (10px base)
  static TextStyle tiny(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 10),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? TColor.secondaryText,
    );
  }

  // ============ SPECIALIZED STYLES ============

  /// Button text (16px base)
  static TextStyle button(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 16),
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color ?? Colors.white,
    );
  }

  /// Price text - Emphasized pricing (16px base)
  static TextStyle price(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    bool isDiscounted = false,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 16),
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color ?? (isDiscounted ? Colors.red : TColor.primary),
    );
  }

  /// Large price - For prominent pricing display (20px base)
  static TextStyle priceSize(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
    bool isDiscounted = false,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 20),
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color ?? (isDiscounted ? Colors.red : TColor.primary),
    );
  }

  /// Form label text (14px base)
  static TextStyle formLabel(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 14),
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? TColor.textTittle,
    );
  }

  /// Hint text for inputs (14px base)
  static TextStyle hint(
    BuildContext context, {
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 14),
      fontWeight: FontWeight.normal,
      color: color ?? TColor.placeholder,
    );
  }

  /// Error text (12px base)
  static TextStyle error(
    BuildContext context, {
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize(context, 12),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: Colors.red,
    );
  }

  // ============ HELPER METHODS ============

  /// Get scaled size for custom use cases
  static double scaled(BuildContext context, double baseSize) {
    return fontSize(context, baseSize);
  }

  /// Check if current screen is considered small
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }

  /// Check if current screen is considered large (tablet)
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 600;
  }
}
