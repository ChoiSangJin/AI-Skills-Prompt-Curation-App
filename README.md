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

The preparation script generates Android/iOS scaffolding without replacing Dart code, restricts Android native ABIs to ARM64, enables Internet access, and disables Android backup. iOS builds require macOS/Xcode; verify Keychain entitlements and signing on the target device. Android release builds require the fixed private release keystore. Missing signing credentials fail the release build; there is no debug-signing fallback.

## Download

After CI succeeds on main, open this repository's **Releases** page and download `app-release.apk`. It supports Android ARM64 devices. Pull requests expose a clearly labeled test-signed APK using a disposable certificate; production signing secrets are not used on PR runs. Do not install PR test APKs as updates to production. GitHub Actions must be enabled and allowed to create releases.

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

## Release identity migration in v1.1.4

Starting with v1.1.4 (versionCode 6), production releases use the four registered GitHub signing Secrets below. The user approved this one-time migration from the v1.1.3 certificate; uninstall/reinstall is required for that transition and removes local app data. Later releases keep this new certificate and increase versionCode to support in-place updates. The application ID remains `com.choisangjin.ai_skills_curation`.

The current public certificate pin is `signing/release-certificate.sha256`. Its check remains mandatory: do not regenerate or replace the registered signing identity on subsequent builds.

The previous v1.1.3 local keystore remains preserved at `/workspace/credentials/ai-moa/release.p12` with its password file. Its public fingerprint is archived at `signing/legacy/v1.1.3-certificate.sha256`. This is a legacy backup, not the v1.1.4 production signing identity. Keep it securely and never upload it to a public branch or release. The local legacy build helper correctly refuses to sign a new release when its certificate differs from the current pin.

### GitHub Actions production signing

Use the already registered repository Secrets; do not regenerate or overwrite them:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The alias and private-key password are independent inputs. JKS and PKCS12 keystores are detected automatically. No extra certificate Secret is needed: the public certificate is checked against `signing/release-certificate.sha256` and a mismatch stops the release to protect in-place updates. PRs validate the release path with a disposable JKS key using a different alias and distinct store/key passwords; production Secrets are never passed to PR jobs. Temporary credential files are removed after every run.

No Secret setup or value updates are required for this repository. The existing registration helper is a legacy utility and refuses to overwrite registered Secrets; it is not part of the v1.1.4 release flow.

### Publishing an already signed local APK

The `Publish verified signed APK` workflow can upload a local production APK through GitHub Actions' own repository token; no private signing key or password is sent to Actions. Stage only the public APK, its checksum, public certificate fingerprint and release-info.json on a temporary `release-assets/vX.Y.Z` branch. The staged workflow must be the reviewed publish-presigned.yml from main; pushes can trigger publication, or maintainers can dispatch it manually. The job validates artifact hashes, package/version metadata, the pinned signer and source commit ancestry before publishing. It refuses to overwrite an already published release. Do not include private credentials in asset branches.
