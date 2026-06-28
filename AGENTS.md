# Repository Instructions

## Android releases

- The production device is a Samsung S22 Ultra, so release APKs must target ARM64 only.
- Build with:

  ```bash
  flutter build apk --target-platform android-arm64 --release
  ```

- Do not use `flutter build apk --release` without `--target-platform android-arm64`.
  That produces a universal APK containing ARM64, ARMv7, and x86_64 libraries and
  increases the artifact from roughly 7 MB to roughly 22 MB.
- Publish `budget_manager/build/app/outputs/flutter-apk/app-release.apk` as
  `app-release.apk`; the in-app updater depends on that exact asset name.
