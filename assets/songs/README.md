# Songs Directory

This directory contains JSON files with song data for the HertzMe app.

## JSON Format

Each song file should follow this format:

```json
{
  "name": "Song Name",
  "duration": 241.06,
  "notes": [
    {
      "note": "C4",
      "midi": 60,
      "frequency": 261.63,
      "timestamp": 20.46
    },
    {
      "note": "D4",
      "midi": 62,
      "frequency": 293.66,
      "timestamp": 21.50
    }
  ]
}
```

### Fields

- **name**: The display name of the song
- **duration**: Total duration of the song in seconds
- **notes**: Array of note objects with:
  - **note**: Note name (e.g., "C4", "D#4", "E-4")
  - **midi**: MIDI note number (0-127)
  - **frequency**: Frequency in Hz
  - **timestamp**: Time in seconds from the start of the song

## Adding New Songs

**It's now fully automatic!** Just follow these steps:

1. Generate or create a JSON file with the song data following the format above
2. Save it in this directory (`assets/songs/`)
3. Stop and restart the app (hot reload won't work)

That's it! The app automatically scans this directory and loads all `.json` files at startup. No code changes needed!

## Current Songs

- **frozen_let_it_go.json**: "Let It Go" from Disney's Frozen
- **elan_voda_co_ma_drzi_nad_vodou.json**: "Voda čo ma drží nad vodou" by Elán


