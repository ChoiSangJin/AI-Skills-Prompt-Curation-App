"""Restore four signing inputs without logging credential values."""
import base64,hashlib,os,re,subprocess
from pathlib import Path

root=Path(os.environ['RUNNER_TEMP'])
required=['ANDROID_KEYSTORE_BASE64','ANDROID_KEYSTORE_PASSWORD','ANDROID_KEY_ALIAS','ANDROID_KEY_PASSWORD']
if any(not os.environ.get(name) for name in required):
    raise SystemExit('Missing required Android signing Secrets; all four inputs are required.')
key=root/'ai-moa-release.p12'
files={
    'ai-moa-release.password':os.environ['ANDROID_KEYSTORE_PASSWORD'],
    'ai-moa-release.alias':os.environ['ANDROID_KEY_ALIAS'],
    'ai-moa-release.key-password':os.environ['ANDROID_KEY_PASSWORD'],
}
try:
    data=base64.b64decode(''.join(os.environ['ANDROID_KEYSTORE_BASE64'].split()),validate=True)
except ValueError:
    raise SystemExit('Invalid Android keystore base64.') from None
key.write_bytes(data);key.chmod(0o600)
for name,value in files.items():
    path=root/name;path.write_text(value);path.chmod(0o600)
args=['keytool','-J-Duser.language=en','-J-Duser.country=US','-keystore',str(key),'-storepass:file',str(root/'ai-moa-release.password')]
try:
    listing=subprocess.run(args+['-list'],check=True,capture_output=True,text=True).stdout
    store_type=re.search(r'^Keystore type:\s*(JKS|PKCS12)\s*$',listing,re.MULTILINE)
    if not store_type:raise ValueError('Unsupported keystore type')
    cert=subprocess.run(args+['-exportcert','-alias',os.environ['ANDROID_KEY_ALIAS']],check=True,capture_output=True).stdout
    # This reads the private key too, so an incorrect independent key password
    # fails before compilation. The generated public CSR is not printed.
    subprocess.run(args+['-certreq','-alias',os.environ['ANDROID_KEY_ALIAS'],'-keypass:file',str(root/'ai-moa-release.key-password')],check=True,capture_output=True)
except (subprocess.CalledProcessError,ValueError):
    raise SystemExit('Signing credential verification failed. Check the four registered signing Secrets.') from None
fingerprint=hashlib.sha256(cert).hexdigest()
if os.environ.get('AI_MOA_TEST_SIGNING')=='1':
    expected=os.environ.get('AI_MOA_EXPECTED_CERT_SHA256','').strip()
else:
    expected=Path('signing/release-certificate.sha256').read_text().strip()
if not expected or fingerprint!=expected:
    raise SystemExit('Signing certificate differs from the pinned release identity; refusing release.')
(root/'ai-moa-release.store-type').write_text(store_type[1])
(root/'ai-moa-release.fingerprint').write_text(fingerprint)
print('Signing credentials and pinned certificate verified; values were not printed.')
