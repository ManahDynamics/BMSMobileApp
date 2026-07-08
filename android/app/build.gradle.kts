plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.manah.bms"
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
        applicationId = "com.manah.bms"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Configure release signing with your keystore
            // Create a keystore file and update signingConfigs below
            // signingConfig = signingConfigs.getByName("release")
            
            // Temporarily using debug signing for testing
            // Replace with proper release signing before store submission
            signingConfig = signingConfigs.getByName("debug")
            
            // Code shrinking disabled temporarily due to R8 conflicts
            // Re-enable after refining ProGuard rules
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    signingConfigs {
        create("release") {
            // TODO: Replace with your actual keystore details
            // storeFile = file("path/to/your/keystore.jks")
            // storePassword = "your_store_password"
            // keyAlias = "your_key_alias"
            // keyPassword = "your_key_password"
        }
    }
}

flutter {
    source = "../.."
}
