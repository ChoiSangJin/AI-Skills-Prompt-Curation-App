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

## Preserved local production key (AI Moa)

The production key is kept outside Git at `/workspace/credentials/ai-moa/release.p12`, with its private password file `release.password`. Only the public fingerprint in `signing/release-certificate.sha256` is committed. Preserve this entire credential directory when moving environments and keep a secure independent backup. Never regenerate the key when restoring an environment: the initializer refuses if a public pin exists but the original private key is missing.

For every update, keep application ID `com.choisangjin.ai_skills_curation`, increase `versionCode`, and build with the same key:

```sh
python3 tool/local-release.py
```

This checks the private key against the committed public certificate, signs the release and verifies the resulting APK. GitHub Secrets are optional: without them CI creates test-only artifacts and never publishes them as releases. Production APKs can be uploaded from this trusted workspace after verification. Existing development-signed installations require one migration reinstall.

### Optional CI production releases

GitHub Secrets are not required for local signing or uploading a verified APK. If an administrator wants CI to publish releases automatically, upload the already-preserved key (never generate another one):

```sh
bash tool/configure-release-signing.sh /workspace/credentials/ai-moa
```

This optional step needs repository Secrets write access. It uploads ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD and ANDROID_SIGNING_CERT_SHA256. Main CI checks the fixed public pin before signing; PR/test builds use disposable keys and are never published as production releases.

### Publishing an already signed local APK

The `Publish verified signed APK` workflow can upload a local production APK through GitHub Actions' own repository token; no private signing key or password is sent to Actions. Stage only the public APK, its checksum, public certificate fingerprint and release-info.json on a temporary `release-assets/vX.Y.Z` branch. The staged workflow must be the reviewed publish-presigned.yml from main; pushes can trigger publication, or maintainers can dispatch it manually. The job validates artifact hashes, package/version metadata, the pinned signer and source commit ancestry before publishing. It refuses to overwrite an already published release. Do not include private credentials in asset branches.
