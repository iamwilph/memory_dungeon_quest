// import 'dart:convert';

// import 'package:web/web.dart' as web;

// import '../models/campaign_progress.dart';
// import 'campaign_progress_store.dart';

// class LocalCampaignProgressStore implements CampaignProgressStore {
//   static const _storageKey = 'memory_dungeon.campaign_progress';

//   @override
//   Future<void> clear() async {
//     web.window.localStorage.removeItem(_storageKey);
//   }

//   @override
//   Future<CampaignProgress?> load() async {
//     final raw = web.window.localStorage.getItem(_storageKey);
//     if (raw == null) return null;

//     final decoded = jsonDecode(raw);
//     if (decoded is! Map) return null;

//     return CampaignProgress.fromJson(Map<String, Object?>.from(decoded));
//   }

//   @override
//   Future<void> save(CampaignProgress progress) async {
//     web.window.localStorage.setItem(_storageKey, jsonEncode(progress.toJson()));
//   }
// }
