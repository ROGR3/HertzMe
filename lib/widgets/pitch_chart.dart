import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants/app_constants.dart';
import '../models/pitch_data.dart';
import '../services/pitch_analyzer.dart';
import '../logic/pitch_chart_logic.dart';

/// Widget pro zobrazení scrolling grafu pitchu v reálném čase
///
/// Graf zobrazuje:
/// - Osa Y: Noty (C1 až C9) nebo Hz (podle nastavení)
/// - Osa X: Čas (nastavitelné okno, defaultně 20 sekund)
/// - Plynulý pohyb grafu doprava při nových datech
/// - Pokud je vybrána písnička: 1/3 historie, 2/3 budoucnost
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
    this.timeWindow = AppConstants.defaultTimeWindow,
  });

  @override
  State<PitchChart> createState() => _PitchChartState();
}

class _PitchChartState extends State<PitchChart> {
  static final PitchAnalyzer _pitchAnalyzer = PitchAnalyzer();
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

    // Určíme časové okno grafu
    // Pokud máme referenční data, zobrazíme 1/3 historie a 2/3 budoucnosti
    // Jinak zobrazíme pouze historii
    final bool hasReference =
        widget.referenceData != null && widget.referenceStartTime != null;
    final double pastWindow = hasReference
        ? widget.timeWindow / 3
        : widget.timeWindow;
    final double futureWindow = hasReference
        ? (widget.timeWindow * 2 / 3)
        : 0.0;

    // Příprava segmentů pro graf (upravené časové okno)
    final segments = _logic.prepareSegments(
      pitchData: widget.pitchData,
      currentTime: currentTime,
      timeWindow: pastWindow,
      showNotes: widget.showNotes,
    );

    // Příprava referenčních segmentů (upravené časové okno)
    List<List<FlSpot>> referenceSegments = [];
    if (widget.referenceData != null && widget.referenceStartTime != null) {
      referenceSegments = _logic.prepareReferenceSegmentsWithFuture(
        referenceData: widget.referenceData!,
        currentTime: currentTime,
        pastWindow: pastWindow,
        futureWindow: futureWindow,
        showNotes: widget.showNotes,
      );
    }

    // Výpočet rozsahu Y
    // Pevný rozsah pro chart
    const double fixedRange = AppConstants.fixedChartRange;

    // Pokud uživatel zatím neposunul graf, nastavíme výchozí pozici
    _userMinY ??= AppConstants.defaultMinY;

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
          isCurved: false,
          color: AppConstants.successColor,
          barWidth: AppConstants.referencePitchLineWidth,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          dashArray: const [8, 4],
        ),
      );
    }

    // Přidáme aktuální křivku (modrá, plná)
    for (final segment in segments) {
      allLineBarsData.add(
        LineChartBarData(
          spots: segment,
          isCurved: false,
          color: AppConstants.primaryAccent,
          barWidth: AppConstants.userPitchLineWidth,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppConstants.primaryAccent.withValues(
              alpha: AppConstants.userPitchAreaAlpha,
            ),
          ),
        ),
      );
    }

    // Zajistíme konzistentní velikost okna - vždy zobrazíme plný rozsah
    // Bez ohledu na to, zda je currentTime malé
    final minX = currentTime - pastWindow;
    final maxX = currentTime + futureWindow;

    // Vytvoříme extra čáry pro zobrazení "teď" (pokud máme referenční data)
    final extraLinesHorizontal = <HorizontalLine>[];
    final extraLinesVertical = hasReference
        ? [
            VerticalLine(
              x: currentTime,
              color: AppConstants.currentTimeIndicatorColor.withValues(
                alpha: AppConstants.timeIndicatorAlpha,
              ),
              strokeWidth: AppConstants.userPitchLineWidth,
              dashArray: const [5, 5],
            ),
          ]
        : <VerticalLine>[];

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (!widget.showNotes) return;

        setState(() {
          // Citlivost posunu - čím menší číslo, tím pomalejší posun
          // Invertujeme směr (táhnutí dolů = posun grafu nahoru, abychom viděli nižší noty)
          final delta =
              details.primaryDelta! * AppConstants.chartDragSensitivity;

          _userMinY = (_userMinY! + delta).clamp(
            AppConstants.minChartMidi,
            AppConstants.maxChartMidi,
          );
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
            horizontalInterval: widget.showNotes
                ? AppConstants.chartNoteInterval
                : (maxY - minY) / AppConstants.chartHzDivisions,
            getDrawingHorizontalLine: (value) {
              if (widget.showNotes) {
                final midiNote = value.round();
                final isOctave =
                    (midiNote - 36) % AppConstants.semitonesPerOctave == 0;
                return FlLine(
                  color: AppConstants.chartGridMajor.withValues(
                    alpha: isOctave
                        ? AppConstants.chartGridMajorAlpha
                        : AppConstants.chartGridMinorAlpha,
                  ),
                  strokeWidth: isOctave
                      ? AppConstants.gridMajorLineWidth
                      : AppConstants.gridMinorLineWidth,
                );
              } else {
                return FlLine(
                  color: AppConstants.chartGridMajor.withValues(
                    alpha: AppConstants.chartGridHzAlpha,
                  ),
                  strokeWidth: AppConstants.gridMinorLineWidth,
                );
              }
            },
          ),

          // Extra čáry
          extraLinesData: ExtraLinesData(
            verticalLines: extraLinesVertical,
            horizontalLines: extraLinesHorizontal,
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
                reservedSize: AppConstants.chartBottomTitlesHeight,
                interval: AppConstants.chartTimeLabelInterval,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      top: AppConstants.smallPadding,
                    ),
                    child: Text(
                      '${value.toStringAsFixed(0)}s',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: AppConstants.chartLabelFontSize,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: AppConstants.chartLeftTitlesWidth,
                interval: widget.showNotes
                    ? AppConstants.chartNoteInterval
                    : (maxY - minY) / AppConstants.chartHzTitleDivisions,
                getTitlesWidget: (value, meta) {
                  if (widget.showNotes) {
                    final midiNote = value.round();
                    if (midiNote >= AppConstants.baseMidiNote &&
                        midiNote <= 120) {
                      final indexInRange = midiNote - AppConstants.baseMidiNote;
                      final notes = _pitchAnalyzer.getNoteRange();
                      if (indexInRange >= 0 && indexInRange < notes.length) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            right: AppConstants.smallPadding,
                          ),
                          child: Text(
                            notes[indexInRange],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: AppConstants.chartLabelFontSize,
                            ),
                          ),
                        );
                      }
                    }
                    return const Text('');
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(
                        right: AppConstants.smallPadding,
                      ),
                      child: Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: AppConstants.chartLabelFontSize,
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
              color: AppConstants.chartGridMajor.withValues(
                alpha: AppConstants.chartBorderAlpha,
              ),
              width: AppConstants.chartBorderWidth,
            ),
          ),
        ),
      ),
    );
  }
}
