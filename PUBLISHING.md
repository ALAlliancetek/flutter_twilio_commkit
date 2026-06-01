# Publishing to pub.dev

This guide walks through every step required to publish the four `flutter_twilio_commkit` packages to [pub.dev](https://pub.dev).

---

## Pre-flight checklist

Work through this list **before** running `dart pub publish`.

### 1. GitHub repository

- [ ] Create a public GitHub repository, e.g. `https://github.com/your-org/flutter_twilio_commkit`
- [ ] Push all four packages to it
- [ ] Replace every occurrence of `your-org` in the four `pubspec.yaml` files with your real GitHub username/org

### 2. Update pubspec.yaml URLs (all 4 packages)

Change the placeholder URLs to your real repository:

```yaml
repository: https://github.com/<your-org>/flutter_twilio_commkit
homepage:   https://github.com/<your-org>/flutter_twilio_commkit
issue_tracker: https://github.com/<your-org>/flutter_twilio_commkit/issues
```

### 3. Switch `path:` dependencies to version references

`path:` dependencies are only valid **locally**. Before publishing, each package that references another via `path:` must use a version constraint instead.

Update `flutter_twilio_commkit/pubspec.yaml`:

```yaml
dependencies:
  flutter_twilio_commkit_platform_interface: ^0.1.0   # was: path: ../...
  flutter_twilio_commkit_android: ^0.1.0              # was: path: ../...
  flutter_twilio_commkit_ios: ^0.1.0                  # was: path: ../...
```

Update `flutter_twilio_commkit_android/pubspec.yaml`:

```yaml
dependencies:
  flutter_twilio_commkit_platform_interface: ^0.1.0   # was: path: ../...
```

Update `flutter_twilio_commkit_ios/pubspec.yaml`:

```yaml
dependencies:
  flutter_twilio_commkit_platform_interface: ^0.1.0   # was: path: ../...
```

> **Tip:** Keep a `pubspec_local.yaml` or a Git branch (`local-dev`) that retains the `path:` references for local development.

### 4. LICENSE

- [ ] Replace `Copyright (c) 2026 Your Organization` in `LICENSE` with your real name / organization name.

### 5. Verify static analysis passes

```bash
# Run from each package root
cd flutter_twilio_commkit_platform_interface && dart analyze
cd ../flutter_twilio_commkit_android && dart analyze
cd ../flutter_twilio_commkit_ios && dart analyze
cd ../flutter_twilio_commkit && flutter analyze
```

All packages must have **zero errors**.

### 6. Verify package score preview

```bash
cd flutter_twilio_commkit
dart pub publish --dry-run
```

Check for any warnings about missing docs, bad pubspec fields, etc.

---

## Publishing order

**You must publish the packages in dependency order** — each package must be on pub.dev before packages that depend on it.

```
Step 1 → flutter_twilio_commkit_platform_interface
Step 2 → flutter_twilio_commkit_android
Step 3 → flutter_twilio_commkit_ios
Step 4 → flutter_twilio_commkit
```

---

## Step-by-step commands

### Authenticate with pub.dev

```bash
dart pub login
# Opens a browser — log in with your Google account
```

### Step 1 — Publish platform_interface

```bash
cd flutter_twilio_commkit_platform_interface
dart pub publish
```

Wait for the package to appear on pub.dev (usually < 1 minute) before proceeding.

### Step 2 — Publish Android package

```bash
cd ../flutter_twilio_commkit_android
dart pub publish
```

### Step 3 — Publish iOS package

```bash
cd ../flutter_twilio_commkit_ios
dart pub publish
```

### Step 4 — Publish main package

```bash
cd ../flutter_twilio_commkit
dart pub publish
```

---

## After publishing

1. Visit `https://pub.dev/packages/flutter_twilio_commkit` and verify the pub score
2. Star your own package to help visibility
3. Add topics on pub.dev if not auto-populated from pubspec.yaml
4. Share the package link in the [Flutter Community Discord](https://discord.gg/flutter) and [r/FlutterDev](https://reddit.com/r/FlutterDev)

---

## Releasing a new version

1. Update the version in **all 4 `pubspec.yaml` files** (keep them in sync)
2. Add an entry to `CHANGELOG.md` at the top
3. Commit and tag: `git tag v0.2.0 && git push --tags`
4. Publish in order: platform_interface → android → ios → main

---

## pub.dev scoring

pub.dev scores packages across five categories. Here is where `flutter_twilio_commkit` stands:

| Category | Max | Status |
|---|---|---|
| Follow Dart file conventions | 10 | ✅ analysis_options.yaml, flutter_lints |
| Provide documentation | 20 | ✅ dartdoc on all public symbols |
| Platform support | 20 | ✅ Android + iOS declared |
| Pass static analysis | 50 | ✅ zero errors |
| Support up-to-date deps | — | ✅ modern constraint ranges |

Target score: **130 / 130**

---

## FAQ

### Can I publish without a GitHub repository?

Yes, but the `repository:` and `issue_tracker:` fields will be missing, which lowers discoverability and pub.dev score. A public GitHub repo is strongly recommended.

### Do I need Twilio credentials to publish?

No. The native Twilio SDKs are pulled in by Gradle (Android) and CocoaPods (iOS) at **build time** in the host app — they are not bundled into the pub package itself.

### Is there a conflict with the Twilio brand?

Twilio's terms allow building and publishing open-source wrappers. The package name does not claim to be an official Twilio product — it is a community SDK. Consider adding a disclaimer to your README: *"This is an unofficial community SDK, not affiliated with or endorsed by Twilio."*

### What about the `audioplayers` transitive dependency?

`audioplayers` is used only for the ringtone feature in `TwilioIncomingCallScreen`. It is an optional runtime feature — if `ringtonePath` is `null`, the player is never initialized. The dependency is lightweight and well-maintained.

