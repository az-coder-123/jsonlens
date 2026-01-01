# Version Check — JSONLens

This document explains how the **Version Check** feature works in JSONLens, how it is implemented, how to test it, and suggested improvements.

## Purpose
- Provide an unobtrusive, **non-blocking** notification when a new app version is available.
- Minimize network usage and avoid interrupting the user experience.
- Cache results to avoid repeated requests on each launch.

## High-level flow
1. On app startup (post-frame) the app will force a network version check (non-blocking). It also checks when manually triggered (e.g., from About).
2. The app first verifies network connectivity. If offline, the check is skipped.
3. If cached data exists and is fresh (TTL: 1 hour by default), the cached result is used.
4. When a new version is detected, the app shows a small single-line banner in the bottom-right with a message like: `New version 1.2.3 available`.
5. Users can tap the banner to see release notes and open the download link.

## API used
- Supabase REST endpoint (provided):

```bash
curl --location 'https://lezadwcqeaufwdnxntoe.supabase.co/rest/v1/jsonlens?select=version%2Crelease_notes%2C%20download_at%2Ccreated_at&order=version.desc&limit=1' \
  --header 'apikey: sb_publishable_yPx-x3qexCa56EMkbtw0mw_6b8ma8Tc'
```

- Important: the app now expects `version` as an **integer build number** when used to determine update availability. The notifier compares this integer to the platform-specific integer returned by `AppVersions.current()`.

- Recommended response schema (integer `version`):

```json
[
  {
    "version": 2,
    "release_notes": "Improvements and fixes",
    "download_at": "https://example.com/download",
    "created_at": "2026-01-01T00:00:00Z"
  }
]
```

- Backward compatibility: if `version` is not an integer, the app treats it as *no new version* (no update detected). This simplifies platform-specific build checks and avoids semantic parsing issues.

## Implementation notes
- Files to inspect:
  - `lib/features/version_check/version_service.dart` — fetches data from API
  - `lib/features/version_check/version_info.dart` — model + (de)serialization
  - `lib/features/version_check/version_notifier.dart` — Riverpod StateNotifier; caching and TTL, connectivity check, compare logic
  - `lib/features/version_check/version_banner.dart` — bottom-right banner UI
  - `lib/features/version_check/about_dialog.dart` — About dialog with release notes and manual check
- Caching:
  - Uses `SharedPreferences` keys: `version_info_json` and `version_info_ts` (timestamp).
  - TTL default: 3600 seconds (1 hour). You can adjust `_cacheTtlSeconds` in `version_notifier.dart`.
- Connectivity:
  - Uses `connectivity_plus` to detect whether to perform a network call.
  - If no network, check is skipped silently (app behavior remains unaffected).
- Version comparison:
  - `compareVersions(a, b)` compares numeric dotted versions component-wise.
  - We fallback non-numeric parts to `0` (safe for simple semver-like strings).

## UI behaviour
- Banner:
  - Small, single-line, bottom-right, animated.
  - Tap opens a modal showing release notes and an “Update” button (opens `download_at` via `url_launcher`).
- Manual flow:
  - AppBar has a “Check for updates” button that triggers a forced check and shows a brief SnackBar with results.
- Non-blocking:
  - All network calls are performed off the UI thread and the app remains responsive.

## Testing steps
1. Launch app with network; confirm cached data if present is shown immediately (no UI blocking).
2. Trigger manual check via the AppBar button and observe SnackBar result.
3. Tap the bottom-right banner to view release notes and press `Update` (will open the URL).
4. Test offline behavior (airplane mode): manual check should show 'no network' behavior (no crash), cached result remains.
5. Unit tests: `test/version_utils_test.dart` verifies version comparison logic.

## Privacy & security
- The API key used is the Supabase *publishable* key (public). For increased security use a server-side proxy if you want to hide the key.
- No PII is sent to the version endpoint.
- Cache content is stored locally in `SharedPreferences` (no encryption). If the response contains sensitive info, consider encrypting or using a secure storage.
