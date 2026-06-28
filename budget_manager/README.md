# Budget Manager

A Flutter expense and income tracking app exclusively for Android mobile
devices. Desktop, web, iOS, and other generated Flutter targets are not
supported release platforms for this project.

This is a personal, local-only, single-user application intended to run on one
personal phone (a Samsung S22 Ultra). It is not designed as a public,
multi-device, multi-user, or cloud-synchronized product.

## Building the APK

Use the release script in dry-run mode from the repository root:

```bash
tools/publish-android-release.sh --dry-run
```

It resolves JDK 17, runs `flutter pub get`, analysis, and the full test suite,
then builds and verifies the signed ARM64-only APK. Set `FLUTTER_BIN`,
`JAVA_HOME`, or `ANDROID_SDK_ROOT` only when automatic toolchain discovery does
not match the local installation.

The resulting file is:

```text
build/app/outputs/flutter-apk/app-release.apk
```

The production device is a Samsung S22 Ultra, so releases must remain
ARM64-only. Do not remove `--target-platform android-arm64`; a universal APK
also packages ARMv7 and x86_64 libraries and is roughly three times larger.

## Updating the App

When you need to publish a new version, use the following workflow.

### 1. Bump the version

Update all three version declarations and commit them to `master`:

- `pubspec.yaml`: `version: <name>+<build>`
- `android/app/build.gradle.kts`: `versionName` and `versionCode`
- `lib/widgets/sidebar.dart`: displayed `version`

For example, a `1.2.2+10` release requires:

```text
# pubspec.yaml
version: 1.2.2+10

# android/app/build.gradle.kts
versionCode = 10
versionName = "1.2.2"

# lib/widgets/sidebar.dart
const version = '1.2.2';
```

The release script rejects inconsistent versions, versions that do not move
forward, duplicate tags, dirty worktrees, and commits that do not exactly match
`origin/master`.

### 2. Write release notes

Create a Markdown file outside the worktree so the repository remains clean:

```bash
$EDITOR /tmp/budget-v1.2.2-notes.md
```

The script appends the version, build number, and APK SHA-256 automatically.

### 3. Build and publish

Run:

```bash
tools/publish-android-release.sh \
  --notes-file /tmp/budget-v1.2.2-notes.md
```

The script derives the `v<version>` tag, targets the full `origin/master`
commit SHA, uploads the artifact as `app-release.apk`, confirms the remote
digest, and verifies the in-app updater's latest-download URL. The release
artifact should be approximately 7–8 MB.

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
