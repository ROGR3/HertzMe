import 'package:flutter_test/flutter_test.dart';
import 'package:hertzme/models/song.dart';

void main() {
  group('Song JSON Serialization', () {
    test('SongNote fromJson creates correct instance', () {
      final json = {
        'note': 'C4',
        'midi': 60,
        'frequency': 261.63,
        'timestamp': 20.46,
      };

      final songNote = SongNote.fromJson(json);

      expect(songNote.note, 'C4');
      expect(songNote.midiNote, 60);
      expect(songNote.frequency, 261.63);
      expect(songNote.timestamp, 20.46);
    });

    test('SongNote toJson creates correct map', () {
      const songNote = SongNote(
        note: 'C4',
        midiNote: 60,
        frequency: 261.63,
        timestamp: 20.46,
      );

      final json = songNote.toJson();

      expect(json['note'], 'C4');
      expect(json['midi'], 60);
      expect(json['frequency'], 261.63);
      expect(json['timestamp'], 20.46);
    });

    test('Song fromJson creates correct instance', () {
      final json = {
        'name': 'Test Song',
        'duration': 10.5,
        'notes': [
          {
            'note': 'C4',
            'midi': 60,
            'frequency': 261.63,
            'timestamp': 0.0,
          },
          {
            'note': 'D4',
            'midi': 62,
            'frequency': 293.66,
            'timestamp': 1.0,
          },
        ],
      };

      final song = Song.fromJson(json);

      expect(song.name, 'Test Song');
      expect(song.duration, 10.5);
      expect(song.notes.length, 2);
      expect(song.notes[0].note, 'C4');
      expect(song.notes[1].note, 'D4');
    });

    test('Song toJson creates correct map', () {
      const song = Song(
        name: 'Test Song',
        duration: 10.5,
        notes: [
          SongNote(
            note: 'C4',
            midiNote: 60,
            frequency: 261.63,
            timestamp: 0.0,
          ),
          SongNote(
            note: 'D4',
            midiNote: 62,
            frequency: 293.66,
            timestamp: 1.0,
          ),
        ],
      );

      final json = song.toJson();

      expect(json['name'], 'Test Song');
      expect(json['duration'], 10.5);
      expect(json['notes'], isA<List>());
      expect((json['notes'] as List).length, 2);
    });

    test('Song roundtrip (toJson -> fromJson) preserves data', () {
      const originalSong = Song(
        name: 'Test Song',
        duration: 10.5,
        notes: [
          SongNote(
            note: 'C4',
            midiNote: 60,
            frequency: 261.63,
            timestamp: 0.0,
          ),
        ],
      );

      final json = originalSong.toJson();
      final reconstructedSong = Song.fromJson(json);

      expect(reconstructedSong.name, originalSong.name);
      expect(reconstructedSong.duration, originalSong.duration);
      expect(reconstructedSong.notes.length, originalSong.notes.length);
      expect(reconstructedSong.notes[0].note, originalSong.notes[0].note);
      expect(
        reconstructedSong.notes[0].midiNote,
        originalSong.notes[0].midiNote,
      );
      expect(
        reconstructedSong.notes[0].frequency,
        originalSong.notes[0].frequency,
      );
      expect(
        reconstructedSong.notes[0].timestamp,
        originalSong.notes[0].timestamp,
      );
    });
  });
}


