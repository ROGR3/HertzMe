import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/pitch_data.dart';
import '../services/pitch_analyzer.dart';

/// Widget pro zobrazení scrolling grafu pitchu v reálném čase
///
/// Graf zobrazuje:
/// - Osa Y: Noty (C2 až C6) nebo Hz (podle nastavení)
/// - Osa X: Čas (posledních 10 sekund)
/// - Plynulý pohyb grafu doprava při nových datech
class PitchChart extends StatefulWidget {
  /// Seznam PitchData pro zobrazení
  final List<PitchData> pitchData;

  /// Zobrazit noty místo Hz na ose Y
  final bool showNotes;

  /// Délka časového okna v sekundách
  final double timeWindow;

  const PitchChart({
    super.key,
    required this.pitchData,
    this.showNotes = true,
    this.timeWindow = 10.0,
  });

  @override
  State<PitchChart> createState() => _PitchChartState();
}

class _PitchChartState extends State<PitchChart> {
  final PitchAnalyzer _pitchAnalyzer = PitchAnalyzer();

  // Stabilizace rozsahu osy Y - vyhlazené hodnoty pro plynulejší změny
  double? _smoothedMinY;
  double? _smoothedMaxY;
  static const double _smoothingFactor =
      0.85; // Vyšší = stabilnější, ale pomalejší reakce

  // Threshold pro přerušení křivky - pokud není pitch detekován déle než tuto dobu, přerušíme křivku
  static const double _gapThreshold = 0.3; // sekundy

  @override
  Widget build(BuildContext context) {
    if (widget.pitchData.isEmpty) {
      return const Center(
        child: Text('Žádná data', style: TextStyle(color: Colors.grey)),
      );
    }

    // Filtrujeme data pouze z časového okna
    final currentTime = widget.pitchData.isNotEmpty
        ? widget.pitchData.last.timestamp
        : 0.0;
    final filteredData = widget.pitchData
        .where((data) => data.timestamp >= currentTime - widget.timeWindow)
        .toList();

    if (filteredData.isEmpty) {
      return const Center(
        child: Text('Čekám na data...', style: TextStyle(color: Colors.grey)),
      );
    }

    // Vytvoříme body pro graf s filtrováním mezer
    // Pokud mezi dvěma platnými body je mezera větší než threshold, rozdělíme na segmenty
    final allSpots = <FlSpot>[];
    final segments = <List<FlSpot>>[];
    double? lastValidTimestamp;

    for (final data in filteredData) {
      if (data.isValid) {
        final spot = FlSpot(
          data.timestamp,
          widget.showNotes ? data.midiNote.toDouble() : data.frequency,
        );

        // Pokud je mezera od posledního platného bodu větší než threshold, začneme nový segment
        if (lastValidTimestamp != null &&
            data.timestamp - lastValidTimestamp > _gapThreshold) {
          // Pokud máme nějaké body v aktuálním segmentu, uložíme ho
          if (allSpots.isNotEmpty) {
            segments.add(List.from(allSpots));
            allSpots.clear();
          }
        }

        // Přidáme bod do aktuálního segmentu
        allSpots.add(spot);
        lastValidTimestamp = data.timestamp;
      }
      // Neplatná data přeskočíme - tím se automaticky vytvoří mezera v křivce
    }

    // Přidáme poslední segment, pokud není prázdný
    if (allSpots.isNotEmpty) {
      segments.add(allSpots);
    }

    // Určíme rozsah osy Y s auto-centrováním
    // Použijeme pouze poslední 2 sekundy pro stabilnější výpočet (zabrání skákání)
    final recentData = filteredData
        .where((d) => d.timestamp >= currentTime - 2.0)
        .toList();

    double minY, maxY;

    if (widget.showNotes) {
      // Pro noty: auto-centrování na aktuální rozsah
      final validMidiNotes = recentData
          .where((d) => d.isValid)
          .map((d) => d.midiNote.toDouble())
          .toList();

      if (validMidiNotes.isEmpty) {
        // Pokud nemáme data, použijeme výchozí rozsah nebo vyhlazené hodnoty
        if (_smoothedMinY == null || _smoothedMaxY == null) {
          minY = 36.0;
          maxY = 84.0;
        } else {
          minY = _smoothedMinY!;
          maxY = _smoothedMaxY!;
        }
      } else {
        // Najdeme min/max MIDI noty z posledních 2 sekund
        final minMidi = validMidiNotes.reduce((a, b) => a < b ? a : b);
        final maxMidi = validMidiNotes.reduce((a, b) => a > b ? a : b);

        // Menší margin pro větší zoom (pouze 3 půltóny nahoru a dolů)
        final range = (maxMidi - minMidi).abs();
        // Pokud je rozsah malý, přidáme minimálně 6 půltónů celkem (3 nahoru, 3 dolů)
        final margin = range < 6 ? 3.0 : (range * 0.15).clamp(2.0, 6.0);

        double calculatedMinY = (minMidi - margin).clamp(36.0, 84.0);
        double calculatedMaxY = (maxMidi + margin).clamp(36.0, 84.0);

        // Zajistíme minimální rozsah (alespoň 6 půltónů)
        if (calculatedMaxY - calculatedMinY < 6) {
          final center = (calculatedMinY + calculatedMaxY) / 2;
          calculatedMinY = (center - 3).clamp(36.0, 84.0);
          calculatedMaxY = (center + 3).clamp(36.0, 84.0);
        }

        // Vyhlazení rozsahu pro stabilitu
        if (_smoothedMinY == null || _smoothedMaxY == null) {
          _smoothedMinY = calculatedMinY;
          _smoothedMaxY = calculatedMaxY;
        } else {
          _smoothedMinY =
              _smoothingFactor * _smoothedMinY! +
              (1 - _smoothingFactor) * calculatedMinY;
          _smoothedMaxY =
              _smoothingFactor * _smoothedMaxY! +
              (1 - _smoothingFactor) * calculatedMaxY;
        }

        minY = _smoothedMinY!;
        maxY = _smoothedMaxY!;
      }
    } else {
      // Pro Hz: auto-centrování na aktuální rozsah
      final frequencies = recentData
          .where((d) => d.isValid)
          .map((d) => d.frequency)
          .toList();

      if (frequencies.isEmpty) {
        // Pokud nemáme data, použijeme výchozí rozsah nebo vyhlazené hodnoty
        if (_smoothedMinY == null || _smoothedMaxY == null) {
          minY = 65.0; // C2
          maxY = 1047.0; // C6
        } else {
          minY = _smoothedMinY!;
          maxY = _smoothedMaxY!;
        }
      } else {
        // Najdeme min/max frekvence z posledních 2 sekund
        final minFreq = frequencies.reduce((a, b) => a < b ? a : b);
        final maxFreq = frequencies.reduce((a, b) => a > b ? a : b);

        // Menší margin pro větší zoom (pouze 10% nahoru a dolů, minimálně 50 Hz)
        final range = maxFreq - minFreq;
        final margin = range < 50 ? 50.0 : range * 0.1;

        double calculatedMinY = (minFreq - margin).clamp(65.0, 1047.0);
        double calculatedMaxY = (maxFreq + margin).clamp(65.0, 1047.0);

        // Zajistíme minimální rozsah (alespoň 100 Hz)
        if (calculatedMaxY - calculatedMinY < 100) {
          final center = (calculatedMinY + calculatedMaxY) / 2;
          calculatedMinY = (center - 50).clamp(65.0, 1047.0);
          calculatedMaxY = (center + 50).clamp(65.0, 1047.0);
        }

        // Vyhlazení rozsahu pro stabilitu
        if (_smoothedMinY == null || _smoothedMaxY == null) {
          _smoothedMinY = calculatedMinY;
          _smoothedMaxY = calculatedMaxY;
        } else {
          _smoothedMinY =
              _smoothingFactor * _smoothedMinY! +
              (1 - _smoothingFactor) * calculatedMinY;
          _smoothedMaxY =
              _smoothingFactor * _smoothedMaxY! +
              (1 - _smoothingFactor) * calculatedMaxY;
        }

        minY = _smoothedMinY!;
        maxY = _smoothedMaxY!;
      }
    }

    // Filtrujeme body, které jsou mimo rozsah osy Y
    final filteredSegments = segments
        .map((segmentSpots) {
          return segmentSpots.where((spot) {
            return spot.y >= minY && spot.y <= maxY;
          }).toList();
        })
        .where((segmentSpots) => segmentSpots.isNotEmpty)
        .toList();

    return LineChart(
      LineChartData(
        // Nastavení os
        minX: currentTime - widget.timeWindow,
        maxX: currentTime,
        minY: minY,
        maxY: maxY,

        // Styl grafu
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          // Pro noty zobrazujeme mřížku každý půltón (interval 1), pro Hz rozdělíme na 10 částí
          horizontalInterval: widget.showNotes ? 1.0 : (maxY - minY) / 10,
          getDrawingHorizontalLine: (value) {
            // Pro noty: silnější linky každou oktávu (každých 12 půltónů), slabší pro ostatní
            if (widget.showNotes) {
              final midiNote = value.round();
              final isOctave = (midiNote - 36) % 12 == 0;
              return FlLine(
                color: Colors.grey.withValues(alpha: isOctave ? 0.3 : 0.1),
                strokeWidth: isOctave ? 1.5 : 0.5,
              );
            } else {
              return FlLine(
                color: Colors.grey.withValues(alpha: 0.2),
                strokeWidth: 1,
              );
            }
          },
        ),

        // Popisky os
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 2.0,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '${value.toStringAsFixed(0)}s',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              // Pro noty zobrazujeme každou notu (interval 1), pro Hz rozdělíme na 8 částí
              interval: widget.showNotes ? 1.0 : (maxY - minY) / 8,
              getTitlesWidget: (value, meta) {
                if (widget.showNotes) {
                  // Pro noty: zobrazíme název noty
                  final midiNote = value.round();
                  if (midiNote >= 36 && midiNote <= 84) {
                    // Vypočítáme index noty v rozsahu (0-48 pro C2-C6)
                    final indexInRange = midiNote - 36;
                    final notes = _pitchAnalyzer.getNoteRange();
                    if (indexInRange >= 0 && indexInRange < notes.length) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          notes[indexInRange],
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }
                  }
                  return const Text('');
                } else {
                  // Pro Hz: zobrazíme frekvenci
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      value.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  );
                }
              },
            ),
          ),
        ),

        // Data grafu - každý segment má svůj vlastní LineChartBarData pro přerušení křivky
        // Použijeme filtrované segmenty (bez bodů mimo rozsah)
        lineBarsData: filteredSegments.map((segmentSpots) {
          return LineChartBarData(
            spots: segmentSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withValues(alpha: 0.1),
            ),
          );
        }).toList(),

        // Clipování grafu
        clipData: const FlClipData.all(),

        // Border
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
    );
  }
}
