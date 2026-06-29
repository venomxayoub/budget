# Repository Instructions

## Android releases

- The production device is a Samsung S22 Ultra, so release APKs must target ARM64 only.
- Use the canonical release script from the repository root:

  ```bash
  tools/publish-android-release.sh --dry-run
  ```

- Publish with `tools/publish-android-release.sh --notes-file <markdown-file>`.
- The script must retain its ARM64, signature, version, clean-master, full-SHA,
  asset-digest, and tag-specific download verification gates.
- The asset is uploaded as `BudgetManager-v{version}.apk` on the release.
- The in-app updater links to
  `releases/download/v{version}/BudgetManager-v{version}.apk` (tag-specific,
  not `/latest/download/`), so the version baked into the sidebar at build time
  always resolves to its own release.
