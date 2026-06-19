import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';
import 'package:memory_dungeon/constants.dart';

final consentControllerProvider =
    AsyncNotifierProvider.autoDispose<ConsentController, bool>(
      ConsentController.new,
    );

class ConsentController extends AsyncNotifier<bool> {
  var logger = Logger();
  ConsentStatus? status;

  // bool get hasConsent =>
  //     status == ConsentStatus.obtained || status == ConsentStatus.notRequired;

  @override
  FutureOr<bool> build() async {
    status = await ConsentInformation.instance.getConsentStatus();
    return (status == ConsentStatus.obtained ||
        status == ConsentStatus.notRequired);
  }

  void updateConsent() {
    final params = ConsentRequestParameters(
      tagForUnderAgeOfConsent: false,
      consentDebugSettings: ConsentDebugSettings(
        debugGeography:
            kIsDebugMode
                ? DebugGeography.debugGeographyEea
                : DebugGeography.debugGeographyDisabled,
      ),
    );
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          _loadForm();
        }
      },
      (FormError error) {
        logger.e(error);
      },
    );
  }

  void _loadForm() {
    ConsentForm.loadConsentForm(
      (consentForm) async {
        status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show((formError) {
            logger.e(formError);
            _loadForm();
          });
        }
      },
      (formError) {
        logger.e(formError);
      },
    );
  }

  Future<void> debugReset() async {
    await ConsentInformation.instance.reset();
  }
}