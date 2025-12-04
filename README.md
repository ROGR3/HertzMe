# HertzMe

Flutter aplikace pro Android, která analyzuje výšku tónu (pitch) z hlasu v reálném čase a zobrazuje ji jako plynulý graf.

## Funkce

- ✅ **Real-time analýza pitchu** - Používá mikrofon pro detekci výšky tónu
- ✅ **Scrolling graf** - Zobrazuje časové okno s historií a budoucností (pokud je vybrána písnička)
- ✅ **Zobrazení not** - Osa Y zobrazuje názvy not (C1 až C9)
- ✅ **Textové zobrazení** - Aktuální tón zobrazen textově (např. "A4 – 440 Hz")
- ✅ **Přepínání mezi notami a Hz** - Možnost přepnout zobrazení na ose Y
- ✅ **Cvičení s písničkami** - Zobrazení referenční melodie pro cvičení
- ✅ **Vyhlazení dat** - Snížení vibrací při drobných změnách hlasu
- ✅ **Přizpůsobitelný zoom** - Vertikální gesto pro posun zobrazení
- ✅ **Tmavé téma** - Moderní overlay design

## Technické detaily

### Architektura

Aplikace je strukturována do několika vrstev:

- **`lib/models/pitch_data.dart`** - Model pro reprezentaci pitch dat
- **`lib/services/pitch_analyzer.dart`** - Služba pro analýzu pitchu pomocí autocorrelation metody
- **`lib/services/audio_service.dart`** - Služba pro správu audio streamu z mikrofonu
- **`lib/widgets/pitch_chart.dart`** - Widget pro zobrazení scrolling grafu
- **`lib/main.dart`** - Hlavní UI a logika aplikace

### Metoda detekce pitchu

Aplikace používá **autocorrelation metodu** pro detekci základní frekvence (F0):

1. Audio vzorky se normalizují (odstranění DC offsetu)
2. Vypočítá se autocorrelation funkce pro různé lag hodnoty
3. Najde se lag s nejvyšší korelací v rozsahu odpovídajícím frekvencím 65-1047 Hz
4. Lag se převede na frekvenci: `frequency = sampleRate / lag`

**Výhody autocorrelation metody:**
- Přesnější než zero-crossing rate
- Odolná vůči šumu
- Funguje dobře i s harmonickými tóny
- Rychlejší než FFT

### Převod frekvence na noty

Používá se standardní MIDI systém:
- Referenční frekvence: A4 = 440 Hz (MIDI číslo 69)
- Výpočet: `MIDI = 69 + 12 * log2(frequency / 440)`
- Cent odchylka: `cents = 1200 * log2(actual_freq / nearest_note_freq)`

## Požadavky

- Flutter SDK (doporučeno 3.8.1 nebo novější)
- Android SDK
- Android zařízení nebo emulátor s Androidem 5.0+ (API 21+)
- Oprávnění k mikrofonu (aplikace je požádá automaticky)

## Instalace a spuštění

### 1. Instalace závislostí

```bash
cd hertzme
flutter pub get
```

### 2. Spuštění na Android zařízení

Ujistěte se, že máte připojené Android zařízení nebo spuštěný emulátor:

```bash
flutter devices
```

Poté spusťte aplikaci:

```bash
flutter run
```

### 3. Build APK pro distribuci

Pro vytvoření release APK:

```bash
flutter build apk --release
```

APK najdete v: `build/app/outputs/flutter-apk/app-release.apk`

## Použití

1. **Spuštění nahrávání**: Stiskněte tlačítko "Spustit" v dolní části obrazovky
2. **Zpívání/hraní**: Aplikace začne analyzovat pitch z mikrofonu
3. **Zobrazení výsledků**: 
   - Horní část zobrazuje aktuální tón textově
   - Graf zobrazuje historii posledních 10 sekund
4. **Přepínání zobrazení**: Stiskněte ikonu v pravém horním rohu pro přepnutí mezi notami a Hz
5. **Zastavení**: Stiskněte tlačítko "Zastavit"

## Struktura projektu

```
lib/
├── main.dart                 # Hlavní UI a logika aplikace
├── models/
│   └── pitch_data.dart      # Model pro pitch data
├── services/
│   ├── pitch_analyzer.dart  # Analýza pitchu a konverze na noty
│   └── audio_service.dart   # Správa audio streamu
└── widgets/
    └── pitch_chart.dart     # Widget pro scrolling graf
```

## Použité balíčky

- **`record`** (^6.1.2) - Nahrávání audio z mikrofonu
- **`fl_chart`** (^0.69.0) - Knihovna pro grafy
- **`vector_math`** (^2.1.4) - Matematické utility

## Poznámky

- Aplikace je optimalizována pouze pro Android
- Minimální detekovatelná frekvence: 65 Hz (C2)
- Maximální detekovatelná frekvence: 1047 Hz (C6)
- Graf se aktualizuje přibližně 30x za sekundu
- Data jsou vyhlazována exponenciálním průměrem (faktor 0.7)

## Autor

Vytvořeno jako Flutter aplikace pro real-time pitch detection a cvičení zpěvu.
