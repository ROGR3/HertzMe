import 'dart:math';
import '../models/pitch_data.dart';

/// Služba pro analýzu pitchu z audio vzorků
///
/// Používá autocorrelation metodu pro detekci základní frekvence (F0).
/// Tato metoda je přesnější než zero-crossing rate, protože dokáže
/// lépe identifikovat periodu signálu i v přítomnosti harmonických.
class PitchAnalyzer {
  /// Vzorkovací frekvence (Hz)
  static const int sampleRate = 44100;

  /// Minimální detekovatelná frekvence (Hz) - odpovídá přibližně C2
  static const double minFrequency = 65.0;

  /// Maximální detekovatelná frekvence (Hz) - odpovídá přibližně C6
  static const double maxFrequency = 1047.0;

  /// Velikost bufferu pro analýzu (musí být dostatečně velký pro nízké frekvence)
  static const int bufferSize = 4096;

  /// Názvy not v chromatické stupnici
  static const List<String> noteNames = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  /// Referenční frekvence A4 (standardní ladění)
  static const double a4Frequency = 440.0;

  /// MIDI číslo pro A4
  static const int a4Midi = 69;

  /// Detekuje základní frekvenci z audio vzorků pomocí YIN algoritmu
  ///
  /// YIN algoritmus je optimalizovaná verze autocorrelation, která:
  /// - Používá normalizovanou diferenční funkci
  /// - Je spolehlivější pro hlas a hudební nástroje
  /// - Má lepší odolnost vůči šumu
  ///
  /// Algoritmus:
  /// 1. Vypočítá diferenční funkci (difference function)
  /// 2. Normalizuje ji pomocí kumulativní střední hodnoty
  /// 3. Najde první minimum pod prahem
  /// 4. Převádí lag na frekvenci
  double detectFrequency(List<double> samples) {
    if (samples.length < bufferSize) {
      return 0.0;
    }

    // Použijeme pouze potřebný počet vzorků
    final buffer = samples.take(bufferSize).toList();

    // Normalizace signálu (odstranění DC offsetu)
    final mean = buffer.reduce((a, b) => a + b) / buffer.length;
    final normalized = buffer.map((s) => s - mean).toList();

    // Výpočet diferenční funkce pomocí YIN algoritmu
    final differenceFunction = _computeDifferenceFunction(normalized);

    // Normalizace pomocí kumulativní střední hodnoty
    final cumulativeMean = _computeCumulativeMeanNormalizedDifference(
      differenceFunction,
    );

    // Najdeme první minimum pod prahem v rozsahu odpovídajícím min-max frekvencím
    final minLag = (sampleRate / maxFrequency).round();
    final maxLag = (sampleRate / minFrequency).round();

    const threshold = 0.1; // Prahová hodnota pro detekci (nižší = citlivější)

    int bestLag = 0;
    double minValue = double.infinity;

    // Hledáme první minimum pod prahem
    for (int lag = minLag; lag < min(maxLag, cumulativeMean.length); lag++) {
      if (cumulativeMean[lag] < threshold) {
        // Najdeme lokální minimum kolem tohoto lagu
        int localMinLag = lag;
        double localMinValue = cumulativeMean[lag];

        // Hledáme minimum v okolí ±2 vzorky
        for (int i = lag - 2; i <= lag + 2 && i < cumulativeMean.length; i++) {
          if (i > 0 && cumulativeMean[i] < localMinValue) {
            localMinValue = cumulativeMean[i];
            localMinLag = i;
          }
        }

        if (localMinValue < minValue) {
          minValue = localMinValue;
          bestLag = localMinLag;
        }
        break; // Použijeme první nalezené minimum
      }
    }

    // Pokud jsme nenašli žádné minimum pod prahem, zkusíme najít globální minimum
    if (bestLag == 0) {
      for (int lag = minLag; lag < min(maxLag, cumulativeMean.length); lag++) {
        if (cumulativeMean[lag] < minValue) {
          minValue = cumulativeMean[lag];
          bestLag = lag;
        }
      }

      // Pokud je minimum příliš vysoké, signál není periodický
      if (minValue > 0.3) {
        return 0.0;
      }
    }

    if (bestLag == 0 || bestLag < minLag) {
      return 0.0;
    }

    // Parabolická interpolace pro přesnější určení lagu
    double exactLag = bestLag.toDouble();
    if (bestLag > 0 && bestLag < cumulativeMean.length - 1) {
      final y1 = cumulativeMean[bestLag - 1];
      final y2 = cumulativeMean[bestLag];
      final y3 = cumulativeMean[bestLag + 1];

      final denominator = 2 * (2 * y2 - y1 - y3);
      if (denominator != 0) {
        final delta = (y1 - y3) / denominator;
        exactLag = bestLag + delta;
      }
    }

    // Převod lag na frekvenci
    final frequency = sampleRate / exactLag;

    // Ověření, že frekvence je v rozsahu
    if (frequency < minFrequency || frequency > maxFrequency) {
      return 0.0;
    }

    return frequency;
  }

  /// Vypočítá diferenční funkci (difference function) pro YIN algoritmus
  ///
  /// Optimalizovaná verze pro rychlejší výpočet - počítáme pouze do maxLag
  List<double> _computeDifferenceFunction(List<double> signal) {
    final n = signal.length;
    final maxLag = (sampleRate / minFrequency).round();
    final actualMaxLag = min(maxLag, n);
    final diff = List<double>.filled(actualMaxLag, 0.0);

    for (int lag = 0; lag < actualMaxLag; lag++) {
      double sum = 0.0;
      for (int j = 0; j < n - lag; j++) {
        final delta = signal[j] - signal[j + lag];
        sum += delta * delta;
      }
      diff[lag] = sum;
    }

    return diff;
  }

  /// Vypočítá kumulativní střední normalizovanou diferenční funkci
  List<double> _computeCumulativeMeanNormalizedDifference(List<double> diff) {
    final n = diff.length;
    final cmndf = List<double>.filled(n, 0.0);

    cmndf[0] = 1.0; // První hodnota je vždy 1

    double runningSum = 0.0;
    for (int lag = 1; lag < n; lag++) {
      runningSum += diff[lag];
      if (runningSum > 0) {
        cmndf[lag] = diff[lag] * lag / runningSum;
      } else {
        cmndf[lag] = 1.0;
      }
    }

    return cmndf;
  }

  /// Převádí frekvenci na PitchData objekt
  ///
  /// Výpočet:
  /// 1. Vypočítá MIDI číslo pomocí logaritmického vztahu mezi frekvencemi
  /// 2. Určí název noty z MIDI čísla
  /// 3. Vypočítá cent odchylku od nejbližší noty
  PitchData frequencyToPitchData(double frequency, double timestamp) {
    if (frequency <= 0) {
      return PitchData.empty(timestamp);
    }

    // Výpočet MIDI čísla pomocí logaritmického vztahu
    // MIDI číslo = 69 + 12 * log2(frequency / 440)
    final midiNote = (69 + 12 * (log(frequency / a4Frequency) / ln2)).round();

    // Omezení na platný rozsah MIDI (0-127)
    final clampedMidi = midiNote.clamp(0, 127);

    // Název noty z MIDI čísla
    final noteName = noteNames[clampedMidi % 12];
    final octave = (clampedMidi ~/ 12) - 1;
    final note = '$noteName$octave';

    // Výpočet cent odchylky od nejbližší noty
    // Cent = 1200 * log2(actual_freq / nearest_note_freq)
    final nearestNoteFreq = _midiToFrequency(clampedMidi);
    final cents = 1200 * (log(frequency / nearestNoteFreq) / ln2);

    return PitchData(
      frequency: frequency,
      note: note,
      timestamp: timestamp,
      midiNote: clampedMidi,
      cents: cents,
    );
  }

  /// Převádí MIDI číslo na frekvenci
  double _midiToFrequency(int midiNote) {
    return a4Frequency * pow(2, (midiNote - a4Midi) / 12);
  }

  /// Převádí frekvenci na název noty (pro rychlý přístup)
  String frequencyToNote(double frequency) {
    if (frequency <= 0) return '-';

    final midiNote = (69 + 12 * (log(frequency / a4Frequency) / ln2)).round();
    final clampedMidi = midiNote.clamp(0, 127);

    final noteName = noteNames[clampedMidi % 12];
    final octave = (clampedMidi ~/ 12) - 1;

    return '$noteName$octave';
  }

  /// Vypočítá všechny noty v rozsahu pro zobrazení na ose Y
  ///
  /// Vrací seznam not od nejnižší po nejvyšší v rozsahu C2 až C6
  List<String> getNoteRange() {
    final notes = <String>[];

    // C2 má MIDI číslo 36, C6 má MIDI číslo 84
    for (int midi = 36; midi <= 84; midi++) {
      final noteName = noteNames[midi % 12];
      final octave = (midi ~/ 12) - 1;
      notes.add('$noteName$octave');
    }

    return notes;
  }

  /// Vypočítá frekvenci pro danou notu
  double noteToFrequency(String note) {
    // Parsování noty (např. "A4" -> A, 4)
    if (note.length < 2) return 0.0;

    final notePart = note.substring(0, note.length - 1);
    final octavePart = note.substring(note.length - 1);

    final noteIndex = noteNames.indexOf(notePart);
    if (noteIndex == -1) return 0.0;

    final octave = int.tryParse(octavePart);
    if (octave == null) return 0.0;

    final midiNote = (octave + 1) * 12 + noteIndex;
    return _midiToFrequency(midiNote);
  }
}
