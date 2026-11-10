#!/usr/bin/env bash
set -euo pipefail
# Generate platform scaffolding in isolation without replacing application files.
template=$(mktemp -d)
trap 'rm -rf "$template"' EXIT
flutter create --platforms=android,ios --org com.choisangjin --project-name ai_skills_curation "$template/app"
for platform in android ios; do
  if [ ! -d "$platform" ]; then cp -R "$template/app/$platform" "$platform"; fi
done
python3 - <<'PY'
from pathlib import Path
p = Path('android/app/build.gradle.kts')
s = p.read_text()
if 'abiFilters' not in s:
    s = s.replace('defaultConfig {', 'defaultConfig {\n        ndk { abiFilters.clear(); abiFilters.add("arm64-v8a") }')
p.write_text(s)
p = Path('android/app/src/main/AndroidManifest.xml')
s = p.read_text()
if 'android.permission.INTERNET' not in s:
    s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
if 'android:allowBackup' not in s:
    s = s.replace('<application', '<application android:allowBackup="false"', 1)
p.write_text(s)
PY
flutter pub get
