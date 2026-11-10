#!/usr/bin/env bash
# Run on your own trusted computer with an admin-capable GitHub CLI login.
set -euo pipefail
umask 077
repo=ChoiSangJin/AI-Skills-Prompt-Curation-App
signing_dir=${1:?Usage: bash tool/configure-release-signing.sh /absolute/private/backup-directory}
for binary in gh keytool python3; do command -v "$binary" >/dev/null; done
# Check access and refuse accidental rotation before creating any material.
existing=$(gh secret list --repo "$repo" --json name)
printf '%s' "$existing" | python3 -c 'import json,sys; names={x["name"] for x in json.load(sys.stdin)}; sys.exit("Signing secrets already exist; do not rotate the key.") if names & {"ANDROID_KEYSTORE_BASE64","ANDROID_KEYSTORE_PASSWORD","ANDROID_SIGNING_CERT_SHA256"} else None'
mkdir -p "$signing_dir"
chmod 700 "$signing_dir"
if [ -e "$signing_dir/release.p12" ] || [ -e "$signing_dir/password" ]; then
  echo 'Existing backup found. Refusing to replace it.' >&2; exit 1
fi
python3 - "$signing_dir/password" <<'PY'
import secrets,sys
from pathlib import Path
Path(sys.argv[1]).write_text(secrets.token_urlsafe(48))
PY
keytool -genkeypair -keystore "$signing_dir/release.p12" -storetype PKCS12 -alias ai-moa -keyalg RSA -keysize 3072 -sigalg SHA256withRSA -validity 10000 -dname 'CN=AI Moa Release' -storepass:file "$signing_dir/password" -keypass:file "$signing_dir/password" >/dev/null 2>&1
python3 - "$signing_dir" <<'PY'
import base64,hashlib,subprocess,sys
from pathlib import Path
root=Path(sys.argv[1])
(root/'keystore.base64').write_text(base64.b64encode((root/'release.p12').read_bytes()).decode())
cert=subprocess.run(['keytool','-exportcert','-keystore',str(root/'release.p12'),'-alias','ai-moa','-storepass:file',str(root/'password')],check=True,capture_output=True).stdout
(root/'certificate.sha256').write_text(hashlib.sha256(cert).hexdigest())
PY
# Values are streamed to GitHub, never included in command arguments or output.
gh secret set ANDROID_KEYSTORE_BASE64 --repo "$repo" < "$signing_dir/keystore.base64"
gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$repo" < "$signing_dir/password"
gh secret set ANDROID_SIGNING_CERT_SHA256 --repo "$repo" < "$signing_dir/certificate.sha256"
rm "$signing_dir/keystore.base64"
echo 'Fixed signing configured. Keep release.p12 and password in a secure, independent backup.'
