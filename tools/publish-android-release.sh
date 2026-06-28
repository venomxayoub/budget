#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel)"
readonly APP_DIR="$REPO_ROOT/budget_manager"
readonly APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"

DRY_RUN=false
NOTES_FILE=""

log() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Build, verify, and publish the signed ARM64 Android APK.

Usage:
  tools/publish-android-release.sh --notes-file FILE
  tools/publish-android-release.sh --dry-run

Options:
  --notes-file FILE  Markdown release notes. Required when publishing.
  --dry-run          Build and verify without creating a GitHub release.
  -h, --help         Show this help.

Environment overrides:
  FLUTTER_BIN         Flutter executable to use.
  JAVA_HOME           JDK 17 installation to use.
  ANDROID_SDK_ROOT    Android SDK containing build-tools.
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

java_major_version() {
  "$1/bin/java" -version 2>&1 \
    | sed -nE '1s/.*version "([0-9]+).*/\1/p'
}

resolve_java_home() {
  local candidate
  local -a candidates=()

  if [[ -n "${JAVA_HOME:-}" ]]; then
    candidates+=("$JAVA_HOME")
  fi
  candidates+=(
    "$HOME/.gradle/jdks/eclipse_adoptium-17-amd64-linux.2"
    "$HOME/.sdkman/candidates/java/current"
    "/usr/lib/jvm/java-17-openjdk"
    "/usr/lib/jvm/java-17-openjdk-amd64"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate/bin/java" ]] \
      && [[ "$(java_major_version "$candidate")" == "17" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  die "JDK 17 was not found. Set JAVA_HOME to a JDK 17 installation."
}

read_pubspec_version() {
  sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' "$1"
}

while (($# > 0)); do
  case "$1" in
    --notes-file)
      (($# >= 2)) || die "--notes-file requires a path"
      NOTES_FILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

if [[ "$DRY_RUN" == false ]]; then
  [[ -n "$NOTES_FILE" ]] || die "--notes-file is required when publishing"
  [[ -s "$NOTES_FILE" ]] || die "Release notes file is missing or empty: $NOTES_FILE"
  NOTES_FILE="$(cd "$(dirname "$NOTES_FILE")" && pwd)/$(basename "$NOTES_FILE")"
fi

for command in git unzip sha256sum sed sort find; do
  require_command "$command"
done
if [[ "$DRY_RUN" == false ]]; then
  require_command gh
  require_command curl
fi

if [[ -z "${FLUTTER_BIN:-}" ]]; then
  FLUTTER_BIN="$(command -v flutter || true)"
  if [[ -z "$FLUTTER_BIN" && -x "$HOME/flutter/bin/flutter" ]]; then
    FLUTTER_BIN="$HOME/flutter/bin/flutter"
  fi
fi
[[ -n "$FLUTTER_BIN" && -x "$FLUTTER_BIN" ]] \
  || die "Flutter was not found. Set FLUTTER_BIN to the Flutter executable."

JAVA_HOME="$(resolve_java_home)"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
export ANDROID_SDK_ROOT
[[ -d "$ANDROID_SDK_ROOT/build-tools" ]] \
  || die "Android build-tools not found under $ANDROID_SDK_ROOT"

APKSIGNER="$(find "$ANDROID_SDK_ROOT/build-tools" -type f -name apksigner -print \
  | sort -V | tail -n 1)"
AAPT="$(find "$ANDROID_SDK_ROOT/build-tools" -type f -name aapt -print \
  | sort -V | tail -n 1)"
[[ -x "$APKSIGNER" ]] || die "apksigner was not found in Android build-tools"
[[ -x "$AAPT" ]] || die "aapt was not found in Android build-tools"

cd "$REPO_ROOT"

log "Checking repository state"
[[ -z "$(git status --porcelain)" ]] \
  || die "The worktree must be clean before releasing."
git fetch --quiet origin master

if [[ "$DRY_RUN" == false ]]; then
  log "Checking GitHub authentication"
  gh auth status >/dev/null
  REPOSITORY="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
  git fetch --quiet origin --tags
else
  REPOSITORY="$(git remote get-url origin)"
fi

HEAD_SHA="$(git rev-parse HEAD)"
REMOTE_MASTER_SHA="$(git rev-parse origin/master)"
[[ "$HEAD_SHA" == "$REMOTE_MASTER_SHA" ]] \
  || die "HEAD must exactly match origin/master. HEAD=$HEAD_SHA origin/master=$REMOTE_MASTER_SHA"

log "Validating release version"
PUBSPEC_VERSION="$(read_pubspec_version "$APP_DIR/pubspec.yaml")"
[[ "$PUBSPEC_VERSION" == *+* ]] \
  || die "pubspec.yaml version must use name+build format"
VERSION_NAME="${PUBSPEC_VERSION%+*}"
BUILD_NUMBER="${PUBSPEC_VERSION##*+}"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || die "Invalid build number: $BUILD_NUMBER"

ANDROID_VERSION_NAME="$(sed -nE 's/.*versionName = "([^"]+)".*/\1/p' \
  "$APP_DIR/android/app/build.gradle.kts")"
ANDROID_BUILD_NUMBER="$(sed -nE 's/.*versionCode = ([0-9]+).*/\1/p' \
  "$APP_DIR/android/app/build.gradle.kts")"
SIDEBAR_VERSION="$(sed -nE "s/.*const version = '([^']+)'.*/\1/p" \
  "$APP_DIR/lib/widgets/sidebar.dart")"

[[ "$ANDROID_VERSION_NAME" == "$VERSION_NAME" ]] \
  || die "versionName ($ANDROID_VERSION_NAME) does not match pubspec ($VERSION_NAME)"
[[ "$ANDROID_BUILD_NUMBER" == "$BUILD_NUMBER" ]] \
  || die "versionCode ($ANDROID_BUILD_NUMBER) does not match pubspec ($BUILD_NUMBER)"
[[ "$SIDEBAR_VERSION" == "$VERSION_NAME" ]] \
  || die "Sidebar version ($SIDEBAR_VERSION) does not match pubspec ($VERSION_NAME)"

TAG="v$VERSION_NAME"
if [[ "$DRY_RUN" == false ]]; then
  if git show-ref --verify --quiet "refs/tags/$TAG" \
    || git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1 \
    || gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
    die "Release tag already exists: $TAG"
  fi

  LATEST_TAG="$(gh release list --repo "$REPOSITORY" --limit 1 \
    --json tagName --jq '.[0].tagName // empty')"
  if [[ -n "$LATEST_TAG" ]] && git rev-parse "$LATEST_TAG^{commit}" >/dev/null 2>&1; then
    LATEST_PUBSPEC_VERSION="$(git show "$LATEST_TAG:budget_manager/pubspec.yaml" \
      | sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p')"
    if [[ "$LATEST_PUBSPEC_VERSION" == *+* ]]; then
      LATEST_VERSION_NAME="${LATEST_PUBSPEC_VERSION%+*}"
      LATEST_BUILD_NUMBER="${LATEST_PUBSPEC_VERSION##*+}"
      ((BUILD_NUMBER > LATEST_BUILD_NUMBER)) \
        || die "Build $BUILD_NUMBER must be greater than released build $LATEST_BUILD_NUMBER"
      [[ "$VERSION_NAME" != "$LATEST_VERSION_NAME" ]] \
        || die "Version $VERSION_NAME is already released"
      HIGHEST_VERSION="$(printf '%s\n%s\n' "$LATEST_VERSION_NAME" "$VERSION_NAME" \
        | sort -V | tail -n 1)"
      [[ "$HIGHEST_VERSION" == "$VERSION_NAME" ]] \
        || die "Version $VERSION_NAME must be newer than $LATEST_VERSION_NAME"
    fi
  fi
fi

printf 'Repository: %s\nVersion:    %s\nBuild:      %s\nTag:        %s\nCommit:     %s\n' \
  "$REPOSITORY" "$VERSION_NAME" "$BUILD_NUMBER" "$TAG" "$HEAD_SHA"

log "Running Flutter checks"
cd "$APP_DIR"
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" analyze
"$FLUTTER_BIN" test

log "Building signed ARM64 release APK"
"$FLUTTER_BIN" build apk --target-platform android-arm64 --release
[[ -f "$APK_PATH" ]] || die "APK was not created at $APK_PATH"

log "Verifying APK architecture, signature, and metadata"
NATIVE_LIBS="$(unzip -Z1 "$APK_PATH" | sed -n '/^lib\//p')"
[[ -n "$NATIVE_LIBS" ]] || die "APK does not contain native libraries"
while IFS= read -r library; do
  [[ "$library" == lib/arm64-v8a/* ]] \
    || die "Unexpected non-ARM64 library in APK: $library"
done <<<"$NATIVE_LIBS"

"$APKSIGNER" verify --verbose "$APK_PATH" >/dev/null
BADGING="$($AAPT dump badging "$APK_PATH")"
APK_VERSION_NAME="$(sed -nE "s/^package:.*versionName='([^']+)'.*/\1/p" <<<"$BADGING")"
APK_BUILD_NUMBER="$(sed -nE "s/^package:.*versionCode='([^']+)'.*/\1/p" <<<"$BADGING")"
[[ "$APK_VERSION_NAME" == "$VERSION_NAME" ]] \
  || die "APK versionName ($APK_VERSION_NAME) does not match $VERSION_NAME"
[[ "$APK_BUILD_NUMBER" == "$BUILD_NUMBER" ]] \
  || die "APK versionCode ($APK_BUILD_NUMBER) does not match $BUILD_NUMBER"

APK_SHA256="$(sha256sum "$APK_PATH" | cut -d ' ' -f 1)"
APK_SIZE="$(stat -c '%s' "$APK_PATH")"
printf 'APK:        %s\nSize:       %s bytes\nSHA-256:    %s\n' \
  "$APK_PATH" "$APK_SIZE" "$APK_SHA256"

cd "$REPO_ROOT"
[[ -z "$(git status --porcelain)" ]] \
  || die "Build changed tracked or untracked source files; refusing to publish."

if [[ "$DRY_RUN" == true ]]; then
  log "Dry run complete; GitHub release was not created"
  exit 0
fi

COMBINED_NOTES="$(mktemp)"
trap 'rm -f "$COMBINED_NOTES"' EXIT
{
  cat "$NOTES_FILE"
  printf '\n\n### Build\n\n'
  printf -- '- Version: `%s`\n' "$VERSION_NAME"
  printf -- '- Build: `%s`\n' "$BUILD_NUMBER"
  printf -- '- APK SHA-256: `%s`\n' "$APK_SHA256"
} >"$COMBINED_NOTES"

log "Publishing $TAG"
gh release create "$TAG" \
  --repo "$REPOSITORY" \
  --target "$HEAD_SHA" \
  --title "$TAG" \
  --notes-file "$COMBINED_NOTES" \
  "$APK_PATH"

log "Verifying published release"
PUBLISHED_TARGET="$(gh release view "$TAG" --repo "$REPOSITORY" \
  --json targetCommitish --jq .targetCommitish)"
PUBLISHED_DIGEST="$(gh release view "$TAG" --repo "$REPOSITORY" \
  --json assets --jq '.assets[] | select(.name == "app-release.apk") | .digest')"
RELEASE_URL="$(gh release view "$TAG" --repo "$REPOSITORY" --json url --jq .url)"

[[ "$PUBLISHED_TARGET" == "$HEAD_SHA" ]] \
  || die "Published target ($PUBLISHED_TARGET) does not match $HEAD_SHA"
[[ "$PUBLISHED_DIGEST" == "sha256:$APK_SHA256" ]] \
  || die "Published APK digest ($PUBLISHED_DIGEST) does not match local APK"
curl -fsSIL "https://github.com/$REPOSITORY/releases/latest/download/app-release.apk" \
  >/dev/null

log "Release published successfully"
printf '%s\n' "$RELEASE_URL"
