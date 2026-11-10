#!/usr/bin/env bash
# Optional: enable CI production releases using the ALREADY preserved local key.
set -euo pipefail
umask 077
repo=ChoiSangJin/AI-Skills-Prompt-Curation-App
signing_dir=${1:-/workspace/credentials/ai-moa}
checkout=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
python3 "$checkout/tool/init-local-signing.py" "$signing_dir"
existing=$(gh secret list --repo "$repo" --json name)
printf '%s' "$existing" | python3 -c 'import json,sys; names={x["name"] for x in json.load(sys.stdin)}; sys.exit("Signing secrets already exist; do not rotate the key.") if names & {"ANDROID_KEYSTORE_BASE64","ANDROID_KEYSTORE_PASSWORD","ANDROID_KEY_ALIAS","ANDROID_KEY_PASSWORD"} else None'
python3 - "$signing_dir/release.p12" <<'PYCODE' | gh secret set ANDROID_KEYSTORE_BASE64 --repo "$repo"
import base64,sys
from pathlib import Path
sys.stdout.write(base64.b64encode(Path(sys.argv[1]).read_bytes()).decode())
PYCODE
gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$repo" < "$signing_dir/release.password"
printf %s ai-moa | gh secret set ANDROID_KEY_ALIAS --repo "$repo"
gh secret set ANDROID_KEY_PASSWORD --repo "$repo" < "$signing_dir/release.password"
echo 'Optional CI signing enabled with the existing local release identity.'
