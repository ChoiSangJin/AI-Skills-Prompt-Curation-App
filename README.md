# AI 모아 — AI 도구와 프롬프트 큐레이션

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

## Gemini connection troubleshooting

The app discovers currently available text-generation models with `models.list` instead of pinning an aging model. Key verification lists models without spending generation quota; generation permissions and quota are checked on the first actual generation. A model can be changed in Settings after verification.

- 404: model unavailable; refresh the model list by confirming the key again.
- 429: project/model rate or quota limit; check AI Studio quota and billing. A valid key may still receive this error. No automatic quota retries.
- 503: provider temporarily unavailable; retry later.
- 401/403: check the key, API restrictions and supported region.

Provider response bodies and API keys are never shown in error messages. Tests use mocked HTTP responses; a user-owned live key and device remain necessary for real quota and storage validation.

Brand palette: #FFC7C7, #FFE2E2, #F6F6F6, #8785A2, with dark text for contrast. Launcher source and pre-sized Android/iOS icons are checked in under assets/branding; platform preparation applies them on every build.
