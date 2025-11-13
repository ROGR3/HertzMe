/// Model pro reprezentaci jednoho měření pitchu
class PitchData {
  /// Frekvence v Hz
  final double frequency;
  
  /// Název noty (např. "A4")
  final String note;
  
  /// Časová značka v sekundách od začátku měření
  final double timestamp;
  
  /// MIDI číslo noty (0-127)
  final int midiNote;
  
  /// Cent odchylka od nejbližší noty (-50 až +50)
  final double cents;

  const PitchData({
    required this.frequency,
    required this.note,
    required this.timestamp,
    required this.midiNote,
    required this.cents,
  });

  /// Vytvoří prázdné PitchData (když není detekován žádný tón)
  factory PitchData.empty(double timestamp) {
    return PitchData(
      frequency: 0.0,
      note: '-',
      timestamp: timestamp,
      midiNote: 0,
      cents: 0.0,
    );
  }

  /// Zkontroluje, zda je to platné měření
  bool get isValid => frequency > 0 && note != '-';
}

