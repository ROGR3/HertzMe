import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
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
      backgroundColor: AppConstants.primaryBackground,
      appBar: AppBar(
        title: const Text(
          'Vyberte písničku',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppConstants.secondaryBackground,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.standardPadding),
        children: [
          // Možnost "Volný zpěv" - bez písničky
          Card(
            margin: const EdgeInsets.only(bottom: AppConstants.cardMargin),
            color: AppConstants.secondaryBackground,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.standardPadding,
                vertical: AppConstants.cardMargin,
              ),
              leading: const Icon(
                Icons.mic,
                color: AppConstants.primaryAccent,
                size: AppConstants.iconSizeStandard,
              ),
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
                color: AppConstants.primaryAccent,
                size: AppConstants.iconSizeSmall,
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
              margin: const EdgeInsets.only(bottom: AppConstants.cardMargin),
              color: AppConstants.secondaryBackground,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.standardPadding,
                  vertical: AppConstants.cardMargin,
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
                  color: AppConstants.primaryAccent,
                  size: AppConstants.iconSizeSmall,
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
