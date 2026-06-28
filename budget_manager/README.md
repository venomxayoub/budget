# Budget Manager

A Flutter expense and income tracking app exclusively for Android mobile
devices. Desktop, web, iOS, and other generated Flutter targets are not
supported release platforms for this project.

This is a personal, local-only, single-user application intended to run on one
personal phone (a Samsung S22 Ultra). It is not designed as a public,
multi-device, multi-user, or cloud-synchronized product.

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

The production device is a Samsung S22 Ultra. Always build an **ARM64-only**
release:

```bash
flutter build apk --target-platform android-arm64 --release
```

The APK is output to `build/app/outputs/flutter-apk/app-release.apk`.
It should be approximately 7–8 MB. Do not omit `--target-platform android-arm64`:
the default command packages ARM64, ARMv7, and x86_64 together and produces an
unnecessary universal APK of approximately 22 MB.

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
- **Private app storage** — the database is no longer exposed in shared storage
- **Android Auto Backup** — the private database is eligible for encrypted device backup
- **Pre-migration safety** — the app copies your database before any upgrade, and runs migrations atomically

If upgrading from a release that stored data in `/storage/emulated/0/budget_manager`,
open the sidebar, choose **Import Previous Data**, and select `budget_manager.db`.
The Android system picker grants access only to that file; broad storage permission is not required.

## Development

```bash
flutter run
flutter analyze
```
