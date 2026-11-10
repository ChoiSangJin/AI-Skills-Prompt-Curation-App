"""Signing regression tests use disposable credentials only."""
import base64,os,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

class SigningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture=tempfile.TemporaryDirectory()
        root=Path(cls.fixture.name)
        subprocess.run(['python3',str(ROOT/'tool/create-test-signing.py')],env={**os.environ,'RUNNER_TEMP':str(root)},capture_output=True,check=True)
        cls.inputs={
            'ANDROID_KEYSTORE_BASE64':base64.b64encode((root/'ai-moa-release.p12').read_bytes()).decode(),
            'ANDROID_KEYSTORE_PASSWORD':(root/'ai-moa-release.password').read_text(),
            'ANDROID_KEY_ALIAS':(root/'ai-moa-release.alias').read_text(),
            'ANDROID_KEY_PASSWORD':(root/'ai-moa-release.key-password').read_text(),
            'AI_MOA_TEST_SIGNING':'1',
            'AI_MOA_EXPECTED_CERT_SHA256':(root/'ai-moa-release.fingerprint').read_text(),
        }
    @classmethod
    def tearDownClass(cls):cls.fixture.cleanup()
    def restore(self, overrides=None):
        with tempfile.TemporaryDirectory() as d:
            env={**os.environ,**self.inputs,**(overrides or {}),'RUNNER_TEMP':d}
            result=subprocess.run(['python3',str(ROOT/'tool/restore-signing.py')],cwd=ROOT,env=env,capture_output=True,text=True)
            if result.returncode==0:
                self.assertEqual((Path(d)/'ai-moa-release.store-type').read_text(),'JKS')
                self.assertEqual((Path(d)/'ai-moa-release.alias').stat().st_mode & 0o777,0o600)
            for name in ['ANDROID_KEYSTORE_PASSWORD','ANDROID_KEY_PASSWORD','ANDROID_KEY_ALIAS']:
                self.assertFalse(env[name] and env[name] in result.stdout+result.stderr, 'Credential value leaked')
            return result
    def test_distinct_passwords_and_nondefault_alias(self):
        self.assertNotEqual(self.inputs['ANDROID_KEYSTORE_PASSWORD'],self.inputs['ANDROID_KEY_PASSWORD'])
        self.assertEqual(self.restore().returncode,0)
    def test_wrong_key_password_fails(self):self.assertNotEqual(self.restore({'ANDROID_KEY_PASSWORD':'wrong-private-key-password'}).returncode,0)
    def test_missing_alias_fails(self):self.assertNotEqual(self.restore({'ANDROID_KEY_ALIAS':''}).returncode,0)
    def test_changed_certificate_fails(self):self.assertNotEqual(self.restore({'AI_MOA_EXPECTED_CERT_SHA256':'0'*64}).returncode,0)
    def test_gradle_patch_is_idempotent_and_uses_independent_inputs(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'android/app/build.gradle.kts';p.parent.mkdir(parents=True)
            p.write_text('plugins {}\nandroid {\n    buildTypes {\n        release {\n            signingConfig = signingConfigs.getByName("debug")\n        }\n    }\n}\n')
            for _ in range(2):subprocess.run(['python3',str(ROOT/'tool/apply-release-signing.py')],cwd=d,check=True)
            content=p.read_text()
            self.assertEqual(content.count('create("release")'),1)
            self.assertIn('keyAlias = System.getenv("ANDROID_RELEASE_KEY_ALIAS")',content)
            self.assertIn('keyPassword = System.getenv("ANDROID_RELEASE_KEY_PASSWORD")',content)
            self.assertNotIn('signingConfigs.getByName("debug")',content)

if __name__=='__main__':unittest.main()
