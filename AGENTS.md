# Repository Instructions

## Android releases

- The production device is a Samsung S22 Ultra, so release APKs must target ARM64 only.
- Use the canonical release script from the repository root:

  ```bash
  tools/publish-android-release.sh --dry-run
  ```

- Publish with `tools/publish-android-release.sh --notes-file <markdown-file>`.
- The script must retain its ARM64, signature, version, clean-master, full-SHA,
  asset-digest, and latest-download verification gates.
- Publish `budget_manager/build/app/outputs/flutter-apk/app-release.apk` as
  `app-release.apk`; the in-app updater depends on that exact asset name.
