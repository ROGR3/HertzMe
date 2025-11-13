import 'pitch_data.dart';

/// Model pro reprezentaci písničky s jejími tóny
class Song {
  /// Název písničky
  final String name;

  /// Sekvence tónů písničky - každý tón má časovou značku a frekvenci/notu
  final List<SongNote> notes;

  /// Celková délka písničky v sekundách
  final double duration;

  const Song({required this.name, required this.notes, required this.duration});

  /// Vytvoří PitchData pro daný čas v písničce
  /// Vrací nejbližší tón k danému času
  PitchData? getPitchAtTime(double time) {
    if (notes.isEmpty || time < 0 || time > duration) {
      return null;
    }

    // Najdeme nejbližší tón k danému času
    SongNote? closestNote;
    double minDistance = double.infinity;

    for (final note in notes) {
      final distance = (note.timestamp - time).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closestNote = note;
      }
    }

    if (closestNote == null) return null;

    // Vytvoříme PitchData z SongNote
    return PitchData(
      frequency: closestNote.frequency,
      note: closestNote.note,
      timestamp: time,
      midiNote: closestNote.midiNote,
      cents: 0.0, // Referenční tóny jsou přesné
    );
  }

  /// Vrací všechny PitchData pro zobrazení v grafu
  /// Vytvoří kontinuální sekvenci bodů s interpolací mezi notami
  List<PitchData> getPitchDataSequence() {
    if (notes.isEmpty) return [];

    final result = <PitchData>[];
    const sampleRate = 20.0; // 20 bodů za sekundu pro plynulou křivku

    for (int i = 0; i < notes.length; i++) {
      final currentNote = notes[i];
      final nextNote = i < notes.length - 1 ? notes[i + 1] : null;

      // Vytvoříme body pro aktuální notu
      if (nextNote != null) {
        // Mezi aktuální a následující notou vytvoříme interpolované body
        final duration = nextNote.timestamp - currentNote.timestamp;
        final numSamples = (duration * sampleRate).ceil();
        final step = duration / numSamples;

        for (int j = 0; j < numSamples; j++) {
          final t = currentNote.timestamp + (j * step);
          result.add(
            PitchData(
              frequency: currentNote.frequency,
              note: currentNote.note,
              timestamp: t,
              midiNote: currentNote.midiNote,
              cents: 0.0,
            ),
          );
        }
      } else {
        // Poslední nota - vytvoříme body až do konce (nebo alespoň 0.5 sekundy)
        final duration = 0.5; // Minimální délka poslední noty
        final numSamples = (duration * sampleRate).ceil();
        final step = duration / numSamples;

        for (int j = 0; j < numSamples; j++) {
          final t = currentNote.timestamp + (j * step);
          result.add(
            PitchData(
              frequency: currentNote.frequency,
              note: currentNote.note,
              timestamp: t,
              midiNote: currentNote.midiNote,
              cents: 0.0,
            ),
          );
        }
      }
    }

    return result;
  }
}

/// Reprezentace jednoho tónu v písničce
class SongNote {
  /// Frekvence v Hz
  final double frequency;

  /// Název noty (např. "A4")
  final String note;

  /// Časová značka v sekundách od začátku písničky
  final double timestamp;

  /// MIDI číslo noty
  final int midiNote;

  const SongNote({
    required this.frequency,
    required this.note,
    required this.timestamp,
    required this.midiNote,
  });
}
