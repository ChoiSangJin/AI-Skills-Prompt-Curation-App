"""Verify cryptographic APK signatures and pin the actual signer certificate."""
import json, os, re, subprocess
from pathlib import Path

root = Path(os.environ['RUNNER_TEMP'])
try:
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])
    tools = list((sdk / 'build-tools').glob('*/apksigner'))
    if not tools:
        raise RuntimeError('Android SDK apksigner was not found.')
    signer = max(tools, key=lambda p: tuple(int(n) for n in re.findall(r'\d+', p.parent.name)))
    result = subprocess.run([str(signer), 'verify', '--verbose', '--print-certs', 'build/app/outputs/flutter-apk/app-release.apk'], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError('apksigner verification failed:\n' + result.stdout + '\n' + result.stderr)
    expected = (root / 'ai-moa-release.fingerprint').read_text().strip().lower()
    actual = set(s.lower() for s in re.findall(r'Signer[^\n]*certificate SHA-256 digest:\s*([0-9a-fA-F]{64})', result.stdout))
    if actual != {expected}:
        raise RuntimeError('APK signer does not match the restored certificate.\nExpected public fingerprint: ' + expected + '\nPublic apksigner report:\n' + result.stdout)
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
        stream.write('Verified APK certificate SHA-256 (PR certificates are disposable tests): `' + expected + '`\n')
    print('APK cryptographic signature and expected certificate verified.')
except Exception as error:
    # Only public APK/certificate information is included; no keystore contents,
    # credential files, environment dumps or passwords enter diagnostics.
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        payload = {'name': 'APK signature diagnostics', 'head_sha': os.environ['GITHUB_SHA'], 'status': 'completed', 'conclusion': 'failure', 'output': {'title': 'APK signature verification failed', 'summary': str(error)[-40000:]}}
        request = root / 'signature-diagnostic.json'
        request.write_text(json.dumps(payload))
        subprocess.run(['gh', 'api', '--method', 'POST', 'repos/' + os.environ['GITHUB_REPOSITORY'] + '/check-runs', '--input', str(request)], stdout=subprocess.DEVNULL, check=False)
    raise SystemExit(str(error))
