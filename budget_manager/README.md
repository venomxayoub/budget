# Budget Manager

A Flutter expense and income tracking app for Android.

## Updating the App

When you need to publish a new version:

### 1. Bump the version

In `android/app/build.gradle.kts`:

```groovy
defaultConfig {
    versionCode = 2  // increment by 1 each release
    versionName = "1.0.1"  // update as needed
}
```

### 2. Rebuild the APK

```bash
flutter build apk --target-platform android-arm64 --release
```

The APK is output to `build/app/outputs/flutter-apk/app-release.apk`.

### 3. Publish a GitHub release

```bash
gh release create v1.0.1 \
  --title "v1.0.1" \
  --notes "Release notes here" \
  build/app/outputs/flutter-apk/app-release.apk
```

### 4. Install on device

Download the APK from the GitHub release on your Samsung S22 Ultra and open it. Since the APK is signed with the same `keystore.jks`, Android will treat it as an update to the existing install — no data loss.

Your data is also protected by:
- **Android Auto Backup** — data is automatically backed up to Google Drive
- **Pre-migration safety** — the app copies your database before any upgrade, and runs migrations atomically

## Development

```bash
flutter run
flutter analyze
```
