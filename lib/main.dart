import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/app_theme.dart';
import 'constants/app_constants.dart';
import 'models/pitch_data.dart';
import 'models/song.dart';
import 'services/audio_service.dart';
import 'services/tone_player.dart';
import 'widgets/pitch_chart.dart';
import 'widgets/pitch_display.dart';
import 'widgets/recording_controls.dart';
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
      theme: AppTheme.darkTheme,
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

    // Přehráváme celou písničku (ne jen 10 sekund)
    await _tonePlayer.playReferenceTones(
      _selectedSong!,
      maxDuration: _selectedSong!.duration,
    );
  }

  /// Spustí nahrávání a zároveň přehrává referenční tóny
  Future<void> _startSingWithMusic() async {
    if (_selectedSong == null) return;

    try {
      // Spustíme nahrávání s AEC (Acoustic Echo Cancellation)
      await _audioService.startRecordingWithAEC();

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

      // Spustíme timer pro pravidelné aktualizace UI
      _updateTimer = Timer.periodic(
        const Duration(milliseconds: AppConstants.uiUpdateRate),
        (_) {
          if (mounted) {
            setState(() {
              // Odstraníme stará data mimo časové okno
              final currentTime = _pitchHistory.isNotEmpty
                  ? _pitchHistory.last.timestamp
                  : 0.0;
              _pitchHistory.removeWhere(
                (data) =>
                    data.timestamp <
                    currentTime - AppConstants.defaultTimeWindow,
              );
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _status = 'Zpívání s hudbou...';
          _pitchHistory.clear();
          _currentPitch = null;
          _smoothedFrequency = null;
        });
      }

      // Počkáme chvíli, než se mikrofon stabilizuje před spuštěním přehrávání
      await Future.delayed(const Duration(milliseconds: 200));

      // Nastavíme čas začátku písničky TEPRVE TEĎKA (po delay), aby byl synchronizovaný s přehrávacím startem
      if (mounted) {
        setState(() {
          _songStartTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
        });
      }

      // Nyní spustíme přehrávání referenčních tónů
      // Použijeme délku písničky místo hardcoded limitu
      if (_isRecording) {
        _tonePlayer.playReferenceTones(
          _selectedSong!,
          maxDuration: _selectedSong!.duration,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Chyba při spuštění: $e';
        });
      }
    }
  }

  /// Přepne mezi nahrávání a zastavením
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

      // Spustíme timer pro pravidelné aktualizace UI
      _updateTimer = Timer.periodic(
        const Duration(milliseconds: AppConstants.uiUpdateRate),
        (_) {
          if (mounted) {
            setState(() {
              // Odstraníme stará data mimo časové okno
              final currentTime = _pitchHistory.isNotEmpty
                  ? _pitchHistory.last.timestamp
                  : 0.0;
              _pitchHistory.removeWhere(
                (data) =>
                    data.timestamp <
                    currentTime - AppConstants.defaultTimeWindow,
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
            AppConstants.pitchSmoothingFactor * _smoothedFrequency! +
            (1 - AppConstants.pitchSmoothingFactor) * pitchData.frequency;
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
      backgroundColor: AppConstants.primaryBackground,
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
                  fontSize: AppConstants.labelFontSize,
                  color: Colors.green[300],
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: AppConstants.secondaryBackground,
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
              // Capture context before async operations
              final navigator = Navigator.of(context);

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
              if (!mounted) return;
              navigator.push(
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
                color: AppConstants.primaryBackground,
                child: PitchChart(
                  pitchData: _pitchHistory,
                  referenceData: _selectedSong?.getPitchDataSequence(),
                  referenceStartTime: _songStartTime,
                  showNotes: _showNotes,
                  timeWindow: AppConstants.defaultTimeWindow,
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
                  vertical: AppConstants.standardPadding,
                  horizontal: AppConstants.largePadding,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.topOverlayGradient(),
                ),
                child: PitchDisplay(
                  currentPitch: _currentPitch,
                  referencePitch: _referencePitch,
                ),
              ),
            ),

            // 3. Spodní overlay - Ovládání
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(AppConstants.largePadding),
                decoration: BoxDecoration(
                  gradient: AppTheme.bottomOverlayGradient(),
                ),
                child: RecordingControls(
                  isRecording: _isRecording,
                  selectedSong: _selectedSong,
                  onToggleRecording: _toggleRecording,
                  onPlayReference: _playBeginning,
                  onSingWithMusic: _startSingWithMusic,
                  status: _status,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
