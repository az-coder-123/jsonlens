import 'package:flutter_test/flutter_test.dart';
import 'package:jsonlens/features/version_check/version_notifier.dart';

void main() {
  group('compareVersions', () {
    test('detects newer major', () {
      expect(VersionNotifier.compareVersions('2.0.0', '1.9.9'), 1);
    });

    test('detects older patch', () {
      expect(VersionNotifier.compareVersions('1.2.3', '1.2.4'), -1);
    });

    test('handles different lengths', () {
      expect(VersionNotifier.compareVersions('1.2', '1.2.0'), 0);
      expect(VersionNotifier.compareVersions('1.2.1', '1.2'), 1);
    });

    test('non-numeric parts fall back to 0', () {
      expect(VersionNotifier.compareVersions('1.2.alpha', '1.2.0'), 0);
    });
  });
}
