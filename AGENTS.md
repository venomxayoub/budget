# Repository Instructions

## Safe change process

- Start every task from the repository root with:

  ```bash
  git status --short --branch
  git diff --check
  ```

- Treat existing dirty files as user work. Do not reset, overwrite, reformat,
  or stage unrelated changes.
- Read the relevant source and tests before editing:
  - Persistence: `budget_manager/lib/database/database_helper.dart`
  - Business state: `budget_manager/lib/providers/transaction_provider.dart`
  - Models: `budget_manager/lib/models/`
  - UI: `budget_manager/lib/screens/` and `budget_manager/lib/widgets/`
  - Behavior coverage: `budget_manager/test/`
- Keep changes scoped. Do not move persistence into widgets, duplicate provider
  state, change money from integer cents, or weaken tests to match a broken
  implementation.
- Use the canonical validation command before handing work back:

  ```bash
  FLUTTER_BIN="$HOME/.local/share/flutter/bin/flutter" tools/check.sh
  ```

- If a task needs commits, group them by purpose. Stage explicit files or hunks,
  then commit with a short message that names the purpose.
- If a task needs publishing, commit and push first. The release script requires
  a clean worktree and `HEAD == origin/master`.

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
