# Kontext projektu - Vocal Pitch Monitor

## Přehled projektu

Flutter aplikace pro Android, která v reálném čase analyzuje výšku tónu (pitch) z hlasu pomocí mikrofonu a zobrazuje ji jako scrolling graf. Aplikace je podobná "Vocal Pitch Monitor" s tmavým tématem a plynulým zobrazením.

## Architektura

Projekt používá čistou architekturu s oddělením UI, logiky a služeb:

```
lib/
├── main.dart                 # Hlavní UI (tmavé téma, textové zobrazení aktuálního tónu)
├── models/
│   └── pitch_data.dart      # Model: frequency, note, timestamp, midiNote, cents
├── services/
│   ├── pitch_analyzer.dart  # YIN algoritmus pro detekci pitchu + konverze na noty
│   └── audio_service.dart   # Správa audio streamu z mikrofonu (record package)
└── widgets/
    └── pitch_chart.dart     # Scrolling graf s fl_chart (auto-centrování, filtrování)
```

## Klíčové komponenty

### 1. `PitchAnalyzer` (lib/services/pitch_analyzer.dart)

**Metoda detekce**: YIN algoritmus (optimalizovaná verze autocorrelation)

**Proces**:
- Normalizace signálu (odstranění DC offsetu)
- Výpočet diferenční funkce (difference function)
- Normalizace pomocí kumulativní střední hodnoty (CMNDF)
- Hledání prvního minima pod prahem (0.1)
- Převod lag na frekvenci: `frequency = sampleRate / lag`

**Konstanty**:
- `sampleRate = 44100 Hz`
- `bufferSize = 4096` vzorků
- `minFrequency = 65 Hz` (C2)
- `maxFrequency = 1047 Hz` (C6)
- `threshold = 0.1` (pro YIN detekci)

**Konverze na noty**:
- MIDI systém: `MIDI = 69 + 12 * log2(frequency / 440)`
- Cent odchylka: `cents = 1200 * log2(actual_freq / nearest_note_freq)`

### 2. `AudioService` (lib/services/audio_service.dart)

**Funkce**:
- Správa audio streamu z mikrofonu (`record` package)
- Akumulace vzorků do bufferu (min. 4096 vzorků)
- Konverze PCM16 bytes → double samples (normalizované -1.0 až 1.0)
- Stream PitchData pro UI

**Důležité**:
- Používá `ByteData.getInt16()` pro správnou konverzi little-endian signed 16-bit
- Buffer se akumuluje a po analýze se ponechá polovina pro plynulost
- Stream se aktualizuje při každém dostatečně velkém chunku

### 3. `PitchChart` (lib/widgets/pitch_chart.dart)

**Funkce**:
- Scrolling graf posledních 10 sekund
- Auto-centrování na aktuální rozsah pitchu
- Filtrování mezer větších než threshold
- Filtrování bodů mimo rozsah osy Y

**Klíčové optimalizace**:
- **Auto-centrování**: Používá pouze poslední 2 sekundy pro výpočet rozsahu
- **Vyhlazení rozsahu**: Exponenciální průměr (faktor 0.85) pro stabilitu
- **Segmentace**: Rozděluje data na segmenty při mezerách > 0.3 sekundy
- **Filtrování**: Odstraňuje body mimo rozsah Y před vykreslením

**Konstanty**:
- `_gapThreshold = 0.3` sekundy (mezera pro přerušení křivky)
- `_smoothingFactor = 0.85` (vyhlazení rozsahu osy Y)
- `timeWindow = 10.0` sekund (zobrazený časový rozsah)

**Margin pro zoom**:
- Noty: 15% rozsahu nebo min. 3 půltóny nahoru/dolů
- Hz: 10% rozsahu nebo min. 50 Hz nahoru/dolů

### 4. `main.dart` - Hlavní UI

**Komponenty**:
- Horní část: Textové zobrazení aktuálního tónu (nota + frekvence + cent odchylka)
- Střední část: Scrolling graf (`PitchChart`)
- Spodní část: Tlačítko pro spuštění/zastavení + status

**Vyhlazení dat**:
- Exponenciální průměr s faktorem 0.7 pro snížení vibrací
- Aplikuje se na frekvenci před vytvořením PitchData

**Aktualizace UI**:
- Timer každých 33ms (~30 FPS)
- Odstraňuje data starší než 10 sekund

## Technické detaily

### Balíčky (pubspec.yaml)
- `record: ^6.1.2` - Nahrávání audio z mikrofonu
- `fl_chart: ^0.69.0` - Knihovna pro grafy
- `vector_math: ^2.1.4` - Matematické utility

### Android konfigurace
- `AndroidManifest.xml` obsahuje `RECORD_AUDIO` oprávnění
- Aplikace je optimalizována pouze pro Android

### Formát audio dat
- PCM16, 44100 Hz, mono (1 kanál)
- Little-endian signed 16-bit integer
- Normalizace na rozsah -1.0 až 1.0

## Poslední změny a optimalizace

1. **YIN algoritmus**: Nahrazen autocorrelation za spolehlivější YIN pro hlas
2. **Akumulace bufferu**: Vzorky se akumulují do většího bufferu před analýzou
3. **Oprava PCM konverze**: Použití `ByteData.getInt16()` pro správnou konverzi
4. **Auto-centrování grafu**: Graf se automaticky přizpůsobí aktuálnímu rozsahu
5. **Stabilizace rozsahu**: Vyhlazení pro plynulejší změny bez skákání
6. **Segmentace křivky**: Přerušení při mezerách > 0.3 sekundy
7. **Filtrování mimo rozsah**: Body mimo zazoomovanou část se nezobrazují
8. **Zobrazení všech not**: Osa Y zobrazuje všechny noty (interval 1.0), ne jen C

## Důležité poznámky

- **Vzorkovací frekvence**: 44100 Hz (fixní)
- **Buffer pro analýzu**: Minimálně 4096 vzorků (pro spolehlivou detekci nízkých frekvencí)
- **Rozsah detekce**: 65-1047 Hz (C2 až C6)
- **Aktualizace grafu**: ~30 FPS (každých 33ms)
- **Vyhlazení frekvence**: Faktor 0.7 (v main.dart)
- **Vyhlazení rozsahu Y**: Faktor 0.85 (v pitch_chart.dart)
- **Threshold pro mezery**: 0.3 sekundy (pro přerušení křivky)

## Možná vylepšení do budoucna

- Přidat možnost změny threshold pro mezery
- Přidat možnost změny faktoru vyhlazení
- Přidat možnost změny časového okna (místo fixních 10 sekund)
- Přidat export dat do CSV/JSON
- Přidat možnost nahrání a přehrání

## Spuštění

```bash
cd hello_app
flutter pub get
flutter run
```

## Testování

Aplikace byla testována na Android zařízení. Pro správnou funkci je potřeba:
- Oprávnění k mikrofonu
- Android 5.0+ (API 21+)
- Funkční mikrofon

