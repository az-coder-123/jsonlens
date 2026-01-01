import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import 'version_notifier.dart';

class AboutAppDialog extends ConsumerStatefulWidget {
  const AboutAppDialog({super.key});

  @override
  ConsumerState<AboutAppDialog> createState() => _AboutAppDialogState();
}

class _AboutAppDialogState extends ConsumerState<AboutAppDialog> {
  bool _checking = false;
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _currentVersion = pkg.version);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(versionNotifierProvider);

    final latest = state.info?.latestVersion ?? '—';
    final notes = state.info?.releaseNotes ?? 'No release notes available.';

    return AlertDialog(
      title: Text(
        '${AppStrings.appName} — About',
        style: GoogleFonts.jetBrainsMono(),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current version: $_currentVersion',
              style: GoogleFonts.jetBrainsMono(),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Text('Latest version: $latest', style: GoogleFonts.jetBrainsMono()),
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              'Release notes:',
              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(
                  notes,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: GoogleFonts.jetBrainsMono()),
        ),
        TextButton(
          onPressed: _checking
              ? null
              : () async {
                  setState(() => _checking = true);
                  await ref
                      .read(versionNotifierProvider.notifier)
                      .checkForUpdateIfConnected(force: true);
                  setState(() => _checking = false);
                },
          child: _checking
              ? const SizedBox(
                  width: 24,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Check for updates', style: GoogleFonts.jetBrainsMono()),
        ),
        if (state.info?.downloadAt != null)
          TextButton(
            onPressed: () async {
              final url = Uri.parse(state.info!.downloadAt!);
              try {
                await launchUrl(url);
              } catch (_) {}
            },
            child: Text('Update', style: GoogleFonts.jetBrainsMono()),
          ),
      ],
    );
  }
}
