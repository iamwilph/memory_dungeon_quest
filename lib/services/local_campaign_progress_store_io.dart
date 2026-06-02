import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/campaign_progress.dart';
import 'campaign_progress_store.dart';

class LocalCampaignProgressStore implements CampaignProgressStore {
  static const _fileName = 'campaign_progress.json';

  @override
  Future<void> clear() async {
    final file = await _progressFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<CampaignProgress?> load() async {
    final file = await _progressFile();
    if (!await file.exists()) return null;

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    return CampaignProgress.fromJson(Map<String, Object?>.from(decoded));
  }

  @override
  Future<void> save(CampaignProgress progress) async {
    final file = await _progressFile();
    await file.writeAsString(jsonEncode(progress.toJson()), flush: true);
  }

  Future<File> _progressFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }
}
