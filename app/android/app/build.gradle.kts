import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (spec 10). Three ways in, in priority order:
//   1. android/key.properties (a local release build; git-ignored)
//   2. the ANDROID_* environment variables, which CI fills from secrets and
//      which write a keystore decoded from ANDROID_KEYSTORE_BASE64
//   3. nothing at all — fall back to the debug keystore so
//      `flutter build apk --release` still works for anyone, including a
//      fork's CI run. The artifact is then named release-unsigned.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else if (!System.getenv("ANDROID_KEYSTORE_BASE64").isNullOrEmpty()) {
    val decoded = Base64.getDecoder()
        .decode(System.getenv("ANDROID_KEYSTORE_BASE64"))
    val target = File(rootProject.layout.buildDirectory.get().asFile, "spectra-release.jks")
    target.parentFile.mkdirs()
    target.writeBytes(decoded)
    keystoreProperties["storeFile"] = target.absolutePath
    keystoreProperties["storePassword"] = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: ""
    keystoreProperties["keyAlias"] = System.getenv("ANDROID_KEY_ALIAS") ?: ""
    keystoreProperties["keyPassword"] = System.getenv("ANDROID_KEY_PASSWORD") ?: ""
}
val hasReleaseKeystore = keystoreProperties["storeFile"] != null

android {
    namespace = "dev.spectra.spectra"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.spectra.spectra"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // No keystore: the debug keys keep `flutter build apk
                // --release` working. The workflow renames the artifact
                // release-unsigned so nobody mistakes it for a shippable one.
                logger.lifecycle("spectra: no release keystore; signing release-unsigned with the debug key")
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
