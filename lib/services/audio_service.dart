import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import '../models/pitch_data.dart';
import 'pitch_analyzer.dart';

/// Služba pro správu audio streamu a detekci pitchu v reálném čase
///
/// Tato služba:
/// - Spravuje připojení k mikrofonu
/// - Převede audio data na vzorky
/// - Analyzuje pitch pomocí PitchAnalyzer
/// - Poskytuje stream PitchData pro UI
class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final PitchAnalyzer _pitchAnalyzer = PitchAnalyzer();

  Stream<Uint8List>? _audioStream;
  StreamSubscription<Uint8List>? _audioSubscription;
  final _pitchController = StreamController<PitchData>.broadcast();

  bool _isRecording = false;
  double _startTime = 0.0;

  // Buffer pro akumulaci audio vzorků (potřebujeme větší buffer pro spolehlivou detekci)
  final List<double> _sampleBuffer = [];

  /// Stream PitchData pro UI
  Stream<PitchData> get pitchStream => _pitchController.stream;

  /// Zkontroluje, zda má aplikace oprávnění k mikrofonu
  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  /// Spustí nahrávání a analýzu pitchu
  Future<void> startRecording() async {
    if (_isRecording) return;

    if (!await hasPermission()) {
      throw Exception('Microphone permission denied');
    }

    // Spustíme audio stream
    _audioStream = await _audioRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: PitchAnalyzer.sampleRate,
        numChannels: 1,
      ),
    );

    _isRecording = true;
    _startTime = DateTime.now().millisecondsSinceEpoch / 1000.0;

    // Přihlásíme se k audio streamu a analyzujeme každý chunk
    _audioSubscription = _audioStream!.listen(
      _processAudioChunk,
      onError: (error) {
        _pitchController.addError(error);
      },
    );
  }

  /// Zastaví nahrávání
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    await _audioRecorder.stop();
    _audioStream = null;
    _isRecording = false;

    // Vyčistíme buffer
    _sampleBuffer.clear();
  }

  /// Zpracuje chunk audio dat
  ///
  /// Konverze:
  /// 1. PCM16 bytes -> double samples (normalizované na -1.0 až 1.0)
  /// 2. Akumuluje vzorky do bufferu
  /// 3. Analyzuje pitch z dostatečně velkého bufferu
  /// 4. Vytvoří PitchData a pošle do streamu
  void _processAudioChunk(Uint8List audioData) {
    if (!_isRecording) return;

    // Konverze bytes na vzorky
    final samples = _bytesToSamples(audioData);

    // Přidáme vzorky do bufferu
    _sampleBuffer.addAll(samples);

    // Pokud máme dostatek vzorků, analyzujeme pitch
    // Potřebujeme alespoň 4096 vzorků pro spolehlivou detekci
    if (_sampleBuffer.length >= PitchAnalyzer.bufferSize) {
      // Vytvoříme kopii bufferu pro analýzu
      final bufferCopy = List<double>.from(_sampleBuffer);

      // Detekce frekvence
      final frequency = _pitchAnalyzer.detectFrequency(bufferCopy);

      // Vytvoření PitchData
      final currentTime =
          (DateTime.now().millisecondsSinceEpoch / 1000.0) - _startTime;
      final pitchData = _pitchAnalyzer.frequencyToPitchData(
        frequency,
        currentTime,
      );

      // Odeslání do streamu
      _pitchController.add(pitchData);

      // Odstraníme staré vzorky (ponecháme poslední polovinu pro plynulost)
      final keepCount = PitchAnalyzer.bufferSize ~/ 2;
      if (_sampleBuffer.length > keepCount) {
        _sampleBuffer.removeRange(0, _sampleBuffer.length - keepCount);
      }
    }
  }

  /// Konvertuje PCM16 bytes na double vzorky
  ///
  /// PCM16 formát:
  /// - Každý vzorek je 16-bit signed integer (little-endian)
  /// - Rozsah: -32768 až 32767
  /// - Normalizujeme na -1.0 až 1.0
  List<double> _bytesToSamples(Uint8List bytes) {
    final samples = <double>[];
    final byteData = ByteData.sublistView(bytes);

    // Procházíme bytes po dvojicích (16-bit = 2 bytes)
    for (int i = 0; i < bytes.length - 1; i += 2) {
      // Použijeme ByteData pro správnou konverzi little-endian signed 16-bit
      final sampleInt = byteData.getInt16(i, Endian.little);

      // Normalizace na rozsah -1.0 až 1.0
      samples.add(sampleInt / 32768.0);
    }

    return samples;
  }

  /// Uvolní zdroje
  Future<void> dispose() async {
    await stopRecording();
    await _pitchController.close();
    _audioRecorder.dispose();
  }

  /// Zkontroluje, zda právě probíhá nahrávání
  bool get isRecording => _isRecording;
}
