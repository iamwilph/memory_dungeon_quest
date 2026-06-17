import 'dart:async';
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

  late final AudioPlayer _sfxPlayer;   // Short sounds, overlap-friendly
  late final AudioPlayer _ambientPlayer; // Long looping ambient tracks
  late final AudioPlayer _menuPlayer;   // Long looping menu ambient

  bool _isMuted = false;
  late ValueNotifier<bool> _mutedNotifier;

  /// SFX volume (0.0–1.0).
  double _sfxVolume = 1.0;
  late ValueNotifier<double> _sfxVolumeNotifier;

  /// Ambient volume (0.0–1.0).
  double _ambientVolume = 1.0;
  late ValueNotifier<double> _ambientVolumeNotifier;

  /// Menu ambient volume (0.0–1.0).
  double _menuVolume = 1.0;
  late ValueNotifier<double> _menuVolumeNotifier;

  /// Exposed for reactive UI — widgets can listen via ValueListenableBuilder.
  ValueListenable<bool> get mutedValue => _mutedNotifier;
  ValueListenable<double> get sfxVolumeValue => _sfxVolumeNotifier;
  ValueListenable<double> get ambientVolumeValue => _ambientVolumeNotifier;
  ValueListenable<double> get menuVolumeValue => _menuVolumeNotifier;

  String? _currentAmbientDungeon;
  String? _ambientDungeonWhenStopped; // Tracks the dungeon ID when stopAmbient() is called (for un-mute restore)
  // bool _wasMenuPlayingWhenMuted = false; // Tracks whether menu ambient was playing when muted

  /// Loads the persisted muted state from disk (if any) and applies it.
  Future<void> loadMutedPreference() async {
    try {
      final file = await _mutedFile();
      if (file.existsSync()) {
        final raw = await file.readAsString();
        final data = jsonDecode(raw);
        if (data is bool && data != _isMuted) {
          _isMuted = data;
          _mutedNotifier.value = _isMuted;
        }
      }
    } catch (e) {
      // Corrupted file — ignore, stick with default false
    }
  }

  /// Saves the current muted state to disk.
  Future<void> saveMutedPreference() async {
    try {
      final file = await _mutedFile();
      await file.writeAsString(jsonEncode(_isMuted), flush: true);
    } catch (e) {
      // Silently fail — muted preference is non-critical
    }
  }

  Future<File> _mutedFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/audio_muted.json');
  }

  /// Returns the volumes file path.
  Future<File> _volumesFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/audio_volumes.json');
  }

  /// Loads persisted volume values from disk.
  Future<void> loadVolumePreferences() async {
    try {
      final file = await _volumesFile();
      if (file.existsSync()) {
        final raw = await file.readAsString();
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['sfxVolume'] is double && data['sfxVolume'] != _sfxVolume) {
          _sfxVolume = data['sfxVolume'] as double;
          _sfxVolumeNotifier.value = _sfxVolume;
        }
        if (data['ambientVolume'] is double && data['ambientVolume'] != _ambientVolume) {
          _ambientVolume = data['ambientVolume'] as double;
          _ambientVolumeNotifier.value = _ambientVolume;
        }
        if (data['menuVolume'] is double && data['menuVolume'] != _menuVolume) {
          _menuVolume = data['menuVolume'] as double;
          _menuVolumeNotifier.value = _menuVolume;
        }
      }
    } catch (e) {
      // Corrupted file — ignore, stick with defaults
    }
  }

  /// Saves all volume values to disk.
  Future<void> saveVolumePreferences() async {
    try {
      final file = await _volumesFile();
      final data = {
        'sfxVolume': _sfxVolume,
        'ambientVolume': _ambientVolume,
        'menuVolume': _menuVolume,
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      // Silently fail — volume preference is non-critical
    }
  }

  void init() {
    _sfxPlayer = AudioPlayer(playerId: 'sfx');
    _ambientPlayer = AudioPlayer(playerId: 'ambient');
    _menuPlayer = AudioPlayer(playerId: 'menu-ambient');
    // ReleaseMode.stop keeps the native player alive after playback ends so
    // that setVolume() calls between plays are not discarded. The default
    // ReleaseMode.release tears down the native engine after each sound,
    // meaning any setVolume() applied to an idle player targets a
    // non-existent native object and is silently ignored.
    _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    // Configure ambient players for looping
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);
    _menuPlayer.setReleaseMode(ReleaseMode.loop);
    // Load persisted volume preferences
    unawaited(loadVolumePreferences());
  }

  /// Sets the SFX volume (0.0–1.0) and persists it.
  /// Applies immediately to any currently-playing SFX track.
  void setSfxVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
    _sfxVolumeNotifier.value = _sfxVolume;
    // Push the new volume to the native player immediately. With
    // ReleaseMode.stop the native player persists between plays so this
    // always reaches a live native object.
    unawaited(_sfxPlayer.setVolume(_sfxVolume));
    unawaited(saveVolumePreferences());
  }

  /// Sets the ambient volume (0.0–1.0) and persists it.
  /// Applies immediately to any currently-playing ambient track.
  void setAmbientVolume(double volume) {
    _ambientVolume = volume.clamp(0.0, 1.0);
    _ambientVolumeNotifier.value = _ambientVolume;
    // Apply immediately — ambient uses ReleaseMode.loop so the native
    // player always persists. This also handles live slider drag updates.
    unawaited(_ambientPlayer.setVolume(_ambientVolume));
    unawaited(saveVolumePreferences());
  }

  /// Sets the menu ambient volume (0.0–1.0) and persists it.
  /// Applies immediately to any currently-playing menu track.
  void setMenuVolume(double volume) {
    _menuVolume = volume.clamp(0.0, 1.0);
    _menuVolumeNotifier.value = _menuVolume;
    unawaited(_menuPlayer.setVolume(_menuVolume));
    unawaited(saveVolumePreferences());
  }

  Future<void> playSfx(String assetPath) async {
    if (_isMuted) return;
    try {
      // Pass volume directly into play() — this is the only reliable way to
      // set volume in audioplayers. setVolume() on a separate call is racy
      // and ignored on many platforms when the source is reloaded.
      await _sfxPlayer.play(
        AssetSource('audio/$assetPath'),
        volume: _sfxVolume,
      );
    } catch (e) {
      // Silently fail if asset missing — don't crash the game
    }
  }

  Future<void> playSfxOnce({required String assetPath, required void Function() onComplete}) async {
    if (_isMuted) { onComplete(); return; }
    final player = AudioPlayer(playerId: 'sfx-once');
    await player.play(AssetSource('audio/$assetPath'), volume: _sfxVolume);
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
      debugPrint('loading $path audio for $dungeonId');
      if (path != null) {
        await _ambientPlayer.play(AssetSource('audio/$path'), volume: _ambientVolume);
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
    // Remember which dungeon ambient was playing so we can restore it on un-mute
    _ambientDungeonWhenStopped = _currentAmbientDungeon;
    _currentAmbientDungeon = null;
  }

  /// Returns whether the menu ambient is currently playing.
  bool get isMenuAmbientPlaying => _menuPlayer.state == PlayerState.playing;

  /// Plays the menu ambient loop (dungeon.mp3). Respects muted state.
  Future<void> playMenuAmbient() async {
    if (_isMuted) return;
    try {
      await _menuPlayer.play(AssetSource('audio/ambience/dungeon.mp3'), volume: _menuVolume);
    } catch (e) {
      // Silently fail if asset missing
    }
  }

  /// Stops the menu ambient audio.
  Future<void> stopMenuAmbient() async {
    try {
      await _menuPlayer.stop();
    } catch (e) {
      // Silently fail
    }
  }

  /// Resumes dungeon ambient after un-muting (if a dungeon was active).
  /// Menu ambient is handled separately by MenuScreen's mute listener.
  Future<void> resumeAmbientIfUnmuted() async {
    if (_isMuted) return;
    if (_ambientDungeonWhenStopped != null && _currentAmbientDungeon == null) {
      final dungeonId = _ambientDungeonWhenStopped!;
      _ambientDungeonWhenStopped = null; // clear before await to prevent double-trigger
      await startAmbient(dungeonId);
    }
  }

  void setMuted(bool muted) {
    if (muted) {
      // Capture what is playing NOW, before we stop anything, so
      // resumeAmbientIfUnmuted() knows what to restart on un-mute.
      _ambientDungeonWhenStopped = _currentAmbientDungeon;
      // _wasMenuPlayingWhenMuted = isMenuAmbientPlaying;
      _isMuted = true;
      _mutedNotifier.value = true;
      unawaited(_ambientPlayer.stop());
      unawaited(_menuPlayer.stop());
    } else {
      // Un-muting: flip the flag first so playMenuAmbient / startAmbient
      // don't bail out early, then resume whatever was playing.
      _isMuted = false;
      _mutedNotifier.value = false;
    }
    unawaited(saveMutedPreference());
  }

  bool get isMuted => _isMuted;

  String? _getAmbientPath(String dungeonId) {
    switch (dungeonId) {
      case 'stone_chamber': return 'ambience/stone_drip.mp3';
      case 'lava_chamber': return 'ambience/lava_rumble.mp3';
      case 'ice_chamber': return 'ambience/ice_crack.mp3';
      case 'crypt_chamber': return 'ambience/crypt_wind.mp3';
      case 'void_chamber': return 'ambience/void_hum.mp3';
      case 'forest_chamber': return 'ambience/forest_whisper.mp3';
      default: return null;
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