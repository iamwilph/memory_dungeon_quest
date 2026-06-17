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
  }

  late final AudioPlayer _sfxPlayer;   // Short sounds, overlap-friendly
  late final AudioPlayer _ambientPlayer; // Long looping ambient tracks

  bool _isMuted = false;
  late ValueNotifier<bool> _mutedNotifier;

  /// Exposed for reactive UI — widgets can listen via ValueListenableBuilder.
  ValueListenable<bool> get mutedValue => _mutedNotifier;

  String? _currentAmbientDungeon;

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
      debugPrint('loading $path audio for $dungeonId');
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

  void setMuted(bool muted) {
    _isMuted = muted;
    _mutedNotifier.value = muted; // Notify all listeners
    // Persist the preference immediately
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
    _sfxPlayer.dispose();
    _ambientPlayer.dispose();
  }
}