import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:memory_dungeon/constants.dart';

/// Returns the appropriate banner ad unit ID based on the platform.
/// Both platforms currently return test ad unit IDs — replace with
/// your real ad unit IDs before production builds.
String _bannerAdUnitId() {
  if (Platform.isAndroid) {
    return kIsDebugMode
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-1090169600845784/1674195813';
  } else if (Platform.isIOS) {
    return kIsDebugMode
        ? 'ca-app-pub-3940256099942544/2934735716'
        : 'ca-app-pub-1090169600845784/6415386600';
  }
  return ''; // Fallback — no ad on unsupported platforms
}

/// A widget that displays a Google Mobile Ads banner ad.
/// Returns [SizedBox.shrink] if the ad fails to load.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Ad loaded: ${ad.responseInfo}');
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Ad failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null || !kShowAds) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: _bannerAd!.size.height.toDouble(),
      width: _bannerAd!.size.width.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
