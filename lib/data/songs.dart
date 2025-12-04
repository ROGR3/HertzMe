import '../models/song.dart';
import '../services/pitch_analyzer.dart';
import '../utils/music_utils.dart';

/// Databáze písniček pro cvičení
class SongsDatabase {
  // Private constructor to prevent instantiation
  SongsDatabase._();

  static final PitchAnalyzer _pitchAnalyzer = PitchAnalyzer();

  /// Seznam všech dostupných písniček
  static List<Song> get songs => [
    _createTwinkleTwinkle(),
    _createHappyBirthday(),
    _createDoReMi(),
    _createLongDoReMi(),
    _createMaryHadALittleLamb(),
  ];

  /// Helper method to create a SongNote from note name and timestamp
  static SongNote _createNote(String noteName, double timestamp) {
    final frequency = _pitchAnalyzer.noteToFrequency(noteName);
    final midiNote = MusicUtils.frequencyToMidi(frequency);
    return SongNote(
      frequency: frequency,
      note: noteName,
      timestamp: timestamp,
      midiNote: midiNote,
    );
  }

  /// Helper method to create a sequence of notes with uniform duration
  static List<SongNote> _createNoteSequence(List<String> noteNames, {double startTime = 0.0, double noteDuration = 1.0}) {
    final notes = <SongNote>[];
    double time = startTime;
    
    for (final noteName in noteNames) {
      notes.add(_createNote(noteName, time));
      time += noteDuration;
    }
    
    return notes;
  }

  /// Helper method to create notes with variable durations
  static List<SongNote> _createNotesWithDurations(List<(String, double)> noteData, {double startTime = 0.0}) {
    final notes = <SongNote>[];
    double time = startTime;
    
    for (final (noteName, duration) in noteData) {
      notes.add(_createNote(noteName, time));
      time += duration;
    }
    
    return notes;
  }

  /// Twinkle Twinkle Little Star - jednoduchá melodie
  static Song _createTwinkleTwinkle() {
    const noteDuration = 1.0;
    
    // Melodie: C C G G A A G, F F E E D D C
    final melody1 = ['C4', 'C4', 'G4', 'G4', 'A4', 'A4', 'G4'];
    final melody2 = ['F4', 'F4', 'E4', 'E4', 'D4', 'D4', 'C4'];
    
    final notes = [
      ..._createNoteSequence(melody1, noteDuration: noteDuration),
      ..._createNoteSequence(melody2, startTime: melody1.length * noteDuration, noteDuration: noteDuration),
    ];

    return Song(
      name: 'Twinkle Twinkle Little Star',
      notes: notes,
      duration: notes.last.timestamp + noteDuration,
    );
  }

  /// Happy Birthday - populární melodie
  static Song _createHappyBirthday() {
    // Happy Birthday to You
    final melody1 = [
      ('C4', 0.6), ('C4', 0.4), ('D4', 1.0),
      ('C4', 1.0), ('F4', 1.0), ('E4', 1.6),
    ];

    final melody2 = [
      ('C4', 0.6), ('C4', 0.4), ('D4', 1.0),
      ('C4', 1.0), ('G4', 1.0), ('F4', 1.6),
    ];

    final notes1 = _createNotesWithDurations(melody1);
    final notes2 = _createNotesWithDurations(melody2, startTime: notes1.last.timestamp + melody1.last.$2);

    final notes = [...notes1, ...notes2];
    final duration = notes2.last.timestamp + melody2.last.$2;

    return Song(name: 'Happy Birthday', notes: notes, duration: duration);
  }

  /// Do Re Mi - stupnice
  static Song _createDoReMi() {
    const noteDuration = 0.8;
    
    // C D E F G A B C (C dur stupnice)
    final scale = ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5'];
    final notes = _createNoteSequence(scale, noteDuration: noteDuration);

    return Song(
      name: 'Do Re Mi (C Dur Stupnice)',
      notes: notes,
      duration: notes.last.timestamp + noteDuration,
    );
  }

  /// Long Do Re Mi - dlouhá stupnice (3s na notu)
  static Song _createLongDoReMi() {
    const noteDuration = 3.0;
    
    // C D E F G A B C (C dur stupnice)
    final scale = ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5'];
    final notes = _createNoteSequence(scale, noteDuration: noteDuration);

    return Song(
      name: 'Long Do Re Mi (3s)',
      notes: notes,
      duration: notes.last.timestamp + noteDuration,
    );
  }

  /// Mary Had a Little Lamb - jednoduchá melodie
  static Song _createMaryHadALittleLamb() {
    const noteDuration = 0.8;

    // E D C D E E E
    final melody1 = ['E4', 'D4', 'C4', 'D4', 'E4', 'E4', 'E4'];
    
    // D D D E G G
    final melody2 = ['D4', 'D4', 'D4', 'E4', 'G4', 'G4'];
    
    // E D C D E E E E D D E D C
    final melody3 = ['E4', 'D4', 'C4', 'D4', 'E4', 'E4', 'E4', 'E4', 'D4', 'D4', 'E4', 'D4', 'C4'];

    final notes = [
      ..._createNoteSequence(melody1, noteDuration: noteDuration),
      ..._createNoteSequence(melody2, startTime: melody1.length * noteDuration, noteDuration: noteDuration),
      ..._createNoteSequence(melody3, startTime: (melody1.length + melody2.length) * noteDuration, noteDuration: noteDuration),
    ];

    return Song(
      name: 'Mary Had a Little Lamb',
      notes: notes,
      duration: notes.last.timestamp + noteDuration,
    );
  }
}
