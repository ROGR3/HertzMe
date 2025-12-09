import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../constants/app_constants.dart';
import '../models/pitch_data.dart';
import '../utils/music_utils.dart';

/// Widget for displaying current and reference pitch information
class PitchDisplay extends StatelessWidget {
  final PitchData? currentPitch;
  final PitchData? referencePitch;

  const PitchDisplay({
    super.key,
    this.currentPitch,
    this.referencePitch,
  });

  bool get _isPitchMatch {
    if (currentPitch == null || referencePitch == null) return false;
    if (!currentPitch!.isValid) return false;
    
    return MusicUtils.isPitchMatch(
      currentPitch!.midiNote,
      currentPitch!.cents,
      referencePitch!.midiNote,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (referencePitch != null) {
      return _buildWithReference();
    } else {
      return _buildSingleNote();
    }
  }

  /// Builds display when reference pitch is available
  Widget _buildWithReference() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reference note
        Column(
          children: [
            Text('Cíl', style: AppTheme.labelStyle),
            Text(
              referencePitch!.note,
              style: AppTheme.smallNoteStyle.copyWith(
                color: AppConstants.successColor,
              ),
            ),
          ],
        ),
        // Current note
        Column(
          children: [
            Text('Ty', style: AppTheme.labelStyle),
            Text(
              currentPitch?.note ?? '-',
              style: AppTheme.mediumNoteStyle.copyWith(
                color: AppTheme.getPitchColor(
                  isValid: currentPitch?.isValid == true,
                  isMatching: _isPitchMatch,
                ),
              ),
            ),
            // Display cents deviation if valid and significant
            if (currentPitch?.isValid == true &&
                currentPitch!.cents.abs() > AppConstants.centDisplayThreshold)
              Text(
                '${currentPitch!.cents > 0 ? '+' : ''}${currentPitch!.cents.toStringAsFixed(0)}',
                style: AppTheme.centsStyle(currentPitch!.cents),
              ),
          ],
        ),
      ],
    );
  }

  /// Builds display for single note (no reference)
  Widget _buildSingleNote() {
    return Column(
      children: [
        Text(
          currentPitch?.note ?? '-',
          style: AppTheme.largeNoteStyle,
        ),
        if (currentPitch?.isValid == true)
          Text(
            '${currentPitch!.frequency.toStringAsFixed(1)} Hz',
            style: AppTheme.frequencyStyle,
          ),
      ],
    );
  }
}


