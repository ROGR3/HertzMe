import 'package:flutter/material.dart';

/// Application-wide constants for configuration and theming
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // ==================== Audio Configuration ====================
  
  /// Smoothing factor for pitch detection (0.0 = no smoothing, 1.0 = max smoothing)
  static const double pitchSmoothingFactor = 0.7;
  
  /// Time window for displaying pitch history (seconds)
  static const double defaultTimeWindow = 20.0;
  
  /// Threshold for considering gaps between pitch segments (seconds)
  static const double pitchGapThreshold = 0.3;
  
  /// Update rate for UI refresh (milliseconds)
  static const int uiUpdateRate = 33; // ~30 FPS
  
  /// Maximum duration for reference tone playback (seconds)
  static const double maxReferenceDuration = 10.0;
  
  /// Sample rate for reference tone generation (Hz)
  static const int referenceSampleRate = 44100;
  
  /// Volume level for tone playback (0.0 - 1.0)
  static const double toneVolume = 0.15;
  
  // ==================== Audio Envelope Settings ====================
  
  /// Attack time for tone envelope (seconds)
  static const double toneAttackTime = 0.05;
  
  /// Release time for tone envelope (seconds)
  static const double toneReleaseTime = 0.1;
  
  // ==================== Chart Configuration ====================
  
  /// Past window ratio when reference is present (1/3 of total)
  static const double pastWindowRatio = 1.0 / 3.0;
  
  /// Future window ratio when reference is present (2/3 of total)
  static const double futureWindowRatio = 2.0 / 3.0;
  
  /// Fixed Y-axis range in semitones (MIDI notes)
  static const double fixedChartRange = 36.0; // 3 octaves
  
  /// Default minimum Y value (C3 = MIDI 48)
  static const double defaultMinY = 48.0;
  
  /// Chart grid horizontal interval for note mode (semitones)
  static const double chartNoteInterval = 1.0;
  
  /// Chart grid divisions for Hz mode
  static const int chartHzDivisions = 10;
  
  /// Chart title label divisions for Hz mode
  static const int chartHzTitleDivisions = 8;
  
  /// Chart vertical drag sensitivity
  static const double chartDragSensitivity = 0.1;
  
  /// Minimum MIDI note for chart (C1)
  static const double minChartMidi = 24.0;
  
  /// Maximum MIDI note for chart (C8)
  static const double maxChartMidi = 108.0;
  
  /// Chart border width
  static const double chartBorderWidth = 1.0;
  
  /// Chart line width for user pitch
  static const double userPitchLineWidth = 2.0;
  
  /// Chart line width for reference pitch
  static const double referencePitchLineWidth = 3.0;
  
  // ==================== UI Timing ====================
  
  /// Delay between reference tone notes (milliseconds)
  static const int tonePlaybackDelay = 50;
  
  // ==================== Pitch Matching ====================
  
  /// Threshold for considering pitches matched (cents)
  static const double pitchMatchThreshold = 50.0;
  
  /// Threshold for displaying cent deviation
  static const double centDisplayThreshold = 1.0;
  
  /// Threshold for highlighting large cent deviation
  static const double largeCentDeviation = 20.0;
  
  // ==================== Theme Colors ====================
  
  /// Primary background color
  static const Color primaryBackground = Color(0xFF1A1A1A);
  
  /// Secondary background color (cards, app bar)
  static const Color secondaryBackground = Color(0xFF2A2A2A);
  
  /// Primary accent color
  static const Color primaryAccent = Colors.blue;
  
  /// Success/correct color
  static const Color successColor = Colors.green;
  
  /// Error/incorrect color
  static const Color errorColor = Colors.red;
  
  /// Warning color (moderate deviation)
  static const Color warningColor = Colors.orange;
  
  /// Vertical divider color (current time indicator)
  static const Color currentTimeIndicatorColor = Colors.orange;
  
  /// Chart grid color (major lines)
  static const Color chartGridMajor = Colors.grey;
  
  /// Chart grid alpha for major lines
  static const double chartGridMajorAlpha = 0.3;
  
  /// Chart grid alpha for minor lines
  static const double chartGridMinorAlpha = 0.1;
  
  /// Chart grid alpha for Hz mode
  static const double chartGridHzAlpha = 0.2;
  
  /// Major grid line width
  static const double gridMajorLineWidth = 1.5;
  
  /// Minor grid line width
  static const double gridMinorLineWidth = 0.5;
  
  /// Chart border alpha
  static const double chartBorderAlpha = 0.3;
  
  /// User pitch line alpha (below area)
  static const double userPitchAreaAlpha = 0.1;
  
  /// Current time indicator alpha
  static const double timeIndicatorAlpha = 0.6;
  
  // ==================== Text Styles ====================
  
  /// Large note display font size
  static const double noteFontSizeLarge = 56.0;
  
  /// Medium note display font size
  static const double noteFontSizeMedium = 48.0;
  
  /// Small note display font size
  static const double noteFontSizeSmall = 32.0;
  
  /// Frequency display font size
  static const double frequencyFontSize = 16.0;
  
  /// Cents display font size
  static const double centsFontSize = 12.0;
  
  /// Label font size
  static const double labelFontSize = 12.0;
  
  /// Chart axis label font size
  static const double chartLabelFontSize = 10.0;
  
  // ==================== Layout Constants ====================
  
  /// Standard padding
  static const double standardPadding = 16.0;
  
  /// Large padding
  static const double largePadding = 24.0;
  
  /// Small padding
  static const double smallPadding = 8.0;
  
  /// Card margin
  static const double cardMargin = 12.0;
  
  /// Icon size (standard)
  static const double iconSizeStandard = 32.0;
  
  /// Icon size (small)
  static const double iconSizeSmall = 20.0;
  
  /// Reserved size for chart bottom titles
  static const double chartBottomTitlesHeight = 30.0;
  
  /// Reserved size for chart left titles
  static const double chartLeftTitlesWidth = 50.0;
  
  /// Chart time label interval (seconds)
  static const double chartTimeLabelInterval = 2.0;
  
  // ==================== MIDI Constants ====================
  
  /// Octave contains 12 semitones
  static const int semitonesPerOctave = 12;
  
  /// MIDI note for middle C (C4)
  static const int middleC = 60;
  
  /// Base MIDI note for calculations (C1)
  static const int baseMidiNote = 24;
  
  /// Maximum MIDI note value
  static const int maxMidiNote = 127;
}


