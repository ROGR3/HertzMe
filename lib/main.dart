import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/pitch_data.dart';
import 'models/song.dart';
import 'services/audio_service.dart';
import 'services/tone_player.dart';
import 'widgets/pitch_chart.dart';
import 'widgets/song_selection_page.dart';

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
  final TonePlayer _tonePlayer = TonePlayer();

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

  // Cvičení s písničkou
  Song? _selectedSong;
  double? _songStartTime; // Čas kdy začala písnička (absolutní čas)

  // Získá referenční notu pro aktuální čas
  PitchData? get _referencePitch {
    if (_selectedSong == null || _songStartTime == null || !_isRecording) {
      return null;
    }
    final currentTime = _pitchHistory.isNotEmpty
        ? _pitchHistory.last.timestamp
        : ((DateTime.now().millisecondsSinceEpoch / 1000.0) - _songStartTime!);
    return _selectedSong!.getPitchAtTime(currentTime);
  }

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
    _tonePlayer.dispose();
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

  /// Přehrává začátek písničky (bez nahrávání)
  Future<void> _playBeginning() async {
    if (_selectedSong == null) return;

    // Zastavíme případné přehrávání
    await _tonePlayer.stop();

    // Přehráváme referenční tóny po dobu 10 sekund
    await _tonePlayer.playReferenceTones(_selectedSong!, maxDuration: 10.0);
  }

  /// Spustí nahrávání s přehráváním písničky od začátku
  Future<void> _startSinging() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  /// Spustí/zastaví nahrávání (pouze pro volný zpěv bez písničky)
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
              // Pokud máme referenční křivku, vynutíme aktualizaci grafu
              // (setState() už je voláno, takže graf se aktualizuje)
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
          // Pokud máme vybranou písničku, nastavíme čas začátku (bez přehrávání hudby)
          if (_selectedSong != null) {
            _songStartTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
          }
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

    // Zastavíme přehrávání referenčních tónů
    await _tonePlayer.stop();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _status = 'Nahrávání zastaveno';
        _songStartTime = null; // Resetujeme čas začátku písničky
      });
    }
  }

  /// Zkontroluje, zda se aktuální pitch shoduje s referenčním
  bool _isPitchMatch(PitchData current, PitchData reference) {
    // Považujeme za shodu, pokud je rozdíl menší než 50 centů (půltón)
    final midiDiff = (current.midiNote - reference.midiNote).abs();
    if (midiDiff == 0) {
      // Stejná nota, zkontrolujeme centy
      return current.cents.abs() < 50;
    }
    return false;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vocal Pitch Monitor',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_selectedSong != null)
              Text(
                _selectedSong!.name,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[300],
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
        actions: [
          // Tlačítko pro výběr písničky
          IconButton(
            icon: Icon(
              _selectedSong != null ? Icons.queue_music : Icons.playlist_add,
              color: _selectedSong != null ? Colors.green : null,
            ),
            tooltip: _selectedSong != null
                ? 'Změnit písničku'
                : 'Vybrat písničku',
            onPressed: () async {
              // Pokud běží nahrávání, zastavíme ho
              if (_isRecording) {
                await _stopRecording();
              }

              // Zastavíme případné přehrávání
              await _tonePlayer.stop();

              // Resetujeme graf a data
              if (mounted) {
                setState(() {
                  _pitchHistory.clear();
                  _currentPitch = null;
                  _smoothedFrequency = null;
                  _songStartTime = null;
                });
              }

              // Otevřeme výběr písničky
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SongSelectionPage(
                    onSongSelected: (song) {
                      if (mounted) {
                        setState(() {
                          _selectedSong = song;
                          _songStartTime = null;
                          // Zastavíme případné přehrávání
                          _tonePlayer.stop();
                        });
                      }
                    },
                  ),
                ),
              );
            },
          ),
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
                  // Pokud máme referenční písničku, zobrazíme referenční notu vlevo a aktuální vpravo
                  if (_referencePitch != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Referenční nota (vlevo)
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Mělo by být',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _referencePitch!.note,
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Aktuální nota (uprostřed/vpravo)
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Zpívám',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentPitch?.note ?? '-',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _currentPitch?.isValid == true &&
                                          _referencePitch != null
                                      ? (_isPitchMatch(
                                              _currentPitch!,
                                              _referencePitch!,
                                            )
                                            ? Colors.green
                                            : Colors.red)
                                      : Colors.blue,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    // Klasické zobrazení bez referenční noty
                    Column(
                      children: [
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
                        Text(
                          _currentPitch?.isValid == true
                              ? '${_currentPitch!.frequency.toStringAsFixed(1)} Hz'
                              : '- Hz',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // Zobrazení frekvence (pokud není referenční písnička)
                  if (_referencePitch == null)
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
                  referenceData: _selectedSong?.getPitchDataSequence(),
                  referenceStartTime: _songStartTime,
                  showNotes: _showNotes,
                  timeWindow: 10.0,
                ),
              ),
            ),

            // Spodní část: Status a ovládací tlačítka
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
                  // Pokud máme vybranou písničku, zobrazíme dvě tlačítka
                  if (_selectedSong != null && !_isRecording)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Tlačítko pro přehrání začátku
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: _playBeginning,
                              icon: const Icon(Icons.play_arrow, size: 24),
                              label: const Text(
                                'Přehrát začátek',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Tlačítko pro spuštění zpívání
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: _startSinging,
                              icon: const Icon(Icons.mic, size: 24),
                              label: const Text(
                                'Začít zpívat',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (_selectedSong != null && _isRecording)
                    // Při nahrávání zobrazíme pouze tlačítko pro zastavení
                    ElevatedButton.icon(
                      onPressed: _stopRecording,
                      icon: const Icon(Icons.stop, size: 28),
                      label: const Text(
                        'Zastavit',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    )
                  else
                    // Bez písničky - klasické tlačítko
                    ElevatedButton.icon(
                      onPressed: _toggleRecording,
                      icon: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        size: 28,
                      ),
                      label: Text(
                        _isRecording ? 'Zastavit' : 'Spustit',
                        style: const TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording
                            ? Colors.red
                            : Colors.blue,
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
