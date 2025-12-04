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
  runApp(const HertzMeApp());
}

/// Hlavní aplikace - HertzMe
class HertzMeApp extends StatelessWidget {
  const HertzMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HertzMe',
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
              // Odstraníme stará data mimo časové okno (20 sekund)
              final currentTime = _pitchHistory.isNotEmpty
                  ? _pitchHistory.last.timestamp
                  : 0.0;
              _pitchHistory.removeWhere(
                (data) => data.timestamp < currentTime - 20.0,
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
              'HertzMe',
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
        child: Stack(
          children: [
            // 1. Graf na pozadí (téměř přes celou obrazovku)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF1A1A1A), // Tmavé pozadí
                child: PitchChart(
                  pitchData: _pitchHistory,
                  referenceData: _selectedSong?.getPitchDataSequence(),
                  referenceStartTime: _songStartTime,
                  showNotes: _showNotes,
                  timeWindow: 20.0, // Pomalejší scrollování
                ),
              ),
            ),

            // 2. Horní overlay - Informace o tónu
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 24.0,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    if (_referencePitch != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Referenční nota
                          Column(
                            children: [
                              Text(
                                'Cíl',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _referencePitch!.note,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          // Aktuální nota
                          Column(
                            children: [
                              Text(
                                'Ty',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _currentPitch?.note ?? '-',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: _currentPitch?.isValid == true
                                      ? (_isPitchMatch(
                                              _currentPitch!,
                                              _referencePitch!,
                                            )
                                            ? Colors.green
                                            : Colors.red)
                                      : Colors.blue,
                                ),
                              ),
                              // Zobrazíme centy jen decentně pod notou
                              if (_currentPitch?.isValid == true &&
                                  _currentPitch!.cents.abs() > 1)
                                Text(
                                  '${_currentPitch!.cents > 0 ? '+' : ''}${_currentPitch!.cents.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _currentPitch!.cents.abs() > 20
                                        ? Colors.red[300]
                                        : Colors.orange[300],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      )
                    else
                      // Jen aktuální nota (pokud není reference)
                      Column(
                        children: [
                          Text(
                            _currentPitch?.note ?? '-',
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          if (_currentPitch?.isValid == true)
                            Text(
                              '${_currentPitch!.frequency.toStringAsFixed(1)} Hz',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // 3. Spodní overlay - Ovládání
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_status.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _status,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    // Tlačítka
                    if (_selectedSong != null && !_isRecording)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FloatingActionButton.extended(
                            heroTag: 'play',
                            onPressed: _playBeginning,
                            backgroundColor: Colors.green,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Přehrát'),
                          ),
                          const SizedBox(width: 16),
                          FloatingActionButton.extended(
                            heroTag: 'rec',
                            onPressed: _startSinging,
                            backgroundColor: Colors.blue,
                            icon: const Icon(Icons.mic),
                            label: const Text('Zpívat'),
                          ),
                        ],
                      )
                    else if (_selectedSong != null && _isRecording)
                      FloatingActionButton.extended(
                        onPressed: _stopRecording,
                        backgroundColor: Colors.red,
                        icon: const Icon(Icons.stop),
                        label: const Text('Zastavit'),
                      )
                    else
                      FloatingActionButton.extended(
                        onPressed: _toggleRecording,
                        backgroundColor: _isRecording
                            ? Colors.red
                            : Colors.blue,
                        icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                        label: Text(_isRecording ? 'Zastavit' : 'Start'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
