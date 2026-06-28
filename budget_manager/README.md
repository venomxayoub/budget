# Budget Manager

A Flutter expense and income tracking app exclusively for Android mobile
devices. Desktop, web, iOS, and other generated Flutter targets are not
supported release platforms for this project.

This is a personal, local-only, single-user application intended to run on one
personal phone (a Samsung S22 Ultra). It is not designed as a public,
multi-device, multi-user, or cloud-synchronized product.

## Building the APK

The Android release build requires Flutter, the Android SDK, and JDK 17. Ensure
`JAVA_HOME` points to a JDK 17 installation; newer JDKs may not be compatible
with the project's Gradle and Kotlin versions.

From the repository root, run:

```bash
cd budget_manager
flutter pub get
flutter analyze
flutter test
flutter build apk --target-platform android-arm64 --release
```

If the shell has an invalid or incompatible `JAVA_HOME`, set it for the build:

```bash
JAVA_HOME=/path/to/jdk-17 \
  flutter build apk --target-platform android-arm64 --release
```

The build is signed using the release configuration in
`android/app/build.gradle.kts`. The resulting file is:

```text
build/app/outputs/flutter-apk/app-release.apk
```

The production device is a Samsung S22 Ultra, so releases must remain
ARM64-only. Do not remove `--target-platform android-arm64`; a universal APK
also packages ARMv7 and x86_64 libraries and is roughly three times larger.

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

Follow [Building the APK](#building-the-apk). The release artifact should be
approximately 7–8 MB.

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
