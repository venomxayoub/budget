# Budget Manager

A Flutter expense and income tracking app exclusively for Android mobile
devices. Desktop, web, iOS, and other generated Flutter targets are not
supported release platforms for this project.

This is a personal, local-only, single-user application intended to run on one
personal phone (a Samsung S22 Ultra). It is not designed as a public,
multi-device, multi-user, or cloud-synchronized product.

## Deterministic Contributor Guide

This section is the operating guide for coding agents, especially smaller
models. Follow it literally. Do not replace these workflows with a plausible
alternative: consistency and preservation of user data are more important than
shorter code or fewer commands.

### Start with the real repository state

Run all Git and release commands from the repository root. Run Flutter checks
inside `budget_manager` unless the command below says otherwise.

```bash
git status --short --branch
git diff --check
```

The worktree may already contain user changes. Do not reset or overwrite them,
and do not format or include unrelated files. Read the relevant screen,
provider method, database method, model, and behavior tests before changing a
feature.

Repository responsibilities:

| Area | Source of truth |
| --- | --- |
| Persistent data and migrations | `lib/database/database_helper.dart` |
| In-memory state and business operations | `lib/providers/transaction_provider.dart` |
| Stored record shapes | `lib/models/` |
| User behavior | `lib/screens/`, `docs/`, and behavior tests under `test/` |
| Android build and publication | `tools/publish-android-release.sh` |

Do not put persistence directly in a screen, duplicate provider state inside a
widget, or create a second release workflow.

### Use the correct Flutter SDK

On the primary development machine, use the current SDK at
`$HOME/.local/share/flutter/bin/flutter`. `$HOME/flutter/bin/flutter` is an
older SDK and can rewrite `pubspec.lock` to older transitive dependencies.

```bash
export FLUTTER_BIN="${FLUTTER_BIN:-$HOME/.local/share/flutter/bin/flutter}"
tools/check.sh
```

`tools/check.sh` runs `pub get`, analysis, the complete test suite with
coverage, and the coverage threshold gate. It also refreshes local Flutter
tooling files with the correct SDK, which avoids stale `.dart_tool` references
to the older `$HOME/flutter` checkout. After `pub get`, verify that
`pubspec.lock` did not change unless dependency changes were explicitly
requested. Use a targeted test while developing, then run the canonical check
before handing work back. A failing intended-behavior test is a bug signal; do
not skip it, weaken its assertion, or rewrite it to match the current
implementation.

### Preserve these product invariants

Money is stored as integer cents. Never add floating-point money columns or
perform financial calculations with `double`.

Entries:

- Expenses and incomes share one chronological Entries view but remain
  separate stored record types and category sets.
- Editing changes the existing record; it must not create a duplicate or
  replace its original creation date.
- Delete means soft-delete to Archive. Entry deletion, restoration, and
  permanent deletion do not use confirmation dialogs.
- Archived entries can be restored or permanently deleted.

Categories:

- Expense and income categories are separate. Never use an expense-category ID
  for an income or the reverse.
- A fresh database seeds the default categories. Adding one category must not
  reseed or replace the other category set.

Debts and loans:

- Positive balance means the other person owes the user; negative means the
  user owes the other person.
- `gave` increases the balance, `received` decreases it, and `update` sets the
  complete signed balance rather than applying a difference.
- Archiving a profile keeps its complete transaction history. An archived
  profile cannot be renamed or receive new transactions.
- Debt profile and debt transaction deletion require confirmation.

Subscriptions:

- Creating a subscription always creates one Expense payment immediately.
- Editing name, price, frequency, or renewal date never creates a payment.
- Pause and Cancel are distinct states, but both stop renewal processing.
- Unpause and Uncancel reset the renewal anchor to today, create an immediate
  payment, and schedule the next renewal from today.
- The startup/resume processor runs at most once per local calendar day and
  creates every missed renewal exactly once.
- Monthly and annual recurrence retains its original day anchor across short
  months and leap years.
- A subscription payment is the same Expense object shown in Entries and in
  subscription history. Archive, restore, edit, and permanent deletion must be
  reflected in both views.
- Subscription payments use the automatically created or reused
  `Subscription` expense category.

Database changes:

- Increase the SQLite database version for every schema change.
- Add a forward migration and update fresh-database and legacy-migration tests.
- Preserve existing rows. Never drop user data to make a migration easier.
- Keep multi-record operations atomic and idempotent. Write completion flags
  only after all related records commit successfully.
- Continue accepting valid legacy databases through Import Previous Data.

### Choose the canonical command

| Requested outcome | Command or action |
| --- | --- |
| Check one behavior while developing | `"$FLUTTER_BIN" test --no-pub test/<file>_test.dart` |
| Validate all source changes | From repo root: `tools/check.sh` |
| Build and verify a release candidate | From repo root: `FLUTTER_BIN="$HOME/.local/share/flutter/bin/flutter" tools/publish-android-release.sh --dry-run` |
| Publish an Android release | From repo root: `FLUTTER_BIN="$HOME/.local/share/flutter/bin/flutter" tools/publish-android-release.sh --notes-file <markdown-file>` |

Do not use `flutter build apk` directly for a release outcome. Do not manually
upload an APK, create a partial tag, use a short commit SHA, or rename the
release asset. The script is the only supported path because it performs the
same architecture, signature, version, clean-master, full-SHA, digest, and
tag-specific download checks every time.

GitHub Actions runs `tools/check.sh` on pull requests and pushes to `master`.
If local and CI results disagree, treat CI as a signal to inspect environment
drift rather than bypassing the failing gate.

Before handing work back:

1. Confirm only intended files changed with `git status --short`.
2. Run `git diff --check`.
3. Run targeted tests while developing, then `tools/check.sh`.
4. Report any failing behavior precisely; do not hide an unresolved failure.
5. Do not claim an APK or release exists unless the canonical script completed
   and its final verification passed.

### Regression guard

`test/debt_rename_regression_test.dart` protects against a previous bug where
the debt-profile rename dialog disposed its `TextEditingController` before the
dialog exit animation finished. Keep this test enabled and passing.

## Building the APK

Use the release script in dry-run mode from the repository root:

```bash
tools/publish-android-release.sh --dry-run
```

It resolves JDK 17, runs `flutter pub get`, analysis, and the full test suite,
then builds and verifies the signed ARM64-only APK. Set `FLUTTER_BIN`,
`JAVA_HOME`, or `ANDROID_SDK_ROOT` only when automatic toolchain discovery does
not match the local installation.

The resulting APK at `build/app/outputs/flutter-apk/app-release.apk` is
uploaded to the release as `BudgetManager-v{version}.apk`.

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
commit SHA, uploads the artifact as `BudgetManager-v{version}.apk`,
confirms the remote digest, and verifies the in-app updater's tag-specific
download URL. The release artifact should be approximately 7–8 MB.

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
export FLUTTER_BIN="${FLUTTER_BIN:-$HOME/.local/share/flutter/bin/flutter}"
cd budget_manager
"$FLUTTER_BIN" run
cd ..
tools/check.sh
```
