import 'dart:math';
import '../models/song.dart';
import '../services/pitch_analyzer.dart';

/// Databáze písniček pro cvičení
class SongsDatabase {
  static final PitchAnalyzer _pitchAnalyzer = PitchAnalyzer();

  /// Seznam všech dostupných písniček
  static List<Song> get songs => [
    _createTwinkleTwinkle(),
    _createHappyBirthday(),
    _createDoReMi(),
    _createMaryHadALittleLamb(),
  ];

  /// Twinkle Twinkle Little Star - jednoduchá melodie
  static Song _createTwinkleTwinkle() {
    final notes = <SongNote>[];
    double time = 0.0;
    const noteDuration = 0.5; // Každá nota trvá 0.5 sekundy

    // Melodie: C C G G A A G
    final melody = ['C4', 'C4', 'G4', 'G4', 'A4', 'A4', 'G4'];
    for (final noteName in melody) {
      final frequency = _pitchAnalyzer.noteToFrequency(noteName);
      final midiNote = _frequencyToMidi(frequency);
      notes.add(SongNote(
        frequency: frequency,
        note: noteName,
        timestamp: time,
        midiNote: midiNote,
      ));
      time += noteDuration;
    }

    // F F E E D D C
    final melody2 = ['F4', 'F4', 'E4', 'E4', 'D4', 'D4', 'C4'];
    for (final noteName in melody2) {
      final frequency = _pitchAnalyzer.noteToFrequency(noteName);
      final midiNote = _frequencyToMidi(frequency);
      notes.add(SongNote(
        frequency: frequency,
        note: noteName,
        timestamp: time,
        midiNote: midiNote,
      ));
      time += noteDuration;
    }

    return Song(
      name: 'Twinkle Twinkle Little Star',
      notes: notes,
      duration: time,
    );
  }

  /// Happy Birthday - populární melodie
  static Song _createHappyBirthday() {
    final notes = <SongNote>[];
    double time = 0.0;

    // Happy Birthday to You - první část
    final melody = [
      ('C4', 0.3),
      ('C4', 0.2),
      ('D4', 0.5),
      ('C4', 0.5),
      ('F4', 0.5),
      ('E4', 0.8),
    ];

    for (final (noteName, duration) in melody) {
      final frequency = _pitchAnalyzer.noteToFrequency(noteName);
      final midiNote = _frequencyToMidi(frequency);
      notes.add(SongNote(
        frequency: frequency,
        note: noteName,
        timestamp: time,
        midiNote: midiNote,
      ));
      time += duration;
    }

    // Druhá část
    final melody2 = [
      ('C4', 0.3),
      ('C4', 0.2),
      ('D4', 0.5),
      ('C4', 0.5),
      ('G4', 0.5),
      ('F4', 0.8),
    ];

    for (final (noteName, duration) in melody2) {
      final frequency = _pitchAnalyzer.noteToFrequency(noteName);
      final midiNote = _frequencyToMidi(frequency);
      notes.add(SongNote(
        frequency: frequency,
        note: noteName,
        timestamp: time,
        midiNote: midiNote,
      ));
      time += duration;
    }

    return Song(
      name: 'Happy Birthday',
      notes: notes,
      duration: time,
    );
  }

  /// Do Re Mi - stupnice
  static Song _createDoReMi() {
    final notes = <SongNote>[];
    double time = 0.0;
    const noteDuration = 0.4;

    // C D E F G A B C (C dur stupnice)
    final scale = ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5'];
    for (final noteName in scale) {
      final frequency = _pitchAnalyzer.noteToFrequency(noteName);
      final midiNote = _frequencyToMidi(frequency);
      notes.add(SongNote(
        frequency: frequency,
        note: noteName,
        timestamp: time,
        midiNote: midiNote,
      ));
      time += noteDuration;
    }

    return Song(
      name: 'Do Re Mi (C Dur Stupnice)',
      notes: notes,
      duration: time,
    );
  }

  /// Mary Had a Little Lamb - jednoduchá melodie
  static Song _createMaryHadALittleLamb() {
    final notes = <SongNote>[];
    double time = 0.0;
    const noteDuration = 0.4;

    // E D C D E E E
    final melody = ['E4', 'D4', 'C4', 'D4', 'E4', 'E4', 'E4'];
    for (final noteName in melody) {
      final frequency = _pitchAnalyzer.noteToFrequency(noteName);
      final midiNote = _frequencyToMidi(frequency);
      notes.add(SongNote(
        frequency: frequency,
        note: noteName,
        timestamp: time,
        midiNote: midiNote,
      ));
      time += noteDuration;
    }

    // D D D E G G
    final melody2 = ['D4', 'D4', 'D4', 'E4', 'G4', 'G4'];
    for (final noteName in melody2) {
      final frequency = _pitchAnalyzer.noteToFrequency(noteName);
      final midiNote = _frequencyToMidi(frequency);
      notes.add(SongNote(
        frequency: frequency,
        note: noteName,
        timestamp: time,
        midiNote: midiNote,
      ));
      time += noteDuration;
    }

    // E D C D E E E E D D E D C
    final melody3 = ['E4', 'D4', 'C4', 'D4', 'E4', 'E4', 'E4', 'E4', 'D4', 'D4', 'E4', 'D4', 'C4'];
    for (final noteName in melody3) {
      final frequency = _pitchAnalyzer.noteToFrequency(noteName);
      final midiNote = _frequencyToMidi(frequency);
      notes.add(SongNote(
        frequency: frequency,
        note: noteName,
        timestamp: time,
        midiNote: midiNote,
      ));
      time += noteDuration;
    }

    return Song(
      name: 'Mary Had a Little Lamb',
      notes: notes,
      duration: time,
    );
  }

  /// Pomocná funkce pro převod frekvence na MIDI číslo
  static int _frequencyToMidi(double frequency) {
    if (frequency <= 0) return 0;
    final midiNote = (69 + 12 * (log(frequency / 440.0) / log(2))).round();
    return midiNote.clamp(0, 127);
  }
}

