# Android Release Signing Setup

## Overview

To publish your app to the Google Play Store, you need to sign it with a release keystore. This document guides you through creating and configuring the keystore.

## Step 1: Generate a Release Keystore

Run the following command in your terminal:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

You'll be prompted to:
- Enter a keystore password (remember this!)
- Enter key password (remember this!)
- Enter your name, organization, city, state, and country code

**IMPORTANT:** Store this keystore file securely. If you lose it, you won't be able to update your app on the Play Store.

## Step 2: Reference the Keystore in the App

Create a file named `key.properties` in the `android/` directory (this file should NOT be committed to version control):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/path/to/your/upload-keystore.jks
```

## Step 3: Update build.gradle.kts

Modify `android/app/build.gradle.kts` to read from the key.properties file:

Add this at the top of the file (before the android block):

```kotlin
// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
```

Then update the singingConfigs block:

```kotlin
signingConfigs {
    create("release") {
        if (keystoreProperties.containsKey("storeFile")) {
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }
}
```

And update the release buildType:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

## Step 4: Add key.properties to .gitignore

Ensure `android/key.properties` is in your `.gitignore` file to prevent committing sensitive credentials:

```gitignore
android/key.properties
*.jks
```

## Step 5: Build the Release APK/AAB

Build the Android App Bundle (AAB) for Play Store submission:

```bash
flutter build appbundle --release
```

Or build an APK for testing:

```bash
flutter build apk --release
```

The output will be in:
- AAB: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/apk/release/app-release.apk`

## Step 6: Get SHA-256 Fingerprint for Firebase

After creating your keystore, get the SHA-256 fingerprint:

```bash
keytool -list -v -keystore ~/upload-keystore.jks -alias upload
```

Copy the SHA-256 certificate fingerprint and add it to:
- Firebase Console → Project Settings → Your apps → Android app → SHA certificate fingerprints

## Security Best Practices

1. **Never commit your keystore or key.properties to version control**
2. **Store the keystore in a secure location** (password manager, encrypted drive)
3. **Backup your keystore** in multiple secure locations
4. **Use strong passwords** for both keystore and key
5. **Document your passwords** in a secure location (you'll need them for future updates)

## Troubleshooting

### "Keystore file not found"
- Ensure the path in `key.properties` is correct
- Use absolute path or path relative to `android/` directory

### "Wrong password"
- Double-check the passwords in `key.properties`
- Ensure you're using the correct keystore and key passwords

### Build fails with signing errors
- Verify the keystore file exists
- Check that the key alias matches what you created
- Ensure all required properties are set in `key.properties`

## Current Status

- ✅ ProGuard rules configured
- ✅ Build configuration set up for release
- ⚠️ Keystore needs to be generated
- ⚠️ key.properties needs to be created
- ⚠️ build.gradle.kts needs to be updated with keystore properties
