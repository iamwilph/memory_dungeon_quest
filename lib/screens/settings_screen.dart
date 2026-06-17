import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/dungeon_config.dart';
import '../theme/dungeon_theme.dart';
import '../widgets/hud_element.dart';
import '../widgets/torch_overlay.dart';
import '../widgets/ambient_particles.dart';
import '../services/audio_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: DungeonTheme.getTheme(DungeonThemeType.stone).bgGradient,
            ),
          ),
          const AmbientParticles(),
          const TorchOverlay(child: SizedBox.expand()),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _backButton(context),
                      Text(
                        'SETTINGS',
                        style: DungeonTheme.getTitleStyle(context, const Color(0xFFF1C40F)),
                      ),
                      const SizedBox(width: 60),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Settings Content
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Sound Toggle
                            _buildSoundToggle(context),
                            const SizedBox(height: 24),

                            // Volume Sliders
                            _buildVolumeSliders(context),
                            const SizedBox(height: 32),

                            // Reset Campaign
                            _buildResetButton(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFF5A6B7C).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.arrow_back, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text('RETURN', style: DungeonTheme.getBodyStyle(11, Colors.white70, weight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundToggle(BuildContext context) {
    final audio = AudioService();
    return ValueListenableBuilder<bool>(
      valueListenable: audio.mutedValue,
      builder: (context, isMuted, _) {
        return HudElement(
          padding: const EdgeInsets.all(20),
          borderRadius: 12,
          seed: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    color: isMuted ? Colors.white24 : const Color(0xFFF1C40F),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SOUND',
                    style: DungeonTheme.getBodyStyle(14, Colors.white, weight: FontWeight.bold),
                  ),
                ],
              ),
              // Toggle switch
              GestureDetector(
                onTap: () {
                  final wasMuted = isMuted;
                  audio.setMuted(!isMuted);
                  // When un-muting, resume the ambient audio that was playing
                  if (wasMuted && !audio.isMuted) {
                    audio.resumeAmbientIfUnmuted();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isMuted ? 'Sound unmuted' : 'Sound muted',
                      ),
                      duration: const Duration(seconds: 1),
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                    ),
                  );
                },
                child: Container(
                  width: 50,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isMuted
                        ? const Color(0xFF5A6B7C).withValues(alpha: 0.5)
                        : const Color(0xFFF1C40F),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVolumeSliders(BuildContext context) {
    final audio = AudioService();
    return HudElement(
      padding: const EdgeInsets.all(20),
      borderRadius: 12,
      seed: 43,
      child: ValueListenableBuilder<bool>(
        valueListenable: audio.mutedValue,
        builder: (context, isMuted, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SFX Volume Slider
              _buildVolumeRow(
                context: context,
                label: 'SFX',
                icon: Icons.volume_up,
                volumeValue: audio.sfxVolumeValue,
                setVolume: audio.setSfxVolume,
                isMuted: isMuted,
              ),
              const SizedBox(height: 16),
              // Ambient Volume Slider
              _buildVolumeRow(
                context: context,
                label: 'AMBIENT',
                icon: Icons.music_note,
                volumeValue: audio.ambientVolumeValue,
                setVolume: audio.setAmbientVolume,
                isMuted: isMuted,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVolumeRow({
    required BuildContext context,
    required String label,
    required IconData icon,
    required ValueListenable<double> volumeValue,
    required void Function(double) setVolume,
    required bool isMuted,
  }) {
    // Fixed width for the label area so both sliders start at the same X position
    const double labelAreaWidth = 100.0;

    return Row(
      children: [
        // Label area — fixed width so both rows' sliders align
        SizedBox(
          width: labelAreaWidth,
          child: Row(
            children: [
              Icon(
                icon,
                color: isMuted
                    ? const Color(0xFF5A6B7C)
                    : const Color(0xFFF1C40F),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: DungeonTheme.getBodyStyle(
                  12,
                  isMuted ? Colors.white38 : Colors.white,
                  weight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Slider — expands to fill remaining width equally for both rows
        Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: volumeValue,
            builder: (context, volume, _) {
              return Slider(
                value: volume,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                activeColor: isMuted
                    ? const Color(0xFF5A6B7C).withValues(alpha: 0.4)
                    : const Color(0xFFF1C40F),
                inactiveColor: const Color(0xFF5A6B7C).withValues(alpha: 0.3),
                // onChanged is null when muted — Flutter disables the slider
                onChanged: isMuted ? null : setVolume,
              );
            },
          ),
        ),
        // Percentage label — fixed width so it doesn't cause slider width jitter
        SizedBox(
          width: 36,
          child: ValueListenableBuilder<double>(
            valueListenable: volumeValue,
            builder: (context, volume, _) {
              return Text(
                '${(volume * 100).toInt()}%',
                textAlign: TextAlign.right,
                style: DungeonTheme.getBodyStyle(
                  11,
                  isMuted ? Colors.white24 : const Color(0xFFF1C40F),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return HudElement(
      padding: const EdgeInsets.all(20),
      borderRadius: 12,
      seed: 99,
      child: Column(
        children: [
          Text(
            'CAMPAIGN RESET',
            style: DungeonTheme.getBodyStyle(14, const Color(0xFFE74C3C), weight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'This will lock all deeper chambers and clear your inventory.',
            textAlign: TextAlign.center,
            style: DungeonTheme.getBodyStyle(11, Colors.white54),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => _showResetConfirmation(context),
            child: Text(
              'RESET CAMPAIGN',
              style: DungeonTheme.getBodyStyle(12, Colors.white, weight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: HudElement(
            borderRadius: 12.0,
            padding: const EdgeInsets.all(20.0),
            seed: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RESET PROGRESS?',
                  style: DungeonTheme.getTitleStyle(context, const Color(0xFFE74C3C)),
                ),
                const SizedBox(height: 12.0),
                Text(
                  'This will lock all deeper chambers (Lava, Ice, Crypt) and clear your inventory. Are you sure you wish to return to the entrance?',
                  textAlign: TextAlign.center,
                  style: DungeonTheme.getBodyStyle(12.0, Colors.white70),
                ),
                const SizedBox(height: 24.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'ABANDON',
                        style: DungeonTheme.getBodyStyle(12.0, Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 20.0),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE74C3C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                      onPressed: () {
                        Provider.of<GameState>(context, listen: false).resetGame();
                        Navigator.pop(context);
                        Navigator.pop(context); // Return to menu
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF2C3E50),
                            content: Text(
                              'Campaign progress has been erased. The dungeon seals are restored.',
                              style: DungeonTheme.getBodyStyle(12.0, Colors.white),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'ERASE SEALS',
                        style: DungeonTheme.getBodyStyle(12.0, Colors.white, weight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}