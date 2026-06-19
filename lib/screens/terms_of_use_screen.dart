import 'package:flutter/material.dart';
import '../models/dungeon_config.dart';
import '../theme/dungeon_theme.dart';
import '../widgets/hud_element.dart';
import '../widgets/torch_overlay.dart';
import '../widgets/ambient_particles.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

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
                        'TERMS OF USE',
                        style: DungeonTheme.getShopTitleStyle(context, const Color(0xFFF1C40F)),
                      ),
                      const SizedBox(width: 60),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Scrollable Content
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              _buildSection(
                                context,
                                title: '1. ACCEPTANCE OF TERMS',
                                content:
                                    'By downloading, installing, or playing Memory Dungeon ("the App"), you agree to be bound by these Terms of Use. If you do not agree, do not use the App. These terms apply to all users, guests, and visitors of the App.',
                              ),
                              _buildSection(
                                context,
                                title: '2. LICENSE TO USE',
                                content:
                                    'We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial entertainment purposes. You may not modify, reverse-engineer, distribute, or create derivative works from the App or any of its content.',
                              ),
                              _buildSection(
                                context,
                                title: '3. USER CONDUCT',
                                content:
                                    'You agree not to: cheat, exploit, or use third-party tools to gain an unfair advantage; modify or tamper with game data; attempt to access other users\' data; use the App for any unlawful purpose; or harass, abuse, or harm other users. Violation may result in permanent restriction of access.',
                              ),
                              _buildSection(
                                context,
                                title: '4. PRIVACY & DATA',
                                content:
                                    'Memory Dungeon stores all game progress, settings, and preferences locally on your device. We do not collect, transmit, or store personal data on any server. No telemetry, analytics, or advertising networks are used. Your campaign progress, high scores, and preferences remain entirely on your device unless you choose to share them.',
                              ),
                              _buildSection(
                                context,
                                title: '5. INTELLECTUAL PROPERTY',
                                content:
                                    'All content within the App — including but not limited to graphics, audio, text, icons, images, game mechanics, rune designs, card art, and written descriptions — is the exclusive property of the App developer and is protected by applicable copyright, trademark, and other intellectual property laws. You may not copy, reproduce, or redistribute any portion of the App\'s content without express written permission.',
                              ),
                              _buildSection(
                                context,
                                title: '6. IN-APP PURCHASES & VIRTUAL CURRENCY',
                                content:
                                    'Memory Dungeon may offer virtual items, currency, or enhancements for purchase. All purchases are final and non-refundable. Virtual currency and items have no real-world monetary value, cannot be exchanged for real currency, and may only be used within the App. We reserve the right to modify, discontinue, or modify the availability of any in-app offerings.',
                              ),
                              _buildSection(
                                context,
                                title: '7. LIMITATION OF LIABILITY',
                                content:
                                    'The App is provided "as is" and "as available" without warranties of any kind, either express or implied. The developer shall not be liable for any damages arising from the use or inability to use the App, including but not limited to data loss, device damage, or loss of progress. Your use of the App is at your own risk.',
                              ),
                              _buildSection(
                                context,
                                title: '8. THIRD-PARTY SERVICES',
                                content:
                                    'The App may integrate with third-party services (e.g., Firebase for crash reporting, audio playback libraries). These services are governed by their own terms and privacy policies. We encourage you to review their policies. Integration with third-party services does not imply endorsement or affiliation.',
                              ),
                              _buildSection(
                                context,
                                title: '9. MODIFICATIONS TO TERMS',
                                content:
                                    'We reserve the right to update or modify these Terms at any time without prior notice. Continued use of the App after changes constitutes acceptance of the new terms. We will notify users of material changes through an in-app notice or update the "Last Updated" date below.',
                              ),
                              _buildSection(
                                context,
                                title: '10. TERMINATION',
                                content:
                                    'We reserve the right to suspend or terminate your access to the App at our sole discretion, without notice, for conduct that we believe violates these Terms or is harmful to other users, the developer, or third parties.',
                              ),
                              _buildSection(
                                context,
                                title: '11. CONTACT',
                                content:
                                    'If you have any questions about these Terms, please contact us at: wilfred.cruz.ph@gmail.com',
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Last Updated: June 19, 2026',
                                style: DungeonTheme.getBodyStyle(10, Colors.white30),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
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

  Widget _buildSection(BuildContext context, {required String title, required String content}) {
    return HudElement(
      padding: const EdgeInsets.all(16),
      borderRadius: 10,
      seed: title.hashCode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: DungeonTheme.getGothicStyle(13, const Color(0xFFF1C40F), weight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: DungeonTheme.getBodyStyle(11, Colors.white70).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}