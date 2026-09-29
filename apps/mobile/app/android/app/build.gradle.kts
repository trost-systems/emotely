import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // The app's store identity, shared with the original emotely listings on
    // both stores (see docs/adr/0012). It must never change.
    namespace = "de.emotely.emotely"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "de.emotely.emotely"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // The performance survey runs as an instrumentation test on
        // Firebase Test Lab (src/androidTest, #242). The runner and its
        // rules come with the integration_test plugin (as `api`); declaring
        // them here again fails the build on consistent resolution.
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // The survey measures a profile build, so its test APK must target the
    // profile variant: `./gradlew app:assembleAndroidTest
    // -PtestBuildType=profile`. Everything else keeps the default.
    testBuildType = (project.findProperty("testBuildType") as String?) ?: "debug"

    // Release signing uses the upload key from android/key.properties
    // (written by CI from secrets, never committed — see ADR 0013). Without
    // the file the release build signs with the debug key, so
    // `flutter run --release` keeps working on a dev machine.
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
        signingConfigs {
            create("upload") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("upload")
            } else {
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