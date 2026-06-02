import '../models/campaign_progress.dart';

abstract class CampaignProgressStore {
  Future<CampaignProgress?> load();
  Future<void> save(CampaignProgress progress);
  Future<void> clear();
}

class MemoryCampaignProgressStore implements CampaignProgressStore {
  CampaignProgress? _progress;

  MemoryCampaignProgressStore([this._progress]);

  CampaignProgress? get progress => _progress;

  @override
  Future<void> clear() async {
    _progress = null;
  }

  @override
  Future<CampaignProgress?> load() async {
    return _progress;
  }

  @override
  Future<void> save(CampaignProgress progress) async {
    _progress = progress;
  }
}
