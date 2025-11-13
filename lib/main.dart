import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/pitch_data.dart';
import 'services/audio_service.dart';
import 'widgets/pitch_chart.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Nastavíme orientaci pouze na portrétní (pro Android)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const VocalPitchMonitorApp());
}

/// Hlavní aplikace - Vocal Pitch Monitor
class VocalPitchMonitorApp extends StatelessWidget {
  const VocalPitchMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocal Pitch Monitor',
      debugShowCheckedModeBanner: false,
      // Tmavé téma podobné Vocal Pitch Monitor
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          surface: Color(0xFF2A2A2A),
          onSurface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const PitchMonitorPage(),
    );
  }
}

/// Hlavní stránka s pitch monitorem
class PitchMonitorPage extends StatefulWidget {
  const PitchMonitorPage({super.key});

  @override
  State<PitchMonitorPage> createState() => _PitchMonitorPageState();
}

class _PitchMonitorPageState extends State<PitchMonitorPage> {
  final AudioService _audioService = AudioService();

  // Seznam PitchData pro graf (posledních 10 sekund)
  final List<PitchData> _pitchHistory = [];

  // Aktuální PitchData pro textové zobrazení
  PitchData? _currentPitch;

  // Stav aplikace
  bool _isRecording = false;
  String _status = 'Připraveno k nahrávání';

  // Nastavení
  bool _showNotes = true; // Zobrazit noty místo Hz
  final double _smoothingFactor =
      0.7; // Faktor vyhlazení (0.0 = žádné, 1.0 = maximální)

  // Vyhlazená hodnota pro snížení vibrací
  double? _smoothedFrequency;

  StreamSubscription<PitchData>? _pitchSubscription;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _pitchSubscription?.cancel();
    _updateTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  /// Zkontroluje oprávnění k mikrofonu
  Future<void> _checkPermission() async {
    final hasPermission = await _audioService.hasPermission();
    if (!hasPermission && mounted) {
      setState(() {
        _status = 'Oprávnění k mikrofonu zamítnuto';
      });
    }
  }

  /// Spustí/zastaví nahrávání
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  /// Spustí nahrávání a analýzu
  Future<void> _startRecording() async {
    try {
      await _audioService.startRecording();

      // Přihlásíme se k streamu pitch dat
      _pitchSubscription = _audioService.pitchStream.listen(
        _onPitchData,
        onError: (error) {
          if (mounted) {
            setState(() {
              _status = 'Chyba: $error';
              _isRecording = false;
            });
          }
        },
      );

      // Spustíme timer pro pravidelné aktualizace UI (30x za sekundu)
      _updateTimer = Timer.periodic(
        const Duration(milliseconds: 33), // ~30 FPS
        (_) {
          if (mounted) {
            setState(() {
              // Odstraníme stará data mimo časové okno (10 sekund)
              final currentTime = _pitchHistory.isNotEmpty
                  ? _pitchHistory.last.timestamp
                  : 0.0;
              _pitchHistory.removeWhere(
                (data) => data.timestamp < currentTime - 10.0,
              );
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _status = 'Nahrávání...';
          _pitchHistory.clear();
          _currentPitch = null;
          _smoothedFrequency = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Chyba při spuštění: $e';
        });
      }
    }
  }

  /// Zastaví nahrávání
  Future<void> _stopRecording() async {
    await _pitchSubscription?.cancel();
    _pitchSubscription = null;

    _updateTimer?.cancel();
    _updateTimer = null;

    await _audioService.stopRecording();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _status = 'Nahrávání zastaveno';
      });
    }
  }

  /// Zpracuje nová pitch data ze streamu
  void _onPitchData(PitchData pitchData) {
    if (!mounted) return;

    // Vyhlazení frekvence pro snížení vibrací
    if (pitchData.isValid) {
      if (_smoothedFrequency == null) {
        _smoothedFrequency = pitchData.frequency;
      } else {
        // Exponenciální vyhlazení
        _smoothedFrequency =
            _smoothingFactor * _smoothedFrequency! +
            (1 - _smoothingFactor) * pitchData.frequency;
      }

      // Vytvoříme nové PitchData s vyhlazenou frekvencí
      final smoothedPitchData = PitchData(
        frequency: _smoothedFrequency!,
        note: pitchData.note,
        timestamp: pitchData.timestamp,
        midiNote: pitchData.midiNote,
        cents: pitchData.cents,
      );

      setState(() {
        _currentPitch = smoothedPitchData;
        _pitchHistory.add(smoothedPitchData);
      });
    } else {
      // Pokud není detekován žádný tón, použijeme původní data
      setState(() {
        _currentPitch = pitchData;
        _pitchHistory.add(pitchData);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text(
          'Vocal Pitch Monitor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
        actions: [
          // Přepínač mezi notami a Hz
          IconButton(
            icon: Icon(_showNotes ? Icons.music_note : Icons.waves),
            tooltip: _showNotes ? 'Zobrazit Hz' : 'Zobrazit noty',
            onPressed: () {
              setState(() {
                _showNotes = !_showNotes;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Horní část: Textové zobrazení aktuálního tónu
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              color: const Color(0xFF2A2A2A),
              child: Column(
                children: [
                  // Hlavní zobrazení noty
                  Text(
                    _currentPitch?.note ?? '-',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Zobrazení frekvence
                  Text(
                    _currentPitch?.isValid == true
                        ? '${_currentPitch!.frequency.toStringAsFixed(1)} Hz'
                        : '- Hz',
                    style: TextStyle(fontSize: 24, color: Colors.grey[400]),
                  ),
                  // Cent odchylka (pokud je detekován tón)
                  if (_currentPitch?.isValid == true &&
                      _currentPitch!.cents.abs() > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${_currentPitch!.cents > 0 ? '+' : ''}${_currentPitch!.cents.toStringAsFixed(0)} cent',
                        style: TextStyle(
                          fontSize: 14,
                          color: _currentPitch!.cents.abs() > 20
                              ? Colors.red[300]
                              : Colors.orange[300],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Střední část: Graf
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: PitchChart(
                  pitchData: _pitchHistory,
                  showNotes: _showNotes,
                  timeWindow: 10.0,
                ),
              ),
            ),

            // Spodní část: Status a ovládací tlačítko
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              color: const Color(0xFF2A2A2A),
              child: Column(
                children: [
                  // Status text
                  Text(
                    _status,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 16),
                  // Tlačítko pro spuštění/zastavení
                  ElevatedButton.icon(
                    onPressed: _toggleRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 28),
                    label: Text(
                      _isRecording ? 'Zastavit' : 'Spustit',
                      style: const TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
