import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/pitch_data.dart';
import '../services/pitch_analyzer.dart';
import '../logic/pitch_chart_logic.dart';

/// Widget pro zobrazení scrolling grafu pitchu v reálném čase
///
/// Graf zobrazuje:
/// - Osa Y: Noty (C2 až C6) nebo Hz (podle nastavení)
/// - Osa X: Čas (posledních 10 sekund)
/// - Plynulý pohyb grafu doprava při nových datech
class PitchChart extends StatefulWidget {
  /// Seznam PitchData pro zobrazení (aktuální zpěv uživatele)
  final List<PitchData> pitchData;

  /// Referenční data (písnička) pro zobrazení jako vodítko
  final List<PitchData>? referenceData;

  /// Časový offset pro referenční data (kdy začíná písnička)
  final double? referenceStartTime;

  /// Zobrazit noty místo Hz na ose Y
  final bool showNotes;

  /// Délka časového okna v sekundách
  final double timeWindow;

  const PitchChart({
    super.key,
    required this.pitchData,
    this.referenceData,
    this.referenceStartTime,
    this.showNotes = true,
    this.timeWindow = 10.0,
  });

  @override
  State<PitchChart> createState() => _PitchChartState();
}

class _PitchChartState extends State<PitchChart> {
  final PitchAnalyzer _pitchAnalyzer = PitchAnalyzer();
  final PitchChartLogic _logic = PitchChartLogic();
  double? _userMinY; // Uložená pozice pro manuální posun

  @override
  Widget build(BuildContext context) {
    // Určíme aktuální čas - pokud máme data, použijeme poslední timestamp,
    // jinak použijeme aktuální čas pro zobrazení referenční křivky
    double currentTime;
    if (widget.pitchData.isNotEmpty) {
      currentTime = widget.pitchData.last.timestamp;
    } else if (widget.referenceStartTime != null) {
      // Pokud nemáme aktuální data, ale máme referenční, použijeme čas od začátku referenčních dat
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch / 1000.0) -
          widget.referenceStartTime!;
      currentTime = elapsed;
    } else {
      // Pokud nemáme vůbec žádná data, použijeme 0
      currentTime = 0.0;
    }

    // Pokud nemáme žádná data a ani referenční, zobrazíme prázdný stav
    if (widget.pitchData.isEmpty &&
        (widget.referenceData == null || widget.referenceStartTime == null)) {
      return const Center(
        child: Text('Žádná data', style: TextStyle(color: Colors.grey)),
      );
    }

    // Příprava segmentů pro graf
    final segments = _logic.prepareSegments(
      pitchData: widget.pitchData,
      currentTime: currentTime,
      timeWindow: widget.timeWindow,
      showNotes: widget.showNotes,
    );

    // Příprava referenčních segmentů
    List<List<FlSpot>> referenceSegments = [];
    if (widget.referenceData != null && widget.referenceStartTime != null) {
      referenceSegments = _logic.prepareReferenceSegments(
        referenceData: widget.referenceData!,
        currentTime: currentTime,
        timeWindow: widget.timeWindow,
        showNotes: widget.showNotes,
      );
    }

    // Výpočet rozsahu Y
    // Pevný rozsah cca C3 (48) až C6 (84) = 36 půltónů (3 oktávy)
    const double fixedRange = 36.0;

    // Pokud uživatel zatím neposunul graf, nastavíme výchozí pozici
    // C3 (MIDI 48) jako spodní hranice
    if (_userMinY == null) {
      _userMinY = 48.0;
    }

    double minY = _userMinY!;
    double maxY = minY + fixedRange;

    // Pokud nezobrazujeme noty (Hz), musíme přepočítat rozsah
    if (!widget.showNotes) {
      // TODO: Implementovat přepočet pro Hz pokud bude potřeba
      // Pro teď použijeme logiku z minula nebo default
      final minMaxY = _logic.calculateMinMaxY(
        pitchData: widget.pitchData,
        referenceData: widget.referenceData,
        currentTime: currentTime,
        timeWindow: widget.timeWindow,
        showNotes: widget.showNotes,
      );
      minY = minMaxY.minY;
      maxY = minMaxY.maxY;
    }

    // Vytvoříme seznam všech lineBarsData (nejprve referenční, pak aktuální)
    final allLineBarsData = <LineChartBarData>[];

    // Přidáme referenční křivku (zelená, přerušovaná)
    for (final refSegment in referenceSegments) {
      allLineBarsData.add(
        LineChartBarData(
          spots: refSegment,
          isCurved: false, // Vypnuto vyhlazování křivky
          color: Colors.green, // Jasnější zelená barva
          barWidth: 3, // Silnější čára pro lepší viditelnost
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          dashArray: [8, 4], // Přerušovaná čára (delší čárky)
        ),
      );
    }

    // Přidáme aktuální křivku (modrá, plná)
    for (final segment in segments) {
      allLineBarsData.add(
        LineChartBarData(
          spots: segment,
          isCurved: false, // Vypnuto vyhlazování křivky
          color: Colors.blue,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blue.withValues(alpha: 0.1),
          ),
        ),
      );
    }

    // Zajistíme, že minX není záporné, pokud currentTime je malé
    final minX = (currentTime - widget.timeWindow).clamp(0.0, currentTime);
    final maxX = currentTime.clamp(0.0, double.infinity);

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (!widget.showNotes) return;

        setState(() {
          // Citlivost posunu - čím menší číslo, tím pomalejší posun
          // Invertujeme směr (táhnutí dolů = posun grafu nahoru, abychom viděli nižší noty)
          final delta = details.primaryDelta! * 0.1;

          _userMinY = (_userMinY! + delta).clamp(
            24.0,
            108.0,
          ); // C1 (24) až C8 (108)
        });
      },
      child: LineChart(
        duration: Duration
            .zero, // Vypneme animace pro plynulý posun bez "interpolace"
        LineChartData(
          // Nastavení os
          minX: minX,
          maxX: maxX,
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
                    // Rozsah se nyní dynamicky mění, takže musíme podporovat všechny noty
                    // C1 = 24, C9 = 120
                    if (midiNote >= 24 && midiNote <= 120) {
                      // Vypočítáme index noty v rozsahu (0-96 pro C1-C9)
                      // C1 (24) je index 0 v getNoteRange()
                      final indexInRange = midiNote - 24;
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
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),

          // Data grafu - obsahuje referenční křivku (zelená) a aktuální křivku (modrá)
          lineBarsData: allLineBarsData,

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
      ),
    );
  }
}
