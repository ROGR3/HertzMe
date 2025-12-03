import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/logic/pitch_chart_logic.dart';
import 'package:hello_app/models/pitch_data.dart';

void main() {
  late PitchChartLogic logic;

  setUp(() {
    logic = PitchChartLogic();
  });

  group('PitchChartLogic', () {
    group('prepareSegments', () {
      test('creates segments correctly handling gaps', () {
        final data = [
          PitchData(frequency: 440, note: 'A4', timestamp: 1.0, midiNote: 69, cents: 0),
          PitchData(frequency: 440, note: 'A4', timestamp: 1.1, midiNote: 69, cents: 0),
          // Gap > 0.3s
          PitchData(frequency: 440, note: 'A4', timestamp: 1.5, midiNote: 69, cents: 0),
          PitchData(frequency: 440, note: 'A4', timestamp: 1.6, midiNote: 69, cents: 0),
        ];

        final segments = logic.prepareSegments(
          pitchData: data,
          currentTime: 2.0,
          timeWindow: 5.0,
          showNotes: true,
        );

        expect(segments.length, 2);
        expect(segments[0].length, 2);
        expect(segments[1].length, 2);
      });

      test('filters data outside time window but keeps one point before', () {
        final data = [
          PitchData(frequency: 440, note: 'A4', timestamp: 0.9, midiNote: 69, cents: 0), // Before window (starts at 1.0)
          PitchData(frequency: 440, note: 'A4', timestamp: 1.1, midiNote: 69, cents: 0), // In window
          PitchData(frequency: 440, note: 'A4', timestamp: 1.3, midiNote: 69, cents: 0), // In window
        ];

        // Window 1.0 to 3.0
        final segments = logic.prepareSegments(
          pitchData: data,
          currentTime: 3.0,
          timeWindow: 2.0,
          showNotes: true,
        );

        // Should include 0.9 because it's immediately before window start (1.0)
        expect(segments.length, 1);
        expect(segments[0].length, 3);
        expect(segments[0][0].x, 0.9);
      });

      test('converts to MIDI notes when showNotes is true', () {
        final data = [
           PitchData(frequency: 440, note: 'A4', timestamp: 1.0, midiNote: 69, cents: 0),
        ];

        final segments = logic.prepareSegments(
          pitchData: data,
          currentTime: 2.0,
          timeWindow: 5.0,
          showNotes: true,
        );

        expect(segments[0][0].y, 69.0);
      });

      test('converts to Frequency when showNotes is false', () {
        final data = [
           PitchData(frequency: 440, note: 'A4', timestamp: 1.0, midiNote: 69, cents: 0),
        ];

        final segments = logic.prepareSegments(
          pitchData: data,
          currentTime: 2.0,
          timeWindow: 5.0,
          showNotes: false,
        );

        expect(segments[0][0].y, 440.0);
      });
    });

    group('calculateMinMaxY', () {
      test('returns default range when no data', () {
        final result = logic.calculateMinMaxY(
          pitchData: [],
          referenceData: null,
          currentTime: 10.0,
          timeWindow: 5.0,
          showNotes: true,
        );

        expect(result.minY, 36.0);
        expect(result.maxY, 84.0);
      });

      test('calculates range based on recent data (Notes)', () {
         final data = [
           PitchData(frequency: 440, note: 'A4', timestamp: 9.0, midiNote: 60, cents: 0), // C4
           PitchData(frequency: 440, note: 'A4', timestamp: 9.5, midiNote: 72, cents: 0), // C5
         ];

         final result = logic.calculateMinMaxY(
           pitchData: data,
           referenceData: null,
           currentTime: 10.0,
           timeWindow: 5.0,
           showNotes: true,
         );

         // Range is 12. Margin 12 * 0.15 = 1.8 -> clamped to 2.0.
         // Min: 60 - 2.0 = 58.0
         // Max: 72 + 2.0 = 74.0
         expect(result.minY, closeTo(58.0, 0.1));
         expect(result.maxY, closeTo(74.0, 0.1));
      });
      
      test('ensures minimum range of 6 semitones', () {
         final data = [
           PitchData(frequency: 440, note: 'A4', timestamp: 9.0, midiNote: 60, cents: 0),
           PitchData(frequency: 440, note: 'A4', timestamp: 9.5, midiNote: 61, cents: 0),
         ];

         final result = logic.calculateMinMaxY(
           pitchData: data,
           referenceData: null,
           currentTime: 10.0,
           timeWindow: 5.0,
           showNotes: true,
         );

         expect(result.maxY - result.minY, greaterThanOrEqualTo(6.0));
      });
    });
  });
}

