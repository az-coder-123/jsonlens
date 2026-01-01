import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import 'version_notifier.dart';

/// Small bottom-right single-line banner that shows new version text (if available)
class VersionBanner extends ConsumerWidget {
  const VersionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(versionNotifierProvider);

    // Do not render if no new version
    if (state.info == null || !state.hasNew) return const SizedBox.shrink();

    final text = 'New version ${state.info!.latestVersion} available';

    return Positioned(
      right: AppDimensions.paddingM,
      bottom: AppDimensions.paddingM + 24, // above bottom bar
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          color: AppColors.surface,
          child: InkWell(
            onTap: () async {
              // open download link if present
              final url = state.info!.downloadAt;
              if (url != null && url.isNotEmpty) {
                // open externally
                // use url_launcher here if needed
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update, color: AppColors.primary, size: 18),
                  const SizedBox(width: AppDimensions.paddingS),
                  Text(
                    text,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: AppDimensions.fontSizeS,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
