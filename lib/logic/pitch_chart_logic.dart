import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/pitch_data.dart';

/// Třída zapouzdřující logiku pro PitchChart
class PitchChartLogic {
  static const double _gapThreshold = 0.3; // sekundy

  /// Připraví segmenty pro graf z dat pitchu
  List<List<FlSpot>> prepareSegments({
    required List<PitchData> pitchData,
    required double currentTime,
    required double timeWindow,
    required bool showNotes,
  }) {
    // 1. Filtrace dat
    final minTime = currentTime - timeWindow;
    final firstIndex = pitchData.indexWhere(
      (d) => d.timestamp >= minTime,
    );

    final List<PitchData> filteredData;
    if (firstIndex == -1) {
      if (pitchData.isNotEmpty && pitchData.last.timestamp < minTime) {
        filteredData = [];
      } else {
        filteredData = [];
      }
    } else {
      final startIndex = firstIndex > 0 ? firstIndex - 1 : 0;
      filteredData = pitchData.sublist(startIndex);
    }

    // 2. Vytvoření spotů a segmentů
    final segments = <List<FlSpot>>[];
    final allSpots = <FlSpot>[];
    double? lastValidTimestamp;

    for (final data in filteredData) {
      if (data.isValid) {
        final spot = FlSpot(
          data.timestamp,
          showNotes ? data.midiNote.toDouble() : data.frequency,
        );

        if (lastValidTimestamp != null &&
            data.timestamp - lastValidTimestamp > _gapThreshold) {
          if (allSpots.isNotEmpty) {
            segments.add(List.from(allSpots));
            allSpots.clear();
          }
        }

        allSpots.add(spot);
        lastValidTimestamp = data.timestamp;
      }
    }

    if (allSpots.isNotEmpty) {
      segments.add(allSpots);
    }

    return segments;
  }

  /// Připraví referenční segmenty
  List<List<FlSpot>> prepareReferenceSegments({
    required List<PitchData> referenceData,
    required double currentTime,
    required double timeWindow,
    required bool showNotes,
  }) {
    final graphMinTime = currentTime - timeWindow;
    final graphMaxTime = currentTime;

    final filteredReferenceData = referenceData
        .where((data) {
          if (currentTime <= 0) {
            return data.timestamp >= 0 && data.timestamp <= 1.0;
          }
          if (currentTime < timeWindow) {
            return data.timestamp >= 0 && data.timestamp <= currentTime + 1.0;
          }
          return data.timestamp >= graphMinTime - 2.0 &&
              data.timestamp <= graphMaxTime + 2.0;
        })
        .toList();

    final segments = <List<FlSpot>>[];
    final refSpots = filteredReferenceData
        .where((data) => data.isValid)
        .map(
          (data) => FlSpot(
            data.timestamp,
            showNotes ? data.midiNote.toDouble() : data.frequency,
          ),
        )
        .toList();

    if (refSpots.isNotEmpty) {
      segments.add(refSpots);
    }

    return segments;
  }

  /// Vypočítá rozsah osy Y (min, max)
  ({double minY, double maxY}) calculateMinMaxY({
    required List<PitchData> pitchData,
    required List<PitchData>? referenceData,
    required double currentTime,
    required double timeWindow,
    required bool showNotes,
  }) {
    // Filtrujeme data pro výpočet rozsahu (poslední 2 sekundy)
    final recentData = pitchData
        .where((d) => d.timestamp >= currentTime - 2.0)
        .toList();

    final allRecentData = List<PitchData>.from(recentData);
    
    if (referenceData != null && referenceData.isNotEmpty) {
      final recentReference = referenceData
          .where((d) {
            // Zahrneme referenční data v relevantním okně
             return d.timestamp >= currentTime - 2.0 && d.timestamp <= currentTime + 1.0;
          })
          .toList();
      allRecentData.addAll(recentReference);
    }

    if (showNotes) {
      return _calculateMinMaxNotes(allRecentData);
    } else {
      return _calculateMinMaxFrequency(allRecentData);
    }
  }

  ({double minY, double maxY}) _calculateMinMaxNotes(List<PitchData> data) {
    final validMidiNotes = data
        .where((d) => d.isValid)
        .map((d) => d.midiNote.toDouble())
        .toList();

    if (validMidiNotes.isEmpty) {
      return (minY: 36.0, maxY: 84.0);
    }

    final minMidi = validMidiNotes.reduce((a, b) => a < b ? a : b);
    final maxMidi = validMidiNotes.reduce((a, b) => a > b ? a : b);

    final range = (maxMidi - minMidi).abs();
    final margin = range < 6 ? 3.0 : (range * 0.15).clamp(2.0, 6.0);

    double calculatedMinY = (minMidi - margin).clamp(36.0, 84.0);
    double calculatedMaxY = (maxMidi + margin).clamp(36.0, 84.0);

    if (calculatedMaxY - calculatedMinY < 6) {
      final center = (calculatedMinY + calculatedMaxY) / 2;
      calculatedMinY = (center - 3).clamp(36.0, 84.0);
      calculatedMaxY = (center + 3).clamp(36.0, 84.0);
    }

    return (minY: calculatedMinY, maxY: calculatedMaxY);
  }

  ({double minY, double maxY}) _calculateMinMaxFrequency(List<PitchData> data) {
    final frequencies = data
        .where((d) => d.isValid)
        .map((d) => d.frequency)
        .toList();

    if (frequencies.isEmpty) {
      return (minY: 65.0, maxY: 1047.0);
    }

    final minFreq = frequencies.reduce((a, b) => a < b ? a : b);
    final maxFreq = frequencies.reduce((a, b) => a > b ? a : b);

    final range = maxFreq - minFreq;
    final margin = range < 50 ? 50.0 : range * 0.1;

    double calculatedMinY = (minFreq - margin).clamp(65.0, 1047.0);
    double calculatedMaxY = (maxFreq + margin).clamp(65.0, 1047.0);

    if (calculatedMaxY - calculatedMinY < 100) {
      final center = (calculatedMinY + calculatedMaxY) / 2;
      calculatedMinY = (center - 50).clamp(65.0, 1047.0);
      calculatedMaxY = (center + 50).clamp(65.0, 1047.0);
    }

    return (minY: calculatedMinY, maxY: calculatedMaxY);
  }
}

