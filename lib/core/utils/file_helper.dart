import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Helper utilities for file operations such as saving text files.
///
/// Uses `file_selector` to present a native save dialog and writes the
/// selected path using `dart:io`. If the native save dialog is unavailable
/// (plugin/channel error), falls back to saving a file in the system temp
/// directory and returns the actual path so the UI can present it to the user.
abstract final class FileHelper {
  /// Result of a save operation, optionally containing the saved path.
  static Future<SaveOutcome> saveTextFile({
    required String suggestedName,
    required String contents,
  }) async {
    try {
      // For desktop platforms, present a native Save dialog so the user can
      // choose the destination and filename.
      if (!kIsWeb &&
          (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        final result = await getSaveLocation(
          suggestedName: suggestedName,
          acceptedTypeGroups: [
            XTypeGroup(label: 'JSON', extensions: ['json']),
          ],
        );

        // User cancelled
        if (result == null) return const SaveOutcome._(SaveStatus.cancelled);

        final file = File(result.path);
        await file.writeAsString(contents);
        return SaveOutcome.saved(file.path);
      }

      // Non-desktop (mobile/web): fall back to saving to a temp file and
      // return the path so the caller can present it to the user.
      final tmp = Directory.systemTemp;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$suggestedName';
      final tempFile = File('${tmp.path}/$fileName');
      await tempFile.writeAsString(contents);
      return SaveOutcome.saved(tempFile.path);
    } on PlatformException catch (e, st) {
      // Platform channel couldn't be reached (plugin not registered or channel
      // not available). Fall back to writing to a temporary file and return
      // that path so the user can find the saved content.
      debugPrint('FileHelper.saveTextFile PlatformException: $e');
      debugPrint('Stack: $st');

      try {
        final tmp = Directory.systemTemp;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_$suggestedName';
        final tempFile = File('${tmp.path}/$fileName');
        await tempFile.writeAsString(contents);
        debugPrint('FileHelper fallback saved to ${tempFile.path}');
        return SaveOutcome.saved(tempFile.path);
      } catch (e2, st2) {
        debugPrint('FileHelper fallback failed: $e2');
        debugPrint('Stack: $st2');
        return const SaveOutcome._(SaveStatus.failed);
      }
    } on FileSystemException catch (e, st) {
      // Likely a permissions/sandbox issue — log details for debugging
      debugPrint('FileHelper.saveTextFile FileSystemException: ${e.message}');
      debugPrint('Path: ${e.path}');
      debugPrint('OS Error: ${e.osError}');
      debugPrint('Stack: $st');
      return const SaveOutcome._(SaveStatus.failed);
    } catch (e, st) {
      // General fallback logging
      debugPrint('FileHelper.saveTextFile failed: $e');
      debugPrint('Stack: $st');
      return const SaveOutcome._(SaveStatus.failed);
    }
  }

  /// Open a text file and return its contents (and path if available).
  static Future<OpenOutcome> openTextFile({
    List<String> extensions = const ['json', 'txt'],
  }) async {
    try {
      final groups = [XTypeGroup(label: 'Text', extensions: extensions)];
      final xfile = await openFile(acceptedTypeGroups: groups);

      if (xfile == null) return const OpenOutcome.cancelled();

      // Read contents (XFile provides readAsString)
      final contents = await xfile.readAsString();
      return OpenOutcome.opened(contents, path: xfile.path);
    } on PlatformException catch (e, st) {
      debugPrint('FileHelper.openTextFile PlatformException: $e');
      debugPrint('Stack: $st');
      return const OpenOutcome.failed();
    } catch (e, st) {
      debugPrint('FileHelper.openTextFile failed: $e');
      debugPrint('Stack: $st');
      return const OpenOutcome.failed();
    }
  }
}

enum SaveStatus { saved, cancelled, failed }

/// Outcome wrapper for save operations with optional saved path.
class SaveOutcome {
  final SaveStatus status;
  final String? path;
  const SaveOutcome._(this.status, [this.path]);
  const SaveOutcome.cancelled() : this._(SaveStatus.cancelled);
  const SaveOutcome.failed() : this._(SaveStatus.failed);
  static SaveOutcome saved(String path) =>
      SaveOutcome._(SaveStatus.saved, path);
}

// ------------------------
// Open (load) functionality
// ------------------------

enum OpenStatus { opened, cancelled, failed }

/// Outcome wrapper for file open operations containing contents and path.
class OpenOutcome {
  final OpenStatus status;
  final String? contents;
  final String? path;

  const OpenOutcome._(this.status, {this.contents, this.path});
  const OpenOutcome.cancelled() : this._(OpenStatus.cancelled);
  const OpenOutcome.failed() : this._(OpenStatus.failed);
  static OpenOutcome opened(String contents, {String? path}) =>
      OpenOutcome._(OpenStatus.opened, contents: contents, path: path);
}

extension FileHelperOpen on FileHelper {
  static Future<OpenOutcome> openTextFile({
    List<String> extensions = const ['json', 'txt'],
  }) async {
    try {
      final groups = [XTypeGroup(label: 'Text', extensions: extensions)];
      final xfile = await openFile(acceptedTypeGroups: groups);

      if (xfile == null) return const OpenOutcome.cancelled();

      // Read contents (XFile provides readAsString)
      final contents = await xfile.readAsString();
      return OpenOutcome.opened(contents, path: xfile.path);
    } on PlatformException catch (e, st) {
      debugPrint('FileHelper.openTextFile PlatformException: $e');
      debugPrint('Stack: $st');
      return const OpenOutcome.failed();
    } catch (e, st) {
      debugPrint('FileHelper.openTextFile failed: $e');
      debugPrint('Stack: $st');
      return const OpenOutcome.failed();
    }
  }
}
