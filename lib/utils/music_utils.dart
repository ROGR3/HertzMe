import 'dart:math';
import '../constants/app_constants.dart';

/// Utility functions for music and pitch calculations
class MusicUtils {
  // Private constructor to prevent instantiation
  MusicUtils._();

  /// Reference frequency for A4 (Hz)
  static const double a4Frequency = 440.0;

  /// MIDI note number for A4
  static const int a4MidiNote = 69;

  /// Converts frequency to MIDI note number
  /// 
  /// Formula: MIDI = 69 + 12 * log2(frequency / 440)
  /// 
  /// Returns 0 for invalid frequencies
  static int frequencyToMidi(double frequency) {
    if (frequency <= 0) return 0;
    final midiNote = (a4MidiNote + AppConstants.semitonesPerOctave * (log(frequency / a4Frequency) / ln2)).round();
    return midiNote.clamp(0, AppConstants.maxMidiNote);
  }

  /// Converts MIDI note number to frequency (Hz)
  /// 
  /// Formula: frequency = 440 * 2^((MIDI - 69) / 12)
  static double midiToFrequency(int midiNote) {
    return a4Frequency * pow(2, (midiNote - a4MidiNote) / AppConstants.semitonesPerOctave);
  }

  /// Calculates cent deviation between two frequencies
  /// 
  /// Cent = 1200 * log2(freq1 / freq2)
  /// 
  /// One cent is 1/100th of a semitone
  static double frequencyToCents(double actualFrequency, double referenceFrequency) {
    if (actualFrequency <= 0 || referenceFrequency <= 0) return 0.0;
    return 1200 * (log(actualFrequency / referenceFrequency) / ln2);
  }

  /// Checks if two MIDI notes match within the specified cent threshold
  /// 
  /// Returns true if the notes are the same and cent deviation is acceptable
  static bool isPitchMatch(int midiNote1, double cents1, int midiNote2, {double threshold = AppConstants.pitchMatchThreshold}) {
    return midiNote1 == midiNote2 && cents1.abs() < threshold;
  }

  /// Returns the note name (without octave) from a MIDI note number
  /// 
  /// Example: MIDI 60 (C4) returns "C"
  static String getMidiNoteName(int midiNote) {
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    return noteNames[midiNote % AppConstants.semitonesPerOctave];
  }

  /// Returns the octave number from a MIDI note number
  /// 
  /// Example: MIDI 60 (C4) returns 4
  static int getMidiOctave(int midiNote) {
    return (midiNote ~/ AppConstants.semitonesPerOctave) - 1;
  }

  /// Returns the full note name with octave from a MIDI note number
  /// 
  /// Example: MIDI 60 returns "C4"
  static String midiToNoteName(int midiNote) {
    return '${getMidiNoteName(midiNote)}${getMidiOctave(midiNote)}';
  }

  /// Parses a note name string to extract note and octave
  /// 
  /// Returns null if parsing fails
  /// 
  /// Example: "C#4" returns ("C#", 4)
  static ({String note, int octave})? parseNoteName(String noteName) {
    if (noteName.length < 2) return null;

    // Handle both "C4" and "C#4" formats
    final String notePart;
    final String octavePart;

    if (noteName.length == 2) {
      // Format: "C4"
      notePart = noteName.substring(0, 1);
      octavePart = noteName.substring(1);
    } else {
      // Format: "C#4"
      notePart = noteName.substring(0, noteName.length - 1);
      octavePart = noteName.substring(noteName.length - 1);
    }

    final octave = int.tryParse(octavePart);
    if (octave == null) return null;

    return (note: notePart, octave: octave);
  }

  /// Converts a note name to MIDI note number
  /// 
  /// Returns null if the note name is invalid
  /// 
  /// Example: "C4" returns 60
  static int? noteNameToMidi(String noteName) {
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    
    final parsed = parseNoteName(noteName);
    if (parsed == null) return null;

    final noteIndex = noteNames.indexOf(parsed.note);
    if (noteIndex == -1) return null;

    return (parsed.octave + 1) * AppConstants.semitonesPerOctave + noteIndex;
  }
}

