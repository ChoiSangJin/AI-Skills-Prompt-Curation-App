"""Validate pre-signed public artifacts without loading any private signing key."""
import hashlib,json,os,re,shutil,subprocess
from pathlib import Path
incoming=Path('incoming')
info=json.loads((incoming/'release-info.json').read_text())
pin=Path('signing/release-certificate.sha256').read_text().strip()
apk=incoming/'app-release.apk'
assert re.fullmatch(r'[0-9a-f]{40}',info['source_commit'])
assert info['certificate_sha256']==pin
assert info['application_id']=='com.choisangjin.ai_skills_curation'
assert os.environ['RELEASE_TAG']=='v'+info['version_name']
assert hashlib.sha256(apk.read_bytes()).hexdigest()==info['apk_sha256']
assert (incoming/'app-release.apk.sha256').read_text().split()[0]==info['apk_sha256']
sdk=Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])
tools=list((sdk/'build-tools').glob('*/aapt2'))
aapt=max(tools,key=lambda p:tuple(map(int,re.findall(r'\d+',p.parent.name))))
report=subprocess.check_output([str(aapt),'dump','badging',str(apk)],text=True)
assert "name='"+info['application_id']+"'" in report.splitlines()[0]
assert "versionCode='"+str(info['version_code'])+"'" in report.splitlines()[0]
assert "versionName='"+info['version_name']+"'" in report.splitlines()[0]
output=Path('build/app/outputs/flutter-apk');output.mkdir(parents=True,exist_ok=True)
shutil.copyfile(apk,output/'app-release.apk')
root=Path(os.environ['RUNNER_TEMP'])
(root/'ai-moa-release.fingerprint').write_text(pin)
(root/'release-notes.md').write_text('AI 모아 '+info['version_name']+' — 고정 배포 키 적용\n\n앱 ID와 배포 인증서를 유지하고 versionCode를 증가시키는 방식으로 업데이트합니다. 이전 개발 서명판에서는 이번 전환에 한해 재설치가 필요하며, 삭제 시 로컬 데이터가 삭제됩니다. 이후 동일 키로 서명된 더 높은 버전은 기존 앱 위에 업데이트할 수 있습니다. 개인 키와 비밀번호는 공개 저장소 및 릴리스에 포함하지 않았습니다.\n')
print('APK hash, application ID, version and pinned certificate metadata verified.')
