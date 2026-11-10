"""Restore CI-only signing material; never print credential values."""
import os, base64, hashlib, subprocess
from pathlib import Path
root = Path(os.environ['RUNNER_TEMP'])
required = ['ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_SIGNING_CERT_SHA256']
if any(not os.environ.get(name) for name in required):
    raise SystemExit('Missing release-signing secrets. Run tool/configure-release-signing.sh locally with repository admin access.')
key = root / 'ai-moa-release.p12'
password = root / 'ai-moa-release.password'
key.write_bytes(base64.b64decode(os.environ['ANDROID_KEYSTORE_BASE64'], validate=True))
password.write_text(os.environ['ANDROID_KEYSTORE_PASSWORD'])
key.chmod(0o600)
password.chmod(0o600)
cert = subprocess.run(['keytool', '-exportcert', '-keystore', str(key), '-alias', 'ai-moa', '-storepass:file', str(password)], check=True, capture_output=True).stdout
fingerprint = hashlib.sha256(cert).hexdigest()
expected = os.environ['ANDROID_SIGNING_CERT_SHA256'].replace(':', '').lower().strip()
if fingerprint != expected:
    raise SystemExit('Signing certificate fingerprint mismatch; refusing release.')
pin = Path('signing/release-certificate.sha256')
if os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('GITHUB_EVENT_NAME') != 'pull_request' and os.environ.get('AI_MOA_TEST_SIGNING') != '1' and pin.exists() and pin.read_text().strip() != fingerprint:
    raise SystemExit('Production certificate differs from the pinned release identity.')
(root / 'ai-moa-release.fingerprint').write_text(fingerprint)
print('Fixed release keystore restored and fingerprint verified.')
