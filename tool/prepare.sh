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
import shutil
import plistlib
import re
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
s = re.sub(r'android:label="[^"]*"', 'android:label="AI 모아"', s)
p.write_text(s)
for icon in Path('assets/branding/android').glob('mipmap-*/*.png'):
    target = Path('android/app/src/main/res') / icon.parent.name / icon.name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(icon, target)
p = Path('ios/Runner/Info.plist')
with p.open('rb') as f: info = plistlib.load(f)
info['CFBundleDisplayName'] = 'AI 모아'
with p.open('wb') as f: plistlib.dump(info, f)
for icon in Path('assets/branding/ios').glob('*.png'):
    shutil.copyfile(icon, Path('ios/Runner/Assets.xcassets/AppIcon.appiconset') / icon.name)
PY
flutter pub get
