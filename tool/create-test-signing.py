"""PR-only disposable key: validates release signing without production secrets."""
import base64, hashlib, os, secrets, subprocess, tempfile
from pathlib import Path
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    password = secrets.token_urlsafe(48)
    key_password = secrets.token_urlsafe(48)
    key_password_file = root / 'key-password'
    key_password_file.write_text(key_password)
    key_password_file.chmod(0o600)
    password_file = root / 'password'
    password_file.write_text(password)
    password_file.chmod(0o600)
    key = root / 'test.p12'
    subprocess.run(['keytool','-genkeypair','-keystore',str(key),'-storetype','JKS','-alias','ci-test-alias','-keyalg','RSA','-keysize','2048','-validity','2','-dname','CN=Disposable CI Test Only','-storepass:file',str(password_file),'-keypass:file',str(key_password_file)], check=True, capture_output=True)
    cert = subprocess.run(['keytool','-exportcert','-keystore',str(key),'-alias','ci-test-alias','-storepass:file',str(password_file)],check=True,capture_output=True).stdout
    environment = {**os.environ, 'AI_MOA_TEST_SIGNING': '1', 'ANDROID_KEYSTORE_BASE64': base64.b64encode(key.read_bytes()).decode(), 'ANDROID_KEYSTORE_PASSWORD': password, 'ANDROID_KEY_ALIAS': 'ci-test-alias', 'ANDROID_KEY_PASSWORD': key_password, 'AI_MOA_EXPECTED_CERT_SHA256': hashlib.sha256(cert).hexdigest()}
    subprocess.run(['python3',str(Path(__file__).with_name('restore-signing.py'))],env=environment,check=True)
print('Disposable PR test certificate only; not a production signing identity.')
