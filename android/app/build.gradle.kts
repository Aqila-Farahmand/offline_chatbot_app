plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
    // When using the BoM, don't specify versions in Firebase dependencies
    // Add the dependency for the Firebase Authentication library
    implementation("com.google.firebase:firebase-auth")
    // MediaPipe Tasks GenAI LLM Inference API
    implementation("com.google.mediapipe:tasks-genai:0.10.24")
}
android {
    namespace = "it.aqila.farahmand.medicoai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "it.aqila.farahmand.medicoai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        multiDexEnabled = true
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        ndk {
            // Force only 64-bit ARM to avoid armeabi-v7a builds
            abiFilters.clear()
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    // Removed externalNativeBuild and JNI packaging since llama.cpp is no longer used on Android

}

flutter {
    source = "../.."
}
