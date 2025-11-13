import 'package:flutter/material.dart';
import '../models/song.dart';
import '../data/songs.dart';

/// Stránka pro výběr písničky k cvičení
class SongSelectionPage extends StatelessWidget {
  final Function(Song?) onSongSelected;

  const SongSelectionPage({super.key, required this.onSongSelected});

  @override
  Widget build(BuildContext context) {
    final songs = SongsDatabase.songs;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text(
          'Vyberte písničku',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Možnost "Volný zpěv" - bez písničky
          Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            color: const Color(0xFF2A2A2A),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              leading: const Icon(Icons.mic, color: Colors.blue, size: 32),
              title: const Text(
                'Volný zpěv',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Zpívejte bez referenční písničky',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.blue,
                size: 20,
              ),
              onTap: () {
                Navigator.pop(context);
                onSongSelected(null);
              },
            ),
          ),
          // Seznam písniček
          ...songs.map((song) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              color: const Color(0xFF2A2A2A),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                title: Text(
                  song.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Délka: ${song.duration.toStringAsFixed(1)}s • ${song.notes.length} tónů',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.blue,
                  size: 20,
                ),
                onTap: () {
                  Navigator.pop(context);
                  onSongSelected(song);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
