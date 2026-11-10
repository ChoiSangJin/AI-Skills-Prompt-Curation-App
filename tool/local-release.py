"""Build and verify a release using the preserved key; never generate a key."""
import base64,os,subprocess,sys,tempfile,shutil,urllib.parse
from pathlib import Path
checkout=Path(__file__).resolve().parent.parent
os.chdir(checkout)
root=Path(sys.argv[1] if len(sys.argv)>1 else '/workspace/credentials/ai-moa')
key=root/'release.p12';password=root/'release.password'
pin=checkout/'signing/release-certificate.sha256'
if not all(p.is_file() for p in [key,password,pin]): raise SystemExit('Restore the preserved release key, password and certificate pin before building.')
gradle=Path(os.environ.get('GRADLE_USER_HOME','/workspace/ai-moa-gradle'))
(gradle/'init.d').mkdir(parents=True,exist_ok=True)
shutil.copyfile(checkout/'tool/gradle.init.gradle',gradle/'init.d/moa.gradle')
# Refresh proxy endpoints from this invocation; cloud bridge ports may change.
proxy=urllib.parse.urlparse(os.environ.get('HTTPS_PROXY',''))
properties=gradle/'gradle.properties'
lines=properties.read_text().splitlines() if properties.exists() else []
lines=[line for line in lines if not line.startswith(('systemProp.http.proxyHost=','systemProp.http.proxyPort=','systemProp.https.proxyHost=','systemProp.https.proxyPort='))]
if proxy.hostname:
 for protocol in ['http','https']:
  lines.extend([f'systemProp.{protocol}.proxyHost={proxy.hostname}',f'systemProp.{protocol}.proxyPort={proxy.port or 80}'])
properties.write_text('\n'.join(lines)+'\n')
with tempfile.TemporaryDirectory() as directory:
 env={**os.environ,'RUNNER_TEMP':directory,'GRADLE_USER_HOME':str(gradle),'GITHUB_STEP_SUMMARY':str(Path(directory)/'summary.md'),'ANDROID_KEYSTORE_BASE64':base64.b64encode(key.read_bytes()).decode(),'ANDROID_KEYSTORE_PASSWORD':password.read_text(),'ANDROID_SIGNING_CERT_SHA256':pin.read_text().strip()}
 subprocess.run(['python3','tool/restore-signing.py'],env=env,check=True)
 env.pop('ANDROID_KEYSTORE_BASE64');env.pop('ANDROID_KEYSTORE_PASSWORD')
 subprocess.run(['bash','tool/prepare.sh'],env=env,check=True)
 env.update(ANDROID_RELEASE_KEYSTORE=str(Path(directory)/'ai-moa-release.p12'),ANDROID_RELEASE_PASSWORD=password.read_text())
 subprocess.run(['flutter','build','apk','--release','--target-platform','android-arm64'],env=env,check=True)
 env.pop('ANDROID_RELEASE_PASSWORD')
 subprocess.run(['python3','tool/verify-apk-signature.py'],env=env,check=True)
 print('Production APK signed with the pinned, preserved certificate: build/app/outputs/flutter-apk/app-release.apk')
