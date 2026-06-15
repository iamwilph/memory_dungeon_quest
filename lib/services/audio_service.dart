import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  late final AudioPlayer _sfxPlayer;   // Short sounds, overlap-friendly
  late final AudioPlayer _ambientPlayer; // Long looping ambient tracks

  bool _isMuted = false;
  String? _currentAmbientDungeon;

  void init() {
    _sfxPlayer = AudioPlayer(playerId: 'sfx');
    _ambientPlayer = AudioPlayer(playerId: 'ambient');
    // Configure ambient for looping
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> playSfx(String assetPath) async {
    if (_isMuted) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/$assetPath'));
    } catch (e) {
      // Silently fail if asset missing — don't crash the game
    }
  }

  Future<void> playSfxOnce({required String assetPath, required void Function() onComplete}) async {
    if (_isMuted) { onComplete(); return; }
    final player = AudioPlayer(playerId: 'sfx-once');
    await player.play(AssetSource('audio/$assetPath'));
    player.onPlayerComplete.listen((_) {
      onComplete();
      player.dispose();
    });
  }

  Future<void> startAmbient(String dungeonId) async {
    if (_isMuted || _currentAmbientDungeon == dungeonId) return;
    // Stop current ambient first
    await _ambientPlayer.stop();
    try {
      final path = _getAmbientPath(dungeonId);
      if (path != null) {
        await _ambientPlayer.play(AssetSource('audio/$path'));
        _currentAmbientDungeon = dungeonId;
      } else {
        // Fallback: no ambient, just silence or generic stone ambience
        _currentAmbientDungeon = 'generic';
      }
    } catch (e) {
      _currentAmbientDungeon = null;
    }
  }

  Future<void> stopAmbient() async {
    await _ambientPlayer.stop();
    _currentAmbientDungeon = null;
  }

  void setMuted(bool muted) => _isMuted = muted;
  bool get isMuted => _isMuted;

  String? _getAmbientPath(String dungeonId) {
    switch (dungeonId) {
      case 'stone': return 'ambience/stone_drip.mp3';
      case 'lava': return 'ambience/lava_rumble.mp3';
      case 'ice': return 'ambience/ice_crack.mp3';
      case 'crypt': return 'ambience/crypt_wind.mp3';
      case 'voidChamber': return 'ambience/void_hum.mp3';
      case 'forest': return 'ambience/forest_whisper.mp3';
      default: return null;
    }
  }

  void dispose() {
    _sfxPlayer.dispose();
    _ambientPlayer.dispose();
  }
}