# AI Skills & Prompt Curation

Flutter client for Android ARM64 and iOS. GitHub trends are cached in SQLite for 12 hours. Gemini summaries and task recipes use a user-supplied API key stored with flutter_secure_storage. Offline sample recipes require no key.

## Development

With Flutter 3.38.5, Android SDK and Java 17 available:

```
bash tool/prepare.sh
flutter analyze --no-fatal-infos
flutter run
flutter build apk --release --target-platform android-arm64
```

The preparation script generates Android/iOS scaffolding without replacing Dart code, restricts Android native ABIs to ARM64, enables Internet access, and disables Android backup. iOS builds require macOS/Xcode; verify Keychain entitlements and signing on the target device. Android release builds currently use Flutter's development signing configuration. Configure a persistent private release keystore before production distribution; builds signed by different temporary keys cannot update each other in place.

## Download

After CI succeeds on main, open this repository's **Releases** page and download `app-release.apk`. It supports Android ARM64 devices. Pull requests expose an APK as a workflow artifact instead. GitHub Actions must be enabled and allowed to create releases.

## Verification status

Android analysis and compilation run in the linked GitHub Actions workflow on every PR. Check the workflow result for the exact commit before installing its artifact. Device secure storage/SQLite behavior and live Gemini API integration still require device validation.

GitHub search has its own low unauthenticated rate limit. When offline or rate limited the app retains cached data. Gemini requests send task text or public repository metadata to Google and may incur API charges. Keys can be removed in Settings.
