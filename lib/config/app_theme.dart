import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Application theme configuration
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  /// Dark theme for the application (similar to Vocal Pitch Monitor)
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppConstants.primaryAccent,
      scaffoldBackgroundColor: AppConstants.primaryBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppConstants.primaryAccent,
        surface: AppConstants.secondaryBackground,
        onSurface: Colors.white,
      ),
      useMaterial3: true,
    );
  }

  /// Creates a gradient for overlays (fade from black to transparent)
  static LinearGradient topOverlayGradient({double opacity = 0.8}) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha: opacity),
        Colors.transparent,
      ],
    );
  }

  /// Creates a gradient for bottom overlays (fade from black to transparent)
  static LinearGradient bottomOverlayGradient({double opacity = 0.9}) {
    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Colors.black.withValues(alpha: opacity),
        Colors.transparent,
      ],
    );
  }

  /// Standard card decoration
  static BoxDecoration get cardDecoration {
    return const BoxDecoration(
      color: AppConstants.secondaryBackground,
    );
  }

  /// Text style for large note display
  static const TextStyle largeNoteStyle = TextStyle(
    fontSize: AppConstants.noteFontSizeLarge,
    fontWeight: FontWeight.bold,
    color: AppConstants.primaryAccent,
  );

  /// Text style for medium note display
  static const TextStyle mediumNoteStyle = TextStyle(
    fontSize: AppConstants.noteFontSizeMedium,
    fontWeight: FontWeight.bold,
  );

  /// Text style for small note display
  static const TextStyle smallNoteStyle = TextStyle(
    fontSize: AppConstants.noteFontSizeSmall,
    fontWeight: FontWeight.bold,
  );

  /// Text style for frequency display
  static TextStyle frequencyStyle = TextStyle(
    fontSize: AppConstants.frequencyFontSize,
    color: Colors.grey[500],
  );

  /// Text style for cent display
  static TextStyle centsStyle(double cents) {
    return TextStyle(
      fontSize: AppConstants.centsFontSize,
      color: cents.abs() > AppConstants.largeCentDeviation
          ? Colors.red[300]
          : Colors.orange[300],
    );
  }

  /// Text style for labels
  static TextStyle labelStyle = TextStyle(
    fontSize: AppConstants.labelFontSize,
    color: Colors.grey[400],
    fontWeight: FontWeight.bold,
  );

  /// Text style for status text
  static TextStyle statusStyle = TextStyle(
    fontSize: AppConstants.labelFontSize,
    color: Colors.grey[400],
    fontStyle: FontStyle.italic,
  );

  /// Gets color for pitch display based on validity and matching
  static Color getPitchColor({
    required bool isValid,
    bool isMatching = false,
  }) {
    if (!isValid) return AppConstants.primaryAccent;
    return isMatching ? AppConstants.successColor : AppConstants.errorColor;
  }
}


