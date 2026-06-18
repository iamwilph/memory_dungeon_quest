import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _mutedNotifier = ValueNotifier<bool>(_isMuted);
    _sfxVolumeNotifier = ValueNotifier<double>(_sfxVolume);
    _ambientVolumeNotifier = ValueNotifier<double>(_ambientVolume);
    _menuVolumeNotifier = ValueNotifier<double>(_menuVolume);
  }

  late final AudioPlayer _sfxPlayer;
  late final AudioPlayer _ambientPlayer;
  late final AudioPlayer _menuPlayer;

  bool _isMuted = false;
  late ValueNotifier<bool> _mutedNotifier;

  double _sfxVolume = 1.0;
  late ValueNotifier<double> _sfxVolumeNotifier;

  double _ambientVolume = 1.0;
  late ValueNotifier<double> _ambientVolumeNotifier;

  double _menuVolume = 1.0;
  late ValueNotifier<double> _menuVolumeNotifier;

  ValueListenable<bool> get mutedValue => _mutedNotifier;
  ValueListenable<double> get sfxVolumeValue => _sfxVolumeNotifier;
  ValueListenable<double> get ambientVolumeValue => _ambientVolumeNotifier;
  ValueListenable<double> get menuVolumeValue => _menuVolumeNotifier;

  String? _currentAmbientDungeon;
  String? _ambientDungeonWhenStopped;

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  void init() {
    _sfxPlayer = AudioPlayer(playerId: 'sfx');
    _ambientPlayer = AudioPlayer(playerId: 'ambient');
    _menuPlayer = AudioPlayer(playerId: 'menu-ambient');

    // ReleaseMode.stop keeps the native player alive so setVolume() always
    // reaches a live native object between plays.
    _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);
    _menuPlayer.setReleaseMode(ReleaseMode.loop);
  }

  // ---------------------------------------------------------------------------
  // Persistence — mute
  // ---------------------------------------------------------------------------

  Future<void> loadMutedPreference() async {
    try {
      final file = await _mutedFile();
      if (file.existsSync()) {
        final raw = await file.readAsString();
        final data = jsonDecode(raw);
        if (data is bool) {
          _isMuted = data;
          _mutedNotifier.value = _isMuted;
        }
      }
    } catch (_) {}
  }

  Future<void> saveMutedPreference() async {
    try {
      final file = await _mutedFile();
      await file.writeAsString(jsonEncode(_isMuted), flush: true);
    } catch (_) {}
  }

  Future<File> _mutedFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/audio_muted.json');
  }

  // ---------------------------------------------------------------------------
  // Persistence — volume
  // ---------------------------------------------------------------------------

  /// Loads saved volumes from disk and applies them to all three players.
  /// Must be called AFTER init() so the AudioPlayer instances exist.
  Future<void> loadVolumePreferences() async {
    try {
      final file = await _volumesFile();
      if (file.existsSync()) {
        final raw = await file.readAsString();
        final data = jsonDecode(raw) as Map<String, dynamic>;

        if (data['sfxVolume'] is double) {
          _sfxVolume = (data['sfxVolume'] as double).clamp(0.0, 1.0);
          _sfxVolumeNotifier.value = _sfxVolume;
        }
        if (data['ambientVolume'] is double) {
          _ambientVolume = (data['ambientVolume'] as double).clamp(0.0, 1.0);
          _ambientVolumeNotifier.value = _ambientVolume;
        }
        if (data['menuVolume'] is double) {
          _menuVolume = (data['menuVolume'] as double).clamp(0.0, 1.0);
          _menuVolumeNotifier.value = _menuVolume;
        }
      }
    } catch (_) {}

    // Always push loaded (or default) values to the native players so the
    // hardware level matches the Dart state from the very first play() call.
    await _sfxPlayer.setVolume(_sfxVolume);
    await _ambientPlayer.setVolume(_ambientVolume);
    await _menuPlayer.setVolume(_menuVolume);
  }

  Future<void> saveVolumePreferences() async {
    try {
      final file = await _volumesFile();
      await file.writeAsString(
        jsonEncode({
          'sfxVolume': _sfxVolume,
          'ambientVolume': _ambientVolume,
          'menuVolume': _menuVolume,
        }),
        flush: true,
      );
    } catch (_) {}
  }

  Future<File> _volumesFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/audio_volumes.json');
  }

  // ---------------------------------------------------------------------------
  // Volume setters
  // ---------------------------------------------------------------------------

  /// Called by the SFX slider. Updates the Dart field, the notifier (so the
  /// slider UI reflects the value), the native player level, and persists.
  void setSfxVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
    _sfxVolumeNotifier.value = _sfxVolume;
    // setVolume() on the native player works reliably when ReleaseMode.stop
    // is set — the native player stays alive between sounds.
    _sfxPlayer.setVolume(_sfxVolume);
    saveVolumePreferences();
  }

  /// Called by the AMBIENT slider. Controls both the dungeon loop and the
  /// menu ambient loop — there is only one AMBIENT slider in Settings.
  void setAmbientVolume(double volume) {
    _ambientVolume = volume.clamp(0.0, 1.0);
    _menuVolume = _ambientVolume; // single slider controls both
    _ambientVolumeNotifier.value = _ambientVolume;
    _menuVolumeNotifier.value = _menuVolume;
    // setVolume() reaches the native player immediately while the loop is
    // playing — this is what makes the slider feel live.
    _ambientPlayer.setVolume(_ambientVolume);
    _menuPlayer.setVolume(_menuVolume);
    saveVolumePreferences();
  }

  /// Internal — only used if you ever add a separate menu slider.
  void setMenuVolume(double volume) {
    _menuVolume = volume.clamp(0.0, 1.0);
    _menuVolumeNotifier.value = _menuVolume;
    _menuPlayer.setVolume(_menuVolume);
    saveVolumePreferences();
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  Future<void> playSfx(String assetPath) async {
    if (_isMuted) return;
    try {
      // Do NOT pass volume: here. The player-level volume set by setSfxVolume /
      // loadVolumePreferences is already applied to the native player.
      // Passing volume: into play() overrides the player-level volume on every
      // call, which means any setVolume() call between plays is silently undone.
      await _sfxPlayer.play(AssetSource('audio/$assetPath'));
    } catch (_) {}
  }

  Future<void> playSfxOnce({
    required String assetPath,
    required void Function() onComplete,
  }) async {
    if (_isMuted) {
      onComplete();
      return;
    }
    // Unique playerId per call prevents concurrent one-shot sounds from
    // stomping each other's native player instance.
    final player = AudioPlayer(
      playerId: 'sfx-once-${DateTime.now().microsecondsSinceEpoch}',
    );
    player.setReleaseMode(ReleaseMode.stop);
    // Apply the current SFX volume to this fresh player before playing.
    await player.setVolume(_sfxVolume);
    await player.play(AssetSource('audio/$assetPath'));
    player.onPlayerComplete.listen((_) {
      onComplete();
      player.dispose();
    });
  }

  Future<void> startAmbient(String dungeonId) async {
    if (_isMuted || _currentAmbientDungeon == dungeonId) return;
    await _ambientPlayer.stop();
    try {
      final path = _getAmbientPath(dungeonId);
      debugPrint('loading $path audio for $dungeonId');
      if (path != null) {
        // Do NOT pass volume: here — same reason as playSfx.
        await _ambientPlayer.play(AssetSource('audio/$path'));
        _currentAmbientDungeon = dungeonId;
      } else {
        _currentAmbientDungeon = 'generic';
      }
    } catch (_) {
      _currentAmbientDungeon = null;
    }
  }

  Future<void> stopAmbient() async {
    await _ambientPlayer.stop();
    _ambientDungeonWhenStopped = _currentAmbientDungeon;
    _currentAmbientDungeon = null;
  }

  bool get isMenuAmbientPlaying => _menuPlayer.state == PlayerState.playing;

  Future<void> playMenuAmbient() async {
    if (_isMuted) return;
    try {
      await _menuPlayer.play(AssetSource('audio/ambience/dungeon.mp3'));
    } catch (_) {}
  }

  Future<void> stopMenuAmbient() async {
    try {
      await _menuPlayer.stop();
    } catch (_) {}
  }

  Future<void> resumeAmbientIfUnmuted() async {
    if (_isMuted) return;
    if (_ambientDungeonWhenStopped != null && _currentAmbientDungeon == null) {
      final dungeonId = _ambientDungeonWhenStopped!;
      _ambientDungeonWhenStopped = null;
      await startAmbient(dungeonId);
    }
  }

  // ---------------------------------------------------------------------------
  // Mute
  // ---------------------------------------------------------------------------

  void setMuted(bool muted) {
    if (muted) {
      _ambientDungeonWhenStopped = _currentAmbientDungeon;
      _isMuted = true;
      _mutedNotifier.value = true;
      _ambientPlayer.stop();
      _menuPlayer.stop();
    } else {
      _isMuted = false;
      _mutedNotifier.value = false;
    }
    saveMutedPreference();
  }

  bool get isMuted => _isMuted;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? _getAmbientPath(String dungeonId) {
    switch (dungeonId) {
      case 'stone_chamber':  return 'ambience/stone_drip.mp3';
      case 'lava_chamber':   return 'ambience/lava_rumble.mp3';
      case 'ice_chamber':    return 'ambience/ice_crack.mp3';
      case 'crypt_chamber':  return 'ambience/crypt_wind.mp3';
      case 'void_chamber':   return 'ambience/void_hum.mp3';
      case 'forest_chamber': return 'ambience/forest_whisper.mp3';
      default:               return null;
    }
  }

  void dispose() {
    _mutedNotifier.dispose();
    _sfxVolumeNotifier.dispose();
    _ambientVolumeNotifier.dispose();
    _menuVolumeNotifier.dispose();
    _sfxPlayer.dispose();
    _ambientPlayer.dispose();
    _menuPlayer.dispose();
  }
}