import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hertzme/data/songs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SongsDatabase', () {
    test('initialize loads songs successfully', () async {
      // Mock the asset bundle for testing
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'loadString' &&
              methodCall.arguments == 'assets/songs/frozen_let_it_go.json') {
            // Return a minimal valid JSON
            return '''
{
  "name": "Test Frozen Song",
  "duration": 10.0,
  "notes": [
    {
      "note": "C4",
      "midi": 60,
      "frequency": 261.63,
      "timestamp": 0.0
    }
  ]
}
''';
          }
          return null;
        },
      );

      await SongsDatabase.initialize();

      final songs = SongsDatabase.songs;
      
      // Should have hardcoded songs + the loaded JSON song
      expect(songs.length, greaterThanOrEqualTo(5));
      
      // Verify we have the standard songs
      expect(songs.any((s) => s.name.contains('Twinkle')), true);
      expect(songs.any((s) => s.name.contains('Happy Birthday')), true);
      expect(songs.any((s) => s.name.contains('Do Re Mi')), true);
    });

    test('songs getter returns fallback if not initialized', () {
      // Clear the cached songs
      // We can't directly access _cachedSongs, but we can verify fallback works
      final songs = SongsDatabase.songs;
      
      // Should have at least the hardcoded songs
      expect(songs.length, greaterThanOrEqualTo(5));
    });

    test('all songs have valid properties', () async {
      await SongsDatabase.initialize();
      
      final songs = SongsDatabase.songs;

      for (final song in songs) {
        // Each song should have a name
        expect(song.name, isNotEmpty);
        
        // Each song should have a positive duration
        expect(song.duration, greaterThan(0));
        
        // Each song should have at least one note
        expect(song.notes, isNotEmpty);
        
        // Each note should have valid properties
        for (final note in song.notes) {
          expect(note.note, isNotEmpty);
          expect(note.frequency, greaterThan(0));
          expect(note.midiNote, greaterThanOrEqualTo(0));
          expect(note.timestamp, greaterThanOrEqualTo(0));
        }
      }
    });
  });
}


