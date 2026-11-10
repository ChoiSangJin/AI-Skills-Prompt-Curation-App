from pathlib import Path
p = Path('android/app/build.gradle.kts')
s = p.read_text()
if '// AI_MOA_FIXED_SIGNING' not in s:
    old = 'signingConfig = signingConfigs.getByName("debug")'
    if old not in s:
        raise SystemExit('Unexpected Flutter signing template; review manually.')
    s = s.replace('android {', '// AI_MOA_FIXED_SIGNING\nval releaseKeyStorePath = System.getenv("ANDROID_RELEASE_KEYSTORE")\n\nandroid {', 1)
    s = s.replace('    buildTypes {', '''    signingConfigs {
        create("release") {
            if (!releaseKeyStorePath.isNullOrBlank()) {
                storeFile = file(releaseKeyStorePath)
                storePassword = System.getenv("ANDROID_RELEASE_PASSWORD")
                keyAlias = "ai-moa"
                keyPassword = System.getenv("ANDROID_RELEASE_PASSWORD")
            }
        }
    }
    buildTypes {''', 1)
    s = s.replace('// TODO: Add your own signing config for the release build.', '// Fixed release identity; credentials are provided only at build time.').replace('// Signing with the debug keys for now, so `flutter run --release` works.', '')
    s = s.replace(old, 'signingConfig = signingConfigs.getByName("release")')
    s += '''
// Never produce a debug-signed or unsigned release when credentials are absent.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") } &&
        (releaseKeyStorePath.isNullOrBlank() || System.getenv("ANDROID_RELEASE_PASSWORD").isNullOrBlank())) {
        throw GradleException("Release signing is required. Configure the fixed AI Moa keystore.")
    }
}
'''
    p.write_text(s)
