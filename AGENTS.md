# Eyebottlelee Quick Guide (AI Sidekick Edition)

## Before You Start: Read the Map
- Treat `docs/medical-recording-prd.md` as the mission briefing and `docs/developing.md` as the daily checklist. Read or re-check them before you move code around so our direction and schedule stay aligned.

## Map of the House (Project Layout)
- `lib/` is the main control room for the app.
  - `lib/services/`: like recording and scheduling robots that manage audio tasks and calendars.
  - `lib/ui/`: the stage where screens and widgets perform for users.
  - `lib/models/`: blueprints that describe our data shapes.
  - `lib/utils/`: handy tool drawer for shared helpers.
- `docs/`: living knowledge base—update it when features or timelines change so future helpers stay in sync.
- `assets/icons/`: icon wardrobe for tray/app images.
- `scripts/`: buttons that keep WSL and Windows copies in step (`sync_wsl_to_windows.sh`) and PowerShell helpers under `scripts/windows/`.
- `windows/runner/`: Windows desktop build bits—check Flutter version compatibility before tweaking platform code.

## Everyday Buttons (Commands)
- `flutter pub get` — refresh dependencies; like restocking the fridge before cooking.
- `flutter run -d windows` — launch the Windows build to see UI and audio behavior in action.
- `flutter analyze` and `flutter test` — lint and unit tests; run them together so bugs are caught early. If tests are missing, add at least a starter stub.
- `pwsh -File scripts/windows/generate-placeholder-icons.ps1` — spin up dev icon placeholders.
- `bash scripts/sync_wsl_to_windows.sh` — manually mirror WSL work into the Windows checkout when needed.

## How We Write Code
- Follow the official Dart style; run `dart format` (or your IDE’s auto-format) before committing.
- Naming: files/classes use UpperCamelCase, private members begin with `_`, constants shout in `UPPER_SNAKE_CASE`.
- Widgets in `lib/ui/widgets/` follow the `FeatureRoleWidget` pattern. Services end with `FeatureService` for consistency.

## Tests Are Safety Nets
- Place tests under `test/` using `<target>_test.dart` names.
- Prioritize unit tests for recording segments, schedule math, and cleanup logic—mock services where helpful.
- For long recording scenarios, follow the Phase 0 soak plan notes and log manual outcomes even if automated tests are pending.

## Commit & PR Storytelling
- Prefix commit messages (`docs:`, `feat:`, `fix:`…) and keep the summary within ~50 characters.
- PRs should list changes, affected modules, and test results (`flutter analyze`, `flutter test`, manual checks) in a simple table.
- When closing issues, include `Fixes #123` or `Refs #123` for traceability.
- UI updates may need a Windows screenshot; sync script changes should update `docs/sync-workflow.md` too.

## Keeping WSL & Windows in Sync
- Post-commit hook triggers `scripts/sync_wsl_to_windows.sh`; if hooks are off, run it yourself.
- Before syncing, close editors touching the Windows path `C:\\ws-workspace\\eyebottlelee` to avoid file conflicts.
- New scripts need executable bits (`chmod +x`) and a matching PowerShell version under `scripts/windows/`.

## Security & Settings
- Keep secrets in `.env` or OS key stores—never commit them.
- Review `pubspec.yaml` changes against the roadmap in `docs/developing.md` to avoid plan drift.
- Windows auto-start or OneDrive flows rely on admin rights; if they fail, align UI hints and docs with that reality.

## How to Explain Things to the User
- Assume the user is brand-new to coding. Use plain, friendly sentences and short steps.
- Prefer everyday analogies ("like restocking the fridge") to describe tricky ideas.
- Highlight only the core actions first; add extras after confirming the user is ready.
- Offer numbered options when suggesting next steps so the user can pick easily.
- If you must mention advanced terms, define them right away in simple words.
- Double-check the current date (today is October 4, 2025) and cite exact dates when plans depend on timing.

## When in Doubt
- Pause and re-read the docs, then ask the user gentle clarifying questions.
- Keep responses concise but encouraging—think supportive coach rather than textbook.
