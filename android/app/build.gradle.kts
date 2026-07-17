plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.audix.audix"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.audix.audix"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Raised for audio_service, flutter_secure_storage and background_downloader.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // --target-platform selects which *engine* libraries are packaged; it does not
        // constrain AGP. A plugin shipping a prebuilt .aar carrying every ABI gets its
        // libraries packaged regardless, leaving lib/armeabi-v7a/ and lib/x86_64/ holding
        // a couple of plugin libraries and none of the engine's.
        //
        // That is not dead weight but a trap: Android's installer picks the first
        // device-supported ABI with *any* entry under lib/ and does not check it is
        // complete, so a 32-bit-only device selects armeabi-v7a, installs, and dies at
        // startup on the missing libflutter.so. Everything works wherever arm64-v8a wins,
        // which is why it survives testing.
        //
        // Mirroring --target-platform here keeps one source of truth: the build command.
        ndk {
            val requested = (project.findProperty("target-platform") as String?)
                ?.split(",")
                ?.mapNotNull {
                    when (it.trim()) {
                        "android-arm" -> "armeabi-v7a"
                        "android-arm64" -> "arm64-v8a"
                        "android-x86" -> "x86"
                        "android-x64" -> "x86_64"
                        else -> null
                    }
                }
                .orEmpty()
            if (requested.isNotEmpty()) {
                // clear() first, and this has to be exactly here. The Flutter Gradle plugin
                // sets abiFilters to every ABI Flutter supports — deliberately, so Play does
                // not advertise x86 — and it does so from apply(), which Gradle runs when the
                // plugins {} block above is processed, i.e. before this block. So the set is
                // already full by now and addAll() alone silently changes nothing.
                //
                // Replacing it is safe because --target-platform already narrowed the engine
                // libraries to `requested`; this just makes the plugin libraries agree.
                //
                // If Flutter ever moves configureAbis() into afterEvaluate, this stops
                // working — silently. CI's inspect-apk check is what would catch that.
                abiFilters.clear()
                abiFilters.addAll(requested)
            }
            // Left alone for a plain `flutter build apk`, which keeps Flutter's own default.
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
