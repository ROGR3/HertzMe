import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/song.dart';

/// Widget for recording control buttons
class RecordingControls extends StatelessWidget {
  final bool isRecording;
  final Song? selectedSong;
  final VoidCallback onToggleRecording;
  final VoidCallback? onPlayReference;
  final String status;

  const RecordingControls({
    super.key,
    required this.isRecording,
    required this.selectedSong,
    required this.onToggleRecording,
    this.onPlayReference,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.standardPadding),
            child: Text(
              status,
              style: TextStyle(
                fontSize: AppConstants.labelFontSize,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        _buildButtons(),
      ],
    );
  }

  Widget _buildButtons() {
    // When song is selected and not recording: show Play and Sing buttons
    if (selectedSong != null && !isRecording) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            heroTag: 'play',
            onPressed: onPlayReference,
            backgroundColor: AppConstants.successColor,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Přehrát'),
          ),
          const SizedBox(width: AppConstants.standardPadding),
          FloatingActionButton.extended(
            heroTag: 'rec',
            onPressed: onToggleRecording,
            backgroundColor: AppConstants.primaryAccent,
            icon: const Icon(Icons.mic),
            label: const Text('Zpívat'),
          ),
        ],
      );
    }
    
    // When recording (with or without song): show Stop button
    if (isRecording) {
      return FloatingActionButton.extended(
        onPressed: onToggleRecording,
        backgroundColor: AppConstants.errorColor,
        icon: const Icon(Icons.stop),
        label: const Text('Zastavit'),
      );
    }
    
    // Default: show Start/Stop toggle button
    return FloatingActionButton.extended(
      onPressed: onToggleRecording,
      backgroundColor: isRecording
          ? AppConstants.errorColor
          : AppConstants.primaryAccent,
      icon: Icon(isRecording ? Icons.stop : Icons.mic),
      label: Text(isRecording ? 'Zastavit' : 'Start'),
    );
  }
}


