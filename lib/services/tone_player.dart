import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import '../constants/app_constants.dart';
import '../models/song.dart';

/// Služba pro přehrávání referenčních tónů z písničky
class TonePlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _playbackTimer;
  List<SongNote>? _currentSongNotes;
  int _currentNoteIndex = 0;
  double _startTime = 0.0;
  bool _isPlaying = false;

  TonePlayer() {
    // Nastavíme audio kontext pro umožnění současného nahrávání a přehrávání
    _configureAudioPlayer();
  }

  /// Konfiguruje audio player pro současné nahrávání a přehrávání
  void _configureAudioPlayer() {
    // Nastavíme audio context tak, aby umožňoval mix s ostatními audio zdroji (mikrofonem)
    _audioPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true, // Použijeme hlasitý reproduktor pro sing-along
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.voiceCommunication, // Změněno pro lepší podporu mikrofonu
          audioFocus: AndroidAudioFocus.gainTransientMayDuck, // Umožní snížení hlasitosti
        ),
      ),
    );
    
    // Nastavíme nízkou hlasitost
    _audioPlayer.setVolume(0.5);
  }

  /// Přehrává referenční tóny z písničky po dobu maxDuration sekund
  Future<void> playReferenceTones(
    Song song, {
    double maxDuration = 10.0,
  }) async {
    if (_isPlaying) {
      await stop();
    }

    _currentSongNotes = song.notes;
    _currentNoteIndex = 0;
    _startTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
    _isPlaying = true;

    // Přehráváme tóny sekvenčně
    _playNextTone(maxDuration);
  }

  /// Přehrává další tón v sekvenci
  void _playNextTone(double maxDuration) {
    if (!_isPlaying || _currentSongNotes == null) return;

    final elapsed =
        (DateTime.now().millisecondsSinceEpoch / 1000.0) - _startTime;
    if (elapsed >= maxDuration) {
      stop();
      return;
    }

    if (_currentNoteIndex >= _currentSongNotes!.length) {
      stop();
      return;
    }

    final note = _currentSongNotes![_currentNoteIndex];
    
    // Počkáme, dokud nedosáhneme časové značky této noty
    final targetTime = note.timestamp;
    final timeUntilNote = targetTime - elapsed;
    
    if (timeUntilNote > 0.01) {
      // Pokud ještě není čas na tuto notu, počkáme
      Future.delayed(
        Duration(milliseconds: (timeUntilNote * 1000).round()),
        () {
          if (_isPlaying) {
            _playNextTone(maxDuration);
          }
        },
      );
      return;
    }

    // Nyní je čas přehrát tuto notu
    final noteDuration = _currentNoteIndex < _currentSongNotes!.length - 1
        ? (_currentSongNotes![_currentNoteIndex + 1].timestamp - note.timestamp)
        : 0.5; // Poslední nota trvá 0.5 sekundy

    // Zajistíme, že nepřekročíme maxDuration
    final remainingTime = maxDuration - elapsed;
    final actualDuration = min(noteDuration, remainingTime);

    if (actualDuration <= 0) {
      stop();
      return;
    }

    // Vygenerujeme a přehrajeme tón (neblokující)
    _playTone(note.frequency, actualDuration);
    
    // Okamžitě přejdeme na další notu (bez čekání na dokončení přehrávání)
    _currentNoteIndex++;
    
    // Naplánujeme další notu
    if (_isPlaying) {
      // Malé zpoždění pro kontrolu timingu
      Future.delayed(
        const Duration(milliseconds: 10),
        () {
          _playNextTone(maxDuration);
        },
      );
    }
  }

  /// Přehrává tón dané frekvence po dobu duration sekund
  Future<void> _playTone(double frequency, double duration) async {
    if (!_isPlaying) return;

    // Generujeme PCM audio data pro sinusovou vlnu
    const sampleRate = AppConstants.referenceSampleRate;
    final numSamples = (duration * sampleRate).round();
    final samples = Float32List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Sinusová vlna s envelope pro plynulejší začátek a konec
      final envelope = _getEnvelope(i, numSamples);
      samples[i] =
          sin(2 * pi * frequency * t) * envelope * AppConstants.toneVolume;
    }

    // Konvertujeme Float32 na Int16 PCM
    final pcmData = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      pcmData[i] = (samples[i] * 32767).round().clamp(-32768, 32767);
    }

    // Konvertujeme Int16 na Uint8List (little-endian)
    final bytes = Uint8List(numSamples * 2);
    final byteData = ByteData.sublistView(bytes);
    for (int i = 0; i < numSamples; i++) {
      byteData.setInt16(i * 2, pcmData[i], Endian.little);
    }

    // Přehráváme pomocí AudioPlayer s WAV daty
    try {
      // Vytvoříme dočasný WAV soubor v paměti
      final wavData = _createWavFile(bytes, sampleRate);

      // Použijeme playBytesSource pro přehrávání z paměti
      await _audioPlayer.play(BytesSource(wavData));

      // Počkáme na dokončení přehrávání
      // Použijeme jednoduchý delay, protože onPlayerComplete může být nespolehlivý
      await Future.delayed(Duration(milliseconds: (duration * 1000).round()));
    } catch (e) {
      // Pokud selže přehrávání, pokračujeme dál
      // Note: In production, use proper logging instead of print
      // print('Error playing tone: $e');
      // Počkáme alespoň na délku tónu
      await Future.delayed(Duration(milliseconds: (duration * 1000).round()));
    }
  }

  /// Vytvoří WAV hlavičku a přidá PCM data
  Uint8List _createWavFile(Uint8List pcmData, int sampleRate) {
    const wavHeaderSize = 44;
    const bytesPerSample = 2;
    const numChannels = 1;

    final numSamples = pcmData.length ~/ bytesPerSample;
    final dataSize = numSamples * bytesPerSample;
    final fileSize = wavHeaderSize - 8 + dataSize; // -8 for RIFF header itself

    final wav = Uint8List(wavHeaderSize + dataSize);
    final byteData = ByteData.sublistView(wav);

    // RIFF hovedička
    wav.setRange(0, 4, 'RIFF'.codeUnits);
    byteData.setUint32(4, fileSize, Endian.little);
    wav.setRange(8, 12, 'WAVE'.codeUnits);

    // fmt chunk
    wav.setRange(12, 16, 'fmt '.codeUnits);
    byteData.setUint32(16, 16, Endian.little); // fmt chunk size
    byteData.setUint16(20, 1, Endian.little); // audio format (PCM)
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(
      28,
      sampleRate * bytesPerSample * numChannels,
      Endian.little,
    ); // byte rate
    byteData.setUint16(
      32,
      bytesPerSample * numChannels,
      Endian.little,
    ); // block align
    byteData.setUint16(
      34,
      bytesPerSample * 8,
      Endian.little,
    ); // bits per sample

    // data chunk
    wav.setRange(36, 40, 'data'.codeUnits);
    byteData.setUint32(40, dataSize, Endian.little);
    wav.setRange(wavHeaderSize, wavHeaderSize + dataSize, pcmData);

    return wav;
  }

  /// Vypočítá envelope pro plynulejší začátek a konec tónu
  double _getEnvelope(int sampleIndex, int totalSamples) {
    const sampleRate = AppConstants.referenceSampleRate;
    final attackSamples = (AppConstants.toneAttackTime * sampleRate).round();
    final releaseSamples = (AppConstants.toneReleaseTime * sampleRate).round();

    if (sampleIndex < attackSamples) {
      // Attack fáze - plynulý nástup
      return sampleIndex / attackSamples;
    } else if (sampleIndex >= totalSamples - releaseSamples) {
      // Release fáze - plynulý konec
      final releaseIndex = sampleIndex - (totalSamples - releaseSamples);
      return 1.0 - (releaseIndex / releaseSamples);
    } else {
      // Sustain fáze - plná hlasitost
      return 1.0;
    }
  }

  /// Zastaví přehrávání
  Future<void> stop() async {
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    await _audioPlayer.stop();
    _currentSongNotes = null;
    _currentNoteIndex = 0;
  }

  /// Uvolní zdroje
  Future<void> dispose() async {
    await stop();
    await _audioPlayer.dispose();
  }

  /// Zkontroluje, zda právě probíhá přehrávání
  bool get isPlaying => _isPlaying;
}
