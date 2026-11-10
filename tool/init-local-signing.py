"""Create this app's private key once, outside the checkout. Never rotate it."""
import hashlib,os,secrets,subprocess,sys
from pathlib import Path
os.umask(0o077)
checkout=Path(__file__).resolve().parent.parent
root=Path(sys.argv[1] if len(sys.argv)>1 else '/workspace/credentials/ai-moa').resolve()
if root.is_relative_to(checkout): raise SystemExit('Private keys must stay outside the checkout.')
pin=checkout/'signing/release-certificate.sha256'
key=root/'release.p12'; password=root/'release.password'
if pin.exists() and not key.exists(): raise SystemExit('Existing certificate is pinned. Restore the original key backup; never generate a replacement.')
if key.exists() != password.exists(): raise SystemExit('Incomplete credentials. Restore the original key/password backup.')
root.mkdir(parents=True,exist_ok=True);root.chmod(0o700)
if not key.exists():
 password.write_text(secrets.token_urlsafe(48));password.chmod(0o600)
 subprocess.run(['keytool','-genkeypair','-keystore',str(key),'-storetype','PKCS12','-alias','ai-moa','-keyalg','RSA','-keysize','3072','-sigalg','SHA256withRSA','-validity','10000','-dname','CN=AI Moa Release','-storepass:file',str(password),'-keypass:file',str(password)],capture_output=True,check=True)
 key.chmod(0o600)
cert=subprocess.run(['keytool','-exportcert','-keystore',str(key),'-alias','ai-moa','-storepass:file',str(password)],capture_output=True,check=True).stdout
fingerprint=hashlib.sha256(cert).hexdigest()
if pin.exists() and pin.read_text().strip()!=fingerprint: raise SystemExit('Wrong key: certificate differs from the pinned release identity.')
pin.parent.mkdir(exist_ok=True);pin.write_text(fingerprint+'\n')
(root/'certificate.sha256').write_text(fingerprint+'\n')
print('AI Moa release key preserved. Public certificate SHA-256:',fingerprint)
